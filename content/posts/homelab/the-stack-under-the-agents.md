---
title: "The stack under the agents"
date: 2026-08-26
draft: false
tags: ["homelab", "kubernetes", "ai-agents", "security", "architecture"]
description: "A tour of the infrastructure a homelab needs before an AI agent is trustworthy enough to hold a Discord token: bare metal, GitOps, a tunnel instead of an open port, Key Vault reached over federated identity, and agents that can't see each other's credentials."
---

An agent that can read a calendar is a different kind of thing than an agent that plays
Pirate Borg over Discord. Both are "an LLM with tools," but only one of them should be
able to touch a real credential. Getting from "I ran an LLM locally" to "I run several
agents, each with its own identity, each provably unable to reach the others' tools and
secrets" took a stack of decisions, most of them boring on their own and only interesting
stacked on top of each other. This is that stack, bottom to top.

## The floor: bare metal, provisioned not hand-configured

Four nodes: `heavyarms` (Ryzen, 80GB RAM, RTX 1060) as the k3s server, three NUCs as
agents. Ansible takes a blank box to a joined k3s node — common config, NVIDIA drivers
and the container toolkit on the GPU node, then k3s install, in that order, because
agents join using a token the server has to already have generated. Ollama runs directly on `heavyarms`'s host, not as a Kubernetes workload —
there's exactly one GPU in the building and no benefit to pretending it could be
scheduled elsewhere.

Nothing here is clever. That's the point — adding a node is "add it to `hosts.yml`,
re-run the playbook," not a page of tribal knowledge about which machine needed which
manual step.

## GitOps: one repo, ArgoCD as the only thing that touches the cluster

Everything above the OS is declared in this repo and reconciled by ArgoCD via an
app-of-apps — one `Application` per component, each pointing at its own manifests
directory. Adding a service is always the same three steps: manifests, an `Application`
template, wait for the next sync. No separate deploy step exists to forget.

The corollary bit us once: ArgoCD self-heals drift, which also means an uncommitted
`kubectl edit` gets silently reverted on the next sync. Anything not in git doesn't
exist as far as the cluster is concerned, including a fix you were sure you'd applied.

## Edge: no open port, a tunnel instead

Nothing is forwarded on the home router. Two separate Cloudflare Zero Trust Tunnels do
the work: `ugreen-nas` fronts the NAS directly, `homelab-k8s` fronts Traefik inside the
cluster and lets `IngressRoute`s take it from there. Splitting NAS and cluster into two
tunnels means a compromised token on one doesn't hand over the other.

![Edge and DNS: two Cloudflare tunnels routing to the NAS and to Traefik inside the cluster](/images/homelab/diagrams/network.svg)

Both tunnels are outbound-initiated — cloudflared as a container on the NAS, an
in-cluster connector for the k8s side. The firewall never has anything to allow in.

## Identity: two ways in, neither with a standing credential

Two separate questions with one shared rule. A pod needs a secret from Azure; a person
needs to reach a service. Neither gets a long-lived credential parked somewhere waiting
to be stolen.

**Machines to Azure.** Secrets live in Azure Key Vault, reached through Workload
Identity Federation — every pod that needs one trades a k3s-issued OIDC token for Azure
AD trust, per request. No standing Azure credential sits in the cluster.

The design choice worth calling out is what Azure AD is allowed to see to validate that
OIDC token. Validation needs the cluster's discovery documents, and the direct route —
Azure reaching the live k3s apiserver's discovery endpoint — means exposing that
endpoint to something unauthenticated. Instead a static file server
(`k8s-oidc-discovery`) serves just the two documents Azure needs, the OpenID
configuration and the JWKS, fetched once per pod start by an initContainer. Azure AD
never talks to the apiserver.

![Secrets flow: k3s-issued OIDC token, static discovery server, Azure AD, Key Vault, ExternalSecrets Operator](/images/homelab/diagrams/secrets-wif.svg)

`external-secrets` and a `ClusterSecretStore` sync the vault into the cluster;
`jellyfin-mcp` and `hermes-agent` consume it. Still open: Key Vault network ACLs, and
the JWKS refresh path for key rotation.

**People to services.** Every hostname behind either tunnel sits behind a Cloudflare
Access policy — admin email plus WARP device posture, 12-hour session. Authentication
happens at Cloudflare's edge, before a request reaches the tunnel, so an unauthenticated
request never touches anything running in the house.

![Auth flow: Entra ID auth flow](/images/homelab/diagrams/auth-flow.svg)

## The agents themselves: hard isolation, no exceptions

This is the newest layer, and the one the rest of the stack exists to support safely.
`hermes-agent` runs one container hosting multiple agent "profiles" — a Discord RPG game
master, a Jellyfin concierge, an admin dashboard. Each profile that talks to a human has
its own Discord bot application, its own token (delivered as a file at
`/opt/data/profiles/<name>/.env`, never a container-wide env var), its own `config.yaml`
naming only the MCP tools that agent needs, and its own supervised gateway process. A
tool an agent shouldn't have isn't policy-blocked, it's architecturally absent from that
process — an agent that only runs Pirate Borg sessions cannot reach a token that reads a
calendar, because that token isn't in its process.

Every profile is named `<character>_<domain>`, Cyberpunk 2077-sourced. Eight live agents
(`delamain`, `rogue_storyteller`, `gm_researcher`, `jackie_goals`, `hanako_career`,
`judy_journal`, `panam_circle`, `viktor_health`) share one deliberately shared layer —
the same Hindsight backend, isolated by `bank_id` — so shared infrastructure doesn't
mean shared recall.

![Agent isolation: per-profile Discord identity, per-profile MCP tool scope, shared Hindsight memory split by bank_id](/images/homelab/diagrams/agent-isolation.svg)

Some costs don't have a shortcut: every new agent identity is a manual trip to the
Discord developer portal, since bot applications can't be created via API, and each one
separately needs privileged intents enabled before it can connect.

## The tools agents actually call

Above the identity layer sit the MCP servers themselves — small, single-purpose Go
services, each independently built and deployed: `jellyfin-mcp` wraps the Jellyfin API,
`stock-mcp` does market-data lookups (Finnhub for quotes, Yahoo for history), `dice-mcp`
rolls dice for tabletop sessions, `viktor-health-mcp` wraps Google Health, and HolmesGPT
(a third-party Helm chart, not hand-written manifests) does cluster investigation. Same
shape every time — Go source and manifests in their own directory, an Application
template, its own CI workflow gated on changes to its own path.

![GitOps application flow: git to ArgoCD to the app-of-apps to per-component Application templates, with cloudflared and Ollama deployed out of band](/images/homelab/diagrams/app-flow.svg)

## Where it stands

Live and holding: four provisioned nodes, GitOps as the only write path to the cluster,
two tunnels with zero open inbound ports, WIF-backed Key Vault secrets for four services
(`hermes-agent`, `jellyfin-mcp`, `stock-mcp`, `viktor-health-mcp`), eight hard-isolated
agents each with their own Discord identity and memory bank.

Known and not yet closed: Key Vault network ACLs, the JWKS refresh cronjob, and — the
sharpest edge — hard-isolated agent profiles don't currently auto-start after a pod
restart the way the container's default profile does. Each one needs `hermes profile
use <name> && hermes gateway start` run by hand after any restart, which is a gap, not
a design choice, and the next thing to close.

None of this is required for a personal LLM chatbot. It gets required the moment an
agent is asked to hold anything real.
