---
title: "The Homelab"
description: "A k3s cluster in my living room: what runs on it, why each piece is there, and how to use it. Living document — updated as the cluster changes."
groupByYear: false
cardView: true
---

{{< lead >}}
A five-node k3s cluster under my desk, managed by ArgoCD, exposed through Cloudflare
Zero Trust. This page is the map. Every component links to how it works and how to use it.
{{< /lead >}}

{{< alert icon="circle-info" >}}
This is a **living document**, not a dated post. It describes what is running now. For the
story of how it got here, see the [homelab-ai-platform series](/posts/homelab/).
{{< /alert >}}

## The map

Everything that is actually deployed, grouped by the job it does.

{{< mermaid >}}
graph TB
    subgraph EDGE["Edge"]
        CFT["Cloudflare Tunnel<br/>zero inbound ports"]
        TRA["Traefik<br/>ingress + TLS"]
        MLB["MetalLB<br/>.200-.220"]
    end

    subgraph PLAT["Platform"]
        ARG["ArgoCD<br/>app-of-apps"]
        CM["cert-manager<br/>internal CA"]
        ESO["External Secrets<br/>installed, not yet wired"]
    end

    subgraph SVC["My services"]
        HP["headroom-proxy<br/>LLM compression"]
        JM["jellyfin-mcp"]
        SM["stock-mcp"]
        HA["hermes-agent"]
    end

    subgraph OPS["Operations"]
        MON["monitoring<br/>Grafana"]
        HG["HolmesGPT<br/>AI triage"]
    end

    subgraph HOST["On the host, not in k8s"]
        OLL["Ollama<br/>heavyarms :11434"]
    end

    CFT --> TRA
    MLB --> TRA
    TRA --> JM
    TRA --> SM
    TRA --> HA
    TRA --> MON
    ARG -.reconciles.-> SVC
    ARG -.reconciles.-> OPS
    CM -.issues certs.-> TRA
    HP --> OLL
    HA --> HP
    HG -.watches.-> PLAT
{{< /mermaid >}}

Two things that surprise people:

**Ollama is not in Kubernetes.** It runs directly on `heavyarms` via Ansible
(`ansible/roles/ollama/`), because it needs the GPU without fighting device-plugin
scheduling. Cluster workloads reach it as an external host at `192.168.86.44:11434`.

**headroom-proxy has no ingress.** It is cluster-internal only. Nothing outside the
cluster can reach it, by design.

## The hardware

| Node | Role | Hardware | IP |
|---|---|---|---|
| heavyarms | k3s server | Tower · Ryzen 8c · 80 GB · RTX 1060 | 192.168.86.44 |
| exia | k3s agent | NUC7i5DNK | 192.168.86.55 |
| kyrios | k3s agent | NUC7i5DNK | 192.168.86.47 |
| dynames | k3s agent | NUC7i5DNK | 192.168.86.41 |
| idx6011-a622 | NAS (NFS) | UGREEN, UGOS Pro | 192.168.86.49 |

Two NUC11 nodes (`wing`, `deathscythe`) are racked but not joined. They have been "pending"
long enough that it is a decision, not a backlog item.

## How anything gets deployed

Three layers, each with a different trigger.

{{< mermaid >}}
graph LR
    A["Ansible<br/>ansible/"] -->|"OS, k3s, NVIDIA, Ollama"| B["Bare metal"]
    C["kubectl + kustomize<br/>k8s/bootstrap/"] -->|"one-time, by hand"| D["Cluster primitives"]
    E["ArgoCD app-of-apps<br/>k8s/apps/templates/"] -->|"on git push"| F["Ten applications"]
    B --> D --> F
{{< /mermaid >}}

1. **Ansible** provisions the metal — OS, k3s, NVIDIA drivers, and Ollama. Run by hand,
   rarely.
2. **Bootstrap** (`k8s/bootstrap/`) installs what has to exist before GitOps can work:
   ArgoCD itself, MetalLB, Traefik, cert-manager, External Secrets. Applied once with
   `kubectl apply -k`.
3. **GitOps** — after that, ArgoCD's app-of-apps watches `k8s/apps/templates/` and
   reconciles ten applications. Adding a service means committing a manifest, not running
   a command.

The bootstrap/GitOps split is the part worth copying. Anything ArgoCD manages will heal
itself and go `OutOfSync` when reality drifts. Anything outside it will rot silently — I
lost a whole service that way, which is [its own story](/posts/homelab/006-eight-weeks-later-what-the-homelab-actually-runs/).

## How a request reaches a service

There are no forwarded ports on my router. Nothing listens on the public internet.

1. A request for `jellyfin-mcp.apexarcology.com` hits **Cloudflare**.
2. Cloudflare routes it down an **outbound-only tunnel** held open by `cloudflared`.
3. The tunnel terminates at **Traefik**, on a **MetalLB** LoadBalancer IP in
   `192.168.86.200–220`.
4. Traefik matches the `Host()` rule in the service's `IngressRoute` and forwards to the
   **Service**, which load-balances to **Pods**.
5. Internal TLS is issued by **cert-manager** from a self-signed cluster CA.

The tunnel is the reason this is safe to run at home. There is no inbound firewall rule to
get wrong.

## Components

Each page covers what it is, why I chose it, how to use it, and what breaks.

### My services

- **[headroom-proxy](headroom-proxy/)** — OpenAI-compatible proxy that compresses prompts
  before they reach a model. Routes across Ollama, Anthropic, OpenAI, and Gemini.
- **[jellyfin-mcp](jellyfin-mcp/)** — MCP server exposing my media library to agents.
- **[stock-mcp](stock-mcp/)** — MCP server for market data.
- **[hermes-agent](hermes-agent/)** — the agent that actually talks to me, over WhatsApp
  and Discord.

### Edge

- **[Cloudflare Tunnel](cloudflared/)** — public access with zero open ports.
- **[Traefik](traefik/)** — ingress and hostname routing.
- **[MetalLB](metallb/)** — LoadBalancer IPs on bare metal.

### Platform

- **[ArgoCD](argocd/)** — GitOps reconciliation.
- **[cert-manager](cert-manager/)** — internal certificate authority.
- **[External Secrets](external-secrets/)** — installed, but not yet wired to anything.

### Operations

- **[monitoring](monitoring/)** — Grafana, currently with no metrics backend.
- **[HolmesGPT](holmesgpt/)** — AI-assisted incident triage.

{{< alert icon="circle-info" >}}
Two of those pages document things that are **not finished**. External Secrets is running
with zero `ExternalSecret` resources, and Grafana has no Prometheus behind it. Both are
written up as they are, because a map that only shows the working parts is not a map.
{{< /alert >}}

## The story

The map tells you what. These tell you why:

1. [Building an AI agent platform at home](/posts/homelab/001-building-an-ai-agent-platform-at-home/)
2. [Five ADRs in a weekend](/posts/homelab/003-five-adrs-in-a-weekend/)
3. [The Night City Crew](/posts/homelab/004-the-night-city-crew/)
4. [An AI personal trainer workflow](/posts/homelab/005-ai-personal-trainer-workflow/)
5. [Eight weeks later: what the homelab actually runs](/posts/homelab/006-eight-weeks-later-what-the-homelab-actually-runs/)
