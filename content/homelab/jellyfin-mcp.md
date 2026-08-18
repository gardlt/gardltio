---
title: "jellyfin-mcp"
weight: 11
tags: ["homelab", "mcp", "go", "jellyfin", "ai-agents"]
description: "An MCP server that lets AI agents search my media library, see what is playing, and check server health."
---

{{< lead >}}
Gives an AI agent five tools for talking to my Jellyfin media server — search, libraries,
latest additions, active sessions, and system health.
{{< /lead >}}

## What it is

A Model Context Protocol server in Go. MCP is the standard that lets an AI assistant call
external tools; this one wraps the Jellyfin API and exposes five of them:

| Tool | Answers |
|---|---|
| `jellyfin_search_media` | "do I own this film?" |
| `jellyfin_get_libraries` | what libraries exist and how big they are |
| `jellyfin_get_latest_media` | what was added recently |
| `jellyfin_get_sessions` | who is watching what right now |
| `jellyfin_get_system_info` | is the server healthy |

## Why this one

Jellyfin has a perfectly good REST API, so the value here is not access — it is that an
agent can discover these tools and decide to use them without me writing glue for every
question I might ask.

It is also the smallest useful MCP server I could build, which made it the right thing to
learn on. It got the full spec treatment — spec, plan, research, data model, contracts,
tasks — and it is the only service in the cluster where that process ran end to end.

Spec: `specs/009-jellyfin-mcp/`.

## Where it lives

| | |
|---|---|
| Namespace | `jellyfin-mcp` |
| Manifests | `k8s/bootstrap/jellyfin-mcp/` |
| ArgoCD app | `k8s/apps/templates/jellyfin-mcp.yaml` |
| Image | `ghcr.io/gardlt/homelab/jellyfin-mcp:latest` |
| Source | `apps/jellyfin-mcp/` |
| CI | `.github/workflows/jellyfin-mcp.yml` |
| Port | `8080`, Service on `80` |
| URL | `https://jellyfin-mcp.apexarcology.com` |
| Backend | Jellyfin on the NAS |

## Usage

Point an MCP-capable client at the public URL. For a quick check that it is alive:

```bash
kubectl -n jellyfin-mcp get pods
kubectl -n jellyfin-mcp logs deploy/jellyfin-mcp --tail=20
```

Locally, from source:

```bash
cd apps/jellyfin-mcp
go build ./... && ./jellyfin-mcp
```

It needs a Jellyfin server URL and an API key (Jellyfin admin dashboard → API Keys). In
the cluster both arrive as environment variables, the key from a hand-created Secret named
`jellyfin-mcp-secret`. It is never in git — but it is also not yet synced from a vault, so
recreating the namespace means recreating the Secret.

## Troubleshooting

**Every tool call returns an upstream error.**

Nine times out of ten this is the server URL, not the API key. Jellyfin's port is easy to
get wrong and the failure looks identical either way — a wrong port produces a connection
error that surfaces as a generic tool failure. This exact bug shipped and needed a fix
commit. Verify the configured URL and port against the running Jellyfin instance before
touching credentials.

**Pod is `ImagePullBackOff`.**

The image is in GitHub Container Registry and the package is private, so the pull needs
`imagePullSecrets` with a PAT that has `read:packages`. A fresh namespace without that
Secret fails here every time.

**CI builds an old Go toolchain.**

The builder image is pinned in the workflow and drifts behind the `go` directive in
`go.mod`. When the build starts failing on language features, bump the builder image —
this has already happened once.

## Related

- Spec and quickstart: `specs/009-jellyfin-mcp/`
- [Model Context Protocol](https://modelcontextprotocol.io)
- [stock-mcp](../stock-mcp/) — same pattern, different data
