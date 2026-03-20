---
title: "Token Consumption with GitHub Copilot Skills"
date: 2026-03-20T13:28:39-05:00
tags: [ai, copilot, github, cli, tokens, skills]
draft: true
---

# Why Your AI Skills Should Be CLI-First: A Token Cost Analysis

Many AI skills are written so the model does all the heavy lifting: reading raw configuration files, running shell commands, and formatting output line by line. While this works, it comes at a cost: token consumption that scales poorly.

This post walks through a concrete analysis of a workspace setup skill that illustrates this problem and shows how shifting deterministic logic into a CLI binary can cut token consumption by over 95%.

## The Problem: Verbose Skills are Expensive

A typical setup skill instructs the AI to:

1. Read multiple raw configuration files
2. Parse and summarize their contents for the user
3. Place or update configuration files in the correct location

In practice, this means the model is ingesting thousands of tokens just to present information it could have received pre-processed from a CLI command.

### Small Scale vs Large Scale

#### 5 config files

| Component | Estimated tokens |
| --- | ---: |
| Instruction file + tool schemas | 1,800 |
| 5 raw config files read into context | 2,500 |
| Parsing + reasoning + formatting | 700 |
| Response output | 300 |
| **Total per turn** | **5,300** |

At five files, this already consumes more than five thousand input/output tokens for a single turn.

#### 100 config files

| Component | Estimated tokens |
| --- | ---: |
| Instruction file + tool schemas | 1,800 |
| 100 raw config files read into context | 50,000 |
| Parsing + reasoning + formatting | 7,000 |
| Response output | 600 |
| **Total per turn** | **59,400** |

The instruction overhead stays nearly constant, but raw file ingestion scales linearly. The model now spends most of its context window just reading data.

#### CLI-first alternative (100 files)

| Component | Estimated tokens |
| --- | ---: |
| Instruction file + tool schemas | 1,800 |
| CLI summary output (pre-aggregated) | 900 |
| Light reasoning + response | 600 |
| **Total per turn** | **3,300** |

That is roughly a 94% reduction compared with the 59,400-token baseline. In real projects, the reduction can exceed 95% when raw outputs are especially verbose and the CLI returns compact summaries.

## Cost at Scale

Token counts are abstract until you put a dollar figure on them. Using Claude Sonnet as the baseline model (approximately **$3.00 per 1M input tokens** and **$15.00 per 1M output tokens**), here is what those numbers look like in practice.

### Cost Per Turn

| Approach | Input tokens | Output tokens | Cost per turn |
| --- | ---: | ---: | ---: |
| Verbose skill (100 files) | 58,800 | 600 | **~$0.185** |
| CLI-first skill (100 files) | 2,700 | 600 | **~$0.017** |

Calculation (verbose):
```
(58,800 / 1,000,000) × $3.00  =  $0.176  (input)
(   600 / 1,000,000) × $15.00 =  $0.009  (output)
                                  ──────
                                  $0.185 per turn
```

Calculation (CLI-first):
```
(2,700 / 1,000,000) × $3.00  =  $0.008  (input)
(  600 / 1,000,000) × $15.00 =  $0.009  (output)
                                 ──────
                                 $0.017 per turn
```

### Cost Per Developer Per Month

Assuming a developer makes **10 skill invocations per day** across **20 working days**:

| Approach | Turns/month | Cost/dev/month |
| --- | ---: | ---: |
| Verbose skill | 200 | **$37.00** |
| CLI-first skill | 200 | **$3.40** |
| **Savings** | | **$33.60** |

### Cost at Team Scale

| Team size | Verbose (monthly) | CLI-first (monthly) | Annual savings |
| --- | ---: | ---: | ---: |
| 100 devs | $3,700 | $340 | **$40,320** |
| 500 devs | $18,500 | $1,700 | **$201,600** |
| 40,000 devs | $1,480,000 | $136,000 | **$16,128,000** |

These numbers assume a single skill used once per invocation. In practice, complex workflows involve multiple skill turns per task, which multiplies the gap further.

### The Crossover Point

At what point does investing engineering time in a CLI wrapper pay off? A rough back-of-napkin calculation:

- Engineering cost to build and maintain a CLI helper: **~8 hours** at $100/hr = **$800 one-time**
- Break-even for a team of 10: **$800 / $336** = ~**2.4 months**
- Break-even for a team of 50: **$800 / $1,680** = ~**0.5 months**
- Break-even for a team of 100: **$800 / $3,360** = ~**0.24 months**
- Break-even for a company of 40,000: **$800 / $1,344,000** = **under 30 minutes of savings**

For any team larger than a handful of developers using the skill daily, the CLI investment pays for itself quickly. At enterprise scale — say 40,000 developers — the $800 engineering cost is recovered in under 30 minutes of production usage. The annual delta is over **$16 million**.

