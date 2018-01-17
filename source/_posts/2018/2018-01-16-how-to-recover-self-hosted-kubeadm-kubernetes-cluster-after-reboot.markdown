---
layout: post
title: "How to setup & recover a self-hosted kubeadm Kubernetes cluster after reboot"
date: 2018-01-16 12:00:00 +0100
comments: true
categories:
 - kubernetes
---

{% img center https://opencredo.com/wp-content/uploads/2015/12/kubernetes.png 653 160 'kubernetes' %}

## introduction

In this article I will cover the quick setup of a self-hosted Kubernetes 1.9 cluster using kubeadm, **with the ability to recover after a power cycle (e.g., reboot)**

I started playing around with [kubeadm][] again for a new project and was especially interested in the self-hosting feature, which is in alpha state. In short, self-hosted clusters host their control plane (api-server, controller-manager, scheduler) as a workload. Compared to the universe of compilers, self-hosting is when a compiler can correctly compile the source code of itself. In term of kubernetes, this simplifies upgrading clusters to a new version and more in-depth monitoring

<!-- more -->

## quick setup

Consider we have three nodes where kubernetes should be installed. Each node should have internet connectivity and meet the requirements mentioned in the [install guide](https://kubernetes.io/docs/setup/independent/install-kubeadm/).

Let's say; the nodes are node1, node2, and node3. For a quick setup of docker and kubeadm, ssh on each node as root and run:

```
$ wget -cO- https://gist.githubusercontent.com/xetys/0ecfa01790debb2345c0883418dcc7c4/raw/2bcd7f42ce4c51d21b33e84aadc6438979e50286/ubuntu16-kubeadm | bash -

```

Then on node1:

```
$ kubeadm init --pod-network-cidr=192.168.0.0/16 --feature-gates=SelfHosting=true
$ mkdir -p $HOME/.kube
$ cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ chown $(id -u):$(id -g) $HOME/.kube/config
$ kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml
```

On node2 and node3 run:

```
$ kubeadm join --token <token> <master-ip>:<master-port> --discovery-token-ca-cert-hash sha256:<hash>
```

With the values from the output of the `kubeadm init` command. This is a quick setup for a self-hosted kubernetes with calico networking.


## make it recoverable

Currently, a reboot would cause a total failure of the cluster, as no new control plane is scheduled, and kubelet won't reach the API server. To fix this, run:

```
$ git clone https://github.com/xetys/k8s-self-hosted-recovery
$ cd k8s-self-hosted-recovery
$ ./install.sh
```

This will install a systemd service, which runs after the `kubelet.service` and a script `k8s-self-hosted-recover`, which does the *following to recover a self-hosted control plane after reboot*:

* perform the `controlplane` phase of kubeadm to setup the plane using static pods
* wait until the API server is working
* delete the `DaemonSet` of the current self-hosted control plane
* run the `selfhosted` phase of kubeadm

Congratulations, you have a three-node kubernetes 1.9 self-hosted cluster!

Enjoy!

Sources:

* [Docker + kubeadm install](https://gist.github.com/xetys/0ecfa01790debb2345c0883418dcc7c4)
* [k8s-self-hosted-recover GitHub](https://github.com/xetys/k8s-self-hosted-recovery)



[kubeadm]: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/
