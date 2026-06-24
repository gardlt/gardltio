---
title: "Hermes: Why I Built a gRPC Agent Registry Instead of Using an Existing Framework"
date: 2026-06-24
draft: false
tags: ["homelab", "golang", "grpc", "kubernetes", "ai-agents", "adr"]
series: ["homelab-ai-platform"]
description: "The ADR process that led me to build Hermes — a custom Go gRPC agent registry — instead of adopting an existing AI agent platform."
---

When I decided to run AI agents on my home k3s cluster, the first question was: how do agents find each other?

In a monolith, this is trivial. In a microservices architecture, you have Consul, Kubernetes Service DNS, or an API gateway. But agents are different from services — they register themselves, announce their capabilities, go offline, come back, and need to be discoverable by capability rather than just by name. I needed something purpose-built.

My first instinct was to adopt an existing framework. So I evaluated the two most plausible options: **Hermes** (which I'd design from scratch) vs **OpenClaw** (an open-source personal AI assistant platform with 379K GitHub stars and a gateway architecture for WhatsApp, Telegram, Slack, Discord, and Signal).

## The ADR process

I've started using scored Architectural Decision Records for every significant choice in this project. The format is simple: define decision dimensions, score candidates against your actual requirements, then accept the result even when it's uncomfortable. It forces you to be honest about what you actually need rather than what sounds cool.

For the agent framework decision, I scored seven dimensions:

| Dimension | Hermes | OpenClaw |
|---|---|---|
| D1 — Use Case Fit | 2 | 2 |
| D2 — Kubernetes-Native | **3** | 1 |
| D3 — Maintenance Burden | **3** | 1 |
| D4 — Inter-Agent Protocol (gRPC/REST) | **3** | 1 |
| D5 — Dynamic Discovery | **3** | 1 |
| D6 — Channel Integration (WhatsApp/Slack) | **3** | 0 |
| D7 — Community & Self-Sufficiency | **3** | 1 |
| **TOTAL** | **20** | **7** |

The result was unambiguous. OpenClaw is excellent software — 379K stars means a lot of people find it valuable. But it solves a fundamentally different problem: *human-to-agent interaction via messaging channels*. My problem is *machine-to-machine coordination within a Kubernetes cluster*. Those are adjacent but distinct.

OpenClaw's architecture reflects its use case: Node.js runtime, WebSocket node pairing, static workspace routing via `AGENTS.md` config files, and no Helm chart (I'd have to write the k8s manifests myself). For a Discord-accessible personal assistant, that's fine. For a cluster-internal registry where agents register themselves dynamically and other agents query live state with sub-500ms latency — it's the wrong tool.

## Why build from scratch

Building Hermes from scratch carries real cost: I own the code, I fix the bugs, I add the features. OpenClaw has 1,170+ contributors; Hermes has one.

The counterargument: Hermes is small. The core service is a registry with three operations — Register, Query, Watch. The complexity surface is low, the ownership burden is proportional, and I get exactly what I need with no adapter layer over a framework designed for a different use case.

I made the call: build Hermes, own it fully, keep it small.

## What Hermes does

Hermes is a Go service with a dual interface: gRPC on port 50051 and an HTTP/REST gateway on port 8080 (via grpc-gateway). The proto contract defines three operations:

```protobuf
service AgentRegistry {
  rpc Register(RegisterRequest)   returns (RegisterResponse);
  rpc Query(QueryRequest)         returns (QueryResponse);
  rpc Watch(WatchRequest)         returns (stream AgentEvent);
}
```

**Register**: An agent starts, calls `Register` with its name, capabilities, and endpoint. Hermes stores it. The registration carries a TTL — if the agent doesn't heartbeat, Hermes evicts it.

**Query**: Another agent or operator calls `Query` with optional capability filters. Hermes returns all matching live registrations.

**Watch**: A server-streaming RPC. Callers subscribe to agent lifecycle events (registered, evicted, updated) and receive them in real time as the registry changes.

The internal store is an in-memory map protected by a `sync.RWMutex`. A background sweeper goroutine runs on a configurable interval, evicting registrations past their TTL. Tests cover the store independently from the gRPC layer, and the watch tests verify that event streams receive the right events in order.

## The implementation

```
apps/hermes/
├── proto/hermes.proto          # Source of truth
├── gen/hermesv1/               # Generated Go from buf
├── internal/
│   ├── registry/
│   │   ├── record.go           # AgentRecord struct + TTL logic
│   │   ├── store.go            # Thread-safe in-memory registry
│   │   ├── store_test.go       # Store unit tests
│   │   └── sweeper.go          # Background TTL eviction goroutine
│   └── server/
│       ├── server.go           # gRPC + HTTP server setup
│       ├── registry_handlers.go # Register/Query/Watch handlers
│       ├── health.go           # /healthz endpoint
│       ├── metrics.go          # Prometheus metrics
│       ├── register_test.go    # Integration tests for Register
│       └── watch_test.go       # Integration tests for Watch streaming
└── main.go                     # Flag parsing, signal handling, server start
```

`main.go` is 47 lines. It parses two flags (`--grpc-addr`, `--http-addr`), creates the store, starts the sweeper, starts gRPC and HTTP servers in goroutines, and blocks on context cancellation or an error from either server.

## Deploying on k3s

The deployment follows the same ArgoCD App-of-Apps pattern as every other service in the cluster:

```yaml
# k8s/bootstrap/hermes/deployment.yaml (abbreviated)
containers:
  - name: hermes
    image: ghcr.io/gardlt/homelab/hermes:latest
    ports:
      - containerPort: 50051  # gRPC
      - containerPort: 8080   # REST gateway
    readinessProbe:
      httpGet:
        path: /healthz
        port: 8080
```

The service exposes both ports. The `IngressRoute` routes `hermes.apexarcology.com` to port 8080 for REST access. In-cluster agents call the gRPC endpoint directly at `hermes.hermes.svc.cluster.local:50051`, which stays inside the cluster mesh and doesn't route through Cloudflare.

## What the ADR taught me

The most useful part of the scoring process wasn't the number — it was being forced to articulate *why* each dimension mattered. Writing out "D5: agents need to discover each other dynamically via a live registry with sub-500ms query latency" meant I couldn't rationalize OpenClaw's static workspace routing as "good enough." The requirement was specific. The gap was real.

I've applied the same format to every major infrastructure decision since. The scores don't make the decision — the requirements do. The scores just prevent motivated reasoning from overriding them.

Next up: the five infrastructure ADRs that shaped the platform beneath the agents — storage, secrets, monitoring, and DNS.
