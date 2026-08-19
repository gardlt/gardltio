---
title: "Building a Production-Grade AI Agent Platform in My Living Room"
date: 2026-06-24
draft: false
tags: ["homelab", "kubernetes", "k3s", "argocd", "ai-agents", "gitops"]
series: ["homelab-ai-platform"]
description: "My home cluster runs k3s, ArgoCD, Cloudflare Tunnel, and an agent registry built on the open-source Hermes-agent project. Here's why I built it and what it looks like."
---

## Where this started

The original server was a Raspberry Pi. It ran Pi-hole and not much else — "cluster" would have been a generous word for it. I added a few NUCs once the Pi ran out of headroom, then a tower for anything that needed real compute, then a UGREEN NAS to stop treating every node's local disk as permanent storage. It grew the way homelabs grow: one box at a time, each one covering for whatever the last one couldn't do.

For AI, I started the way most people do — calling the Anthropic and OpenAI APIs directly. That worked fine right up until the invoices did. Iterating on agent behavior means a lot of calls, and token costs scale with every dumb mistake in a prompt. I wanted something more economical, which meant running models myself instead of renting someone else's.

Then I started running local AI models. Ollama on the tower, a few inference endpoints, some scripts that called them. The problem wasn't compute — heavyarms has an RTX 1060 that handles 7B and 13B models fine. The problem was coordination. The models were isolated. They couldn't call each other, share context, or act on the cluster they lived in. Each one was a dead end.

I wanted agents. Not chatbots — agents that register themselves, discover each other, maintain memory across sessions, and operate on real infrastructure. That meant building a platform, not just running models. I wanted it on Kubernetes instead of a pile of Compose files, and I wanted the NAS doing what NASes are good at — persistent storage — instead of every node hoarding its own state. Building a platform meant making real decisions about protocols, storage, secrets, observability, and discovery.

This is that story, from the first decision to where we landed.

---

| Node | Type | CPU | RAM | GPU | Role |
|------|------|-----|-----|-----|------|
| **heavyarms** | Tower | Ryzen 8-core | 80 GB | RTX 1060 6 GB | Primary compute |
| **exia** | NUC7i5 | i5 | — | — | k3s worker |
| **kyrios** | NUC7i5 | i5 | — | — | k3s worker |
| **dynames** | NUC7i5 | i5 | — | — | k3s worker |
| *(2x NUC11)* | NUC11 | — | — | — | Staged / waiting |
| UGREEN NAS | NAS | — | — | — | Persistent storage |

The whole thing is powered by k3s, declaratively managed through ArgoCD, and exposed via Cloudflare Zero Trust — no VPN, no port forwarding, no `/etc/hosts` hacks.

I didn't build this for the flex. I built it because I wanted a real platform to run AI agents at home: agents that coordinate with each other, persist memory across sessions, and operate on actual infrastructure rather than a laptop demo environment.

## Why Kubernetes for a homelab?

This comes up every time I talk about this setup. The honest answer: I want the same primitives I use at work. GitOps, declarative configuration, rolling updates, health probes, secrets management that doesn't involve hardcoding tokens in a shell script. Kubernetes gives me all of that at home. k3s specifically gives me Kubernetes without the control-plane overhead — one binary, embedded etcd, runs fine on a NUC7.

The alternative is Docker Compose on the NAS, which I also do for a handful of services. But Compose doesn't give me ArgoCD reconciliation, MetalLB load balancing, or Traefik ingress with cert-manager TLS. Once you have those, every new service is four files and a commit.

## The stack

The platform layers break down clearly:

