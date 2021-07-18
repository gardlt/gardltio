---
title: "Kubernetes Architecture - Control Plane Flows"
date: 2021-04-19T20:24:56-05:00
draft: false
categories: [development, publishing]
tags: [hugo,content,static site generator]
---

## Components 

The kubernetes control plane is where the resources are maintained, scheduled, deployed.

The control plane consist of 4 core services and 1 optional.

* kube-apiserver
* kube-scheaduler
* kube-control-manager
* kube-cloud-control-manager (optional)
* etcd

### kube-apiserver

In order to talk with you K8s cluster all request need to go through the API Server.

`kubectl` and `Helm` interact with the `kube-api` in order to deploy the manifest into the cluster.

In order make valid request to the API you will need a `KUBECONFIG` that contains the credentials to execute command against the k8s cluster.

### kube-scheaduler

The scheduler process will determine in which worker node the pod will be ran on.

Takes into consideration:

* individual and collective resource requirements
* hardware/software/policy constraints
* affinity and anti-affinity specifications
* data locality
* inter-workload interference
* deadlines

### kube-control-manager

Detects cluster state changes. ensures that the desired states of the pods is always maintained.

**Node controller:**
Responsible for noticing and responding when nodes go down.

**Job controller:**
Watches for Job objects that represent one-off tasks, then creates Pods to run those tasks to completion.

**Endpoints controller:**
Populates the Endpoints object (that is, joins Services & Pods).

**Service Account & Token controllers:**
Create default accounts and API access tokens for new namespaces.

> For a large cluster: you need a control plane with sufficient compute and other resources.

### kube-cloud-control-manager

A Kubernetes control plane component that embeds cloud-specific control logic. The cloud controller manager lets you link your cluster into your cloud provider's API, and separates out the components that interact with that cloud platform from components that only interact with your cluster.

The following controllers can have cloud provider dependencies:

Node controller: For checking the cloud provider to determine if a node has been deleted in the cloud after it stops responding
Route controller: For setting up routes in the underlying cloud infrastructure
Service controller: For creating, updating and deleting cloud provider load balancers


### etcd

This is a Highly Available Key Value Store service.

You can consider this the brains of the cluster. All the manifest of the deployed applications will reside and their desired states.

No Application data can be stored in the etcd.



> For a large cluster:
> To improve performance of large clusters, you can store Event objects in a separate dedicated etcd instance. Typically you would run one or two control plane instances per failure zone, scaling those instances vertically first and then scaling horizontally after reaching the point of falling returns to (vertical) scale.


##  Deploying Manifests

### Deploying Kubernetes Manifest

{{< figure src="/images/k8s/kube-scheduler.png" title="" >}}

### Controller Manager - Checking Workloads

{{< figure src="/images/k8s/controller-manager.png" title="" >}}
