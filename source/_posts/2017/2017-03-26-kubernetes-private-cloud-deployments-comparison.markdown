---
layout: post
title: "The ultimate Kubernetes private cloud deployment comparison"
date: 2017-03-26 12:00:00 +0100
comments: true
categories:
 - kubernetes
 - devops
 - microservices
 - development
 - coreos
---

*~ 13 minutes to read*

{% img center https://opencredo.com/wp-content/uploads/2015/12/kubernetes.png 653 160 'kubernetes' %}

## introduction

In [my recent article on K8S deployment](/blog/2017/01/25/deploy-kubernetes-to-bare-metal-with-nginx/) I described my first approach on building a working K8S cluster on a private cloud. Despite this was a working setup, it was simplified to make the setup easier. However my personal aim was more about:

> How to deploy a production ready kubernetes cluster on a private cloud?

To be more precise, what I try to achieve:

> I don't want to use AWS/Azure/GKE for some reasons

> I am using a non wide known cloud provider like [ProfitBricks][], or own virtual solutions, such as KVM, VMWare

> I want to know a generic way for turn key clusters, agnostic to the underlying infrastructure

> I want to have load balancing and storage administration running out of the box

<!--more-->

To give myself a good answer to this non-trivial question, I tried out all good looking solutions out there I could find. Thanks to [ProfitBricks][], I got some free resources on their platform, so I could try the candidates fast. In this article, I will first give a short summary to the comparison for the less patient reader, and then walk through the details of each setup.

Well, after weeks of research, I can summarize my results using the following figure:

{% img center /images/2017/03/k8s-dpl-comparison-results.png 997 290 'K8S private cloud deployment comparison results' %}

I think that figure is quite self-describing. I provisioned at least

* [CoreOS Container Linux](https://coreos.com/os/docs/latest) using my hands (bash scripts), and [matchbox](https://github.com/coreos/matchbox)
* [Rancher][] 1.4.1 on Ubuntu 16.04
* k8s with [kubeadm][] on Ubuntu 16.04
* k8s using the [Kismatic Enterprise Toolkit](https://github.com/apprenda/kismatic)

Before I dive deep into the way how I tested the candidates, the winner here is: kismatic. To make clear: I was testing a small scale scenario with less then 10 nodes overall. For larger installation matchbox is a better solution

## How I tested the scenarios

As a [JHipster developer](https://jhipster.github.io) I am known for my different setups using [JHipster UAA](https://jhipster.github.io/using-uaa/), which is the OAuth 2.0 security solution for Spring Cloud microservices, supporting service-to-service security. However, I built a full-fledged setup of at total 6 + 1 microservices (including JHipster Registry) during my in-depth workshop at [microxchg 2017 @ Berlin](http://microxchg.io/2017/index.html), what is much closer to a real-life microservice setup than the normal bloggy sample application. The final source-code can be found [here](https://github.com/xetys/microxchng-workshop).

So ultimately my reference testing was setting up a kubernetes cluster, then deploying that JHipster microservice, and afterwards doing different stress tests.

In short I:

1. installed kubernetes using one of selected provisioning methods
2. deployed the bookstore
3. checked, whether the bookstore works, in particular how fast it works
4. killed some nodes, and watch the clusters reaction
5. restored killed nodes and expected the setup to work again
6. overscaled to critical state with memory lacks and watched health
7. rebooted, reconfigured and expected to finally see my setup healthy

However, I defined the following goals, which are important for me to operate my microservices on a kubernetes cluster:

1. the cluster doesn't fail to run my application
2. it is not a neck breaking adventure to set the cluster up
3. after installation, I've got a lot of ready to use features, which make my life easier (yes! I am a very lazy guy :D )
4. it is easy to increase or reduce the amount of nodes (ideally HA controllers, too)
5. there is some way to deal either with load balancers or ingress, so I can expose my services to the world wide web, out-of-the-box of course.
6. there is some built-in storage management, which hopefully brings by naked storage as `PersistentVolume` into the cluster
7. the cluster is self-healing, as it promises to be
8. it returns to full functionality and performance, when all failing nodes are restored or new ones are added
9. the setup is secure. This means both, the clusters access, as well as built-in option for HA etcd and HA controllers

For the scoring, every goal can either be satisfied mostly (+1), partially (0) or weak (-1), excepting the goal that my application runs on it. This worths me 2 points for working and -2 if not. So in sum, a setup can reach from -10 to 10 score points, which can be normed to a 0 - 10 rating.


## walking through the candidates

In the next section, I walk through every single setup, giving a short description about the details and give some feedback, what worked good and what worked bad.

### Kismatic

{% img right /images/2017/03/kismatic.png 300 125 'Kismatic Enterprise Toolkit' %}

Let's start with the winner of this comparison: the KET aka. Kismatic Enterprise Toolkit, developed by [Apprenda](https://apprenda.com/). For my tests it was the most competing tool, as it:

* deploys latest k8s cluster in various configurations, with multi-host masters
* is mostly agnostic to the underlying system, as it supports standard linux server distributions as CentOS, Ubuntu etc.
* brings a rock solid ingress solution using nginx (the same I was using in my manual setup), which brings a lot of features as TCP, TLS and other advanced stuff
* is the only of the tested tools with a built-in storage solution, utilizing GlusterFS directly as `PersistentVolume`s
* is very easy to install
 https://www.terraform.io/
With all that feature set, it is really close to RedHats OpenShift (one missing solution, I found that a bit to late), and since it is based on [Ansible][ https://www.ansible.com/], providing SSH keys is the only additional requirement, after the set of supported OSs. When I first time found this tool, I was wondering, how they could do so many docs about planning the cluster, rather than the actual setup. From a humor view, it looked like

> Don't worry to much about the setup...it just works. Worry about the infrastructure, you are going to setup

And that is pretty much the truth. I can summarize the entire setup in a view lines:

* get the toolkit using `curl -L https://github.com/apprenda/kismatic/releases/download/v1.3.0/kismatic-v1.3.0-linux-amd64.tar.gz | tar -zx`
* do `./kismatic install plan` and tell him what you want.
* look into the generated `kismatic-cluster.yaml`, grab some machines, and fill in the details, as `hostname` and `ips` in the right places
* check with `./kismatic install validate` everything is fine and finally `./kismatic install apply` the setup

That it is! As a JHipster developer, I can pretty much say:

> Kismatic enterprise toolkit is the JHipster of kubernetes setups

One issue with KET is, that it is based on the servers IPs, what makes things somehow difficult, if dealing with floating IPs. To say something bad ;-) But yeah, you can do private networking with NATing public access from the private machines.

I was talking to the Apprenda guys at KubeCon 2017, got a lot of tips and hints.

### CoreOS manual and matchbox

{% img right /images/2017/03/coreos.png 594 230 'CoreOS Container Linux' %}

The details about the manual deployment steps of this scenario I described in detail in my last [article](/blog/2017/01/25/deploy-kubernetes-to-bare-metal-with-nginx/).

As I already told in my article, I really like the CoreOS way of dealing with containers at all. To be honestly, I loved the CoreOS approach more than all the other setups. However, both cloud-config / ignition needs some heavy preparations, if starting from scratch. For the manual way, I need to create config images for each nodes, by creating certs, configuration etc. in advance. So this is not very handsome if we are talking about a greater amount of nodes. For autoscaling (changing amount of nodes during a certain period) nodes, this becomes even quite hard to handle.

So the former coreos-baremetal project, now known as matchbox, is a big upgrade to this issue. In short, matchbox uses PXE boot to push CoreOS images to machines during boot, pointing to a built-in ignition server, which is the "better" cloud-config over HTTP. As an operator, I just need to provide some very handsome JSON files, to define my entire setup. I can match these configs by MAC address or zones. The flip side is, that I needed to hook matchbox with dnsmasq (or different DHCP/TFTP solutions) into an existing cloud network system. That wasn't easy, but at least, I failed to bring the machines up more than one time at ProfitBricks for some unknown reason. So generally it seems to be a good way, and scalable. But the ease of the final cluster setups falls either to infrastructure preparation and matchbox setup, which is quite hard to start of at the beginning.

Considering this issue is resolved, it is a quite fast and secure way to deploy K8S, as CoreOS always do TLS, and with matchbox it's possible to change the infrastructure on the fly, what makes it a sustained system to go.

Last but not least, one can skip providing own JSON configs and go on with [CoreOS Tectonic](https://coreos.com/tectonic), the enterprise kubernetes distribution from CoreOS, which provides a graphical installation over matchbox gRPC API. As I struggled with the rebooting of K8S machines, I didn't found built-in ingress solutions or load balancers.

There is also the option of doing own stuff using the gRPC API, so one can just use that in a similar way as Tectonic does it, to configure a setup from some bootstrap machine.

However, a clean CoreOS is a kubernetes without any fancy features, user system, load balancers or something like that. This is cool for a clean state, but one must provide own setups for stuff like ingress.

### Rancher

{% img right /images/2017/03/rancher.png 300 180 'Rancher' %}

[Rancher][] is a pure docker solution, offering multi-host docker orchestration, giving several orchestration options to choose. Next to its own solution, called "Cattle", one can choose Kubernetes. Here it was quite confusing, as it is possible to deploy k8s on cattle, as well as using k8s as a different type of environment. The first way adds backup plans, which are quite cool for production. The latter seems to be the documented way of setting it up.

The setup itself is all about dealing with docker run commands. So from this case it is very easy. There is a built-in ingress solution, what also is good. However I failed to establish communication from a microservice to a Spring Cloud Config server, so ultimately I wasn't able to deploy my setup. Smaller samples worked. The health of the setup got worse, as soon I started to kill running nodes and plugging them back again. I feel, ranchers approach was giving k8s as additional feature, with main focus on it's own orchestration tool. I'm sure I might had better experience using Cattle.

### kubeadm

[Kubeadm][] is the official setup solution to bring up a cluster. The good news is, it is actually working, offering a simple approach, so it is simple to integrate with "infrastructure as code" solutions, like [Terraform][] or [Ansible][]. As it is part of kubernetes itself, it always ships with the current version of k8s. The bad thing is, the self healing didn't worked well for my case, and it doesn't support complex setups (multi-host master, multi-host etcd, ingress, storage management). It also doesn't ship any features, so one end up with a clean cluster. So kubeadm is without debt a good way to go, to quickly setup various clusters to play around. But as being said in the official documentation, it's a work in progress and in so far not ready for production setups. Anyway I recommend to constantly having an eye on that project, as it is evolving fast and I am sure, it will reach production status some days.


## Conclusion

During these tests, I went over various cloud providers, as well as private cloud solutions to give the candidates a try. My claim is, to give a basic overview, what solution to pick right today, if you want to switch to kubernetes. This comparison is mainly focused on a small setup, running a few (but maybe powerful) nodes. Depending of the scale of the setup, I would say:

**If you are running few to several hundreds nodes:** KET is the right tool to go

**If you are running several hundreds to thousands nodes:** CoreOS matchbox is the right tool to go


Of course, with all that methodology in mind, this is a subjective point of view. I maybe missed some points on some concrete system. Finally, I am a software developer first, looking for a way of making my cluster ops live as easy as possible. As always with my articles, I'm open to critic and feedback. If there is something wrong in this comparison, please tell me about that. I hope, in the end this article helps people to pick a good solution.


Happy Kubing!

P.S.: If you are tired of switching from all that clusters from a single bootstrap machine, I created a little tool to get a quick work around, called [kubeconfig-loader](https://github.com/xetys/kubeconfig-loader).




[Rancher]: http://rancher.com/
[kubeadm]: https://kubernetes.io/docs/getting-started-guides/kubeadm/
[ProfitBricks]: https://www.profitbricks.de/de/
[Terraform]: https://www.terraform.io/
[Ansible]: https://www.ansible.com/