| Layer | Tool | Why |
|-------|------|-----|
| Orchestration | k3s v1.29.4 | Lightweight k8s, embedded registry, vxlan CNI |
| Infra as Code | Terraform | DNS records and NAS-side config |
| GitOps | ArgoCD | App-of-Apps pattern, auto-sync on commit |
| Load Balancer | MetalLB | Bare-metal `LoadBalancer` type, IP pool `192.168.86.200-220` |
| Ingress | Traefik v26.1.0 | `IngressRoute` CRDs, TLS termination |
| Certificates | cert-manager | Self-signed cluster CA for internal TLS |
| External Access | Cloudflare Tunnel | Zero Trust exposure, no inbound firewall rules |
| Secrets | External Secrets Operator | GitOps-safe secret sync from Azure Key Vault |
| Monitoring | VictoriaMetrics + Grafana | ~10x lighter than kube-prometheus-stack on NUC7 nodes |
| AI Ops | HolmesGPT | AI-powered k8s investigator, Discord alert integration |
| Agent Registry | Hermes | Open-source gRPC/REST agent discovery service ([NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)), adapted for k3s (more on this below) |

Everything has a URL at `*.home.lab`. ArgoCD, Grafana, HolmesGPT, stock-mcp, the NAS UI, Jellyfin, Photos — all behind Cloudflare Access with WARP device posture. No service touches the public internet without passing Zero Trust first.

## Giving agents tools: MCP servers

Agents are only as useful as the tools they can reach, and tool access happens through [MCP](https://modelcontextprotocol.io) servers deployed on the cluster like everything else.

| MCP Server | Domain | Gives agents |
|------------|--------|---------------|
| `stock-mcp` | Market data | Pricing and ticker lookups |
| `jellyfin-mcp` | Media | Query and control the Jellyfin library instead of just watching it get monitored |
| `homeassistant-mcp` | Home automation | Query and control Home Assistant entities — lights, sensors, switches, automations |
| `tavily-mcp` | Web search | Live web search and page retrieval for anything not already in an agent's memory |

That's not staying at four — more MCP servers are already planned as the agent roster grows, one per domain an agent needs to act in, so this gets its own section rather than a handful of rows buried in the stack table.

I'll cover the MCP layer in more depth — what's deployed, how agents discover which server has which tool, and how that ties into the Night City Crew roster — in a later post in this series.

## Adding a service takes four steps

The pattern is consistent enough that I have it memorized:

1. Create `k8s/bootstrap/<app>/` with manifests and a `kustomization.yaml`
2. Add an ArgoCD `Application` to `k8s/apps/templates/<app>.yaml`
3. Add an `IngressRoute` pointing to `<app>.home.lab`
4. Add the ingress rule and DNS CNAME to `nas/dns/main.tf`

Commit and push. ArgoCD picks it up within 3 minutes.

```yaml
# IngressRoute pattern
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: <app>
  namespace: <app>
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`<app>.home.lab`)
      kind: Rule
      services:
        - name: <app>
          port: 80
  tls:
    secretName: <app>-tls
```

## The part that took the most thinking: agents

Everything above is solved infrastructure. MetalLB, Traefik, ArgoCD — all of these are well-documented, community-maintained, and just work if you follow the docs.

Agents are not a solved problem. If you want AI agents to coordinate on a Kubernetes cluster — discovering each other, calling each other over gRPC, maintaining persistent memory, operating within a GitOps workflow — you have to make decisions. Which agent framework? Which memory system? How do secrets flow to agent pods? What does observability look like when the thing being monitored is an AI agent's behavior, not just its CPU usage?

I wrote eight Architectural Decision Records (ADRs) to answer these questions. Each one scored candidates against my actual requirements rather than hype. The results were sometimes surprising:

- **Agent registry**: Adopted [Hermes-agent](https://github.com/NousResearch/hermes-agent) (NousResearch, open source) rather than building one from scratch, then adapted it to be k3s-native and ArgoCD-compatible.
- **Memory system**: Hindsight for TEMPR four-strategy retrieval — graph + temporal + semantic + keyword, self-hosted, with a real Helm chart.
- **Monitoring**: VictoriaMetrics over kube-prometheus-stack. The NUC7 nodes have ~16 GB RAM shared across all workloads. VictoriaMetrics uses ~400 MB; kube-prometheus-stack uses 2–3 GB.
- **DNS**: Cloudflare Tunnel, because for simplicity and support

The next posts in this series go deep on each of these. Starting with Hermes, because adapting it into the platform was the most interesting part of this whole build.

## What's next

- **Post 2**: Hermes — adopting and adapting NousResearch's open-source agent registry, agents, and what it looks like deployed on k3s.