---
title: "K8s Auth Config"
date: 2021-04-18T13:04:59-05:00
draft: true
---


# Authentication

## User Types

** Service Accounts **

users manage by the Kube APi. Theya are bound to specific namesace and created by the API. THey are tied to a set credentisons stored in secretes.


- normal users

# IAM

- an addmistorator distributing private keys
- user store like Keystone, Google Accounts, Azure Active Directory
- file with a list of usernames and passwords.

## Auth Strategies


### X509 Client Certs

### Static Token File

### Bootstrap Tokens

### Service Account Token

### OpenID Connect Tokens