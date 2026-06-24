---
title: "Home Lab Evolution: Building an AI-Powered Personal Trainer Workflow"
date: 2026-06-24
draft: false
tags: ["homelab", "ai", "ollama", "n8n", "kubernetes", "automation", "fitness", "self-hosted"]
series: ["homelab-ai-platform"]
description: "Two weeks of rebuilding my home lab around practical AI. First project: an n8n + Ollama workflow that tracks fitness goals and sends personalized Telegram nudges."
---

## What changed

Over the past two weeks I rebuilt the home lab with a specific constraint: every service has to do something useful in daily life, not just demonstrate that it runs.

The infrastructure is the same — k3s cluster across heavyarms and the NUC fleet, ArgoCD for GitOps, Cloudflare Tunnel for access. What changed is what runs on top of it. I added dedicated ML inference instances running Ollama and stood up an n8n workflow engine. The goal was to see how fast I could go from "idea" to "running automation" once the platform was in place.

Answer: pretty fast.

---

## First project: AI personal trainer

I wanted to build something with stakes. My partner and I are working on fitness goals — weight, gym consistency, progressive overload — and staying accountable when life gets busy is hard. A tool that watches the data and sends context-aware messages felt like a good test case.

Three workflows, each targeting a different failure mode.

---

### Weight progress motivation

**Problem:** The scale moves slowly. It's easy to lose context on whether you're trending the right direction.

**How it works:**
- Google Sheets holds the weekly weigh-ins
- n8n polls on a schedule, calculates deltas
- Ollama generates a personalized message based on the trend (up, down, or flat)
- Message lands in Telegram

The AI piece isn't just "you lost 0.3 kg, good job." It reads the trend across multiple weeks and adjusts tone accordingly — more energetic when momentum is building, steadier when things plateau. The message changes based on context, not just the latest number.

**Next iteration:** Pull directly from the Google Fit API instead of manual sheet entries.

---

### Gym consistency tracking

**Problem:** Knowing you should go 4 days a week and actually going 4 days a week are different things.

**How it works:**
- Workout log lives in Google Sheets (one row per session)
- n8n counts sessions per week against the 4-day target
- Hit the goal → celebratory message
- Miss the goal → supportive nudge, not guilt

The tone calibration here was important. Shame-based reminders don't work long-term. The LLM prompt is tuned to stay in coach mode, not scorekeeper mode.

---

### Adaptive workout programming

**Problem:** Static workout plans stop working the moment life deviates from the plan.

**How it works:**
- Weekly plan is generated based on previous week's performance
- Two paths:
  - **Success path:** Increase reps, weight, or exercise complexity
  - **Adjustment path:** Build on incomplete workouts instead of advancing past them
- Ollama analyzes the log and generates next week's plan accordingly

This is the most LLM-heavy workflow. The model receives the full training history for the week and outputs a structured plan. Running locally on heavyarms means no token costs and no data leaving the network — workout history stays private.

---

## The stack in practice

```
Google Sheets → n8n trigger → conditional logic → Ollama (local) → Telegram
```

n8n handles the orchestration. Each workflow is a visual graph: triggers, conditions, HTTP calls to the Ollama endpoint, and output formatting before the Telegram send. The visual representation turns out to be useful not just for building but for debugging — you can step through a run and see exactly where data transforms.

The Ollama endpoint is internal only. n8n calls it over the cluster network. No egress, no API keys, no usage limits.

---

## Why this matters beyond fitness

The fitness workflows are the first real test of a pattern I want to apply more broadly:

- **Edge AI (Ollama)** — inference runs locally, no external dependencies
- **Container orchestration (k3s)** — workloads are managed, restartable, scalable
- **Workflow automation (n8n)** — complex conditional logic without writing glue code
- **Real-world data integration** — Google Sheets today, more APIs next

The infrastructure cost to add a new AI-powered workflow is now close to zero. The pattern is established. Plugging in a new data source and a new prompt takes an afternoon.

---

## What's next

Expanding the same framework to other areas:

- **Habit tracking** — general-purpose streaks and accountability
- **Photography** — automated culling or tagging workflows
- **Learning goals** — spaced repetition nudges, reading summaries

The platform is in place. The next projects are mostly about writing the right prompts and connecting the right data sources.

---

## Behind the scenes

The n8n workflows look exactly like you'd expect — nodes connected by edges, data flowing left to right. Triggers on the left, conditional branches in the middle, output nodes on the right. The Ollama call is a standard HTTP node hitting the local inference endpoint.

Fair warning: the naming conventions in the current workflows are rough. Built fast to validate the idea. Cleanup is on the list.

The interesting part isn't the individual nodes — it's that the entire decision loop (collect data, reason about it, send a message) is visual, auditable, and restartable. When something goes wrong, you can see it.
