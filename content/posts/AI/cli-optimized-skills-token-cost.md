---
title: "The Cost of Curiosity: Why CLI-Optimized Skills Win at Enterprise Scale"
date: 2026-06-24
draft: false
tags: ["ai", "tokens", "llm", "cli", "agents", "agentic-workflows", "cost-optimization", "enterprise"]
description: "Verbose AI skills vs. CLI-optimized skills — the per-turn cost difference is 10x. At 40k developers, that gap becomes $16M/year."
---

## The problem with letting the LLM do everything

Agentic skill development is addictive. You describe a task, the agent handles it — reading raw configs, parsing outputs, formatting results, making decisions. It works. For one developer, on one task, the cost is invisible.

The problem surfaces at scale. Every token spent on deterministic logic is money that didn't have to be spent. And those tokens compound.

---

## The numbers

I ran a comparison between two approaches to the same skill:

| Approach | Cost per turn |
|---|---|
| Verbose (LLM handles everything) | ~$0.185 |
| CLI-Optimized (pre-processed data) | ~$0.017 |

**10x difference per turn.**

The verbose version passes raw data to the model and lets it parse, filter, and format before responding. The CLI-optimized version pre-processes that data in code — deterministic transformations that don't need language model reasoning — and only sends the model what it actually needs to reason about.

---

## What this looks like at enterprise scale

Model this across an organization with 40,000 developers:

| Scenario | Annual cost |
|---|---|
| Verbose skills | $1.48M |
| CLI-optimized skills | $136K |
| **Savings** | **~$1.34M** |

Push that across multiple skill categories, higher usage rates, or a larger developer population and you reach $16M+ in annual savings. The math isn't hypothetical — it follows directly from the per-turn delta multiplied by usage volume.

The CLI wrapper pays for itself in under 30 minutes of developer time at enterprise scale. That's not a performance optimization. That's a budget decision.

---

## The principle

**Deterministic work belongs in deterministic code.**

A CLI can parse a JSON config in milliseconds for zero tokens. An LLM can also parse a JSON config — for 200 tokens and a non-trivial latency penalty. Using the LLM for that work isn't wrong, it's just expensive in a way that's easy to miss at the individual level and impossible to ignore at the organizational level.

The pattern for CLI-optimized skills:

1. **Pre-process in code.** Filter, transform, and format data before it reaches the model. Pass structured summaries, not raw outputs.
2. **Reserve the model for reasoning.** Let the LLM do what only an LLM can do: handle ambiguity, generate language, make contextual judgments.
3. **Wrap with a CLI.** A lightweight CLI layer between raw data and model input is the lowest-effort, highest-leverage optimization available.

---

## The broader implication

Token cost is the new compute cost. A decade ago, engineering organizations started tracking cloud spend per feature. The teams that built cost awareness into their infrastructure early had a structural advantage over teams that optimized reactively.

The same dynamic is playing out now with LLM usage. Organizations that build token-efficient skills from the start will carry a lower cost basis as usage scales. Organizations that don't will optimize under pressure, which is always more expensive than optimizing by design.

The curiosity phase is fine. Let developers experiment, let skills get verbose, see what actually gets used. But once a skill is load-bearing — once it's running on thousands of turns per day — the cost of not optimizing becomes real money.

---

*The takeaway: before promoting a skill to production, ask whether any part of it is paying model rates for work a CLI could do for free.*
