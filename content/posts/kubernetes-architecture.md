---
title: "Kubernetes Anatomy"
date: 2021-04-16T21:09:11-05:00
draft: false
---

# What is a K8s?

Kubernetes is a orchestrator that schedules services and insures that services are always running.

# Features

## Services

Its able to expose the containers services via IP or DNS and handle high volume  traffic by load balancing pods

## Storage Orchestrations

It allows methods of mounting a variety of storage devices to the pods using local or public cloud providers.

## Automated rollouts and rollbacks

Using the kubernetes manifest you can define desired state of your deployment. The manifest definitions like the `Deployment` will create `Pod`s on the k8s cluster. It will handle scenarios of rolling upgrades to ensure that no downtime occurs.

## Automatic bin packing

Like in docker, you are able to target limitations of the resources can use for each container. You are also able to create resource quotas at a namespace level to ensure your team does not exceed the threshold.
The K8s will also handle the optimal scheduling of the the resources to the worker nodes

## Self Healing

In order to ensure that k8s containers are never in a valid state. K8s will ensure that the pods are in a healthy state and if they ever become unhealthy it will terminate the bad pods and spin up new ones. User health checks are defined in the k8s manifests.

## Secret and configuration management

Similar to docker secretes and config kubernetes is able to create `ConfigMap` and `Secret` artifacts to store configurations in the cluster. You will also be able to maintain and update the k8s theses configuration types without rebuilding container.



# What are the K8s components?

{{< figure src="/images/k8s/kubernetes-arch.png" title="" >}}

## Control Plane

K8s control plane consist of 4 - 5 components?

* kube-apiserver
* kube-scheaduler
* kube-controller-manager
* kuber-cloud-controller-manager (optional)
* etcd

### API Server

In order to talk with you K8s cluster all request need to go through the API Server.

`kubectl` and `Helm` interact with the `kube-api` in order to deploy the manifest into the cluster.

In order make valid request to the API you will need a `KUBECONFIG` that contains the credentials to execute command against the k8s cluster.

### Scheduler

The scheduler process will determine in which worker node the pod will be ran on.

Takes into consideration:

* individual and collective resource requirements
* hardware/software/policy constraints
* affinity and anti-affinity specifications
* data locality
* inter-workload interference
* deadlines

### Controller Manager

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

### Cloud Controller Manager

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

## Worker Nodes

### Container Runtime Engine (CRE)

CRE:
* docker engine
* crio-io
* containerd

CNI:
* calico
* weave

On each worker node, you will need Container Runtime Engine (CRE) and a Container Network Interface (CNI).
### Kubelet

The kubelet will receive the request from the control plane's control manager to spin up new pods. The kubelet is the component that will interact with the CNI and CRE.

### Kube-Proxy

The `kube-proxy` is the service that will keep record of the running containers IP and handle the forwarding of requests within the worker nodes.





# Sources

https://www.youtube.com/watch?v=X48VuDVv0do&ab_channel=TechWorldwithNana
https://kubernetes.io/docs/concepts/overview/components/
https://kubernetes.io/docs/concepts/architecture/
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/
https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/