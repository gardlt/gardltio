---
title: "cert-manager"
weight: 31
tags: ["homelab", "kubernetes", "cert-manager", "tls", "pki"]
description: "A private certificate authority inside the cluster, issuing TLS certs to internal services automatically."
---

{{< lead >}}
Internal hostnames get real TLS certificates without me touching OpenSSL. A self-signed
CA lives in the cluster and issues them on request.
{{< /lead >}}

## What it is

A controller that watches for `Certificate` resources and produces the corresponding
Kubernetes `Secret` containing a key and cert. It also renews them before expiry, which is
the part that actually matters — a certificate you have to remember to rotate is a
certificate that will expire on a weekend.

Here it runs a **private CA**, not public certificates.

## Why this one

Public certificates for these hostnames would mean Let's Encrypt and a DNS-01 challenge,
which is doable but pointless: everything public already terminates TLS at
[Cloudflare](../cloudflared/), which supplies its own certificate. What is left is
in-cluster and internal-hostname traffic, where a private CA is the right tool.

The trade is trust distribution. A self-signed CA means every client that talks to an
internal hostname directly must trust `homelab-ca`, or see a browser warning. For a
cluster with one operator, that is a one-time import, not a fleet-management problem.

## Where it lives

| | |
|---|---|
| Namespace | `cert-manager` |
| Manifests | `k8s/bootstrap/cert-manager/` |
| ArgoCD app | `k8s/apps/templates/cert-manager.yaml` |
| Version | `v1.14.5` (upstream `cert-manager.yaml`) |
| Issuers | `selfsigned`, `selfsigned-ca` (both `ClusterIssuer`) |
| CA cert | `Certificate/homelab-ca` → `Secret/homelab-ca-secret` |
| Key | ECDSA P-256 |

The two-issuer arrangement is the standard bootstrap chain, and it confuses people the
first time:

1. `ClusterIssuer/selfsigned` signs exactly one thing — the CA certificate itself.
2. `Certificate/homelab-ca` (`isCA: true`) is issued by it and stored in
   `homelab-ca-secret`.
3. `ClusterIssuer/selfsigned-ca` uses that secret to sign everything else.

Services request certs from `selfsigned-ca`. Nothing but the CA should reference
`selfsigned` directly — a cert issued by it is its own root and chains to nothing.

## Usage

Requesting a certificate:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
spec:
  secretName: example-tls
  dnsNames: ["example.apexarcology.com"]
  issuerRef:
    name: selfsigned-ca
    kind: ClusterIssuer
```

Then reference `example-tls` as the `secretName` in the service's `IngressRoute`.

Checking state:

```bash
kubectl get clusterissuer
kubectl get certificate -A
kubectl describe certificate <name> -n <ns>
```

A healthy `Certificate` shows `READY: True`. Anything else, `describe` names the reason.

## Troubleshooting

**`Certificate` stuck with `READY: False`.**

Walk the chain downward — cert-manager creates a `CertificateRequest`, then an `Order`, and
the failure is usually further down than the `Certificate` itself:

```bash
kubectl get certificaterequest -n <ns>
kubectl describe certificaterequest <name> -n <ns>
```

**Browser warns about an untrusted certificate on an internal hostname.**

Expected. `homelab-ca` is not in any public trust store. Export it from
`homelab-ca-secret` and import it into the client:

```bash
kubectl -n cert-manager get secret homelab-ca-secret \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.crt
```

Public hostnames are unaffected — those certificates come from Cloudflare.

**Everything's certificates fail at once.**

Check `homelab-ca-secret` still exists. Deleting it orphans every certificate it signed,
and cert-manager will mint a *new* CA — so previously-trusted clients start failing even
after things look healthy again.

## Related

- [cert-manager documentation](https://cert-manager.io/docs/)
- [Traefik](../traefik/) — the main consumer of these certificates
- [Cloudflare Tunnel](../cloudflared/) — where public TLS comes from instead
