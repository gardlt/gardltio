---
title: "hermes-agent"
weight: 13
tags: ["homelab", "kubernetes", "ai-agents", "whatsapp", "discord"]
description: "The agent I actually talk to — reachable over WhatsApp and Discord, running as a single stateful pod."
---

{{< lead >}}
Everything else on this cluster is infrastructure. This is the thing that infrastructure is
for: an agent I can message from my phone.
{{< /lead >}}

{{< alert icon="circle-info" >}}
This page cites configuration by **key name only**. The manifest contains an allow-list of
personal contact identifiers and dashboard credentials, so nothing is quoted verbatim here.
{{< /alert >}}

## What it is

A packaged agent (`nousresearch/hermes-agent`) running as a single pod, with two chat
front-ends — WhatsApp and Discord — and a web dashboard. It holds persistent state on disk,
so it remembers conversations across restarts.

It is **not** the custom Go gRPC agent registry I built earlier under the same name. That
code no longer exists in the tree; this shares the name and nothing else. That mixup is
worth being
explicit about, because a stale `hermes_url` pointing at the dead registry is still sitting
in [headroom-proxy](../headroom-proxy/)'s ConfigMap.

## Why this one

I built the registry version first, and the honest retrospective is that I built a platform
for agents before having an agent worth running on it. This is the correction: take
something that already works, run it, and use it.

The trade is control. I do not own this code, so its behaviour is its own, and the
configuration surface is whatever it exposes. In exchange it works today, which the version
I wrote never quite did.

## Where it lives

| | |
|---|---|
| Namespace | `hermes-agent` |
| Manifests | `k8s/bootstrap/hermes-agent/` |
| ArgoCD app | `k8s/apps/templates/hermes-agent.yaml` |
| Image | `nousresearch/hermes-agent:v2026.8.3` |
| App port | `8642` (Service `80` → app; health on `9119`) |
| Storage | `PersistentVolumeClaim`, `20Gi`, `local-path` |
| Secret | `hermes-agent-secret` (hand-created) |
| URL | `https://hermes-agent.apexarcology.com` |

{{< alert icon="triangle-exclamation" >}}
The PVC uses k3s `local-path`, which binds the volume to **one node's local disk**. If that
node goes away, the state goes with it — there is no replication and no backup. This is the
least resilient storage in the cluster and it holds the data I would actually miss.
{{< /alert >}}

## Configuration

Environment keys, by purpose. Values live in `hermes-agent-secret` or inline in the
deployment; none are reproduced here.

| Key | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | the model the agent reasons with |
| `DISCORD_BOT_TOKEN` | Discord front-end |
| `WHATSAPP_ENABLED`, `WHATSAPP_MODE` | WhatsApp front-end and how it connects |
| `WHATSAPP_ALLOWED_USERS` | **allow-list of who may talk to it** |
| `WHATSAPP_DM_POLICY`, `GATEWAY_ALLOW_ALL_USERS` | who may open a conversation |
| `HERMES_DASHBOARD*` | dashboard toggle and basic-auth credentials |
| `HERMES_UID`, `HERMES_GID` | filesystem ownership for the PVC |

`WHATSAPP_ALLOWED_USERS` and `GATEWAY_ALLOW_ALL_USERS` are the security boundary. This
agent has an API key and a public hostname; an unrestricted gateway is an open LLM billing
account with a chat interface.

## Usage

Message it on WhatsApp or Discord, from an allow-listed identity. The dashboard is at the
public URL behind basic auth.

```bash
kubectl -n hermes-agent get pods
kubectl -n hermes-agent logs deploy/hermes-agent --tail=50
kubectl -n hermes-agent exec -it deploy/hermes-agent -- sh
```

### Three non-obvious things in the manifest

These are documented in comments in the deployment, and each one cost real debugging time:

1. **Config is seeded by an `initContainer`, not a `subPath` mount.** A `subPath` ConfigMap
   mount is read-only and never updates, and the app expects to be able to write its own
   config file. The initContainer copies the ConfigMap contents into the PVC on startup
   instead.
2. **`args`, not `command`.** The image uses s6-overlay as its entrypoint. Overriding
   `command` bypasses s6 and the supervised services never start — the container comes up
   and does nothing.
3. **Probes hit `9119`, not `8642`.** The app port does not answer a plain health check
   early enough; probing it makes Kubernetes kill the pod during startup.

## Troubleshooting

**Pod runs but nothing is listening / no services started.**

Almost certainly a `command` override reaching past s6-overlay. See above.

**Pod restarts in a loop during startup.**

Probe configuration. Check the probes target `9119` and the initial delay is generous —
this app is slow to become ready.

**Messages are ignored with no error in the logs.**

The sender is not on the allow-list. That is the feature working. Add the identifier to
`WHATSAPP_ALLOWED_USERS` and restart.

**State disappeared.**

Check which node the pod is scheduled on. `local-path` volumes do not follow the pod, so a
reschedule to a different node presents an empty volume rather than an error.

**Pod is `CreateContainerConfigError` after a namespace rebuild.**

`hermes-agent-secret` does not exist. It is created by hand and nothing recreates it — see
[External Secrets](../external-secrets/).

## Related

- [Eight weeks later](/posts/homelab/006-eight-weeks-later-what-the-homelab-actually-runs/) — what happened to the predecessor that is not this
- [headroom-proxy](../headroom-proxy/) — still holds a dead reference to the old registry
