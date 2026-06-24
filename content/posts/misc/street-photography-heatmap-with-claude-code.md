---
title: "I Used an AI Agent to Solve My Biggest Street Photography Problem"
date: 2026-06-24
draft: false
tags: ["photography", "street-photography", "claude-code", "ai-agents", "side-project"]
description: "Winter killed my go-to locations. I built a foot traffic heatmap with Claude Code to find new ones — and learned something about agentic development along the way."
---

## The problem

Street photography lives and dies by location. You need foot traffic, interesting light, and enough density that something worth capturing will happen in the time you're willing to stand around.

Winter kills most of my usual spots. Outdoor markets thin out. Tourist corridors empty. The places that work in July become ghost towns by February. I've been solving this manually for years — walking different neighborhoods, checking event calendars, asking other photographers — but it doesn't scale. I needed a better way to surface high-traffic locations before I leave the house.

This weekend I built one.

---

## What I built

A dynamic heatmap that overlays foot traffic data by day of week, proximity to landmarks, and density of local dining hubs. The idea: restaurants and cafés are a reliable proxy for pedestrian activity. Where people eat, people walk. Where people walk, there's something to photograph.

The tool pulls location data, scores each area across those three dimensions, and renders it as a map layer I can filter by day. Planning a Saturday shoot is now a ten-second lookup instead of guesswork.

---

## How Claude Code changed my process

I've been using GitHub Copilot for a while. It's good at autocomplete, decent at boilerplate. What I wanted to test was whether the "agent" model — giving a tool a goal and letting it reason about the implementation — actually felt different.

It does.

**Speed from idea to MVP.** The agentic approach collapsed the gap between "I want a heatmap" and "here is a working heatmap." Instead of speccing out the component structure, writing stubs, then filling them in, I described what I wanted and iterated on the output. The scaffolding phase that usually takes hours happened in minutes.

**Context matters enormously.** I added a `CLAUDE.md` file with project-specific context — my preferred stack, how I wanted data structured, constraints on the map library. The accuracy improvement was immediate. The agent stopped making generic choices and started making choices that fit my actual setup. Custom context isn't optional; it's the difference between a useful agent and a fast one that needs constant correction.

**Developer intuition still required.** The tool hit a wall on some JavaScript logic around the scoring aggregation. The output was wrong in a non-obvious way — the map rendered, but the weights weren't combining correctly. I had to diagnose it, explain the issue, and guide it through the fix. What impressed me: it didn't just patch the reported line. It understood the underlying logic error and corrected the approach. That's a different kind of collaboration than autocomplete.

---

## Where this lands

Still loyal to Copilot for day-to-day coding. It's fast, it's integrated, it knows my habits. But the gap is narrowing in ways I didn't expect a year ago. Agentic coding — give it a goal, guide it through edge cases, iterate — is a real mode of development, not just a demo.

For side projects where I want to go from zero to something fast, it's now my first move.

The heatmap works. Next shoot is Saturday.

---

*What's the most useful thing you've built with an AI agent? I'm genuinely curious what the non-obvious use cases look like for other people.*
