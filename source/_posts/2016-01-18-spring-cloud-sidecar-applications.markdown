---
layout: post
title: "How to integrate any webapp into Spring Cloud using Sidecar Applications"
date: 2016-01-18 15:55:34 +0100
comments: true
categories:
 - microservice
 - spring cloud
 - java
 - spring
 - development
 - docker
published: true
---


## Introduction

You may were looking for:

- How can non-JVM application be plugged into a spring cloud microservice infrastructure?
- How can I integrate my Rails / NodeJS / Express / PHP application into a Spring Cloud?
- ...and also give the (maybe legacy) applications all the feature a Spring Boot Service inside the cloud have
- ...without big changes on the "outside" apps dependencies or even code?

So this what sidecar applications are for: integrating web applications outside the cloud infrastructure accessible in both directions.

### What are Sidecar Applications?

Inside the Spring Cloud each Spring Boot application gains its power through dependencies and annotation magic performed on the classes. So things, which usualy consist of a lot of implementations behind, are adjustable through one annotation. But inside a microservice cloud there is also a need of enabling usage of other applications written in different frameworks, languages or even running on other plattforms. One central argument for using microservice architectures is, that there are no limitations (ideally) for which tools you use to build web applications.

<!--more-->

But inside a distributed system, this is not trivial. One possible way to achive this to build or find libraries written in the native language/framework of the outside application to communicate with the cloud, implementing features as Eureka service registration and discovery, Hystric curcuit breaking and so on. This actually, would be a lot of work...

Remember inversion of control philosophy: "Can't do this just someone else for me?"

It's time for one more service, exactly for registrating your outside application with your service discovery (I will use Eureka in the examples). There is a lot more you can do with sidecar applications to wire the cloud features. I will focus on the initial setup for now.

### Spring Cloud Netflix Sidecar

