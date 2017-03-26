---
layout: post
title: "How to deploy kubernetes to bare-metal with CoreOS and nginx ingress controller"
date: 2017-01-25 23:31:17 +0100
comments: true
categories: [kubernetes, devops, development]
---
{% img center https://opencredo.com/wp-content/uploads/2015/12/kubernetes.png 653 160 'kubernetes' %}

## Foreword

In this guide I will explain setup a production grade cloud on your bare metal with kubernetes (aka. k8s), including edge routing. When I started my own research on k8s several months ago, I faced the fact this system is only available fully functioning mostly on cloud providers such as GCE, Azure etc. I found a lot of guides, how to deploy k8s onto different cloud systems as CloudStack, Openstack or Juju. But all these guides were specific to more advanced cloud system, or meant to purchase cloud services, which I find expensive. There were also different bare metal guides, which were like guides from hell, covering the entire k8s stack and ended up in tons of pages to read. So this was not a good introduction for someone, who has actually no idea, how the k8s ecosystem works, and just wants some best practice or working sample, to slightly become familiar with the components.

I also found a couple of GitHub repos, with a setup to a specific provisioning system as Terraform, ansible etc., and had a lot of "cool features" bundled inside, so for a newbie it was messy. In the end, I didn't find a guide describing how to solve some classical problems as domain routing, storage management etc.
Then kubeadm came, and I was like "this is it! I can get started with a k8s that easy". I tried it out quite early and quickly learned some limitations, as well as the fact the resulting cluster wasn't able to boot up properly after a reboot (until 1.5.0).

I just wanted a good guide, for someone like me:

> I got bare metal

> I got domains

> I know the web dev ways, like working on Debian, CentOS, etc. with nginx, CGI, etc...

> I know bash!

> I want kubernetes!

> It just can't be that hard?!

 Well, the only way left for me, was allocating *a lot* of time, to work through the [Kubernetes Step-by-Step guilde on CoreOS](https://coreos.com/kubernetes/docs/latest/getting-started.html), and figure out all the facts I need to know, to setup a bare metal cluster. So here we are, lets begin:



### What do we need?

 * 2 or more (virtual) machines, we can use to setup CoreOS
 * a network some DHCP server running, which automatically assigns local IPs to new devices
 * one or more public IP, we can use for edge nodes
 * a linux system with genisoimage and openssl installed

### Why CoreOS?

At the beginning of my discovery I didn't realized the fact, CoreOS has an very alternate approach for its operation in comparison with debian, CentOS, Fedora etc. So it wasn't clear to me, why every "serious" source about cluster creation avoided to use classical linux distribution, which provides a system, were a lot of non-cloudy services can be installed ont the host. CoreOS is designed to operate containers exclusively. Its system design is incompatible with running high level services on the host, such as databases, mail servers or applications. Every service runs in a container on CoreOS, what greatly fits the k8s philosophy. Beside of this, the CoreOS team is one of the most active kubernetes contributors, so they "drive" its development in CoreOS and k8s for a better cooperation.

Furthermore, it has a elegant approach to provide a universal way to provision new machines, called cloud-config. Without any complicated tools like Terraform, you can bring up a bigger amount of CoreOS machines in a short time, don't wasting time with individual provisioning.

### cloud config

A cloud config basically is nothing more then a ROM drive attached to the machine, containing instruction for the machines provisioning. This can be a mounted ISO, a flash drive or whatever. Despite there a more advanced ways of provisioning CoreOS, such as Ignition or matchbox, allowing cool stuff as PXE/iPXE boot, the cloud-config is mighty enough, but also simple, so the reader has at least one scalable idea how to bring up k8s clusters.

### on-premise load balancing

A full on-premise setup, where every part of the infrastructure is under full control of the owner (in house solutions or good old dedicated server hosting), you can't use cloud providers, which gives a easy way to handle public service exposing using `type: LoadBalancer` or dealing with cloud storages. In this guide I will use a classical load balancing approach using DNS load balancing a domain to a set of IPs, as well as handling request using nginx ingress controllers. But at very first, we need a clear picture of what we are going to build:


### basic cluster architecture

{% img center /images/2017/01/k8s-setup.png 1500 863 'basic k8s cluster setup' %}

There are three types of a k8s machine described in this setup:

* controller nodes, which orchestrate the containers in various ways. If there more then one controller, they also coordinate their selves with leader election
* worker nodes, which are used to execute all the pods
* edge routers, which may be also used as worker nodes, which are bound to a publicly routable IP (and domains!)


## Doing the setup

I should first give a picture of the infrastructure I used for this setup:

* a dedicated root server at Hetzner with 12 cores, 64GB RAM and both SSD and HDD disks
* a /29 IPv4 subnet of additional public IPs
* VMWare ESXi 5.5
* pfSense as a router vm, which provides local networks and management of the /29 subnet

Despite this might be a specific environment, there are a lot of similar constructions on a lot of different infrastructures.

### some mighty bash scripts

The hard part of the setup is defining a cloud config, which works for our machines. There are a lot of TLS certificates, systemd units and other files involved. I worked out a little bunch of bash scripts, which do all the steps we need for this. So let's check them out first:

``` sh
$ git clone https://github.com/xetys/kubernetes-coreos-baremetal
$ cd kubernetes-coreos-baremetal
$ ls
-rwxrwxr-x 1 david david 3,6K Jan 26 00:25 build-cloud-config.sh
-rwxrwxr-x 1 david david   84 Jan 26 00:25 build-image.sh
-rw-rw-r-- 1 david david 1,6K Jan 26 00:25 certonly-tpl.yaml
-rwxrwxr-x 1 david david  489 Jan 26 00:25 configure-kubectl.sh
-rw-rw-r-- 1 david david  408 Jan 26 00:25 master-openssl.cnf
-rw-rw-r-- 1 david david  272 Jan 26 00:25 worker-openssl.cnf
```

To sum up, this few files can:

* generate a ISO image from a specific folder, which are automatically detected as cloud config from CoreOS machines
* generate all certificates for controller, worker and the `kubectl` CLI
* scaffolds a proofed cloud config, which installs either the controller or the worker configuration for CoreOS


So basically, we just need to generate some ISOs and plug them into the CoreOS machine before boot. The VMWare way here was to create a VM from OVA (just by adding the stable URL). For XenServer there are templates, and at least we just could install CoreOS to disk.

The first step is to take a look into the `certonly-tpl.yaml` file, and add one or more ssh public keys, to be able to access the machines. This step must be done before we generate our inventory.

### preparing the actual machines

Let's assume, we got the following machines ready:

* controller, 10.10.10.1
* worker 1, 10.10.10.2
* worker 2, 10.10.10.3
* edge router, 123.234.234.123


with CoreOS installed. We can determine the IP of a CoreOS machine by booting it without any cloud-config, and note the IP showed in the login screen.
As usual, we are owner of "example.com", so we can add a DNS A record from the edge routers IP to example.com (and it's wildcard subdomain).

**attention**: The machine with a public IP needs access to the 10.10.10.X network, to join the master and reach the other nodes! Using a router like pfSense can solve this.

After the machines are ready we may now generate a cloud config for each of them.

```
$ ./build-cloud-config.sh controller 10.10.10.1
...
$ ./build-cloud-config.sh worker1 10.10.10.2 10.10.10.1
...
$ ./build-cloud-config.sh worker2 10.10.10.3 10.10.10.1
...
$ ./build-cloud-config.sh example.com 123.234.234.123 10.10.10.1
...
```

After these steps we have got:

* a ssl folder, containing:
  * the TLS certificate authority keypair, which we need to create and verify other TLS certs for this k8s cluster
  * the admin keypair, we use for `kubectl`
* an inventory for each node

```
tree inventory
inventory
├── node-controller
│   ├── cloud-config
│   │   └── openstack
│   │       └── latest
│   │           └── user_data
│   ├── config.iso
│   ├── install.sh
│   └── ssl
│       ├── apiserver.csr
│       ├── apiserver-key.pem
│       └── apiserver.pem
├── node-example.com
│   ├── cloud-config
│   │   └── openstack
│   │       └── latest
│   │           └── user_data
│   ├── config.iso
│   ├── install.sh
│   └── ssl
│       ├── worker.csr
│       ├── worker-key.pem
│       └── worker.pem
├── node-worker1
│   ├── cloud-config
│   │   └── openstack
│   │       └── latest
│   │           └── user_data
│   ├── config.iso
│   ├── install.sh
│   └── ssl
│       ├── worker.csr
│       ├── worker-key.pem
│       └── worker.pem
└── node-worker2
    ├── cloud-config
    │   └── openstack
    │       └── latest
    │           └── user_data
    ├── config.iso
    ├── install.sh
    └── ssl
        ├── worker.csr
        ├── worker-key.pem
        └── worker.pem
```

We can now take a look into each messy cloud config in the `user_data` file, which contains the entire payload such as a basic etc2 configuration, system.d units for flannel and calico, and the official install scripts from CoreOS for bare-metal, delivered as one-shots to provision k8s systemd style.

**attention**: the etc2 setup provided with the script is very simple and working, but not suited for production, and should be reconfigured to a external etcd2 cluster.
I skipped this in the guide, as I want to keep things as less complicated as possible. No doubt, the reader will have finally to chop through a lot of other guides to get a better picture of this setup, using better cloud configs and cooler etcd2 cluster...after studying a simple cluster.

If we need to change something inside the inventory, new config images can be generated using the `build-image.sh` tool, like

```
$ ./build-image.sh inventory/node-controller
```

for changes in our controller setup.

It is also possible to use multiple controller machines, which have to be balanced over one DNS hostname.

### mount images and go

The next step is to plugin the `config.iso` image into the right machine and boot them up, and wait for your k8s cluster to be ready.
In the time of waiting, we can already prepare `kubectl` using

```
$ ./configure-kubectl.sh 10.10.10.1
```

After a while, if nothing bad happened, we should be able to get the nodes:

```
$ kubectl get nodes
NAME            STATUS                     AGE
10.10.10.1      Ready,SchedulingDisabled   3m
10.10.10.2      Ready                      3m
10.10.10.3      Ready                      3m
123.234.234.123 Ready                      3m
```

### first steps for troubleshooting

Sometimes things just don't work as we except, so here are some tricks to figure out what is going wrong

#### on a machine
```
$ ssh core@IP # this should work, if we didn't forget about adding this to the cloud config template
$ journalctl -xe # show the logs of all system components, scrollable, beginning at the end of the logs
$ journalctl -u kubelet -f # show only kublet logs (replace with any other systemd service as flanned, docker, calico...)
$ systemctl status kubelet # quickly list the health of a service, also showing the last few lines of logs
$ docker ps # show the running containers
$ docker ps --all # show also failed or exited ones
$ docker logs <container-id> # print the logs of a container, referenced by the id, first column of the table printed by docker ps
$ curl -s localhost:10255/pods | jq -r '.items[].metadata.name' # controller only, show running pods, should be apiserver, controller-manager, scheduler and proxy
```

#### from outside

```
$ kubectl proxy # starts the proxy, so we can use localhost:8001/ui to access the kubernetes dashboard
$ kubectl run -i --tty busybox --image=busybox --generator="run-pod/v1" # start a simple pod with a shell inside, to check the network using ping, wget or nslookup
$ kubectl get pods -n kube-system # list system containers, to check they are all running
$ kubectl logs <pod> # get the logs of a pod
```


## Setup nginx ingress controller

Hopefully everything worked, we now have got a kubernetes cluster with only a few tools on it. But we want to route traffic from the world wide web into a arbitrary service in our cluster. For this we will setup a so called "ingress controller", implemented for nginx. An [Ingress](https://kubernetes.io/docs/user-guide/ingress/) in short is something, what connects services from k8s to a traffic source, e.g. by hostname or IP.
At the moment, the [nginx ingress controller](https://github.com/kubernetes/contrib/tree/master/ingress/controllers/nginx) is the most advanced one, as it easily supports any TCP and UDP based protocoll, websockets, TLS configuration and more. This might be hard to understand the first time, so I explain this in a different way.

Consider, we don't know what Ingress is, just ssh into the edge node, and bring up a nginx docker container with exposed ports to 80 and 443. We can write some nginx.conf to route traffic into the cluster IP of the target services. As this is unhandy, since we would need to change that nginx.conf each time we add more services or IPs changes, we would consider to extend this container with some unit, which reacts on changes in k8s by reading the API, and automatically write a nginx.conf based on the result.

This is basically what a ingress controller does, changing the config of something as nginx, traefik or cloud provider resources based on the internal configuration.

One thing I am missing, are docs of the usage of DaemonSet for ingress controllers, which makes much more sense then using replication controllers. The official docs just mention it could be done, but [this guys article](https://capgemini.github.io/kubernetes/kube-traefik/) described clearly, why it should be a daemon set.

While a replication controller is only responsible to keep a specific amount of pods up in the cluster, a daemon set can make sure these pods are running on each node. But in addition, we can use a nodeSelector for daemon set, to limit the nodes which are affected by the daemon set.

In short, we first have to mark the edge router with a label:

```
$ kubectl label node "role=edge-router" -l "kubernetes.io/hostname=123.234.234.123"
```

then we have to make sure we have some service to serving error messages, if a user calls an undefined route (404).

So we create a default http backend service for this purpose:

``` sh default-backend.yaml

apiVersion: v1
kind: ReplicationController
metadata:
  name: default-http-backend
  namespace: kube-system
spec:
  replicas: 1
  selector:
    app: default-http-backend
  template:
    metadata:
      labels:
        app: default-http-backend
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - name: default-http-backend
        # Any image is permissable as long as:
        # 1. It serves a 404 page at /
        # 2. It serves 200 on a /healthz endpoint
        image: gcr.io/google_containers/defaultbackend:1.0
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi

---

apiVersion: v1
kind: Service
metadata:
  labels:
    app: default-http-backend
  name: default-http-backend
  namespace: kube-system
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: default-http-backend
  sessionAffinity: None
  type: ClusterIP
```

and apply it with

```
$ kubectl create -f default-backend.yaml -n kube-system
```

and finally define a

``` sh ingress-controller.yaml

apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nginx-ingress-controller-v1
  namespace: kube-system
  labels:
    k8s-app: nginx-ingress-lb
    kubernetes.io/cluster-service: "true"
spec:
  template:
    metadata:
      labels:
        k8s-app: nginx-ingress-lb
        name: nginx-ingress-lb
    spec:
      hostNetwork: true
      terminationGracePeriodSeconds: 60
      nodeSelector:   
        role: edge-router
      containers:
      - image: gcr.io/google_containers/nginx-ingress-controller:0.8.3
        name: nginx-ingress-lb
        imagePullPolicy: Always
        readinessProbe:
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
          initialDelaySeconds: 10
          timeoutSeconds: 1
        # use downward API
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
        ports:
        - containerPort: 80
          hostPort: 80
        - containerPort: 443
          hostPort: 443
        args:
        - /nginx-ingress-controller
        - --default-backend-service=$(POD_NAMESPACE)/default-http-backend
```

which we apply with

```
$ kubectl create -f ingress-controller.yaml
```

We now should be able to access example.com and all of its subdomains, getting a 404 error message.

### adding a test ingress

For a simple test we can run

```
$ kubectl run echoheaders --image=gcr.io/google_containers/echoserver:1.4 --replicas=1 --port=8080
```

to run a simple pod with an application, which prints HTTP headers of the current request.

Then we expose it with:

```
$ kubectl expose deployment echoheaders --port=80 --target-port=8080 --name=echoheaders
```

and finally add an ingress rule

``` sh echoheader-ingress.yaml

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: echomap
spec:
  rules:
  - host: echo.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: echoheaders
          servicePort: 80

```

with

```
$ kubectl create -f echoheader-ingress.yaml
```


## Conclusion

So here we end up with a full functioning kubernetes cluster, which can expose services to domains routing to the edge router. Despite some things are simplified (as etcd2 setup), this is a nearly production grade setup. In fact I used plain bash and cloud config, it's possible to create CoreOS configs for all kinds of bare metal setup, on literally every unixoid system which has `mkisofs` and `openssl`.

As a small fact, utilizing dedicated servers using low level virtualization like VMWare makes it currently possible for me to operate a cluster with 40 cores (it thinks it has them) on a server, with initially only has 12. This is not surprising, but still funny, as I pay for the server 150 euro per month, already having several disk drives, subnets and further little thinks inside. Without them, the server would cost just 100 euro. To bring up a 40 core cluster on GCE, it would cost about a thousand dollars per month.

Another model is to start cheap on a small setup on premise, and scale using cloud providers on demand as soon as load increases.

I hope this guide is helpful for those, who just want to get a kubernetes cluster running, as it is cool and hype, but hard to get :)
