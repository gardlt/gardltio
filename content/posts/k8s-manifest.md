---
title: "K8s Manifest"
date: 2021-04-16T22:11:13-05:00
draft: false
tags: [kubernetes, software, devops]
---

`spec` and `status`


## Spec

For objects that have a spec, you have to set this when you create the object, providing a description of the characteristics you want the resource to have: its desired state.

## Status

The status describes the current state of the object, supplied and updated by the Kubernetes system and its components. The Kubernetes control plane continually and actively manages every object's actual state to match the desired state you supplied.


## Required Fields:

`apiVersion` - Which version of the k8s API you are using to create object

`kind` - What kind of object do you want to create. 

`metadata` - data that helps uniquely identify the object including: name or namespace

`spec` - desired state of the object



# Workloads

Deployment and Replicasets

StatefulSet

DaemonSet

Job and CronJob


# Services, Load Balancing and Networking

- Service
- Topology-aware traffic routing with topology keys
- DNS for services and Pods
- Connecting Application with services
- Ingress 
- Ingress Controller
- Endpoint Slices
- Service Internal Traffic Policy
- Topology Aware hints
- Network Policies
- Addding entries to POD /etc/hosts with HostAliases
- IPv4/IPv6 dual-stack

# Storage

- Volumes
- Persistent Volumes
- Volume Snapshots
- CSI Volume Cloning
- Storage Classes
- Volumn Snapshot Class
- Dynamic Volume Provisioning
- Storage Capacity
- Ephemeral Volumes
- Node-Specific Volumne Limit
- Volumn Health Monitoring

# Configuration
- ConfigMaps
- Secrets
- Managing Resources for containers
- organizing cluster access using kubeconfig files
- Pod priority and Preemption

# Security
- Cloud Native security
- Pod security Standards
- Controlling Access to the Kubernetes API

# Policies
- limit ranges
- resource quotas
- pod security policies
- Procecess ID limits and Reservations
- Node Resource Managers

# Scheaduling and Eviction
- Kubernetes scehaduler
- Assigning Pods to Nodes
- Resource Bin Packing for Extended Resources
- Taints and Tolerations
- Pod overhead
- Eviction Policy
- Scheaduling Framework
- Scheaduler Performance Tunning




