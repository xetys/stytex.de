---
layout: post
title: "The ultimate Kubernetes bare-metal deployment comparison"
date: 2017-03-26 12:00:00 +0100
comments: true
categories:
 - kubernetes
 - devops
 - microservices
 - development
 - coreos
---

{% img center https://opencredo.com/wp-content/uploads/2015/12/kubernetes.png 653 160 'kubernetes' %}

## introduction

In [my recent article on K8S deployment](/blog/2017/01/25/deploy-kubernetes-to-bare-metal-with-nginx/) I described my first approach on building a working K8S cluster. Despite this was a working setup, it was simplified to make the setup easier. However my personal aim was more about:

> How to deploy a production ready kubernetes cluster on bare-metal or on-prem?

To be more precise, what I try to achieve:

> I don't want to use AWS/Azure/GKE for some reasons
> I want to know a generic way for turn key clusters, agnostic to the underlying infrastructure

To give myself a good answer to this non-trivial question, I tried out all good looking solutions out there. Thanks to [ProfitBricks](https://www.profitbricks.de/de/), I got some free resources on their platform, so I could try the candidates fast. After weeks of research, I can summarize my results using the following figure:


{% img center images/2017/03/k8s-dpl-comparison-results.png 997 290 'K8S bare-metal deployment comparison results' %}

I think that figure is quite self-describing. I provisioned at least

* [CoreOS Container Linux](https://coreos.com/os/docs/latest) using my hands (bash scripts), and [matchbox](https://github.com/coreos/matchbox)
* [Rancher](http://rancher.com/) 1.4.1 on Ubuntu 16.04
* k8s with kubeadm on Ubuntu 16.04
* k8s using the [Kismatic Enterprise Toolkit](https://github.com/apprenda/kismatic)

Before I dive deep into the way how I tested the candidates, the winner here is: kismatic. To make clear: I was testing a small scale scenario with less then 10 nodes overall.

## How I tested the scenarios
