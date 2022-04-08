---
title: "Kubernetes Architecture - Control Plane Flows"
date: 2021-04-19T20:24:56-05:00
draft: true
tags: [kubernetes, software, devops]
---

## Components 

The kubernetes control plane is where the resources are maintained, scheduled, deployed.

The control plane consist of 4 core services and 1 optional.

* kube-apiserver
* kube-scheaduler
* kube-control-manager
* kube-cloud-control-manager (optional)
* etcd

##  Deploying Manifests

### Deploying Kubernetes Manifest

{{< figure src="/images/k8s/kube-scheduler.png" title="" >}}

#### Step-By-Step
1. Kubernetes Manifest `kubectl apply -f file.yml`
    1a. Before applying the manifest the kube-api will validate the API manifest
    1b. Validate `KUBECONFIG` certificates
    1c. Validate against authentication 
2. Store Manifest in `etcd` to define the state of the pods.
3. Control Manager
    3a. Checks if the pod exist and is healthy
    3b. If the pod is not deployed or it needs to updated be updated, it will be send to the scheduler
4. Control Manager will send the manifest to the scheduler
    4a. Sends the deployment requests to the API
    4b. The kube-api send the request to the worker node talking to the `kubelet`
    4c. Creates the container and updated the container with the `kube-proxy`

### Controller Manager - Checking Workloads

{{< figure src="/images/k8s/controller-manager.png" title="" >}}

#### Step-By-Step

1. Checks and watches the state of pods
2. Pull Pod information
3. checks desired state
4. Queue new request to update the pod in the cluster
5. Send a request to create/update pods to their desired state
6. Sends the request to the `kubelet` to update or create/update resources