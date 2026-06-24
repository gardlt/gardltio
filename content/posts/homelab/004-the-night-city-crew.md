---
title: "The Night City Crew: Designing a Roster of Specialized AI Agents"
date: 2026-06-24
draft: false
tags: ["homelab", "ai-agents", "kubernetes", "mcp", "cyberpunk", "agent-design"]
series: ["homelab-ai-platform"]
description: "Designing seven specialized AI agents named after Cyberpunk 2077 characters — each with a defined role, a personality contract, and dedicated MCP tool integrations."
---

By the time I had Hermes running and the infrastructure ADRs settled, I had a platform without agents. The registry could register, query, and stream events. The memory system could store and retrieve. The monitoring stack was collecting metrics. What I didn't have was anyone to run on the platform.

That's where the Night City Crew came in.

## The premise

The idea was simple: a roster of specialized AI agents, each named after a character from Cyberpunk 2077, each with a clearly defined domain, a recommended model tier, a personality contract (SOUL), and a specific set of MCP tool integrations. Declare the whole thing in version control. Provision it in one operation.

The character names aren't cosmetic. Each name was chosen to fit the role:

| Agent | Role | Why this character |
|---|---|---|
| **Alt Cunningham** | System Architecture | The most powerful netrunner in Night City. She sees systems as others can't. |
| **Dexter DeShawn** | Planning & Orchestration | A fixer who coordinates jobs, resources, and people with cold precision. |
| **Judy Alvarez** | Frontend & UI/UX | Braindance technician, artist, the person who makes things *feel* right. |
| **Adam Smasher** | Security & Testing | Full cyborg, zero mercy, finds every weakness. Security and adversarial testing. |
| **Panam Palmer** | DevOps & Automation | Nomad engineer who keeps convoys moving. Infrastructure and pipelines. |
| **Hanako Arasaka** | Research & Analysis | Corporate intel and deep research, long-game strategic thinking. |
| **Misty Olszewski** | Travel & Logistics | The wildcard. Falls outside the homelab's core infrastructure domain — included but flagged for operator confirmation. |

## The personality contract (SOUL)

Each agent carries a SOUL — a personality contract committed to the repository alongside the agent definition. The contract specifies:

- **Voice**: Opinionated, zero filler, brief, dry wit.
- **Failure reporting**: Radically honest. State problems plainly without sugarcoating.
- **Position-taking**: Every response commits to a position. No "it depends" without a recommendation.
- **Filler prohibition**: No "Great question", "I'd be happy to help", "Certainly", or "As an AI...". Ever.

The contract is testable: pose the same question to an agent with and without the contract loaded. The contracted response is shorter, takes a position, and omits openers. That's the acceptance criterion, not a vibe check.

The SOUL approach comes from Hindsight's per-agent memory bank model — each agent's Mission, Directives, and Disposition are stored alongside its memories, shaping how it retrieves and reasons about prior context. The personality contract integrates with this: the agent doesn't just *speak* a certain way, it *remembers* a certain way.

## MCP tool integrations

Each agent is wired to exactly the MCP servers it needs for its role. Least privilege applies to tools, not just secrets.

Adam Smasher (security) gets access to infrastructure testing tools and cluster introspection. Hanako Arasaka (research) gets search and data retrieval. Panam Palmer (DevOps) gets cluster management and CI tooling. Alt Cunningham (architecture) gets access to the full system topology through Hermes and the monitoring stack.

The requirement is strict: an agent can only use the integrations declared for it. An integration requiring an external credential that doesn't exist in Azure Key Vault surfaces a clear, actionable failure at provisioning time — it does not silently skip the integration and start the agent in a broken state.

## The declarative model

The crew is defined in version control. The full definition for each agent includes:

```yaml
# agents/alt-cunningham.yaml (illustrative)
name: alt-cunningham
character: Alt Cunningham
role: System Architecture
model: claude-sonnet-4-6  # resolved from model policy at planning time
soul: souls/alt-cunningham.md
integrations:
  - hermes-registry     # query the agent registry
  - victoria-metrics    # read cluster metrics
  - k8s-read            # inspect cluster state
```

Provisioning the roster runs a single operation that creates all seven agents. It is idempotent — running it twice produces no duplicates. Individual agent failures are isolated and reported with the agent name, not swallowed into a generic error. The remaining agents still come up if one fails.

## Outstanding decisions before implementation

The spec for spec 008 carries two open questions that need operator confirmation before the implementation plan can be finalized:

**Misty Olszewski (scope)**: The travel and logistics role falls outside the homelab's infrastructure domain. Does it belong in the crew, or does it get dropped as out-of-domain? My instinct is to include her but constrain the integrations to things that actually exist in the homelab — no booking APIs, no flight data services. She becomes the agent for external-world data coordination that touches the homelab (package tracking, calendar events, etc.), not a general travel assistant.

**External providers**: Several roles would benefit from external cloud models or SaaS MCP integrations. The homelab has Azure Key Vault and can hold API keys for Claude, GPT-4o, and MCP SaaS providers. The question is whether to allow them or restrict the crew to locally available models. My current lean: allow external models where a credential exists in AKV, fail loudly where it doesn't. This keeps the crew useful without pretending the homelab is an island.

## Where this lands

The Night City Crew is the first concrete use case for everything built before it. Hermes registers each agent at startup. Hindsight stores their memories. VictoriaMetrics tracks their behavior. External Secrets Operator delivers their credentials. Cloudflare Tunnel exposes any human-facing interface. ArgoCD reconciles their definitions when they change.

The platform wasn't theoretical. It was built for this.

The full spec is in `specs/008-night-city-crew/spec.md`. Implementation begins once the two outstanding clarifications are resolved — the roster is clear, the contracts are written, and the tool mappings are assigned. What's left is running the provisioning workflow and watching seven agents come online in a cluster sitting under my desk in my living room.

---

*This is part 4 of a 4-part series on building an AI agent platform on a home Kubernetes cluster. The full repository, ADR specs, Hermes source code, and k8s manifests are at [github.com/gardlt/homelab](https://github.com/gardlt/homelab).*
