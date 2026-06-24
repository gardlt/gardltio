---
title: "The LLM Token Optimization Ecosystem — Part 1: Meet the Tools"
date: 2026-06-18T09:00:00-05:00
tags: [ai, tokens, llm, compression, rtk, caveman, headroom, cli, agents]
draft: false
---

> **Series: The LLM Token Optimization Ecosystem**
> **Part 1: Meet the Tools** (you're here) · [Part 2: How They Fit Together](/posts/llm-token-tools-part-2-how-they-fit/) · [Part 3: Does It Pay Off?](/posts/llm-token-tools-part-3-does-it-pay-off/)

---

A distinct open-source category has emerged around reducing the token cost of AI coding agents. These tools do not make models smarter — they make the *surface area* of every interaction smaller. Three high-traction repos dominate this space, each attacking a different slice of the token bill:

- **rtk** (63.1k ⭐) — compresses CLI *command outputs* before they hit the LLM
- **caveman** (62.1k ⭐) — compresses LLM *responses* by making the agent speak in terse fragments
- **headroom** (29.9k ⭐) — compresses *everything the LLM reads* (tool outputs, RAG, logs, files)

Together they address both sides of the API invoice: input tokens (rtk/headroom) and output tokens (caveman). The design philosophies are fundamentally different, and the competitive dynamics are surprisingly cooperative — headroom explicitly bundles the rtk binary; both point to lean-ctx as an alt.

This part profiles all three. [Part 2](/posts/llm-token-tools-part-2-how-they-fit/) covers how they compose and where they deploy; [Part 3](/posts/llm-token-tools-part-3-does-it-pay-off/) runs the cost math.

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

**Next:** [Part 2 — How They Fit Together](/posts/llm-token-tools-part-2-how-they-fit/) maps the competitive landscape, the composable stack, and where each tool actually deploys.

## Sources

- [juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)
- [chopratejas/headroom](https://github.com/chopratejas/headroom)
- [rtk-ai/rtk](https://github.com/rtk-ai/rtk)
- [arxiv: Brevity Constraints paper (2604.00025)](https://arxiv.org/abs/2604.00025)
- [Kompress-v2-base on HuggingFace](https://huggingface.co/chopratejas/kompress-v2-base)
