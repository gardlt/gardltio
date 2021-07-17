---
title: "Kubernetes Architecture - Control Plane Flows"
date: 2021-04-19T20:24:56-05:00
draft: false
---

The kubernetes control plane is where the resources are maintained, scheduled, deployed.

The control plane consist of 4 core services and 1 optional.

* kube-apiserver
* kube-scheaduler
* kube-control-manager
* kube-cloud-control-manager
* etcd
##  Deploying a K8s Workload

{{< figure src="/images/k8s/kube-scheduler.png" title="" >}}

## Controller Manager - Checking Workloads

{{< figure src="/images/k8s/controller-manager.png" title="" >}}
