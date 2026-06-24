---
title: "Four Open-Source Tools That Cut My Token Costs by 80%+"
date: 2026-06-24
draft: false
tags: ["ai", "tokens", "llm", "rtk", "caveman", "headroom", "ponytail", "cost-optimization", "open-source", "cli"]
series: ["token-economics"]
description: "Every git status, test run, and file read costs tokens. rtk, caveman, headroom, and ponytail attack that problem from four different angles — together they cut 80%+ of token usage without degrading answer quality."
---

## The bill nobody's reading

Token costs are the new cloud bill. Most developers don't look at them until they're large enough to matter — and by then the habits are already set.

The pattern is the same everywhere: every `git status`, every test run, every file read gets dumped into the model context. Raw, unfiltered, verbose. The model reads all of it, responds to all of it, and you pay for all of it. On cheap models, the waste is invisible. On Opus or GPT-5.5, it's real money.

Companies are starting to notice. The question "how are you budgeting your tokens?" is showing up in engineering conversations the same way "how are you managing your AWS spend?" did five years ago.

Here's how I'm handling it.

---

## Three tools, three angles

The interesting thing about token optimization is that it's a multi-layer problem. Verbose input, verbose output, uncompressed context, and bloated conversation history are separate failure modes. I found four open-source tools that each own one layer:

### rtk — squeeze the input

`rtk` intercepts CLI output before the model sees it. Every `git status`, every test result, every file listing gets filtered and compressed at the shell level. The model receives a summary, not a raw dump.

The key insight: most CLI output is noise. Status messages, progress bars, redundant headers, unchanged lines in a diff. Strip those before they enter the context and you eliminate a category of cost entirely.

### caveman — shrink the output

`caveman` addresses the other side: model verbosity. Left to its own defaults, a language model will write you paragraphs when sentences would do. Caveman constrains the output format — short answers, no filler, no pleasantries, technical substance preserved.

This matters because output tokens are billed the same as input tokens, and verbose responses also grow your context window on the next turn. Compound savings.

### headroom — compress everything else

`headroom` handles the remaining context: conversation history, retrieved documents, anything that doesn't fit the other two categories. It compresses long-form content before it enters the model without stripping the semantic content that makes it useful.

Think of it as the catch-all layer. `rtk` handles CLI output, `caveman` handles response format, `headroom` handles everything else.

### ponytail — trim the conversation tail

`ponytail` targets a specific and often overlooked cost center: long-running conversations. As a session grows, earlier turns accumulate in context even when they're no longer relevant. `ponytail` progressively compresses or prunes the conversation tail — the older turns that are taking up context budget but contributing little to the current exchange.

It supports Claude, Codex, and Gemini, and ships with configurable intensity levels so you control the aggressiveness of the trim. The reported reductions are significant: ~54% on context from prior turns, ~20% on retrieved documents, ~27% on overall session length in longer agentic workflows.

The use case where this shines: multi-step agentic sessions that run for dozens of turns. Without tail trimming, context grows until you hit the window limit or costs spike. With it, the session stays lean regardless of how long it runs.

---

## What running all four looks like

Individual savings per tool vary. Combined, the reduction exceeds 80% of baseline token usage.

The part that surprised me: answer quality doesn't degrade. Compression isn't the same as loss. Most of what gets removed was noise the model was processing but not meaningfully using — verbose CLI headers, filler sentences in responses, redundant context that was already summarized, and stale early turns that stopped being relevant ten messages ago.

If you're on a paid Opus or GPT-5.5 plan, 80% reduction is a direct budget impact. If you're on a cheaper model, the gain shows up as speed — smaller context windows process faster.

---

## How to think about token budgeting

The mental model that's been useful for me: treat tokens like compute. You wouldn't run a full database export to answer a query that only needs an index. The same discipline applies to what you put in and take out of model context.

A few questions worth asking for any workflow:

- **What's entering the context?** Is it raw output or pre-processed? Could a CLI filter remove half of it before the model sees it?
- **What's leaving the context?** Are responses longer than they need to be? Is the model writing essays when it could write sentences?
- **What's accumulating in context?** Is conversation history growing unbounded? Could earlier turns be compressed without losing the thread?

These aren't rhetorical. Each one is a category of waste with a tool or technique that addresses it.

---

## What's next

Next post: a deep dive into token compression — how `headroom` works under the hood, where semantic compression wins over naive truncation, and what it looks like to build compression into a CI/CD pipeline.

In the meantime: if you're paying Opus rates and not compressing your context, you're leaving real money on the table.

*How are you managing token budget in your workflows? Curious what approaches people are finding outside of the obvious "use a cheaper model" answer.*
