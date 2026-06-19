---
title: "The LLM Token Optimization Ecosystem: rtk, caveman, and headroom"
date: 2026-06-18T09:00:00-05:00
tags: [ai, tokens, llm, compression, rtk, caveman, headroom, cli, agents]
draft: false
---

**Scope:** Technical, Competitive, and Token Economics Analysis
**Repos analyzed:** caveman · headroom · rtk + identified ecosystem

---

## Executive Summary

A distinct open-source category has emerged around reducing the token cost of AI coding agents. These tools do not make models smarter — they make the *surface area* of every interaction smaller. Three high-traction repos dominate this space, each attacking a different slice of the token bill:

- **rtk** (63.1k ⭐) — compresses CLI *command outputs* before they hit the LLM
- **caveman** (62.1k ⭐) — compresses LLM *responses* by making the agent speak in terse fragments
- **headroom** (29.9k ⭐) — compresses *everything the LLM reads* (tool outputs, RAG, logs, files)

Together they address both sides of the API invoice: input tokens (rtk/headroom) and output tokens (caveman). The design philosophies are fundamentally different, and the competitive dynamics are surprisingly cooperative — headroom explicitly bundles the rtk binary; both point to lean-ctx as an alt.

---

## 1. rtk — CLI Output Proxy

**Repo:** [rtk-ai/rtk](https://github.com/rtk-ai/rtk)
**Stars:** 63.1k · **Forks:** 3.9k · **Issues:** 657 open · **PRs:** 576 open
**Releases:** 211 (latest v0.42.4, Jun 12 2026)
**Language:** Rust 92.9%, Shell 4.8%, TypeScript 1.5%
**License:** Apache 2.0
**Team:** Patrick Szymkowiak (founder), Florian Bruniaux, Adrien Eppling

### What It Does

rtk sits as a transparent proxy between the AI agent's Bash tool and the shell. When an agent calls `git status`, a PreToolUse hook intercepts it, rewrites it to `rtk git status`, runs the command, and returns compressed output. The agent never knows compression happened.

Four compression strategies are applied per command type:
1. **Smart Filtering** — strips comments, whitespace, boilerplate
2. **Grouping** — aggregates similar items (files by directory, errors by type)
3. **Truncation** — drops redundancy, keeps signal
4. **Deduplication** — collapses repeated log lines with counts

A tee recovery mechanism saves the full unfiltered output on failure, so the LLM can read it without re-running the command.

### Technical Architecture

Single Rust binary, zero runtime dependencies, <10ms overhead. Supports 100+ commands across files, git, GitHub CLI, test runners (Jest, Cargo, pytest, Go test, RSpec), build tools (ESLint, tsc, Next.js, Rust), package managers, AWS CLI, Docker, and Kubernetes.

Agent integration is hook-based: `rtk init -g` writes a PreToolUse hook to the agent's config. Fourteen agents are supported including Claude Code, GitHub Copilot (VS Code + CLI), Cursor, Gemini CLI, Codex, Windsurf, Cline/Roo Code, OpenCode, OpenClaw, Pi, Hermes, Kilo Code, and Google Antigravity.

**Critical limitation:** The hook only intercepts Bash tool calls. Claude Code's native Read, Grep, and Glob tools bypass the hook entirely — so file reads don't compress through rtk.

### Benchmarks (Claimed)

| Operation | Standard | rtk | Savings |
|-----------|----------|-----|---------|
| `git status` (10×/session) | 3,000 | 600 | -80% |
| `cargo test` (5×/session) | 25,000 | 2,500 | -90% |
| `cat`/`read` (20×/session) | 40,000 | 12,000 | -70% |
| **30-min session total** | ~118,000 | ~23,900 | **-80%** |

### Token Economics Model

rtk's model is simple: reduce *input* tokens by compressing tool outputs. Given Claude Sonnet 4.6 at ~$3/M input tokens, an 80% reduction on 118k input tokens per session = ~$0.28 saved per session, ~$70/month for a developer running 5 sessions/day. The `rtk gain` command tracks this with USD estimates and supports JSON export for dashboards.

### Strengths
- Highest stars in the space; most agent integrations (14)
- Single Rust binary, zero deps — trivial deployment
- Telemetry is opt-in only, GDPR-compliant
- 211 releases reflects fast iteration and active maintenance
- Multilingual README (7 languages) signals global adoption

### Weaknesses / Risks
- 657 open issues and 576 open PRs suggest team is stretched thin
- Hook-only architecture misses Read/Grep/Glob tool calls — leaves significant savings on the table
- No file caching, no MCP server, no reversible compression
- Windows support limited to CLAUDE.md injection mode (no hook)
- Claimed savings are estimates based on "medium TypeScript/Rust projects"; real savings vary

---

## 2. caveman — Output Token Compressor

**Repo:** [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)
**Stars:** 62.1k · **Forks:** 3.5k · **Issues:** 75 open · **PRs:** 133 open
**Releases:** 14 (latest v1.8.2, May 12 2026)
**Language:** JavaScript 62.9%, Python 27.6%, PowerShell 4.9%, Shell 4.6%
**License:** MIT
**Author:** Julius Brussee (solo maintainer)

### What It Does

Caveman is a skill/plugin — a prompt-injected instruction set — that makes AI agents respond in compressed, caveman-style fragments. The agent still reasons at full depth but strips filler words, pleasantries, and redundant phrasing from its output.

Key distinction: caveman **only affects output tokens**. Thinking/reasoning tokens are untouched. Input tokens are unchanged unless you also use `caveman-compress` to rewrite CLAUDE.md files.

```
Normal: "The reason your React component is re-rendering is because
         you're creating a new object reference on each render cycle..."
         = 69 tokens

Caveman: "New object ref each render. Inline object prop = new ref = re-render.
          Wrap in `useMemo`."
          = 19 tokens
```

### Technical Architecture

Architecture is deliberately lightweight: a SKILL.md file injected into the agent's skills directory. A Claude Code session hook auto-activates caveman on every new session. The mechanism is entirely prompt-engineering — no code transformation, no proxy, no binary.

Four compression levels: `lite` (drop filler), `full` (default caveman), `ultra` (telegraphic), `wenyan` (classical Chinese notation, maximally dense).

Sub-skills included:
- `/caveman-commit` — conventional commit messages ≤50 chars
- `/caveman-review` — one-line PR comments
- `/caveman-stats` — real session token usage + lifetime savings + USD
- `/caveman-compress` — rewrites CLAUDE.md/memory files into caveman-speak (~46% input token reduction on context files)
- `caveman-shrink` — MCP middleware that wraps any MCP server and compresses tool descriptions

The repo structure covers 30+ agent targets: `.claude-plugin`, `.agents`, `.codex`, `.kiro`, `.roo`, `.junie` directories, plus plugin formats for OpenClaw, Gemini extensions, and others.

### Benchmarks (Claimed)

Average 65% output token reduction across 10 diverse prompts (range 22–87%). A March 2026 paper ["Brevity Constraints Reverse Performance Hierarchies"](https://arxiv.org/abs/2604.00025) found that constraining models to brief responses *improved* accuracy by 26 points on certain benchmarks — caveman cites this as independent validation.

| Task | Normal | Caveman | Saved |
|------|--------|---------|-------|
| React re-render bug | 1,180 | 159 | 87% |
| Fix auth middleware | 704 | 121 | 83% |
| PostgreSQL pool | 2,347 | 380 | 84% |
| Git rebase vs merge | 702 | 292 | 58% |
| Architecture decision | 446 | 310 | 30% |
| **Average** | **1,214** | **294** | **65%** |

`caveman-compress` on memory/context files averages 46% reduction, which reduces input token cost on every subsequent session.

### Token Economics Model

Output token savings are smaller in absolute dollar terms for most models (output tokens ~5× more expensive per token than input for Sonnet 4.6, but there are far fewer of them). The bigger ROI is speed: 65% fewer output tokens means ~3× faster responses, which compounds into developer productivity. For API users paying output token costs, caveman's savings are real but secondary to the UX improvement.

The ecosystem play is more interesting: cavekit adds per-task token budgets, cavemem compresses cross-session memory, and cavegemma fine-tunes Gemma 4 31B on caveman-style pairs to bake compression into model weights (removing the per-session prompt overhead entirely).

### Strengths
- Extremely easy to install (one curl command, works in 30 seconds)
- No external dependencies, no binaries, no proxies
- Proven traction: 62.1k stars despite being a solo-maintained project
- Ecosystem breadth: caveman → cavemem → cavekit → cavegemma forms a coherent stack
- Accuracy claim supported by third-party research

### Weaknesses / Risks
- Solo maintainer — bus factor of 1; 133 open PRs suggests review bottleneck
- Prompt-only mechanism — can be overridden by complex prompts or model behavior changes
- Output-only savings; doesn't address the growing input token cost problem
- No reversibility or guaranteed format — compressed responses can be harder to parse programmatically
- 14 releases vs. rtk's 211 suggests slower iteration cadence

---

## 3. headroom — Full Context Compression Layer

**Repo:** [chopratejas/headroom](https://github.com/chopratejas/headroom)
**Stars:** 29.9k · **Forks:** 2k · **Issues:** 177 open · **PRs:** 90 open
**Releases:** 155 (latest v0.25.0, Jun 12 2026)
**Language:** Python 78.1%, Rust 17.2%, TypeScript 2.5%
**License:** Apache 2.0

### What It Does

Headroom is the most technically ambitious of the three. Where rtk compresses CLI outputs and caveman compresses responses, headroom compresses *everything the LLM reads* — tool outputs, logs, RAG chunks, files, conversation history — via a pipeline that sits between the application and the LLM provider.

```
Your app/agent
     │   prompts · tool outputs · logs · RAG · files
     ▼
 ┌──────────────────────────────────────────────────┐
 │  Headroom (local)                                │
 │  CacheAligner → ContentRouter → CCR             │
 │                  ├─ SmartCrusher (JSON)          │
 │                  ├─ CodeCompressor (AST)         │
 │                  └─ Kompress-base (text, HF)     │
 └──────────────────────────────────────────────────┘
     │   compressed prompt + retrieval tool
     ▼
LLM provider (Anthropic · OpenAI · Bedrock · …)
```

### Technical Architecture

**Six compression algorithms:**
- `SmartCrusher` — universal JSON compression (arrays, nested objects)
- `CodeCompressor` — AST-aware compression for Python, JS, Go, Rust, Java, C++
- `Kompress-base` — proprietary HuggingFace model trained on agentic traces
- `CacheAligner` — stabilizes prompt prefixes to maximize KV cache hit rates
- `IntelligentContext` — score-based context fitting with learned importance
- `CCR (Compressed Context with Retrieval)` — reversible compression; originals cached locally and retrievable on demand

**Deployment modes:**
- Python library: `compress(messages, model=...)`
- TypeScript SDK: `await compress(messages, { model })`
- Drop-in proxy: `headroom proxy --port 8787`
- Agent wrap: `headroom wrap claude|codex|cursor|aider`
- MCP server: `headroom_compress`, `headroom_retrieve`, `headroom_stats`

**Framework integrations:** Anthropic SDK, OpenAI SDK, Vercel AI SDK, LiteLLM, LangChain, Agno, Strands, ASGI middleware, multi-agent SharedContext.

**`headroom learn`** mines failed sessions and writes corrections back to `CLAUDE.md`/`AGENTS.md`/`GEMINI.md` — a feedback loop that improves agent behavior over time.

Headroom explicitly ships the rtk binary and uses it for shell-output rewriting, then compresses everything downstream. It also supports lean-ctx via `HEADROOM_CONTEXT_TOOL=lean-ctx`.

### Benchmarks (Claimed)

**Real agent workloads:**

| Workload | Before | After | Savings |
|----------|--------|-------|---------|
| Code search (100 results) | 17,765 | 1,408 | 92% |
| SRE incident debugging | 65,694 | 5,118 | 92% |
| GitHub issue triage | 54,174 | 14,761 | 73% |
| Codebase exploration | 78,502 | 41,254 | 47% |

**Accuracy benchmarks (N=100 each):**

| Benchmark | Category | Baseline | Headroom | Delta |
|-----------|----------|----------|----------|-------|
| GSM8K | Math | 0.870 | 0.870 | ±0.000 |
| TruthfulQA | Factual | 0.530 | 0.560 | **+0.030** |
| SQuAD v2 | QA | — | 97% | 19% compression |
| BFCL | Tool use | — | 97% | 32% compression |

Reversibility via CCR means the LLM can retrieve originals when needed — addressing the accuracy risk of lossy compression.

### Token Economics Model

Headroom attacks the largest input token costs: logs, RAG chunks, and tool outputs are often 10–100× larger than necessary. A 92% reduction on a 65k-token SRE debug session saves ~$0.18 per incident in API costs at Sonnet 4.6 pricing. For teams running many automated agent workflows this compounds quickly.

The KV cache alignment via CacheAligner is an underrated feature: stable prompt prefixes allow Anthropic/OpenAI's prompt caching to actually work, creating a compounding effect (cached tokens are ~90% cheaper). This benefit is orthogonal to compression and comes for free.

The `headroom learn` loop is a long-term moat: agent sessions generate proprietary training signal that improves compression quality over time.

### Strengths
- Most technically comprehensive solution in the space
- Reversible compression (CCR) — strong accuracy guarantee
- Proprietary ML model (Kompress-v2-base) trained on agentic traces
- KV cache optimization is orthogonal value with zero additional cost
- Framework agnostic; 10+ SDK integrations
- Enterprise offering with ENTERPRISE.md
- 1,614 commits and 155 releases — highest development velocity of the three

### Weaknesses / Risks
- Most complex to install and configure (Python 3.10+ required, Rust build for some components)
- ML model adds latency (~50–200ms depending on hardware)
- 177 open issues — support surface is wide
- SSL inspection environments have a painful setup path (documented but non-trivial)
- Requires trust: headroom proxies all LLM traffic; enterprise buyers will scrutinize data handling
- Python-first limits use in non-Python stacks despite TypeScript SDK

---

## 4. Competitive Landscape Map

### Direct Competitors

| Project | Stars | Scope | Deploy | Local | Reversible | Lang |
|---------|-------|-------|--------|-------|------------|------|
| **rtk** | 63.1k | CLI output | Hook | ✅ | ❌ | Rust |
| **caveman** | 62.1k | LLM output | Skill/plugin | ✅ | ❌ | JS/Python |
| **headroom** | 29.9k | All context | Proxy/library/MCP | ✅ | ✅ | Python/Rust |
| **lean-ctx** | 4 | CLI + file reads | Hook + MCP | ✅ | ❌ | Rust |
| Compresr.ai | N/A | Text | Hosted API | ❌ | ❌ | — |
| Token Co. | N/A | Text | Hosted API | ❌ | ❌ | — |
| OpenAI Compaction | N/A | Conversation history | Provider-native | ❌ | ❌ | — |

### Related / Ecosystem Repos

**From caveman's own ecosystem:**
- [JuliusBrussee/cavemem](https://github.com/JuliusBrussee/cavemem) — cross-agent memory via SQLite + MCP, session-compressed storage
- [JuliusBrussee/cavekit](https://github.com/JuliusBrussee/cavekit) — Claude Code plugin: NL → blueprint → parallel build plan → working software; per-task token budgets; automated iteration
- [JuliusBrussee/finetune-caveman](https://github.com/JuliusBrussee/finetune-caveman) (cavegemma) — Gemma 4 31B fine-tuned on caveman prompt-completion pairs; bakes compression into model weights

**Adjacent tools:**
- [yvgude/lean-ctx](https://github.com/yvgude/lean-ctx) — Hybrid Shell Hook + MCP Server; 89–99% claimed savings; introduces Token Dense Dialect (mathematical symbols: λ for functions, § for classes, ∂ for interfaces); 6-mode file reading with MD5 session cache; Shannon entropy analysis; web dashboard at localhost:3333. Only 4 stars currently — very early stage, but technically differentiated by MCP server + file caching.

---

## 5. Differentiation Deep-Dive

### Attack Surface Comparison

```
┌─────────────────────────────────────────────────────────────┐
│  Token Bill Anatomy (typical agentic coding session)        │
│                                                             │
│  Input tokens breakdown:                                    │
│  ├── Tool outputs (CLI, git, tests)  ← rtk / lean-ctx      │
│  ├── File reads                      ← headroom / lean-ctx  │
│  ├── RAG / search results            ← headroom             │
│  ├── Conversation history            ← headroom / OpenAI    │
│  └── System prompt / context files   ← caveman-compress     │
│                                                             │
│  Output tokens:                       ← caveman             │
└─────────────────────────────────────────────────────────────┘
```

rtk has the biggest real-world impact per dollar of implementation effort because CLI outputs (git, tests, grep) are the most token-wasteful part of a coding session. headroom covers more surface area but requires more setup. caveman is the only tool addressing output tokens.

### Technical Design Philosophies

**rtk:** Systems-first. Zero runtime dependencies. Predictable, rule-based compression. Fast path: <10ms overhead. Trust is easy — you can read the Rust source and understand exactly what gets stripped. No ML, no black boxes.

**caveman:** Prompt-engineering-first. Zero infrastructure required. The compression algorithm runs in the model's reasoning — which means it's flexible but also vulnerable to prompt drift or model updates that change response style.

**headroom:** ML-first. Trains proprietary models on agentic data. This creates a compounding advantage as the model improves, but also introduces latency, dependency complexity, and a trust surface (you're proxying all traffic through headroom's pipeline).

### The Integration Stack

These tools are designed to compose:

```
[caveman] → compress what the agent says
[rtk/lean-ctx] → compress CLI tool outputs
[headroom] → compress everything else (wraps rtk, adds file/RAG/log compression)
[cavekit + cavemem] → orchestrate agents with token budgets + persistent memory
[cavegemma] → bake caveman-style output compression into model weights
```

Headroom's explicit decision to bundle rtk (and support lean-ctx via env var) signals that the winning architecture isn't one tool — it's a composable layer.

---

## 6. Token Economics Analysis

### Cost Model (Claude Sonnet 4.6 Pricing)

Assuming ~$3/M input tokens, ~$15/M output tokens:

| Tool | Mechanism | Session Savings (tokens) | $/session saved | $/month (5 sessions/day) |
|------|-----------|--------------------------|-----------------|--------------------------|
| rtk | CLI output compression | ~94k input tokens | ~$0.28 | ~$42 |
| caveman | Output compression (~65%) | ~600 output tokens | ~$0.009 | ~$1.35 |
| caveman-compress | Context file compression (46%) | ~400 input tokens/session | ~$0.001 | ~$0.18 |
| headroom (SRE workload) | Full context compression (92%) | ~60k input tokens | ~$0.18 | ~$27 |
| headroom KV cache alignment | Cache hit improvement | Model-dependent | $0.03–0.15 | $4.5–22 |

**Stacking all tools:** a developer using rtk + caveman + headroom could realistically save $60–100/month in API costs on a typical coding workflow. For a team of 10, that's $600–1,000/month — a reasonable ROI trigger for enterprise deployment.

### The Real Value: Speed and Context Length

The dollar savings are real but secondary. The primary value proposition is:

1. **Speed:** 65–80% fewer tokens = 2–5× faster responses. Time is worth more than API cost.
2. **Context longevity:** Compressed context stays within the model's window longer. A 200k-token context window effectively becomes 400–1,000k tokens equivalent with headroom compression.
3. **Agent coherence:** Shorter context = less attention dilution = more focused reasoning.

### Monetization Paths

None of these repos are currently monetized directly. Potential paths:

- **SaaS proxy** (headroom is closest with ENTERPRISE.md) — charge per million tokens compressed
- **Self-hosted enterprise** — team dashboards, compliance, SAML
- **Managed fine-tuning** (cavegemma model direction) — charge for model distillation as a service
- **Developer tooling subscription** — token savings analytics, session recording, team-level dashboards

---

## 7. Key Observations and Risks

**The compression arms race:** As LLMs improve at long-context tasks, the value of compression decreases at the margins. However, token pricing creates a persistent economic incentive regardless of model capability improvements.

**Benchmark credibility:** All three repos self-report benchmarks. rtk's are the most conservative and granular; caveman's cite an independent paper; headroom's cover accuracy preservation most thoroughly. None have been independently reproduced.

**Integration fragility:** Hook-based approaches (rtk, lean-ctx) depend on agent hook APIs that can change with agent updates. Claude Code's hook architecture has been stable but this is a dependency risk.

**Privacy surface:** Headroom proxies all LLM traffic locally, but "locally" means on the developer's machine — fine for individual use, requires careful audit for enterprise deployment (data handling policies, compliance, secrets exposure in logs).

**The lean-ctx wildcard:** With only 4 stars but a well-differentiated technical approach (MCP server + file caching + TDD mode + web dashboard), lean-ctx could grow quickly if it executes on its roadmap. The Token Dense Dialect (mathematical symbols for code constructs) is a genuinely novel approach that RTK and headroom haven't matched.

---

## 8. Recommendations

**For individual developers:** Start with rtk (biggest immediate ROI, zero config) + caveman (simple output compression). Add headroom if you run automated agent workflows with heavy RAG or log analysis.

**For teams:** Headroom's enterprise offering + rtk integration is the right architecture. The `headroom learn` feedback loop is the most defensible long-term value proposition.

**For investors/observers:** The most interesting bet is whether headroom's ML-first approach (Kompress-v2-base) creates a durable moat, or whether rule-based tools like rtk are "good enough." Given that rtk's 63.1k stars came faster than headroom's, and rtk has a more active PR/issue volume, market pull appears stronger for simple, transparent tools.

**Watch:** lean-ctx — technically sound, first-mover on MCP + file caching combo, very early. Also watch cavegemma: if fine-tuned compression becomes good enough, it eliminates the need for all three runtime tools.

---

## 9. Multi-Model Cost Comparison

### Assumptions & Methodology

**Session model:** A 30-minute agentic coding session using a typical TypeScript/Rust project.

| Metric | Without compression | With full stack (rtk + headroom + caveman) |
|--------|--------------------|--------------------------------------------|
| Input tokens | 118,000 | ~12,000 (~90% reduction) |
| Output tokens | 15,000 | ~5,250 (~65% reduction) |
| Net input savings | — | rtk: –80% on CLI outputs; headroom: –50% on remaining reads/RAG |
| Net output savings | — | caveman: –65% average across query types |

**Work schedule:** 5 sessions/day × 22 working days = 110 sessions/month (individual developer).
**Team calculation:** 10 developers × individual monthly cost.
**Batch discount:** Anthropic and OpenAI both offer ~50% off for batch/async processing.
**Prompt cache discount:** ~90% off cached input tokens (applies when prefixes are stable — KV cache alignment via headroom maximizes this).

---

### Per-Session and Monthly Cost by Model

#### Anthropic — Claude Family

| Model | Input $/M | Output $/M | Cost/session (raw) | Cost/session (compressed) | Monthly — 1 dev (raw) | Monthly — 1 dev (compressed) | Monthly savings |
|-------|-----------|------------|-------------------|--------------------------|----------------------|------------------------------|-----------------|
| **Claude Opus 4.8** | $5.00 | $25.00 | $0.97 | $0.19 | $106.70 | $20.90 | **$85.80** |
| **Claude Sonnet 4.6** | $3.00 | $15.00 | $0.58 | $0.11 | $63.80 | $12.10 | **$51.70** |
| **Claude Haiku 4.5** | $1.00 | $5.00 | $0.19 | $0.04 | $20.90 | $4.40 | **$16.50** |

> Opus 4.8 Fast Mode doubles cost ($10/$50); compressed fast-mode session ≈ $0.38, monthly ≈ $41.80.
> Batch API (50% discount): Opus 4.8 compressed drops to ~$0.095/session / $10.45/month.

---

#### OpenAI — GPT & o-series

| Model | Input $/M | Output $/M | Cost/session (raw) | Cost/session (compressed) | Monthly — 1 dev (raw) | Monthly — 1 dev (compressed) | Monthly savings |
|-------|-----------|------------|-------------------|--------------------------|----------------------|------------------------------|-----------------|
| **GPT-5.5** | $5.00 | $30.00 | $1.04 | $0.22 | $114.40 | $24.20 | **$90.20** |
| **GPT-5.5 Pro** | $30.00 | $180.00 | $6.24 | $1.31 | $686.40 | $144.10 | **$542.30** |
| **GPT-4o** | $2.50 | $10.00 | $0.45 | $0.08 | $49.50 | $8.80 | **$40.70** |
| **o3** | $2.00 | $8.00 | $0.36 | $0.07 | $39.60 | $7.70 | **$31.90** |
| **o4-mini** | $0.55 | $2.20 | $0.098 | $0.018 | $10.78 | $1.98 | **$8.80** |

> ⚠️ **o-series reasoning tokens:** o3 and o4-mini generate hidden reasoning tokens billed as output. A response showing 500 output tokens may consume 3,000+ actual billed tokens. Effective output cost can be 3–6× the listed rate for complex reasoning tasks. Compression reduces the *input* cost but cannot reduce reasoning tokens — caveman still reduces final response output tokens.

> GPT-5.5 Batch/Flex: 50% discount → compressed session ≈ $0.11/session.

---

#### Google — Gemini Family

| Model | Input $/M | Output $/M | Cost/session (raw) | Cost/session (compressed) | Monthly — 1 dev (raw) | Monthly — 1 dev (compressed) | Monthly savings |
|-------|-----------|------------|-------------------|--------------------------|----------------------|------------------------------|-----------------|
| **Gemini 2.5 Pro** | $1.25 | $10.00 | $0.30 | $0.068 | $33.00 | $7.48 | **$25.52** |
| **Gemini 2.5 Flash** | $0.30 | $2.50 | $0.073 | $0.017 | $8.03 | $1.87 | **$6.16** |
| **Gemini 2.5 Flash-Lite** | $0.10 | $0.40 | $0.018 | $0.0033 | $1.98 | $0.36 | **$1.62** |

> Gemini 2.5 Pro uses **tiered pricing**: prompts >200k tokens step up significantly. Headroom's compression is particularly valuable here — keeping prompts under the 200k threshold avoids the tier-up surcharge entirely.

---

#### Open-Weight & Alternative Providers

| Model | Input $/M | Output $/M | Cost/session (raw) | Cost/session (compressed) | Monthly — 1 dev (raw) | Monthly — 1 dev (compressed) | Monthly savings |
|-------|-----------|------------|-------------------|--------------------------|----------------------|------------------------------|-----------------|
| **Mistral Large 3** | $0.50 | $1.50 | $0.082 | $0.014 | $9.02 | $1.54 | **$7.48** |
| **Llama 4 Maverick** (hosted) | $0.15 | $0.60 | $0.027 | $0.0050 | $2.97 | $0.55 | **$2.42** |
| **Llama 4 Scout** (hosted) | $0.08 | $0.30 | $0.014 | $0.0026 | $1.54 | $0.29 | **$1.25** |
| **DeepSeek V3.2** | $0.14 | $0.28 | $0.021 | $0.0032 | $2.31 | $0.35 | **$1.96** |
| **DeepSeek R1** (reasoning) | $3.00 | $7.00 | $0.459 | $0.073 | $50.49 | $8.03 | **$42.46** |

> Llama 4 pricing varies by host (Together.ai, Fireworks, Groq, DeepInfra). Scout at $0.08 input is among the cheapest hosted frontier-class models available.
> DeepSeek V3.2 offers Claude Haiku-class capability at ~1/10th the cost — compression ROI is lower in absolute terms but proportionally the same (~83% cost reduction with the full stack).

---

### Summary: Full Compression Stack ROI by Model Tier

| Tier | Model | Raw monthly (1 dev) | Compressed monthly | $ Saved/mo | % Saved | Team of 10 savings |
|------|-------|--------------------|--------------------|------------|---------|-------------------|
| **Frontier-expensive** | GPT-5.5 Pro | $686 | $144 | $542 | 79% | $5,420/mo |
| **Frontier-expensive** | Claude Opus 4.8 | $107 | $21 | $86 | 80% | $860/mo |
| **Frontier-expensive** | GPT-5.5 | $114 | $24 | $90 | 79% | $900/mo |
| **Mid-tier** | DeepSeek R1 | $50 | $8 | $42 | 84% | $420/mo |
| **Mid-tier** | Claude Sonnet 4.6 | $64 | $12 | $52 | 81% | $520/mo |
| **Mid-tier** | GPT-4o | $50 | $9 | $41 | 82% | $410/mo |
| **Mid-tier** | o3 | $40 | $8 | $32 | 80% | $320/mo |
| **Mid-tier** | Gemini 2.5 Pro | $33 | $7.5 | $25.5 | 77% | $255/mo |
| **Budget** | Claude Haiku 4.5 | $21 | $4.4 | $16.5 | 79% | $165/mo |
| **Budget** | o4-mini | $11 | $2 | $9 | 82% | $90/mo |
| **Budget** | Gemini 2.5 Flash | $8 | $1.9 | $6.1 | 77% | $61/mo |
| **Budget** | Mistral Large 3 | $9 | $1.5 | $7.5 | 83% | $75/mo |
| **Ultra-cheap** | Llama 4 Maverick | $3 | $0.55 | $2.4 | 81% | $24/mo |
| **Ultra-cheap** | DeepSeek V3.2 | $2.3 | $0.35 | $2 | 85% | $20/mo |
| **Ultra-cheap** | Gemini 2.5 Flash-Lite | $2 | $0.36 | $1.6 | 82% | $16/mo |

**Key insight:** The percentage savings is nearly constant (~80%) across all models because the compression ratios (90% input, 65% output) are model-agnostic. The *absolute dollar* savings, however, scale linearly with model price — making compression tools most valuable with expensive frontier models.

---

### The Diminishing Marginal ROI Problem

For ultra-cheap models (DeepSeek V3.2, Llama 4 Scout, Gemini Flash-Lite), the absolute savings from compression are $1–3/month per developer — low enough that the integration overhead of headroom/rtk may not be worth it. The break-even math:

- **headroom setup time:** ~30–60 min for initial integration
- **rtk setup:** ~5 min
- **caveman setup:** ~30 sec

For a developer using Gemini Flash-Lite, the $1.62/month savings on token costs doesn't justify the headroom setup. For the same developer using Claude Opus 4.8 or GPT-5.5 Pro, the $86–542/month savings pays back setup in minutes.

**Conclusion:** Compression tools have the highest ROI when used with premium frontier models. As models get cheaper, the economic case for compression weakens, but the speed and context-length benefits remain constant.

---

### Batch Processing Multiplier

For workflows that tolerate latency (test runs, automated reviews, nightly analysis), batch API pricing compounds compression savings:

| Model | Compressed + Batch cost/session | Compressed standard | Additional batch savings |
|-------|--------------------------------|--------------------|-----------------------|
| Claude Opus 4.8 | $0.095 | $0.191 | -50% |
| Claude Sonnet 4.6 | $0.057 | $0.114 | -50% |
| GPT-5.5 | $0.110 | $0.218 | -50% |
| GPT-4o | $0.041 | $0.083 | -50% |

Combining compression + batch + prompt caching can reduce Claude Opus 4.8 per-session cost from $0.965 to under $0.05 — a **95%+ total cost reduction** versus baseline.

---

### Prompt Cache Alignment Bonus (headroom-specific)

Headroom's `CacheAligner` stabilizes prompt prefixes to maximize provider KV cache hit rates. With Anthropic prompt caching:
- Cached input tokens: **90% discount** (effectively $0.50/M for Sonnet 4.6, $0.30/M for Haiku 4.5)
- Cache write tokens: 25% premium (one-time cost, amortized over re-reads)

For a session where 80% of input tokens are repeated context (system prompts, CLAUDE.md, codebase context), the effective input cost drops dramatically. This benefit is orthogonal to compression and stacks multiplicatively — the combination of CacheAligner + compression can reduce the effective input token rate to near-zero for stable context.

---

## 10. Deployment Model: Local-Only vs Enterprise Gateway

A dimension that matters enormously for teams but is easy to miss: **where does the tool actually run?** Most of this ecosystem is strictly per-developer. Only one tool has a credible path to central deployment.

### Local-Only Tools

- **rtk** — strictly local. Single binary, runs on each developer's machine via shell hook. No server mode, no central deployment path. Each developer installs and manages their own instance. The closest it gets to "shared" is the openclaw plugin integration, but even that is per-machine.
- **caveman** — local by design. It's a prompt instruction injected into each agent's config directory. There's no server component whatsoever — it's essentially a SKILL.md file. Deployment means distributing the file to each developer's `~/.claude` or equivalent. No gateway, no central control.
- **lean-ctx** — local only. Shell hook + per-machine MCP server (running on localhost:3333). No multi-user mode, no centralized deployment documented. Very early stage.
- **cavemem / cavekit / cavegemma** — all local. SQLite-backed memory, local agent orchestration, local fine-tuned model weights. No enterprise architecture.

### Can Function as Enterprise Gateway

**headroom** is the only one of the three that has a credible enterprise gateway path. It has multiple deployment modes that go beyond local:

- `headroom proxy --port 8787` — runs as a drop-in HTTP proxy. Any team member (or CI system) routes their LLM API traffic through it. The compression happens server-side before forwarding to Anthropic/OpenAI/Bedrock.
- **Docker image** — `ghcr.io/chopratejas/headroom:latest` — deployable on any container infra (ECS, GKE, Kubernetes). This is the gateway deployment path.
- **ASGI middleware** — `app.add_middleware(CompressionMiddleware)` — embeddable in a FastAPI/Starlette service, meaning the gateway can be part of an internal API layer that all developers hit.
- **SharedContext** — compressed context passing across multi-agent workflows, implying team-level shared state.
- **ENTERPRISE.md** — they explicitly document an enterprise offering, though the details aren't public without contacting them.

The architecture allows an enterprise to deploy one headroom instance, point all developer API keys through it, and apply compression + KV cache alignment + cross-agent memory at the team level — without any per-developer installation.

### Cloud / Hosted (Not Local)

- **Compresr.ai** and **The Token Company** — hosted APIs. You send your text to their endpoint, they compress it, you get tokens back. Zero local install, but your data leaves your environment.
- **OpenAI Compaction** — provider-native, runs on OpenAI's infrastructure. No control or visibility, only covers conversation history.

### Deployment Summary

| Tool | Local only | Self-hosted gateway | Hosted/cloud |
|------|:----------:|:-------------------:|:------------:|
| rtk | ✅ | — | — |
| caveman | ✅ | — | — |
| lean-ctx | ✅ | — | — |
| cavemem / cavekit | ✅ | — | — |
| headroom | ✅ | ✅ | — |
| Compresr.ai | — | — | ✅ |
| Token Company | — | — | ✅ |
| OpenAI Compaction | — | — | ✅ (provider) |

**Bottom line:** If you need central IT control, compliance visibility, or team-level deployment, headroom is the only open-source option in this space. rtk and caveman are fundamentally per-developer tools — you can distribute their configs via dotfiles or onboarding scripts, but there's no central enforcement or observability layer. The gap between "headroom the local tool" and "headroom the enterprise gateway" is real and appears to be their primary monetization lever given the ENTERPRISE.md file.

---

## Sources

- [juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)
- [chopratejas/headroom](https://github.com/chopratejas/headroom)
- [rtk-ai/rtk](https://github.com/rtk-ai/rtk)
- [yvgude/lean-ctx](https://github.com/yvgude/lean-ctx)
- [JuliusBrussee/cavekit](https://github.com/JuliusBrussee/cavekit)
- [Medium: The Ultimate Token-Saving Stack](https://paul-hackenberger.medium.com/the-ultimate-token-saving-stack-rtk-caveman-and-tokensave-163badadd9ec)
- [HyperAI: Caveman Open Source Story](https://hyper.ai/en/stories/021dcfb5e16a50cfea8012b910758bf0)
- [DEV.to: Headroom writeup](https://dev.to/arshtechpro/headroom-cut-your-llm-token-usage-by-up-to-95-without-changing-your-answers-5g06)
- [arxiv: Brevity Constraints paper (2604.00025)](https://arxiv.org/abs/2604.00025)
- [Kompress-v2-base on HuggingFace](https://huggingface.co/chopratejas/kompress-v2-base)
