---
title: "Eight weeks later: what the homelab actually runs"
date: 2026-08-16
draft: false
tags: ["homelab", "kubernetes", "gitops", "argocd", "retrospective", "ai-agents"]
series: ["homelab-ai-platform"]
series_order: 5
aliases: ["/posts/homelab/002-hermes-building-a-grpc-agent-registry/"]
description: "I ended the last series with 'implementation begins once the clarifications are resolved.' Here's an audit of what shipped, what rotted, and the one service I wrote a whole post about that isn't in the repo anymore."
---

[Post 004](/posts/homelab/004-the-night-city-crew/) — the last one about the infrastructure itself —
ended on a promise:

> Implementation begins once the two outstanding clarifications are resolved — the roster
> is clear, the contracts are written, and the tool mappings are assigned.

That was June 24th. It's August 16th. The cluster has been stable for a few weeks now,
which is exactly the wrong moment to feel good about it and exactly the right moment to
audit it. So I went through the repo the way I'd go through someone else's — checking
every claim in the README against the working tree, every ArgoCD app against a manifest,
every CI workflow against the directory it builds.

Most of it held up. One thing did not, and it's the thing I wrote an entire post about.

## The numbers

72 commits between the first one in April and today:

| Type | Count |
|------|-------|
| `feat` | 34 |
| `fix` | 16 |
| `chore` | 11 |
| `docs` | 6 |
| other (`ci`, `revert`, `phase`) | 5 |

Roughly one fix per two features. For infrastructure I'm writing alone, on hardware I own,
with no users to page me, that ratio is higher than I expected. It's also honest: most of
those fixes are the last mile of a deploy, not design errors.

The clearest example is the three most recent commits, all against the same service:

```
d89969e ci: add workflow_dispatch to jellyfin-mcp pipeline
0e3a0ab fix: bump jellyfin-mcp builder image to golang:1.25-alpine
025bec6 fix: correct jellyfin-mcp JELLYFIN_SERVER_URL port to 8899
```

A workflow that couldn't be triggered manually, a Go toolchain a minor version behind, and
a port number that was wrong. Three commits, none of them interesting, all of them
required. This is what "getting to stable" actually consists of, and it's the part the
architecture diagram never shows.

Work by month: 13 in April, 21 in May, 15 in June, 14 in July, 9 in August. The May spike
is the ADR run — five architecture decisions written in a weekend, which was [post
003](./003-five-adrs-in-a-weekend.md). The slope since then is what sustainable actually
looks like.

## What shipped

Twelve specs now live in `specs/`, up from eight when the series ended. The four new ones:

- **009 — jellyfin-mcp.** An MCP server exposing my Jellyfin library to agents. Full
  spec-kit treatment: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`,
  `tasks.md`. Deployed, in ArgoCD, has a CI pipeline. This one worked end to end.
- **010 — agent LLM routing.** How agents pick a model.
- **011 — headroom-llm-proxy.** A multi-provider OpenAI-compatible compression proxy in
  Go. This is the largest thing in the repo now: `apps/headroom-proxy` with six internal
  packages (`backends`, `compression`, `config`, `hermes`, `metrics`, `proxy`).
- **012 — local LLM analysis.** Which local models are actually worth the VRAM.

ArgoCD reconciles ten applications: `cert-manager`, `external-secrets`, `headroom-proxy`,
`hermes-agent`, `holmesgpt`, `jellyfin-mcp`, `metallb`, `monitoring`, `stock-mcp`,
`traefik`. Everything reaches the outside world at `*.apexarcology.com` through the
Cloudflare tunnel. No port forwarding, no VPN, no `/etc/hosts` entries. That part of the
design has needed zero maintenance since it went in, which is the highest praise
infrastructure gets.

Three Go services are in the tree and building: `apps/headroom-proxy`,
`apps/jellyfin-mcp`, `apps/stock-mcp`.

## What rotted

Now the audit findings.

### The Hermes registry isn't in the repo

An earlier post in this series was about Hermes — a
cluster-internal gRPC agent registry, the piece that makes the whole "agents discover each
other" story work. It was real. I wrote it, it compiled, I described its protocol in
detail.

`apps/hermes` does not exist in the working tree.

```
$ test -d apps/hermes && echo yes || echo MISSING
MISSING

