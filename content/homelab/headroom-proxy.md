---
title: "headroom-proxy"
weight: 10
tags: ["homelab", "llm", "go", "kubernetes", "ollama"]
description: "An OpenAI-compatible proxy that compresses prompts before they reach a model, and routes across local Ollama and three cloud providers."
---

{{< lead >}}
One endpoint that speaks the OpenAI API, compresses what you send it, and decides whether
the request goes to the GPU under my desk or to a cloud provider.
{{< /lead >}}

## What it is

A Go service that accepts OpenAI-format chat completion requests and forwards them to one
of four backends: Ollama running on my own hardware, or Anthropic, OpenAI, or Gemini. On
the way through, it compresses the prompt.

The point is that clients do not need to know or care which model answers. They point at
one URL, speak one protocol, and the routing decision lives in a ConfigMap instead of in
every application.

## Why this one

I wrote it, which needs justifying — there are existing proxies.

The reason is the compression step. Long agent prompts carry a lot of repetition, and
every token is either GPU time I am waiting on or money I am spending. A generic proxy
routes; this one rewrites the request before routing it, and only when the prompt is
large enough to be worth it (`min_tokens: 500` — below that, the overhead exceeds the
saving).

The cost is that it is one more service I own. When it breaks, there is no upstream issue
tracker.

Design and alternatives: `specs/011-headroom-llm-proxy/spec.md`.

{{< alert icon="triangle-exclamation" >}}
**Name collision.** This is *not* [headroom-ai/headroom](https://github.com/headroom-ai/headroom),
a third-party tool I also run on the NAS. Same word, unrelated software.
{{< /alert >}}

## Where it lives

| | |
|---|---|
| Namespace | `headroom-proxy` |
| Manifests | `k8s/bootstrap/headroom-proxy/` |
| ArgoCD app | `k8s/apps/templates/headroom-proxy.yaml` |
| Image | `ghcr.io/gardlt/homelab/headroom-proxy:latest` |
| Source | `apps/headroom-proxy/` |
| Port | `8080` |
| URL | **none — cluster-internal only** |
| Spec | `specs/011-headroom-llm-proxy/` |

There is deliberately no `IngressRoute`. Nothing outside the cluster reaches this service.
It holds API keys for three cloud providers; an unauthenticated LLM gateway on the public
internet is somebody else's incident report.

## Usage

In-cluster, at `http://headroom-proxy.headroom-proxy.svc.cluster.local:8080`.

```bash
kubectl -n headroom-proxy port-forward svc/headroom-proxy 8080:8080
```

Then talk to it like the OpenAI API:

```bash
curl localhost:8080/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{"model":"llama3.2:3b-instruct-q4_K_M",
       "messages":[{"role":"user","content":"why is the sky blue"}]}'
```

The `model` field picks the backend. Ask for a local model and it goes to Ollama; ask for
`claude-*` or `gpt-*` and it goes to that provider, assuming the key exists.

### Changing routing or compression

Backends, the default backend, and `min_tokens` all live in
`k8s/bootstrap/headroom-proxy/configmap.yaml`. Edit, commit, and let ArgoCD reconcile —
then restart, because the process reads config at startup:

```bash
kubectl -n headroom-proxy rollout restart deploy/headroom-proxy
```

## Troubleshooting

**Every request to a local model fails, cloud models work.**

Ollama is not in Kubernetes. It runs on `heavyarms` via Ansible, and the proxy reaches it
as a plain host address (`http://192.168.86.44:11434`). A Service or NetworkPolicy will
not help you here — check the host:

```bash
curl -s http://192.168.86.44:11434/api/tags | head
```

If that fails, the problem is on the node, not in the cluster.

**Requests succeed but nothing is compressed.**

Compression is skipped below `min_tokens` (500). Short prompts pass through untouched.
That is intended, not a bug.

**A cloud backend 401s.**

Keys come from a Secret named `headroom-proxy-secrets`, which is **created by hand** — the
External Secrets Operator is installed in the cluster but no `ExternalSecret` resources
exist yet, so nothing syncs it from Azure Key Vault automatically. A rebuilt namespace has
no keys until you recreate that Secret.

```bash
kubectl -n headroom-proxy get secret headroom-proxy-secrets
```

**Known inconsistency:** the ConfigMap still carries a `hermes_url` pointing at
`hermes.hermes.svc.cluster.local:8081`. That registry no longer exists in the cluster —
see [the retrospective](/posts/homelab/006-eight-weeks-later-what-the-homelab-actually-runs/).
The proxy tolerates its absence; the setting is dead weight awaiting cleanup.

## Related

- Spec: `specs/011-headroom-llm-proxy/spec.md`, quickstart in the same directory
- Source: `apps/headroom-proxy/` — backends in `internal/backends/`
- [Eight weeks later](/posts/homelab/006-eight-weeks-later-what-the-homelab-actually-runs/)
