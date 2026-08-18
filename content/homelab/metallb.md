---
title: "MetalLB"
weight: 22
tags: ["homelab", "kubernetes", "metallb", "networking", "bare-metal"]
description: "LoadBalancer Services on bare metal, with no cloud provider to hand out IPs."
---

{{< lead >}}
On a cloud provider, a `LoadBalancer` Service gets an IP automatically. On four NUCs under
a desk, nothing hands one out — MetalLB is what does.
{{< /lead >}}

## What it is

A load-balancer implementation for clusters that are not running in a cloud. It owns a
range of addresses on my home LAN and assigns them to `LoadBalancer` Services.

Without it, a `LoadBalancer` Service sits in `Pending` forever, because Kubernetes itself
has no idea how to obtain an IP — that job normally belongs to the cloud controller
manager, and there isn't one here.

## Why this one

Two ways to expose a service on bare metal: `NodePort`, or MetalLB.

`NodePort` works but gives you a high-numbered port on every node and no stable address.
MetalLB gives a real IP on the home network that behaves the way an IP is supposed to.
Since exactly one Service needs this — [Traefik](../traefik/) — the setup cost is paid
once and everything else routes by hostname behind it.

In **L2 mode**, one node answers ARP for the assigned address. That means failover but not
true load distribution: all traffic for an IP lands on a single node. At four nodes and
home-scale traffic, that is fine. BGP mode would distribute properly and needs a router
that speaks BGP, which mine does not.

## Where it lives

| | |
|---|---|
| Namespace | `metallb-system` |
| Manifests | `k8s/bootstrap/metallb/` |
| Version | `v0.14.5` |
| Mode | Layer 2 (`L2Advertisement`) |
| Pool | `192.168.86.200` – `192.168.86.220` |

The pool is carved out of my home subnet and must sit **outside the router's DHCP range**.
Overlap means the router will eventually lease an address MetalLB has already claimed, and
the resulting conflict is intermittent and miserable to diagnose.

## Usage

Most of the time there is nothing to do — the pool is configured and Traefik holds one
address from it.

Check the assignment:

```bash
kubectl -n metallb-system get ipaddresspool
kubectl -n metallb-system get l2advertisement
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

A `LoadBalancer` Service with an `EXTERNAL-IP` in the `.200–.220` range is working.

## Troubleshooting

**A `LoadBalancer` Service is stuck in `Pending`.**

Either MetalLB is not running, or the pool is exhausted. Twenty-one addresses is a lot for
this cluster, so check the controller first:

```bash
kubectl -n metallb-system get pods
kubectl -n metallb-system logs deploy/controller --tail=30
```

**The IP is assigned but unreachable from the LAN.**

That is the speaker, not the controller. In L2 mode a speaker pod must announce the
address by ARP; if speakers are down, the IP exists in Kubernetes and nowhere else.

```bash
kubectl -n metallb-system get pods -l component=speaker
```

**Intermittent unreachability, works then doesn't.**

Suspect a DHCP collision — something else on the network was leased the same address.
Confirm the router's DHCP range does not overlap `192.168.86.200–220`. This is the failure
that looks like a Kubernetes problem and isn't.

## Related

- [MetalLB documentation](https://metallb.universe.tf/)
- [Traefik](../traefik/) — the one Service that consumes an address