$ git log --oneline --all -- apps/hermes
e513a6a chore: temp
4223708 feat: add Hermes agent registry, Ollama LLM deployment, and routing layer
```

It went in with commit `4223708` and came out in a commit called `chore: temp`. That
commit message is the entire failure. I removed a service during some intermediate step,
labeled the commit with the least informative string available, and never came back —
because nothing told me to.

Nothing told me because the things that *should* have told me are also broken:

- **`.github/workflows/hermes.yml` still exists** and still builds `context: apps/hermes`.
  It targets a directory that isn't there.
- **There is no ArgoCD application for the registry.** `k8s/apps/templates/` has
  `hermes-agent.yaml` and nothing else matching hermes. The registry was never wired into
  GitOps, so ArgoCD had no opinion about it disappearing.
- **`apps/headroom-proxy/internal/hermes` exists** — a client package for a server that
  isn't in the repo.

Two of the four posts in the previous series depended on that service. The lesson isn't
"be careful with `git rm`." It's that **a service outside GitOps has no immune system.**
Every other component in this cluster is declared in `k8s/apps/templates/`, so ArgoCD
would have gone `OutOfSync` the moment its manifest stopped matching reality. Hermes was
built, blogged about, and never registered with the thing whose entire job is noticing
when something is missing.

### GitOps doesn't cover everything it claims to

`k8s/bootstrap/` has twelve directories. `k8s/apps/templates/` has ten applications. The
two that aren't Argo-managed are `argocd` itself — fine, that's the bootstrap paradox —
and `cloudflared`, which is the single component every public URL depends on. It runs on
the NAS, outside the cluster, managed by hand.

That's a defensible choice (the tunnel connector shouldn't depend on the cluster it
exposes) but I never wrote it down as a choice. It reads as an omission, which means
future-me will eventually treat it as one.

### Five ADRs are decisions with no implementation trail

Specs 002, 004, 005, 006, and 007 — memory system, secrets backend, storage, monitoring,
DNS — each contain exactly one file: `spec.md`. No `plan.md`, no `tasks.md`, no
`checklists/`. Specs 001, 009, and 011 have the full treatment.

The decisions themselves are live and the infrastructure exists. But there's no artifact
connecting "we chose External Secrets Operator" to "here is what we did about it," which
means verifying an ADR is still true requires reading manifests instead of reading a
checklist.

### Small stuff

`.gitignore` line 12 reads `secret-ignoreapps/stock-mcp/stock-mcp` — two entries welded
together by a bad edit, matching nothing. It's been there long enough that I stopped
seeing it.

The two NUC11 nodes, `wing` and `deathscythe`, have been listed as `Pending` in the README
since April. Four months of pending is not pending; it's a decision I haven't made.

## What actually went right

Three things, and they share a property.

**The security cleanup happened before it mattered.** In July I untracked Terraform state,
`.env` files, and `.terraform/` directories, then wrote two audits into `docs/` —
`security-audit-2026-07-05.md` and `nas-privacy-audit-2026-07-05.md`. Those were written
while nothing was wrong. Writing them after would have meant rotating credentials.

**Spec-first held for anything nontrivial.** Every service that survives in this repo has a
spec directory. The service that vanished is the one whose spec (001) was about the
*framework*, not about deploying that specific binary. The correlation isn't subtle.

**The boring layer is invisible.** MetalLB, Traefik, cert-manager, and the tunnel have
required essentially no attention since May. I chose conventional, well-documented tools
and then stopped thinking about them. Every hour of trouble in the last two months went to
things I wrote myself.

The shared property: each one is a case where I did the unglamorous version correctly and
then got to ignore it. Everything in the "what rotted" section is a case where I did the
interesting part and skipped the bookkeeping.

## Where it stands

The cluster is stable. Ten ArgoCD applications reconciling, three custom Go services
running, twelve specs, public access through a tunnel that hasn't needed touching. That's
a real platform, and it does real work.

It's also a platform whose agent registry — the component the entire series was built
around — exists only as a CI workflow pointing at nothing and a client library with no
server. I'm not going to end this post by promising to fix that, because ending posts with
promises is precisely how I got here.

What I've changed instead is the process. Posts in this repo now come from
`blogs/README.md`: written after deployment rather than after design, with a pre-publish
checklist that requires every path in the post to exist in the working tree. Had that rule
been in place in June, post 002 would have been fine when it published — and this post
would have been the one that caught it.

The gap between the diagram and the cluster is the only part worth writing about.

---

*Part 5 of a series on building an AI agent platform on a home Kubernetes cluster. Specs,
manifests, and the workflow that builds a directory which doesn't exist are all at
[github.com/gardlt/homelab](https://github.com/gardlt/homelab).*
