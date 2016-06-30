---
layout: "post"
title: "How to setup Gitlab CI for spring cloud microservices and Dokku"
date: "2016-04-18 21:26"
categories: [spring, spring cloud, spring boot, devops, development, java, gitlab]
published: false
---

Well, my last article was more theoretical, so today we are going to do
"nails with heads". This is a direct translation from german, which sounds quite
funny and means: getting straight forward into action.

Today I'm going to show how to setup a server with [GitLab](https://about.gitlab.com/) and [GitLab CI](https://about.gitlab.com/gitlab-ci/), which
performs all tests of a spring cloud application and depending on test result decides,
whether to deploy the application. Of course with **zero downtime deployment**!

For deployment I will show [Dokku](http://dokku.viewdocs.io/dokku/). This is possibly
the smallest Heroku clone ever, with about 100 lines of bash. This solution is highly
configurable and quite cheap as well. It also comes with a cool zero downtime check system
out of the box, which is perfect

## Preparation

Before we begin, we need some basic setup, you should have already prepared:

* a host running GitLab 8 or greater (gitlab.example.com)
* at least one [registered GitLab Runner](http://doc.gitlab.com/ce/ci/runners/README.html) with docker executor in your installation
* a host running Dokku 0.5.0 or greater (dokku.example.com + wildcard)

## Definition of done

We first will will develop (or just checkout) a spring cloud microservice.
I would like to say "spring boot cloud application", but this looks very ugly, and
I haven't seen a non-boot spring cloud application yet.

We will look how this works locally with docker compose and then setup GitLab CI
to run the tests.

After this is verified, the we hook into an existing "dokku git" (later more on that),
and prepare artifacts for dokkus Dockerfile deployment, and deploy into an preconfigured
dokku with running Eureka and Spring Cloud Config.

Let's visualize first, what will happen:

{% img center /images/2016/04/deployment_gitlab_ci_dokku.png 692 509 'deployment pipeline with GitLab CI + dokku' %}

Or in words:

1. your devs ```git push``` into your codes repository
2. GitLab recognizes this and starts GitLab CI runners doing the configured jobs:
    1. run all tests (for us: only spring boot tests)
    2. when 1. was successfully, push to dokku and check correct deployment
3. when dokku gets a git push, it starts a new docker container, start the new version in parellel and shuts down the recent after zero deployment checks

So everything you have to do for continuous deployment, is just pushing into you repository

Awesome? Gotta go!

## Implementing the test application

First we going to visit [http://start.spring.io/](http://start.spring.io/) and generate a spring boot application version 1.4.0 M2 with the follow dependencies:
- web
- eureka discovery

**noooo! current setup with cloud Brixton RC1, RC2, Angel SR6 fails on boot 1.4.0.M2!
We pick 1.3.3.RELEASE + Brixton.RC1**

First, we make a very very simple spring boot application

``` java src/main/java/com/example/CiDokkuDemo.java

  @SpringBootApplication
  @EnableDiscoveryClient
  @RestController
  public class CiDokkuDemoApplication {

  	@RequestMapping("/")
  	public String greet() {
  		return "Hello World! This is Version 1";
  	}

  	public static void main(String[] args) {
  		SpringApplication.run(CiDokkuDemoApplication.class, args);
  	}
  }
```


This is quite straight forward. Note the "Version 1", we will change this later to see
how deployment works.

For simplicity, we go with spring cloud config disabled. This has to be configured in


``` yml src/main/resources/bootstrap.ymk

spring:
  cloud:
    config:
      enabled: false

```

and apply basic spring cloud configuration for service discovery:

``` yml src/main/resources/application.yml

spring:
  application:
    name: ci-dokku-demo

# basic eureka client setup
eureka:
  client:
    service-url:
      defaultZone: ${eurekaUrl:http://eureka:8761/eureka/}
    register-with-eureka: true
    fetch-registry: true
  instance:
    instance-id: ${spring.application.name}:${random.value}
    prefer-ip-address: true
```


### starting the application with docker compose and JHipster Registry

When we start the application the first time, we will notice issues by resolving
the eureka server. So we need this also...

Instead of implementing an own Eureka server instance (what is quite fast also),
we just use JHipster Registry, which is a Spring Eureka and Cloud Config Server.

More on that, there is a pre-built docker container we just can use.
