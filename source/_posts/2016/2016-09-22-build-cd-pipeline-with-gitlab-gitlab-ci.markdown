---
layout: "post"
title: "Build CD pipeline with Gitlab + GitLab CI for spring cloud microservices"
date: "2016-09-22 13:50"
categories: [JHipster, spring cloud, spring boot, devops, development, gitlab, gitlab CI]
published: true
comments: true
---

Today I am writing about a continuous delivery pipeline, built on top of GitLab and GitLab CI. As a very simple but production tested deployment solution, I will push to a [Dokku][] cloud.

In short, we will:

* setup [GitLab][] with CI
* secure connections with TLS certificates using [LetsEncrypt](https://letsencrypt.org/) and [Certbot](https://certbot.eff.org/)
* setup GitLab Container Registry
* configure a pipeline for staging and production using a [Dokku][] host
* run the pipeline

The first part will cover the configuration part of GitLab, the second will demonstrate one possible deployment configuration to zero-downtime-deploy a microservice application, built with [JHipster][]. But before we dig into the details, I will discuss what this setup is supposed to achieve.

{% img center /images/2016/04/deployment_gitlab_ci_dokku.png 1338 500 CD pipeline with GitLab CI %} <center>***(CD pipeline with GitLab CI)***</center>

<!--more-->

This setup follows both, the [immutable server pattern](http://martinfowler.com/bliki/ImmutableServer.html) and a policy (I don't know if there is a definition), where deployment to production must be allowed using CI by enforcing passed tests in all stages. In other words: we want to the one side, having the entire deployment process be as easy as `git push origin master`, but preventing failing deployments using CI and a good test coverage.

In practice, after following this tutorial, you should have an staging and production environment, which can be deployed using either `git push origin master` or `git push origin staging`.
Before the funny part can start, we need some preparation. There are of course developers, who don't have to care about such DevOps things, as they usually get some working CI/CD infrastructure, before they even start working. I had to figure out these things, having nothing more than a workstation, a good idea convincing my boss (microservices for business intelligence) and the permission to order bare metal. As a side effect of this tutorial, you will also be able to build and host an entire development + staging / production infrastructure in less then 100€ / month to run spring cloud microservices.


## Setup

We now walk through four component setups we need for this:

* git host
* CI platform
* container registry
* staging / production cloud

This is nothing special for GitLab itself, but a general setup if you want to switch to modern CD pipelines. The reason why I decided to go with GitLab, is that the first three components of that listed are covered by GitLab out-of-the-box in their Community Edition. So let's go:

### Requirements

I have tried CentOS 6.X and 7, ubuntu 14 and 16 as well as good old debian 8, and found myself most happy with debian. Everything worked just after installation, no suspicious docker-in-docker bugs...
For the minimum setup you should go with two dedicated servers running debian 8. Having more servers reduces the damage taken in system failure.

The first server will run GitLab and its CI runners. So first, we install GitLab. Despite there is a docker way to go, I prefer to install it via package manager to be able to the update. I followed [this guide](https://about.gitlab.com/downloads/#debian8) for installation using apt. You will get updates directly from GitLab via apt, when they got released.

**We need at least version 8.8**

### Setting up GitLab CI

GitLab CI is really working similar to [Travis CI](https://travis-ci.org/). It publishes build tasks to "pending" state and waits, until one of the free workers starts with it. A runner itself is a docker container, which is able to start with a defined image to perform build tasks, such as testing.

In GitLab CI you either can register runners for individual projects, or shared runners for the whole GitLab instance. To make things easy, we define shared runners. This can be done in
> Admin Area -> Runners

Here we find our registration token. To finish the CI setup, we just start runners. But this is one of the tricky things with GitLab CI. While these runners are docker containers, they must run docker commands on their own behalf, too. There are some different solutions, such as docker-in-docker or privileged mode, which all didn't really work for me. So I ended up sharing the hosts docker socket to the runners to solve the runner side problems. To make my images building docker containers, I built some custom containers based on `java:8` and `node:4` by adding the docker client to them. Now step by step:

(on the GitLab machine)

``` sh

docker run -d --name "gitlab-runner-1" --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest

docker exec -it "gitlab-runner-1" gitlab-runner register -n \
  --url https://<your-gitlab-host>/ci \
  --registration-token "<YOUR-TOKEN>" \
  --executor docker \
  --description "ci-runner-1" \
  --docker-image "docker:latest" \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock

```

Or you can use [my Gist](https://gist.github.com/xetys/cc31216d2337f5d3d07b4b3422b88b79) and

``` sh
$ ./create-ci-runner.sh <runner-number> <registration-token> <gitlab-host>
$ # example
$ ./create-ci-runner.sh 1 xXXXYYYz https://my.git.lab.net
```

For spring applications, in particular JHipster apps, we can use [xetys/java-8-docker](https://hub.docker.com/r/xetys/java-8-docker/) or [xetys/node-4-docker](https://hub.docker.com/r/xetys/node-4-docker/).
So we be able to both, run our tests using maven / gradle / npm, **and** create docker images, which will be pushed to our container registry. And this is where we go next:

### Setting up container registry

There are several public container registries for docker, such as [Docker Hub](https://hub.docker.com). But for internal work, you sure want to have a private registry running. As of version 8.8, GitLab comes with a integrated registry, which has access policies according to the access control settings inside GitLab, but also support tokens for temporal sign ups inside CI runners.

Well, there are good news and bad news. The bad news is: since several versions docker it is very rude, if you work with insecure HTTP connections. More on that, you connection is treated as insecure, if you even use self-signed certificates. So the best way to go would be, using trusted certificates. Some years ago you would stop reading this article, as it would now cost you money to proceed with this article.

But happily, there are the good news: you can use [LetsEncrypt](https://letsencrypt.org/) and [Certbot](https://certbot.eff.org/). This is a free TLS provider. To answer frequent questions directly: yes, it is really free, yes it works, you will have to be ok with your cert info will contain only your domain name, no further details.

A solution, which worked **always** for me, independent from the linux distribution, was:

``` sh
$ wget https://dl.eff.org/certbot-auto
$ chmod a+x certbot-auto
$ mv certbot-auto /usr/local/sbin
```

Now in practice: GitLab comes with its own nginx configuration, and registry is enabled by default. We may activate the registry without TLS enforced, but will experience problems during CI because of dockers security policies. So first we will have to generate the certs, then setup GitLabs gitlab.rb properly. For the generation process, we will need to tell LetsEncrypt, that we are indeed are the owner of the GitLab servers domain. For this we shortly stop the GitLab nginx, generate the certs, and start it back again:

``` sh
$ gitlab-ctl stop nginx
$ certbot-auto certonly --standalone -d <your-gitlab-host>
$ gitlab-ctl start nginx
```

***note: after successfully cert creation, you may save this command into a cronjob script like this***

``` sh
/usr/bin/gitlab-ctl stop nginx
/usr/local/sbin/certbot-auto certonly --standalone -d <your-gitlab-host> -n
/usr/bin/gitlab-ctl start nginx
```
***the -n option will renew the existing certs only if they are about to expire***

There will be generated certificates in /etc/letsencrypt/live/<your-gitlab-host>. The last thing to do is, configure GitLab to use TLS for HTTP and registry, by providing a GitLab gitlab.rb as this:

``` rb /etc/gitlab/gitlab.rb
# ...
external_url 'https://<your-gitlab-host>'
registry_external_url 'https://<your-gitlab-host>:4567'

nginx['ssl_certificate'] = "/etc/letsencrypt/live/<your-gitlab-host>/fullchain.pem"
nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/<your-gitlab-host>/privkey.pem"


registry_nginx['ssl_certificate'] = "/etc/letsencrypt/live/<your-gitlab-host>/fullchain.pem"
registry_nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/<your-gitlab-host>/privkey.pem"
# ...
```

To make the changes take effect, run

``` sh
$ gitlab-ctl reconfigure
```

And now on your workstation:

``` sh
$ docker login <your-gitlab-host>:4567
```

with your GitLabs login credentials. If everything configured properly, you should now be able to push and pull to your registry.

### Setup production environment

Well, there are a lot of solutions to actually deploy your docker images, cloud providers such as AWS, GCP, Azure, Profit Bricks, etc. If your application will have to scale, and you have operators to overwatch massive deployment, there sure will be some way to deploy docker images. The details differ from provider to provider. As a higher level of abstraction, you may deploy to [kubernetes](http://kubernetes.io/), which provide a unified API, abstracting the underlying layer off from the process of deployment. Although this is a very nice solution, it is still a hard job to get a production ready installation running. To be more precise: At my work I am currently operating things by myself on bare metal, so I just didn't had the time to setup a kubernetes cluster I could really use for production. Maybe I will report in this blog when I find a straight way to go...So for now, I just need some quick and simple solution to get started with docker deployment, but more advanced then docker-compose. So [Dokku][] was a wonderful way to go for me, as it is 100 lines of bash, run on top of some linux with docker on it.

***note***: Since I got familiar with these technology, docker released integrated swarm support since 1.12, which is maybe a more elegant solution than using dokku. Nevertheless, I didn't found any zero-downtime-deploy support out-of-the-box by quick reading, which keeps me still running my cloud on dokku.

So in short, dokku is:

* a small Heroku clone, accepting buildpack deployment from `git push dokku master`
* supporting damn simple but customizable zero-downtime-deployments, enabled per default as 10 seconds health check + switch + 60s TTL for old containers.
* providing a simple plugin system for postgres, elasticsearch and more

and you can install this from a two lines on a clean debian server (the second machine)

So, all we need for this is:

``` sh
# for debian systems, installs Dokku via apt-get
$ wget https://raw.githubusercontent.com/dokku/dokku/v0.7.2/bootstrap.sh
$ sudo DOKKU_TAG=v0.7.2 bash bootstrap.sh
```

Then you have to visit your <your-production-host> once in a browser, to setup some things you like.

You should setup at least one user to dokku for pushing / pulling, and one for the GitLab server. This can be done using dokkus `sshcommand`

In short:

```
echo "ssh-rsa <KEY1> user@workstation" | sshcommand acl-add dokku user
echo "ssh-rsa <KEY2> deploy@<your-gitlab-host>" | sshcommand acl-add dokku gitlab
```

This enables for both clients to `ssh` into the server, and directed to the dokku command, as well as to the internal git directory. I don't focus on the git deployment capabilities, as this will make this article longer than it already is, there are good docs for this. We will use the dokkus database plugin `postgres`, and the [docker-direct Plugin](https://github.com/josegonzalez/dokku-docker-direct) to perform some docker commands directly, i.E. using `ssh <your-production-host> 'docker-direct pull <your-gitlab-host>:4567/project'`

As mentioned, I don't promote this as a best practice, but dokku currently solves a lot of my needs, because everything needed to interact with the host for deployment, is ssh, which is standard for all UNIX systems. This makes things easier in particular in CI.

### Testing connectivity

As a dirty workaround for image pulling, I created a "dokku" GitLab user, to perform

``` sh
$ docker login <your-gitlab-host>
```

with user "dokku" on the dokku host.

To test this, first create some empty GitLab project, add it to your user (in the following examples: "me"), and run the following ssh commands on your workstation:

``` sh
$ docker pull nginx
$ docker tag nginx:latest <your-gitlab-host>:4567/me/empty-project # the name and registry path to your empty project
$ docker login <your-gitlab-host> # to be able to push images, this must be done once, and you will be authenticated over time
$ docker push <your-gitlab-host>:4567/me/empty-project # push it to the registry
$ ssh dokku@<your-production-host> 'docker-direct pull <your-gitlab-host>:4567/me/empty-project' # test that dokku is able to pull from your registry
```

If the last commands is pulling the image properly, you are ready to deploy from CI.

## Building the pipeline

At this point, we are running at least two servers, one containing GitLab, several GitLab CI runners on it and the GitLab CI registry, and a dokku host on the second (or some other but similar solution like Deis, kubernetes, etc.). For simplicity we just deploy production and staging environments to one dokku host. I prefer to use 4 hosts, one for GitLab, one for runners, and one for each stage.

At this point we are able to perform dokku related commands just by using ssh, but I recommend to use a [dokku client](http://dokku.viewdocs.io/dokku/community/clients/), because this are **very** simple, no dependency heavy toolbelt!

First, we need a JHipster application. First, so we generate a microservice application named 'demo-app' using `yo jhipster`, which we choose with these options:

* microservice application
* gradle as build tool (all this setup work for maven, too)
* PostgreSQL as database
* no additional things like elasticsearch, Hazelcast etc.
* generate some simple entity using `yo jhipster:entity`

As we know, we need a JHipster registry to run microservice applications. For this, we use **once per environment** the following setup:

Inside a blank directory, create a Dockerfile:

``` sh
FROM jhipster/jhipster-registry:v2.5.0
ENV SECURITY_USER_PASSWORD your-custom-password
ENV SPRING_PROFILES_ACTIVE prod,native

EXPOSE 8761
```

then, add and push it to dokku:

``` sh
$ git init
$ git add Dockerfile
$ git commit -m "deploy registry"
$ git remote add dokku dokku@<your-production-host>
$ git push dokku master
```

This automatically creates a new dokku app named "registry", which you can reach by hitting http://registry.<your-production-host>:8761.

Once done, we now proceed with the deployment of "demo-app" to the dokku host registering with that registry.

To have the central configuration mapped to the config server:

``` sh
$ mkdir /central-config
$ dokku docker-options:add registry "--v /central-config:/central-config"
```

### step by step deployment

With a running JHipster registry, we now can start deploying JHipster microservices as many we need. For one single application, we walk through these steps:

#### 1. create dokku app
``` sh
$ dokku apps:create demo-app # or ssh dokku@<your-production-host> 'apps:create demo-app'
```

#### 2. create postgres database using dokku postgres plugin:

``` sh
$ dokku postgres:create DemoApp
```
(we can review the connection details again using `dokku postgres:info DemoApp`)

#### 3. link database to your app

``` sh
$ dokku postgres:link DemoApp demo-app
```

#### 4. setting environment variables to overwrite defaults

``` sh
$ dokku config:set demo-app SPRING_PROFILES_ACTIVE=prod SPRING_CLOUD_CONFIG_URI=http://admin:your-custom-password@registry:8761/config
```

#### 5. link registry to app.

Despite we have the name "registry" clearly associated with that name to the outside, the real container name will be "registry.web.1", as we can review by `docker ps`. So we must link that to the apps container, so it can simply access "registry":

``` sh
$ dokku docker-options:add demo-app deploy "--link=registry.web.1:registry"
```

#### 6. setup spring cloud config

Here we can manage our configuration for all microservice application using spring cloud config. For that, inside directory "/central-config" we place a file named "DemoApp-prod.yml":



``` yml /central-config/DemoApp-prod.yml
spring:
    datasource:
        url: jdbc:postgresql://dokku-postgres-DemoApp:5432/DemoApp
        username: postgres
        password: take from dokku postgres:info
```

#### 7. Prepare deployment directly from workstation:

* create a git repository for the project, like <your-gitlab-host>/me/demo-app
* in projects settings, enable "container registry", so it gets accessable from <your-gitlab-host>/me/demo-app:latest
* run `./gradlew build -Pprod bootRepackage buildDocker` to create a image. Be sure, it has the correct name in "docker.gradle" changed from "demo-app" to "<your-gitlab-host>:4567/me/demo-app:latest"
* push the image using `docker push <your-gitlab-host>/me/demo-app:latest`

Then, on your workstation (or dokku host)


``` sh
$ dokku docker-direct pull <your-gitlab-host>/me/demo-app # load image
$ dokku docker tag <your-gitlab-host>/me/demo-app:latest dokku/demo-app:latest # tag it for dokku deployments
$ dokku tags:deploy demo-app latest # deploy!
```

At this point you should get sure, the apps starts properly, connects to service discovery and cloud config properly.

#### 8. Setup the final CI/CD pipeline

To summarize, what we have done in step 7, we just can make using this bash script:

``` sh dokku_deploy.sh
#!/bin/sh

set -ev

echo "deploying build with ID: $CI_BUILD_REF:$CI_BUILD_ID"


./gradlew -x test build -Pprod buildDocker # no tests, since this is done in other ci stage!

docker tag "$2:build" "$2:$3"
docker push "$2:$3"

ssh "$4" "docker-direct pull $2:$3"
ssh "$4" "docker-direct tag $2:$3 dokku/$1:$3"
ssh "$4" "tags:deploy $1 $3"
```

and place it to the root of our demo-app.

The general usage is:


```
./dokku_deploy.sh <APP-KEBAB-NAME> <CONTAINER-REGISTRY-PATH> <TAGNAME> <SSH-CONFIG-NAME>
```
And for our demo-app it is

```
./dokku_deploy.sh demo-app <your-gitlab-host>:4578/me/demo-app latest <your-production-host>
```

We add the private key of your deploy user for gitlab inside

> Project > Settings > Variables

with key "SSH_PRIVATE_KEY". We want to achieve that `ssh <your-production-host>` is automatically authenticated via RSA for user dokku.

So our first gitlab-ci.yml will look like this

``` yml .gitlab-ci.yml
image: xetys/java-8-docker

before_script:
  - 'which ssh-agent || ( apt-get update -y && apt-get install openssh-client -y )'
  - eval $(ssh-agent -s)
  - ssh-add <(echo "$SSH_PRIVATE_KEY")
  - mkdir -p ~/.ssh
  - 'echo -e "Host <your-production-host>\n\tHost <your-production-host>\n\tStrictHostKeyChecking no\n\tUser dokku\n\n" > ~/.ssh/config'
  - docker login -u gitlab-ci-token -p $CI_BUILD_TOKEN <your-gitlab-host>:4567

stages:
  - test
  - deploy

buildtest-job:
  stage: test
  script:
    - ./gradlew build test

deploy-job:
  stage: deploy
  script:
    - chmod +x dokku_deploy.sh && ./dokku_deploy.sh demo-app <your-gitlab-host>:4578/me/demo-app latest <your-production-host>
  only:
    - master
  when: on_success
```

in detail:

* image: xetys/java-8-docker provides usual java capabilities and docker commands to push images
* before_script: here we setup the communication to our production host (add more lines like these for more different stage hosts)
* stages: this are parallel job categories. Deploy jobs and test jobs will run in parallel, but deploy starts only when all test jobs finish
* only: the deploy task will only start for changes on the master branch
* the jobs: a job, as described [here](http://docs.gitlab.com/ce/ci/quick_start/README.html)
* `when: on_success` is a expression, which only allows to deploy to master, if all of the test jobs exited with code 0 (make sure to set ignoreFailure to false in build.gradle)


```
  test {
      include '**/*UnitTest*'
      include '**/*IntTest*'

      ignoreFailures false
      reports.html.enabled = false
  }
```

And finally, there it is. As soon some pushes or merges happens to any branch, the "buildtest-job" will run. If this was the master branch, the deploy-job runs after test jobs, which deploys the application to production hosts.

To be clear about the deployment part, it is really simple and maybe not adoptable to the most greater spring cloud solutions, but is done in a very similar fashion using systems like kubernetes or fabric8. But the principals today, are quite the same: build artifacts in form of docker images when test succeed, push to container registry, deploy from registry to your cloud. In this case, the dokku setup is easy to follow and simple to reproduce in other systems. I am used to follow the pattern, to use master branch for production stage and staging branch for staging environment. Another pattern is to deploy tags to production and master to staging.

As an deployment alternative, you can work with hooks after pushing to registry, so your production hosts pulls the image itself, triggered by that hook. There are a lot of different ways to setup this pipeline. For me it was not easy, to get quickly started with deploying some production cloud, while learning Spring, microservices, and project management, to give my team members some tool they can easy get started with. So even if this way might look unconventional, my team get away from workstation after a git push, walking the way to our product users while the application gets deployed. This is, how continuous delivery looks to me!

Last but not least, using German server hosting provider like Hetzner or server4u, you will pay about 100€/month for a two machine setup, each with 64GB RAM and Intel Xeon CPU inside, what is much cheaper then the same costs with cloud providers.

## Conclusion

With this article I presented how to setup a working cloud, similar to several production environments I run with spring cloud microservices built with JHipster with a good performance a flexible system. I hope this is not looking to naive or stupid, since I am actually a software developer, not a system administrator :)

P.S.: After buying servers and domains, I need about 50 minutes to setup this setup including testing everything works.

Have a great week!


[GitLab]: https://about.gitlab.com/
[GitLab CI]: https://about.gitlab.com/gitlab-ci/
[Dokku]: http://dokku.viewdocs.io/dokku/
[GitLab Runner]: http://doc.gitlab.com/ce/ci/runners/README.html
[JHipster]: https://jhipster.github.io/
