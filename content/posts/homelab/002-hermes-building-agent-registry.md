---
title: "Hermes: Choosing an Open-Source Agent Framework"
date: 2026-06-24
draft: true
tags: ["homelab", "ai-agents", "kubernetes", "adr", "mcp"]
series: ["homelab-ai-platform"]
description: "The ADR process that led me to adopt Nous Research's open-source Hermes Agent instead of building a custom multi-agent platform from scratch."
---

When I decided to run AI agents on my home k3s cluster, the first question was: build this myself, or adopt something that already exists?

Multi-agent coordination is a genuinely hard problem — spawning isolated subagents for parallel work, reaching tools through a consistent protocol, keeping memory across sessions, living somewhere other than a laptop terminal. Building all of that from scratch is a multi-month project. Before committing to that, I evaluated what already existed.

## The ADR process

I've started using scored Architectural Decision Records for every significant choice in this project. The format is simple: define decision dimensions, score candidates against your actual requirements, then accept the result even when it's uncomfortable. It forces you to be honest about what you actually need rather than what sounds cool.

For the agent framework decision, I scored two candidates: **Hermes Agent**, [Nous Research](https://nousresearch.com)'s open-source self-improving agent platform, and **OpenClaw**, an open-source personal AI assistant platform with a gateway architecture for WhatsApp, Telegram, Slack, Discord, and Signal. The two are close enough in category that Hermes Agent ships an `hermes claw migrate` command specifically for people switching over from OpenClaw.

<!-- TODO: replace with your real dimensions/scores — placeholders below, not fabricated history -->

| Dimension | Hermes Agent | OpenClaw |
|---|---|---|
| D1 — Use Case Fit | ? | ? |
| D2 — Self-hostable / containerizable on k3s | ? | ? |
| D3 — Maintenance burden | ? | ? |
| D4 — MCP tool support | ? | ? |
| D5 — Subagent / multi-agent support | ? | ? |
| D6 — Channel integration (Telegram/Discord/Slack/Home Assistant/etc.) | ? | ? |
| D7 — Community & backing | ? | ? |
| **TOTAL** | **?** | **?** |

Hermes Agent won. <!-- TODO: one or two sentences on why, in your own words -->

## What Hermes Agent actually is

It's not a coding copilot tethered to an IDE, and it's not a chatbot wrapper around a single API call. It's an autonomous agent that gets more capable the longer it runs — it lives wherever you put it, whether that's a $5 VPS, a GPU cluster, or serverless infrastructure like Daytona or Modal that costs nearly nothing when idle. You can talk to it from Telegram while it works on a cloud VM you never SSH into yourself. It's not tied to a laptop, and it's not tied to one interface.

The features that mattered for this cluster:

- **Profiles** — a profile is a separate Hermes home directory: its own `config.yaml`, `.env`, `SOUL.md` identity file, memories, sessions, skills, and cron jobs, isolated from every other profile on the same machine. This is the real mechanism behind the agent roster — each member of the Night City Crew is a profile with its own `SOUL.md` personality contract, not a temporary task worker.
- **Subagent spawning** — separately, within a single profile, it delegates and parallelizes by spawning isolated subagents for parallel workstreams. Useful for one agent breaking down a task, but distinct from the persistent, separately-identified agents that profiles give you.
- **MCP support** — connects to any MCP server for extended tool capabilities. This is how it reaches `stock-mcp`, `jellyfin-mcp`, `homeassistant-mcp`, and `tavily-mcp`.
- **A closed learning loop** — agent-curated memory with periodic nudges, autonomous skill creation, skills that self-improve during use, and cross-session recall.
- **Scheduled automations** — a built-in cron scheduler with delivery to any platform.
- **A messaging gateway** — one gateway process fans out to 20+ platforms (Telegram, Discord, Slack, WhatsApp, Home Assistant, and more), so the agent lives where I do instead of being locked to a terminal.

It's built by Nous Research, the lab behind the Hermes model family, and it's MIT-licensed with real ongoing maintenance — which is the whole point of adopting instead of building.

## Deploying on k3s

<!-- TODO: fill in with your actual deployment — image, ports, ingress, secrets wiring. Placeholder pattern below matches the rest of the series. -->

Hermes Agent runs as its own gateway process, deployed the same way as everything else in the cluster: ArgoCD App-of-Apps, an `IngressRoute` for external access, secrets synced in via External Secrets Operator for the platform tokens and model provider keys.

```yaml
# k8s/bootstrap/hermes/deployment.yaml (abbreviated — fill in real values)
containers:
  - name: hermes-agent
    image: <TODO: real image/tag>
    ports:
      - containerPort: <TODO>
    readinessProbe:
      httpGet:
        path: <TODO>
        port: <TODO>
```

## What the ADR taught me

The most useful part of the scoring process wasn't the number — it was being forced to articulate *why* each dimension mattered before looking at the candidates. Writing the requirements down first meant I couldn't rationalize a familiar or flashier option as "good enough" when a purpose-fit tool did better on paper.

I've applied the same format to every major infrastructure decision since. The scores don't make the decision — the requirements do. The scores just prevent motivated reasoning from overriding them.

Next up: the five infrastructure ADRs that shaped the platform beneath the agents — storage, secrets, monitoring, and DNS.
