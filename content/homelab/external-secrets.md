---
title: "External Secrets"
weight: 32
tags: ["homelab", "kubernetes", "secrets", "external-secrets"]
description: "Installed, running, and doing nothing — the operator is deployed but no ExternalSecret resources exist yet."
---

{{< lead >}}
The intended design is that secrets live in a vault and sync into Kubernetes automatically.
The current reality is that the operator is running and every Secret in this cluster is
still created by hand.
{{< /lead >}}

{{< alert icon="triangle-exclamation" >}}
**This page documents an incomplete component.** External Secrets Operator is deployed and
healthy, but there are **zero** `ExternalSecret` or `SecretStore` resources anywhere in
the repository. It is currently an inert dependency. I found this while writing these
pages, and it had already leaked into three other pages as a claim that wasn't true.
{{< /alert >}}

## What it is

An operator that reads secrets from an external store — Azure Key Vault, in the intended
design — and projects them into Kubernetes `Secret` objects. You commit an `ExternalSecret`
saying *which* secret you want; the value never enters git.

## Why this one

Every service here needs credentials: LLM provider API keys, a Jellyfin API key, a GHCR
pull token. Those cannot go in a private repo — "private" is not an access-control model,
it is an accident waiting for a visibility toggle.

The two real options were sealed-secrets, which encrypts values into git, or ESO, which
keeps them out of git entirely. ESO wins because it also solves rotation: change the value
in the vault and the cluster follows. Sealed-secrets means re-encrypting and re-committing
on every rotation.

## Where it lives

| | |
|---|---|
| Namespace | `external-secrets` |
| Manifests | `k8s/bootstrap/external-secrets/` |
| ArgoCD app | `k8s/apps/templates/external-secrets.yaml` |
| Chart repo | `https://charts.external-secrets.io` |
| Chart version | `"*"` — **unpinned** |

{{< alert icon="triangle-exclamation" >}}
`targetRevision: "*"` means ArgoCD installs whatever the latest chart is at sync time. A
resync months from now can pull a major version with breaking CRD changes, and nothing in
git records what was actually running. Three charts in this cluster have this problem —
this one, [monitoring](../monitoring/), and [HolmesGPT](../holmesgpt/). Pin them.
{{< /alert >}}

## Usage

### Today

Secrets are created by hand, per namespace:

```bash
kubectl -n headroom-proxy create secret generic headroom-proxy-secrets \
  --from-literal=ANTHROPIC_API_KEY=... \
  --from-literal=OPENAI_API_KEY=...
```

The hand-created secrets currently in play are `headroom-proxy-secrets`,
`hermes-agent-secret`, `jellyfin-mcp-secret`, and `ghcr-pull-secret`. **None of them
survive a namespace rebuild**, and none are recorded anywhere except in the running
cluster. That is the actual risk this component exists to remove and hasn't yet.

### What wiring it up requires

Two resources that do not exist yet — a `SecretStore` pointing at the vault with
credentials for it, and an `ExternalSecret` per secret:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: headroom-proxy-secrets
spec:
  secretStoreRef:
    name: azure-kv
    kind: SecretStore
  target:
    name: headroom-proxy-secrets
  data:
    - secretKey: ANTHROPIC_API_KEY
      remoteRef:
        key: anthropic-api-key
```

There is a chicken-and-egg problem to solve first: the `SecretStore` needs credentials for
Key Vault, and those are themselves a secret. Workload identity is the clean answer;
a bootstrap secret created once by hand is the pragmatic one.

Verify the operator is at least alive:

```bash
kubectl -n external-secrets get pods
kubectl get externalsecrets -A     # currently returns nothing
```

## Troubleshooting

**`kubectl get externalsecrets -A` returns nothing.**

Correct, as of now. That is the state described above, not a failure.

**A rebuilt namespace has a pod in `CreateContainerConfigError`.**

The deployment references a `Secret` that no longer exists, because it was created by hand
and nothing recreates it. This is precisely the failure mode ESO is meant to prevent.

## Related

- [External Secrets documentation](https://external-secrets.io/)
- [headroom-proxy](../headroom-proxy/) — largest consumer of hand-created secrets
- [ArgoCD](../argocd/) — what installs it
