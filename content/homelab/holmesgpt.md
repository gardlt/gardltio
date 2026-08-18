---
title: "HolmesGPT"
weight: 41
tags: ["homelab", "kubernetes", "ai", "observability", "troubleshooting"]
description: "AI-assisted incident triage: ask why a pod is broken and get an answer built from live cluster state."
---

{{< lead >}}
Point it at a failing workload and ask why. It gathers the evidence itself — events, logs,
resource state — and explains what it found.
{{< /lead >}}

## What it is

An open-source diagnostic agent from Robusta. It has read access to the cluster and a set
of toolsets for pulling evidence, and it drives an LLM to correlate that evidence into an
explanation.

The interesting part is not the language model, it is that the model is given the ability
to *fetch* — it decides to look at the events, then the logs, then the deployment spec,
in the order a person would.

## Why this one

Everything else in this cluster is infrastructure I understand. This is the one component
that exists to compensate for the fact that I do not have a metrics stack.

Debugging here means `kubectl describe`, then `kubectl logs`, then `kubectl get events`,
then remembering which of those actually contained the answer last time. HolmesGPT does
that sequence without me, and it is meaningfully better at the "correlate three unrelated
symptoms" step than I am at 11pm.

It is not a substitute for [monitoring](../monitoring/). It reads live state, so it can
tell you why something is broken *now* and nothing at all about why it broke on Tuesday.

## Where it lives

| | |
|---|---|
| Namespace | `holmesgpt` |
| Manifests | `k8s/bootstrap/holmesgpt/` |
| ArgoCD app | `k8s/apps/templates/holmesgpt.yaml` |
| Chart | `holmes` from `https://robusta-charts.storage.googleapis.com` |
| Chart version | `"*"` — **unpinned** |
| Model | `anthropic/claude-sonnet-4-6` |
| API key | `Secret/holmesgpt-llm-secret` → `ANTHROPIC_API_KEY` |
| URL | `https://holmesgpt.apexarcology.com` |

The key is a hand-created Secret — see [External Secrets](../external-secrets/) for why
that is still true.

Note that it calls Anthropic directly, **not** through
[headroom-proxy](../headroom-proxy/). Routing it through the proxy would give it prompt
compression and a single place to manage provider keys, and is an obvious unclaimed win.

## Usage

Open `https://holmesgpt.apexarcology.com` and ask in plain language:

> why is the jellyfin-mcp pod restarting

It will pull the pod, its events, and its logs, and answer from those.

Health check:

```bash
kubectl -n holmesgpt get pods
kubectl -n holmesgpt logs deploy/holmesgpt --tail=30
```

## Troubleshooting

**Every question fails with an upstream or auth error.**

The Anthropic key. Confirm the Secret exists and the pod picked it up — a rebuilt namespace
has no Secret, and the pod will start anyway and fail only at request time.

```bash
kubectl -n holmesgpt get secret holmesgpt-llm-secret
```

**It answers, but says it cannot see the resource you asked about.**

RBAC. The chart installs a ClusterRole scoped to reading cluster state; a resource type
outside that scope is invisible to it, and the model will report that honestly rather than
guessing.

**It gives a confident wrong answer.**

It will. It is reasoning over a snapshot with no history, so anything intermittent, or
anything whose cause is outside the cluster — a dead [Ollama](../headroom-proxy/) host, a
DNS record missing from the Terraform — is exactly where it goes wrong. Treat the output
as a lead, not a verdict.

**It stopped working after a resync.**

Unpinned chart version. Check what version is actually deployed against what was there
before.

## Related

- [HolmesGPT](https://github.com/robusta-dev/holmesgpt)
- [monitoring](../monitoring/) — the historical view this does not provide
- [headroom-proxy](../headroom-proxy/) — where its LLM traffic arguably belongs
