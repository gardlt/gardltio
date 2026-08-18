---
title: "ArgoCD"
weight: 30
tags: ["homelab", "kubernetes", "argocd", "gitops"]
description: "The reconciliation loop: git is the desired state, and anything ArgoCD manages heals itself."
---

{{< lead >}}
Ten applications are deployed by committing YAML, not by running `kubectl`. ArgoCD watches
the repo and makes the cluster match it.
{{< /lead >}}

## What it is

A GitOps controller. It reads Kubernetes manifests from this repository and continuously
reconciles the cluster against them. Deploying a change is `git push`; the cluster catches
up on its own.

It runs the **app-of-apps** pattern: one `Application` (`k8s/apps/app-of-apps.yaml`) points
at the directory `k8s/apps/templates/`, and every file in that directory is itself an
`Application`. Adding a service to GitOps means adding one file there.

## Why this one

The alternative was what I was already doing: `kubectl apply` by hand, and a repo that
described the cluster as I remembered it rather than as it was.

The property that matters is not automation, it is **drift detection**. Anything ArgoCD
manages goes `OutOfSync` the moment reality diverges from git, and with `selfHeal: true`
it corrects itself. Anything outside it rots silently — I lost an entire service that way,
and the CI workflow kept building the image for months after the manifests were deleted.
That story is in [the retrospective](/posts/homelab/006-eight-weeks-later-what-the-homelab-actually-runs/).

That failure is the argument for ArgoCD, stated backwards: a service outside GitOps has no
immune system.

## Where it lives

| | |
|---|---|
| Namespace | `argocd` |
| Manifests | `k8s/bootstrap/argocd/` |
| Install | upstream `install.yaml`, **v2.10.5**, via kustomize remote resource |
| Root app | `k8s/apps/app-of-apps.yaml` |
| Managed apps | `k8s/apps/templates/` — ten `Application` files |
| URL | `https://argocd.apexarcology.com` |

ArgoCD is installed by hand with `kubectl apply -k`, not by itself. It has to exist before
anything can be GitOps-managed, and `app-of-apps.yaml` is likewise applied once by hand.
Everything after that is git.

The server runs with `server.insecure: true` (in `argocd-cmd-params-cm.yaml`) because
[Traefik](../traefik/) terminates TLS in front of it. Double TLS termination is the classic
ArgoCD-behind-ingress redirect loop.

## Usage

Adding an application — the whole workflow:

```yaml
# k8s/apps/templates/example.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: example
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/gardlt/homelab.git
    targetRevision: HEAD
    path: k8s/bootstrap/example
  destination:
    server: https://kubernetes.default.svc
    namespace: example
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: ["CreateNamespace=true"]
```

Commit it. The root app notices the new file and creates the application.

Checking state:

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application <name>
```

Forcing a sync without waiting for the poll interval:

```bash
argocd app sync <name>
```

## Troubleshooting

**An application is `OutOfSync` and stays that way.**

This is ArgoCD working. Something changed the live resource outside git, or the manifest in
git is invalid. `describe` the Application and read the sync result — it names the resource
and the diff.

**A change was pushed but nothing happened.**

Check the Application's `targetRevision` and `path`. Every app here uses `HEAD`, so a
change on a non-default branch will never be picked up. Also confirm the file is in
`k8s/apps/templates/` — the root app watches that directory only.

**Deleting a manifest deleted the running workload.**

That is `prune: true`, and it is intentional. Removing a resource from git means removing
it from the cluster. Be deliberate about deletions in a bootstrap directory.

**Something is deployed but ArgoCD doesn't know about it.**

Then it is not GitOps-managed and nothing will notice when it breaks. Two things in this
cluster are in that state on purpose — [cloudflared](../cloudflared/) and the bootstrap
layer itself — and it is worth knowing which. Everything else should have a file in
`k8s/apps/templates/`.

## Related

- [ArgoCD documentation](https://argo-cd.readthedocs.io/)
- [Eight weeks later](/posts/homelab/006-eight-weeks-later-what-the-homelab-actually-runs/) — what happened to the service that left GitOps
