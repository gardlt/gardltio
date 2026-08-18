---
title: "Five Infrastructure ADRs in a Weekend: Storage, Secrets, Monitoring, Memory, and DNS"
date: 2026-06-24
draft: false
tags: ["homelab", "kubernetes", "adr", "victoria-metrics", "cloudflare", "hindsight", "gitops"]
series: ["homelab-ai-platform"]
series_order: 2
description: "How scored Architectural Decision Records resolved storage, secrets, monitoring, memory, and DNS for a home AI agent cluster — and what each decision cost."
---

{{< alert icon="circle-info" >}}
**Update, 2026-08-16.** Two of these five decisions shipped. One stalled halfway
and two were never started at all. There is [a scorecard at the end of this
post](#update-2026-08-16-what-actually-happened) — the post itself is left as
written.
{{< /alert >}}

After deciding to build Hermes, I had the agent registry. What I didn't have was the infrastructure beneath it: persistent storage for agent state and metrics, a secrets backend that works in GitOps, an observability stack that fits on NUC7 nodes, a memory system for agents, and a DNS strategy that doesn't require editing `/etc/hosts` on every client.

I ran five ADRs over a weekend. The format was the same each time: define dimensions, score candidates honestly, accept the result. Here's what I decided and why.

---

## ADR 002 — Memory System: Hindsight over Mem0

**Problem**: Agents need persistent memory — stored context, learned behavior, prior decisions — that survives restarts and is queryable across sessions.

Mem0 was already deployed on the cluster. It had 48K GitHub stars and a working Docker container. Switching to anything else meant decommissioning a running service and migrating data.

The alternative was **Hindsight** by Vectorize.io — a newer system built around TEMPR: four simultaneous retrieval strategies running in parallel.

| Retrieval Strategy | What it does |
|---|---|
| Semantic | Vector similarity — "find memories about Kubernetes storage" |
| Keyword/BM25 | Exact keyword match — "find memories containing 'Longhorn'" |
| Graph | Relationship traversal — "what did this agent decide that led to X" |
| Temporal | Time-range queries — "what happened last month" |

Mem0 offers semantic retrieval on the free/self-hosted tier. Graph retrieval — the ability to traverse relationships between memories — is locked behind the Pro tier at $249/month. I need graph retrieval. That's not a nice-to-have; agents reasoning about prior decisions need to trace chains of causality, not just surface similar-sounding memories.

Scored four dimensions (retrieval quality, feature gating, Kubernetes/Helm deployment, per-agent memory bank config). Hindsight won all four, 12 vs 4. M5–M7 weren't scored — the sweep was decisive enough that they couldn't change the outcome.

**Result**: Mem0 decommissioned. Hindsight deployed via official Helm chart, ArgoCD-managed. Each agent gets a configurable memory bank with Mission, Directives, and Disposition fields — a personality and behavioral contract baked into how it stores and retrieves memories.

**What it cost**: Migrating away from a running service. Not insurmountable, but real switching cost. The ADR made the case that TEMPR's graph retrieval was worth it.

---

## ADR 005 — Storage: R2 for Objects, NAS for Block

**Problem**: No persistent storage layer existed. All current workloads were stateless or relied on NAS-hosted Docker Compose. The cluster needed PVCs for agent memory backends, Prometheus/VictoriaMetrics retention, and Grafana persistence.

Two tiers required:
- **Object storage** (S3-compatible, for backups and artifacts): **Cloudflare R2 + csi-s3** vs **MinIO**
- **Block storage** (RWO PVCs for databases): **Longhorn** vs **NFS from existing NAS**

**Object storage**: R2 won easily (17 vs 9). The complete design already existed in `docs/network-storage-r2.md`. The Terraform was partially written. R2 has zero egress fees. The operational cost is minimal — a CSI DaemonSet using csi-s3/geesefs for FUSE-mounted S3 buckets. MinIO is excellent for on-cluster S3 but requires significant disk allocation and operational overhead that wasn't justified at homelab scale.

**Block storage**: More interesting. Longhorn is the "right" answer for production — configurable replication, scheduled snapshots, built-in UI. But P1 (block storage priority) was scored C: "not needed yet, defer block storage." Without a hard requirement for RWO PVCs right now, Longhorn's complexity wasn't justified.

NFS from the existing UGREEN NAS won (11 vs 7) for block. It's already there, the NAS is reliable, and the `nfs-subdir-external-provisioner` StorageClass adds it to Kubernetes in one Helm install. The tradeoff is real: no HA, no RWO (NFS is RWX only), NAS is a single point of failure. I'll revisit Longhorn when agents need true block storage.

**Result**: Cloudflare R2 + csi-s3 for objects. NAS NFS for block. Longhorn deferred.

---

## ADR 006 — Monitoring: VictoriaMetrics over kube-prometheus-stack

**Problem**: The cluster had Grafana deployed with no data sources, no dashboards, a hardcoded `admin` password, and no persistence. No Prometheus, no AlertManager, no metrics collection.

The NUC7i5DNK nodes are resource-constrained — approximately 16 GB RAM per node, shared across all workloads. Every megabyte allocated to monitoring is a megabyte not available to agents.

Four candidates: kube-prometheus-stack, VictoriaMetrics + Grafana, Grafana Cloud (Alloy agent), Netdata.

The scores broke down clearly once I hit M5 (resource budget):

| Stack | Approx RAM | Notes |
|---|---|---|
| kube-prometheus-stack | 2–3 GB | Full Prometheus + Grafana + AlertManager + exporters |
| VictoriaMetrics | 300–500 MB | VictoriaMetrics + VMAgent + Grafana + VMAlert |
| Grafana Cloud (Alloy) | ~64 MB | Alloy agent only; cloud backend required |
| Netdata | ~100 MB/node | Per-node agent; not Prometheus-compatible |

Grafana Cloud would have won on resource usage, but M1 (self-hosted, no cloud dependency) eliminated it — metrics and logs staying on-cluster is a hard requirement. Netdata was eliminated by not being Prometheus-compatible (M2) and poor k8s-native metric support (M6). kube-prometheus-stack lost on M5 alone — 2–3 GB on NUC7 nodes is too much.

VictoriaMetrics won at 17 vs 13 (kube-prometheus-stack) vs 15 (Grafana Cloud) vs 11 (Netdata). MetricsQL is a Prometheus superset — all existing dashboards and exporters work without modification. VictoriaLogs handles log aggregation without adding another system. VMAlert routes to Discord, complementing HolmesGPT's existing AI-generated findings.

**Result**: VictoriaMetrics + Grafana. Existing standalone Grafana HelmRelease replaced with the victoria-metrics-k8s-stack chart. Hardcoded admin password removed (routed through External Secrets Operator from ADR 004).

---

## ADR 004 — Secrets: Azure Key Vault + External Secrets Operator

**Problem**: Secrets can't live in Git. GitOps requires secrets to be declarative, but a `Secret` manifest with a plaintext password committed to a repository defeats the point.

External Secrets Operator (ESO) was already in the cluster — it syncs secrets from an external backend into Kubernetes `Secret` objects on a defined schedule. The question was which backend.

Options evaluated: HashiCorp Vault (self-hosted), AWS Secrets Manager, Azure Key Vault with Workload Identity OIDC, and Doppler.

The homelab already had Azure investment (planned Azure AI Foundry and APIM workloads). Azure Key Vault with Kubernetes Workload Identity OIDC won: it requires no additional self-hosted service (unlike Vault), integrates cleanly with ESO's `ClusterSecretStore`, and the Workload Identity OIDC flow means pods authenticate to Azure without any credentials in the cluster — just an annotated ServiceAccount and a federated identity credential in Azure AD.

**Result**: Azure Key Vault as the ESO backend. Pod authentication via Workload Identity OIDC. All secrets flow: AKV → ESO → Kubernetes `Secret` → pod env var. No plaintext secrets in Git.

---

## ADR 007 — DNS: Cloudflare Tunnel

**Problem**: k8s services (ArgoCD, Grafana, HolmesGPT, stock-mcp) were accessible only via manual `/etc/hosts` entries. Adding a new device meant editing the hosts file again.

Candidates: Pi-hole, AdGuard Home, CoreDNS extension (already running in k3s), Cloudflare Tunnel.

The decision was made quickly. `nas/dns/` already contained working Terraform (Cloudflare provider v4.52.7) exposing `nas.apexarcology.com`, `photos.apexarcology.com`, and `jellyfin.apexarcology.com` through a Cloudflare Tunnel connector running in UGOS Pro Docker. The pattern was proven and operational.

Extending it to k8s services meant deploying a second `cloudflared` connector as a Kubernetes Deployment and adding `ingress_rule` blocks to the tunnel config for each new service. Same pattern, new tunnel target.

**Result**: Cloudflare Tunnel. `/etc/hosts` instructions removed from README. All services at `*.apexarcology.com` route through Cloudflare Zero Trust. Access requires Cloudflare WARP device enrollment — no exposed ports on the home router.

---

## What five ADRs in a weekend taught me

The scoring process doesn't eliminate judgment — it structures it. The dimensions you choose reflect the requirements you actually have. If you're not honest about what you need, the scores will reflect your biases rather than your constraints.

The most important discipline was accepting the result when it was the uncomfortable answer. Replacing Mem0 (already deployed, already working) with Hindsight because graph retrieval was a hard requirement — that was uncomfortable. Choosing NFS over Longhorn when Longhorn is clearly the more capable system — that required acknowledging that "more capable" doesn't mean "right for right now."

The ADR spec for each of these decisions lives in `specs/` in the repository. Each one has the full scoring table and rationale. Future me (and anyone else reading the repo) can see exactly why each choice was made and what the tradeoffs were.

Next: the Night City Crew — a roster of seven specialized AI agents named after Cyberpunk 2077 characters, each with a defined role, a personality contract, and a set of tool integrations.

## Update, 2026-08-16: what actually happened

Written eight weeks after the fact, checked against the repository rather
than against memory.

Deciding is cheap. Four of these five ADRs read like the work was done, and it
wasn't. Here is the scorecard.

| ADR | Decision | Reality |
|---|---|---|
| 002 | Memory: Hindsight | **Shipped**, but on the NAS via docker-compose (`nas/memory/`), not in the cluster |
| 004 | Secrets: Azure Key Vault + ESO | **Half.** The operator is installed; there are zero `ExternalSecret` resources |
| 005 | Storage: R2 for objects, NAS for block | **Not started.** No R2, no `csi-s3`, no NFS anywhere in `k8s/` |
| 006 | Monitoring: VictoriaMetrics | **Not started.** The string "victoria" appears nowhere in the repo |
| 007 | DNS: Cloudflare Tunnel | **Shipped** and carrying every public hostname |

Two of five landed. Both of those landed *outside* the thing they were supposed
to be part of — Hindsight runs as containers on the NAS, and the tunnel runs in
the cluster but outside ArgoCD, so nothing reconciles it.

The individual misses are worth naming, because none of them is the failure I
would have predicted:

**Monitoring went backwards.** I chose VictoriaMetrics over kube-prometheus-stack
after a genuine comparison, then deployed neither. What exists is Grafana with no
datasource behind it — a dashboard wired to nothing. The ADR argued about which
metrics backend to run and I ended up running none, which is the one outcome the
document did not consider.

**Secrets stopped at the halfway point,** which is the worst place to stop. The
operator is deployed and healthy, so the cluster *looks* like it has secrets
management. Every actual credential is a hand-created `Secret` that exists only in
the running cluster and survives nothing. The decision was right and its absence is
now invisible, which is exactly how it stayed unfinished for eight weeks.

**Storage was never load-bearing enough to force the issue.** The one PVC in the
cluster uses `local-path`, pinning that volume to a single node's disk with no
replication — and it holds the agent's conversation history, the only state here I
would actually miss. R2 and NFS were the right call for data that mattered; I
never moved the data that matters onto them.

So the lesson in the original post — that writing the decision down is what makes
it real — is half right at best. Writing it down made it *reviewable*. It did not
make it happen, and it produced a repository that describes a cluster more capable
than the one I have. An ADR with no implementation and no expiry date is a
liability: it reads as documentation and functions as fiction.

What I would change: an ADR should record a decision **and** the commit that
executes it, or carry a visible "accepted, not implemented" status. Four of these
five said "Accepted" while nothing had shipped.

The full accounting is in
[Eight weeks later](/posts/homelab/006-eight-weeks-later-what-the-homelab-actually-runs/),
and the current state of each component is in [the homelab hub](/homelab/).

