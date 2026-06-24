---
title: "Stop Using AI as a Tool. Start Using It as a Team."
date: 2026-06-24
draft: false
tags: ["ai", "github-copilot", "agentic-workflows", "agile", "software-engineering", "ci-cd"]
description: "Restructuring GitHub Copilot into specialized agent roles — orchestrator, planner, implementor, tester, documentor — and what happens when you move them out of the IDE."
---

## The mental model that changed everything

Most developers use AI as a smarter autocomplete. You're in a file, you need a function, you ask, you get code. That's useful. It's not transformative.

The shift that unlocked real productivity for me: stop thinking about AI as a tool you invoke and start thinking about it as a team member with a defined role. Once I did that, I stopped asking "what can the AI do?" and started asking "who do I need right now?"

In an Agile workflow, the answer is rarely the same person twice.

---

## The roster

My current setup within GitHub Copilot maps each agent to a distinct phase of the development lifecycle:

**The Orchestrator**
Triages incoming work. Takes a feature request, breaks it down, and delegates to the right agent for each sub-task. The entry point for anything new. Without this layer, the other agents operate in isolation and you lose the coordination benefit.

**The Planner**
Owns the architecture. Given a task from the Orchestrator, it maps out the approach — data flow, component boundaries, dependency order, edge cases to consider before writing a line of code. This is the agent that saves you from painting yourself into a corner at 11pm.

**The Implementor**
Writes the core logic. Focused, no architecture decisions, no documentation concerns. Just: here's the spec, here's the code. Keeping this role narrow matters — it's easy to let an implementor drift into planning, which produces code that solves the immediate problem but ignores the broader context.

**The Tester**
Adversarial by design. Its job is to find the ways the Implementor's code breaks. Unit edge cases, integration failures, malformed inputs, race conditions. The Tester doesn't care about shipping — it cares about what happens when the Implementor was wrong. This tension is the point.

**The Documentor**
Ensures the knowledge base evolves with the code. Not retrofitted docs written after the fact — documentation that gets updated as part of the same cycle that produces the feature. The Documentor reads the Implementor's output and the Planner's rationale and synthesizes both into something a future developer (or future agent) can actually use.

---

## What holds them together

A `copilot-instructions.md` file is the connective tissue. It carries:

- Project standards (naming conventions, architectural patterns, test coverage expectations)
- Current context (what phase we're in, what decisions have already been made)
- Role boundaries (what each agent is and isn't responsible for)

Without this file, every agent session starts cold. With it, each agent inherits the full context of the project without you having to re-explain it. The instructions file is the manager. Maintaining it is non-negotiable.

---

## What's next: moving out of the IDE

The workflows above live in the VS Code sidebar right now. That's functional but limited — it requires a human in the loop to hand work from agent to agent.

The next phase is GitHub Actions. The goal is a CI/CD flow where a single prompt — in a PR description, a comment, an issue — triggers the full multi-agent cycle. Orchestrator receives the input, delegates to Planner, Planner outputs a spec, Implementor writes code against it, Tester validates, Documentor updates the relevant files. The commit lands in the branch. The PR is updated.

The "chat" becomes the only interface needed to initiate a full development cycle. The backend handles the coordination.

We're close to this being practical, not experimental. The pieces are available — GitHub Models, Copilot Extensions, Actions workflows, MCP servers. The integration work is real, but it's integration work, not research.

---

## The question worth sitting with

If agents can handle orchestration, planning, implementation, testing, and documentation — what does the developer role look like in two years?

My current answer: you become the person who defines the standards, maintains the context, and makes the judgment calls the agents can't make. You move up the stack. The work doesn't disappear — it changes altitude.

That's a better job, not a smaller one. But it requires building the muscle now.
