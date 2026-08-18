---
title: "stock-mcp"
weight: 12
tags: ["homelab", "mcp", "go", "ai-agents"]
description: "An MCP server exposing market quotes and price history to AI agents."
---

{{< lead >}}
Two tools that let an agent ask what a stock is worth now and what it did before.
{{< /lead >}}

## What it is

A Model Context Protocol server in Go, exposing market data:

| Tool | Returns |
|---|---|
| `get_quote` | current price, `previous_close`, `change_percent`, `as_of` |
| `get_history` | price history over a requested window |

It was the first MCP server I deployed, and it set the shape every service since has
followed: small Go binary, container built by GitHub Actions into GHCR, four manifests,
one ArgoCD application.

## Why this one

Honestly, because it was a small problem with a clean API — a good way to prove the
deployment path before pointing it at anything that mattered.

That turned out to be the most valuable thing about it. The pattern it established is why
`jellyfin-mcp` took a fraction of the time. It is also the one service with no spec
directory, which shows: there is no written record of what it should do, only code.

## Where it lives

| | |
|---|---|
| Namespace | `stock-mcp` |
| Manifests | `k8s/bootstrap/stock-mcp/` |
| ArgoCD app | `k8s/apps/templates/stock-mcp.yaml` |
| Image | `ghcr.io/gardlt/homelab/stock-mcp:latest` |
| Source | `apps/stock-mcp/` |
| CI | `.github/workflows/stock-mcp.yml` |
| Port | `8080`, Service on `80` |
| URL | `https://stock-mcp.apexarcology.com` |
| Spec | none |

## Usage

Point an MCP client at the public URL. To check it directly:

```bash
kubectl -n stock-mcp get pods
kubectl -n stock-mcp logs deploy/stock-mcp --tail=20
```

From source:

```bash
cd apps/stock-mcp
go build ./... && ./stock-mcp
```

## Troubleshooting

**Quotes are stale or empty.**

Check `as_of` in the response before assuming the service is broken. Markets close, and
the upstream provider rate-limits — both look like a hung service from the client side and
neither is one.

**Pod is `ImagePullBackOff`.**

Same cause as every other service here: the GHCR package is private and the namespace
needs `imagePullSecrets` with a `read:packages` PAT.

## Related

- Source: `apps/stock-mcp/`
- [jellyfin-mcp](../jellyfin-mcp/) — the same pattern, fully specced
- [Model Context Protocol](https://modelcontextprotocol.io)
