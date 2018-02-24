---
layout: post
title: "Tutorial: Deploy Kubernetes on Hetzner Cloud + Ingress + OpenEBS storage"
date: 2018-01-29 23:06:09 +0000
comments: true
categories:
 - kubernetes
 - devops
---


<table width="100%">
<tr>
<td align="center"><img src="/images/2018/01/k8s.png" width="256"></td>
<td align="center"><img src="/images/2018/01/icon-hetzner-cloud.svg" width="256"></td>
</table>

## Introduction

In this tutorial, I will describe the setup [Kubernetes][] v1.9.2 on [Hetzner Cloud][] in 10 minutes.
The final cluster will have:

* a basic Kubernetes cluster up and running on 2 nodes
* [OpenEBS][] as dynamic storage provider
* [Helm][] installed (with RBAC)
* [nginx-ingress-controller][]

## Video Tutorial

I've made a short asciinema clip of the entire installation.

[![asciicast](https://asciinema.org/a/eiom8msOO77bk25oZ6onbe3Y2.png)](https://asciinema.org/a/eiom8msOO77bk25oZ6onbe3Y2)

<!-- more -->
## Install and configure hetzner-kloud

In a shell run:

```
$ wget https://github.com/xetys/hetzner-kube/releases/download/0.0.3/hetzner-kube
$ chmod a+x ./hetzner-kube
$ sudo mv ./hetzner-kube /usr/local/bin
```

In [Hetzner Cloud Console][] create a new project "demo" and add an API token "demo". Copy the token and run:

```
$ hetzner-kube context add demo
Token: <PASTE TOKEN HERE>
```

And finally, add your SSH key (assuming you already have one in `~/.ssh/id_resa`) using:

```
$ hetzner-kube ssh-key add --name demo
```

And we are ready to go!

## Deploy cluster

Deploying a cluster is as easy as:

```
$ hetzner-kube cluster create --name demo --ssh-key demo
```

This will create two servers of type CX11 in your account. So playing with this cluster will cost 0,01 EUR per hour (referring to current prices).

## Access kubectl commands

In order to do anything with the cluster, you'll need to ssh to the master to get access to kubectl command or setup your local kubectl with the cluster kubeconfig using:

```
$ hetzner-kube cluster kubeconfig --name demo
```

## Deploying OpenEBS

OpenEBS is a container native storage provider, which supports dynamic storage provisioning, which allows creating persistent volume claims to be automatically bound by created persistent volumes. On Hetzner Cloud, the installation is straight-forward:

```
$ kubectl apply -f https://raw.githubusercontent.com/openebs/openebs/master/k8s/openebs-operator.yaml
$ kubectl apply -f https://raw.githubusercontent.com/openebs/openebs/master/k8s/openebs-storageclasses.yaml
```

You can check the status using `kubectl get pod` and watch maya, and the operator becomes running.

## Test the storage

First we define a `PersistentVolumeClaim`, `Deployment` and `Service` in a file `nginx.yaml`:

``` yml nginx.yaml
apiVersion: v1
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nginx
spec:
  storageClassName: openebs-standalone
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100m
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  template:
    metadata:
      name: nginx
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
          - name: html
            mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          persistentVolumeClaim:
            claimName: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  ports:
    - port: 80
  selector:
    app: nginx
  type: NodePort
```

Get the exact pod name of one nginx pod from `kubectl get pod` and run.

```
$ kubectl exec -it <pod-name> -- bash
root@pod:/# echo "hello world" > /usr/share/nginx/html/index.html
root@pod:/# exit
```

Now you can kill the pods by:

```
$ kubectl delete pod -l app=nginx
```

And wait until they are re-scheduled again. Because of the persistent volume mounted in `/usr/share/nginx/html` the data is available, even when pods are killed.

## Helm and ingress

As Hetzner does not have a cloud provider for load balancers, we will use [nginx-ingress-controller][] for traffic routing.

First, we install a helm, respecting RBAC:

```
$ curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash

$ echo "apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
" | kubectl apply -f -
$ helm init --service-account tiller
```

And now we can install a lot of helm charts. Like this:

```
$ helm install --name ingress --set rbac.create=true,controller.kind=DaemonSet,controller.service.type=ClusterIP
```

This will install an ingress controller, as described a year ago in my [k8s bare-metal article](/blog/2017/01/25/deploy-kubernetes-to-bare-metal-with-nginx/).


## Closing words!

Congratulations! You have a simple but working Kubernetes Cluster. Have fun.

Finally, I can say, that at the time of that article about deploying Kubernetes with CoreOS on bare-metal, I spent about a week for my first running cluster to deploy it. One year later I've learned go and made hetzner-kube my first project in that language. The alpha version for this tutorial was coded in just two evenings!

Have a nice week!





[OpenEBS]: https://www.openebs.io/
[Helm]: https://helm.sh
[nginx-ingress-controller]: https://github.com/kubernetes/ingress-nginx
[Kubernetes]: https://kubernetes.io
[Hetzner Cloud]: https://www.hetzner.de/cloud
[Hetzner Cloud Console]: https://console.hetzner.cloud
