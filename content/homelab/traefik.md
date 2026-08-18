---
title: "Traefik"
weight: 21
tags: ["homelab", "kubernetes", "traefik", "ingress", "networking"]
description: "The ingress controller: one entry point that routes by hostname and terminates TLS inside the cluster."
---

{{< lead >}}
Everything that arrives at the cluster arrives here first. Traefik reads `IngressRoute`
objects, matches the hostname, and forwards to the right Service.
{{< /lead >}}

## What it is

An ingress controller. It holds a single LoadBalancer IP — handed to it by
[MetalLB](../metallb/) — and decides which of the ten-odd services a request belongs to,
based on the `Host()` rule in an `IngressRoute`.

Without it, exposing a service means burning a distinct IP and port per service. With it,
every public hostname shares one address.

## Why this one

k3s ships Traefik by default, so the honest answer is that it was already there and
nothing has justified replacing it.

The reason it stayed is `IngressRoute`. Traefik's own CRD is more expressive than the
stock `Ingress` resource for the things I actually do — middleware chains, TLS options,
routing on more than a path prefix — without pushing everything into annotations. NGINX
would work; it would not be better here.

The cost is lock-in: `IngressRoute` is Traefik-specific, so those manifests do not port to
another controller.

## Where it lives

| | |
|---|---|
| Namespace | `traefik` |
| Manifests | `k8s/bootstrap/traefik/` |
| Install | Helm chart `traefik` `26.1.0` from `https://helm.traefik.io/traefik` |
| Entry point | `websecure` (443) |
| Service type | `LoadBalancer` — IP from MetalLB |

## Usage

Exposing a service is one `IngressRoute` in that service's manifest directory:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: example
spec:
  entryPoints: [websecure]
  routes:
    - match: Host(`example.apexarcology.com`)
      kind: Rule
      services:
        - name: example
          port: 80
```

Then add the hostname to the Cloudflare tunnel config in `nas/dns/` — the Kubernetes half
alone does not make it public. See [Cloudflare Tunnel](../cloudflared/).

Inspect what Traefik currently knows about:

```bash
kubectl get ingressroute -A
kubectl -n traefik get svc traefik          # the LoadBalancer IP
kubectl -n traefik logs deploy/traefik --tail=50
```

The dashboard is not exposed publicly. Reach it by port-forward when you need it.

## Troubleshooting

**404 from Traefik on a hostname that should work.**

Traefik answering at all means the request reached it — so this is a rule mismatch, not a
routing failure. Check the `Host()` value character for character, and check the
`IngressRoute` is in the **same namespace as the Service** it points at. Cross-namespace
references need an `ExternalName` Service or a explicit namespace, and silently 404
otherwise.

**502 after the route matches.**

The rule is right and the backend is wrong. Usually the `port` in the `IngressRoute` is
the container port when it should be the Service port, or the pod is not `Ready`.

```bash
kubectl -n <ns> get endpoints <svc>
```

Empty endpoints means no ready pod is backing the Service — fix the pod, not the route.

**Service works via port-forward but not through the hostname.**

Port-forward bypasses Traefik entirely, so this narrows it to ingress. Check the
`IngressRoute` exists and the `entryPoints` list says `websecure`; a route on the wrong
entry point is valid YAML that never matches.

## Related

- [Traefik documentation](https://doc.traefik.io/traefik/)
- [MetalLB](../metallb/) — where its IP comes from
- [Cloudflare Tunnel](../cloudflared/) — what sits in front of it
- [cert-manager](../cert-manager/) — where its certificates come from
