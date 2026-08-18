---
title: "Cloudflare Tunnel"
weight: 20
tags: ["homelab", "cloudflare", "networking", "security"]
description: "Public access to home services with no forwarded ports and no inbound firewall rules."
---

{{< lead >}}
Every public URL on this cluster is served through an outbound-only tunnel. My router has
no port forwards at all.
{{< /lead >}}

## What it is

`cloudflared` is a connector that dials **out** to Cloudflare and holds the connection
open. Requests for `*.apexarcology.com` arrive at Cloudflare's edge and are handed back
down that existing connection.

The direction is the whole point. Nothing on the internet can initiate a connection to my
house. There is no inbound rule to misconfigure, no port to leave open, and my home IP is
never in DNS.

## Why this one

The alternatives were port forwarding with dynamic DNS, or a VPN.

Port forwarding puts my home IP in public DNS and makes the router the security boundary.
A VPN is fine for me but useless for sharing anything with anyone else. The tunnel gives
public access to the services that should be public, with Cloudflare Access in front of
the ones that should not be — and it costs nothing at this scale.

The cost is a hard dependency on Cloudflare. If they have an outage, everything public
here is down. For a homelab that is an acceptable trade; for anything load-bearing it
would not be.

Decision: `specs/007-dns-adr/spec.md`.

## Where it lives

| | |
|---|---|
| Manifests | `k8s/bootstrap/cloudflared/` |
| ArgoCD app | **none — not GitOps-managed** |
| Image | `cloudflare/cloudflared:2025.5.0` |
| DNS + tunnel config | `nas/dns/` (Terraform) |
| Spec | `specs/007-dns-adr/` |

{{< alert icon="triangle-exclamation" >}}
This is the one component that every public URL depends on and that **ArgoCD does not
manage**. There is no `k8s/apps/templates/cloudflared.yaml`, so nothing goes `OutOfSync`
if it drifts or disappears. That is arguably correct — the thing exposing the cluster
shouldn't depend on the cluster's own reconciliation loop — but it was never written down
as a decision, so it reads as an omission.
{{< /alert >}}

## Usage

DNS records and tunnel routes are Terraform, not Kubernetes:

```bash
cd nas/dns
terraform plan
terraform apply
```

Adding a new public service is two steps: a Traefik `IngressRoute` with the right
`Host()` rule, and a hostname entry in the Terraform so Cloudflare knows to route it.
Miss the second and the service is reachable in-cluster but returns a Cloudflare error
publicly.

Check the connector:

```bash
kubectl -n cloudflared get pods
kubectl -n cloudflared logs deploy/cloudflared --tail=30
```

Healthy logs show registered connections to several Cloudflare colos.

## Troubleshooting

**A new service 404s or 530s publicly but works via port-forward.**

The `IngressRoute` exists but the hostname was never added to the Terraform. This is the
single most common mistake here, because the Kubernetes half succeeds on its own and
gives no hint that the other half is missing. Check `nas/dns/main.tf` for the hostname
before debugging anything in the cluster.

**Everything public is down at once.**

Check the connector pod first, then Cloudflare's status page. A single dead connector
takes out every public URL simultaneously — the blast radius is total by design.

**Certificate warnings on an internal hostname.**

Internal TLS comes from a self-signed cluster CA via [cert-manager](../cert-manager/), not
from Cloudflare. A browser that has not trusted that CA will complain. Public hostnames
terminate at Cloudflare and are unaffected.

## Related

- Spec: `specs/007-dns-adr/spec.md`
- Terraform: `nas/dns/`
- [Traefik](../traefik/) — what the tunnel forwards to
