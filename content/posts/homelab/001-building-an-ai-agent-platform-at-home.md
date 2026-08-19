---
title: "Building a Production-Grade AI Agent Platform in My Living Room"
date: 2026-06-24
draft: false
tags: ["homelab", "kubernetes", "k3s", "argocd", "ai-agents", "gitops"]
series: ["homelab-ai-platform"]
description: "My home cluster runs k3s, ArgoCD, Cloudflare Tunnel, and an agent registry built on the open-source Hermes-agent project. Here is how I structured the infrastructure and why."
---

## Origin

Like most homelabs, this started with a single Raspberry Pi running Pi-hole. When the Pi ran out of overhead, I picked up a few used NUCs. Later came a desktop tower for heavier compute, followed by a UGREEN NAS to get away from storing state on local node disks. 

On the AI side, I initially relied on commercial API endpoints like Anthropic and OpenAI. That works well for simple scripts, but token costs add up quickly when testing and refining agent workflows. To keep iteration cheap, I shifted to running models locally.

Setting up local inference was simple enough—Ollama on the desktop tower handles 7B and 13B models easily on an RTX 1060. However, running isolated models exposed a different problem: none of them had a clean way to coordinate, share state, or interact with the rest of the local network. 

I wanted a system where agents could self-register, discover other services, maintain persistent memory, and execute tasks across the cluster. Building that required treating it as a platform rather than a collection of Docker Compose files. That meant committing to proper storage, secret distribution, service discovery, and observability on Kubernetes.

| Node | Type | CPU | RAM | GPU | Role |
|------|------|-----|-----|-----|------|
| **heavyarms** | Tower | Ryzen 8-core | 80 GB | RTX 1060 6 GB | Primary compute |
| **exia** | NUC7i5 | i5 | — | — | k3s worker |
| **kyrios** | NUC7i5 | i5 | — | — | k3s worker |
| **dynames** | NUC7i5 | i5 | — | — | k3s worker |
| *(2x NUC11)* | NUC11 | — | — | — | Staged / waiting |
| UGREEN NAS | NAS | — | — | — | Persistent storage |

The environment runs on k3s, configured via GitOps through ArgoCD, and exposed through Cloudflare Zero Trust.

## Kubernetes

k3s keeps control-plane resource consumption low enough to run comfortably on older NUCs. The alternative was running Docker Compose on the NAS, which works fine for basic services, but lacks automated reconciliation through ArgoCD, proper ingress routing via Traefik, or cluster-wide load balancing with MetalLB.

## Core Architecture

The infrastructure layers break down as follows:

| Layer | Tool | Rationale |
|-------|------|-----------|
| Orchestration | k3s v1.29.4 | Lightweight footprint, embedded registry, vxlan CNI |
| Infra as Code | Terraform | Provisioning DNS records and NAS storage configurations |
| GitOps | ArgoCD | App-of-Apps pattern with automated git sync |
| Load Balancer | MetalLB | Bare-metal `LoadBalancer` integration using `192.168.86.200-220` |
| Ingress | Traefik v26.1.0 | `IngressRoute` CRD routing and TLS termination |
| Certificates | cert-manager | Internal TLS via a self-signed cluster CA |
| External Access | Cloudflare Tunnel | Zero Trust ingress without open inbound firewall ports |
| Secrets | External Secrets Operator | Syncing secrets safely from Azure Key Vault into k8s |
| Monitoring | VictoriaMetrics + Grafana | Significantly lower memory footprint than standard Prometheus stacks |
| AI Ops | HolmesGPT | Cluster diagnostics with Discord alert routing |
| Agent Registry | Hermes | Open-source agents ([NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)) modified for k3s |

Internal services route through `*.home.lab`. Access to interfaces like ArgoCD, Grafana, and Jellyfin requires authentication through Cloudflare Access paired with WARP device posture checks.

## Tooling via MCP Servers

Agents interact with external systems using [MCP](https://modelcontextprotocol.io) servers deployed into the cluster:

| MCP Server | Domain | Capability |
|------------|--------|------------|
| `stock-mcp` | Financial Data | Market pricing and ticker metadata queries |
| `jellyfin-mcp` | Media | Library indexing and media playback management |
| `homeassistant-mcp` | Automation | State queries and control for home sensors and switches |
| `tavily-mcp` | Search | Real-time web search retrieval |

Additional MCP servers are deployed as new integration requirements surface. I will cover the discovery mechanism and agent routing logic for these tools in a subsequent post.

## Deployment Workflow

Adding new workloads follows a standardized pattern:

1. Add manifests and `kustomization.yaml` under `k8s/bootstrap/<app>/`.
2. Register the ArgoCD `Application` in `k8s/apps/templates/<app>.yaml`.
3. Configure the `IngressRoute` for `<app>.home.lab`.
4. Apply the corresponding DNS CNAME record in `nas/dns/main.tf`.

Once committed to the repository, ArgoCD syncs the changes automatically.

```yaml
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