This feature inside Spring Clouds toolset is inspired by [Netflix Prana](http://techblog.netflix.com/2014/11/prana-sidecar-for-your-netflix-paas.html). A Spring Sidecar application runs on the same host where your outside application and frequently checks the health of your application. The sidecar application registers itself on service discovery and is forwarding calls from cloud to the outside application by a defined sidecar application name. From the view of the outside application, you can access the sidecar over its port to get the registered service instances inside the cloud.


### Playing arround with a working example

To start, just

``` sh
$ git clone https://github.com/xetys/microservices-sidecar-example
```

This repo includes a complete spring cloud microservice infrastructure with Eureka Service Discovery, Zuul Edgeserver, two simple REST services for exposing random numbers as resource, and an Ruby on Rails application with no function, to be integrated with the cloud.

Your machine needs to fit the follow requirements to run the cloud:

- JDK 8
- Oracle VirtualBox
- docker
- docker compose
- docker machine

#### Preparation

``` sh
./gradlew bootRepackage
```
*What*?
This builds all sub modules and creates a bundle of jars to run on the docker containers.

*Note: If the above command results in an error with finding gradles main wrapper class, just apply the following command*

``` sh
$ /path/to/gradle/bin/gradle wrapper
```

*Why?*
The project root consists of a docker-compose.yml:

``` YAML
eureka:
  build: ./eureka
  ports:
    - "8761:8761"
simple1:
  build: ./simple1
  links:
   - eureka
railsdemo:
  build: ./RailsApplication
  links:
   - eureka
  ports:
   - "3000:3000"
   - "9090:9090"
simple2:
  build: ./simple2
  links:
   - eureka
zuul:
  build: ./zuul
  links:
   - eureka
  ports:
    - "8080:8080"
```

This configuration expects to have all the subdirectories listed there containing a Dockerfile, which expects presence of a jar file (excepting the rails application) like gradles "bootRepackage" task generates it. All the spring containers use [ewolff/docker-java](https://hub.docker.com/u/ewolff/) repository, containing a alpine with java 8 on it, and rails runs inside my [xetys/rails-java](https://hub.docker.com/u/xetys/) container, which is inherited from the official rails docker container with an applied JRE 8.


Next:

``` sh
$ ./docker_create.sh
```

*What?*
This script first creates a new virtual machine with boot2docker on it, then executing a
``` sh
$ docker-compose build
```

automatically, to build all docker containers.

I have automated this part dirty, to make this example easely run. In fact I am really new to this topic at this time, this is not the best way to achieve this. Gradle has some docker plugins which may things I do more elegant and efficient. But you can take a look inside this script to understand, how the cloud ist setted up for development.

Next:
``` sh
$ docker-compose up -d
```

This finally starts the application! The result should be:

- a running small web application with some ASCII art of my companies logo on http://localhost:8080 (yay! this actually the cloud is for :D)
- spring clouds service dashboard on http://localhost:8761
- a service generating random numbers on http://localhost:8080/simple2 and an other one called simple1, which retrieves a number from simple2 and adds one more by itself, on http://localhost:8080/simple1 ...yes, we need some example services to make this cloud doing something :D
- a rails application running on http://localhost:3000 as usual, but also as http://localhost:8080/cloud-rails/ , which demonstrates the rails application beeing available for service discovery
- the sidecars point of view in http://localhost:9090


### OMG! Nothing works?! No reaction? Error pages?!? HELP!!!
Be patient! Dependend on how good your machine is, it takes some time to boot up the entire cloud. On my Dell XPS 13 it takes up to 5 minutes...so don't CTRL+C in panic when error occurs at the very beginning.


## How it works

First, we should create a sidecar application. This is done by applying 'org.springframework.cloud:spring-cloud-netflix-sidecar' dependency to our build gradle and annotate your Application class like this:

``` java SidecarApplication.java
@SpringBootApplication
@EnableSidecar
public class SidecarApplication {
    public static void main(String[] args) {
        SpringApplication.run(SidecarApplication.class, args);
    }
}
```

Then we need to configure it properly:

``` YAML application.yml
server:
  port: 9090

spring:
  application:
    name: ${side-app-name}

sidecar:
  port: ${port:3000}
  health-uri: http://localhost:${sidecar.port}/${health-uri:health.json}
  home-page-uri: http://localhost:${sidecar.port}/
```

*What?*
This configuration implies, you must provide at least a side-app-name when starting the sidecar. The avaible startup parameters are now:

- --side-app-name , the name which will appear for service discovery
- --port , the port of the outside application
- --health-uri , a URI accessible from the sidecar intending, the outside app is still up

You can add more configurable fields in this file if you want. But for our rails application, this is enough to start a sidecar with

``` sh
$ java -jar sidecar-1.0.jar --side-app-name=my-rails-app
```

To contact the clouds service discovery via eureka, we have to provide this configuration also:

``` YAML bootstrap.yml
spring:
  cloud:
    config:
      enabled: false

eureka:
  client:
    serviceUrl:
      defaultZone: ${eureka-url:http://localhost:8761/eureka/}
  instance:
    lease-renewal-interval-in-seconds: ${eureka-interval:5}
    prefer-ip-address: true
```

*Why?*
As you can see, there is something like a health check configured. This tells you, your application has to contain a route (/health.json per default or as configured in application.yml) where the response should look like:

``` json
{
   "status": "UP"
}
```

This is quite straight forward by defining a new controller action in rails application controller:

``` ruby application_controller.rb
  def health
    respond_to do |format|
      format.json { render json: {status: 'UP'}}
    end
  end
```

and wire it

``` ruby routes.rb
get 'health' => 'application#health'
```

### Wire up!

The rails application is started up on a docker container with rails and JRE running on it. Directly after the startup of our rails application, we also start a sidecar next to it. The jar file was previosly copied in docker_create.sh.

Well, there we are: Our "sidecarred" rails application appears as "CLOUD-RAILS" in Eureka and is avaible on http://localhost:8080/cloud-rails/ with Zuuls default routing, as soon everything has synchronized well.


Have a good day, hope this article helps someone!
