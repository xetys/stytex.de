---
layout: post
title: "log analysis with ELK Stack in spring cloud"
date: 2016-01-18 15:55:47 +0100
comments: true
categories:
 - spring cloud
 - spring
 - microservices
 - development
 - java
---

## Introduction

Today I am writing about log aggregation and analysis inside a Spring Cloud. When working with a lot of spring cloud services, you get a lot of logs out of the box. When analyzing one big log file coming from a monolith is something you can handle easely, doing the same for maybe 100 unique services is not.

To solve this in a elegant way, we must include an installation of a node including a database just for log, some kind of port for accepting incoming logs and a clear backend with capabilities of performing complex search over the entire log base.

## Elasticsearch + Logstash + Kibana

Elasticsearch is a modern document based database, built on top of Apache Lucene, which is powerfull in searches on millions of records and is cluster scalable out of the box via REST.

Logstash is a tool wiring log streams our sources and saving them into elastichsearch. The very basic task logstash can be used, is to define a shared volume for all docker container and placing the logs there. Logstash allows to apply different filter on your input, to define how your logs are parsed. This is useful, when collecting logs from different sources, but I will only talk about letting all the services sending their logs to logstash directly in JSON format, to keep the configuration simple.

Kibana actually is a backend offering several tools for log analysis.

<!--more-->

## How to make it work

To see a working example with docker-compose, download the sources from [my GitHub](https://github.com/xetys/microservices-example/releases/tag/1.0). You are also free to

``` sh
$ git clone https://github.com/xetys/microservices-example.git
```

and contribute.

### What we are going to do

Logstash will run with UDP Port 5000 open waiting for log in JSON format. So we have to tell all the services to send their logs. We will use Logback with an UDP appender to accomplish this. We also have to have the ELK-instance avaible to all services.

So we start with configuring the ELK-Stack with a logstash config:

```
input {
    udp {
       port => 5000
       codec => json
    }
}

output {
  elasticsearch { protocol => "http" }
  stdout { codec => rubydebug }
}
```

This is quite easy, because with codec json logstash automatically knows how to deal with the input. So we won't define any filters. We tell also the output to elastic search, which logstash automatically finds since it's on the same machine.

This file has to be applied in this Dockerfile

```
FROM willdurand/elk


COPY logstash-spring-cloud.conf /etc/logstash/logstash-spring-cloud.conf
```

which is also quite easy. Logstash will look for config files in /etc/logstash and waiting for logs incoming on port 5000

This container also starts a Kibana instance on port 80, but we want to have it on its usual port 8200 exposed to the host. So the new docker-compose.yml will look like this now:


``` yaml
elk:
  build: ./elk
  ports:
    - "9200:9200"
    - "8200:80"
    - "5000:5000/udp"
eureka:
  build: ./eureka
  ports:
    - "8761:8761"
  links:
    - elk
simple1:
  build: ./simple1
  links:
   - eureka
   - elk
railsdemo:
  build: ./RailsEurekaClient
  links:
   - eureka
   - elk
  ports:
   - "3000:3000"
simple2:
  build: ./simple2
  links:
   - eureka
   - elk
zuul:
  build: ./zuul
  links:
   - eureka
   - elk
  ports:
    - "8080:8080"
```

Note that every instance now links elk. Exposing port 9200 is optinally, if you want to access elasticsearch also.

### Appending logs to logstash

So if we start the cloud now, we will have a fully running ELK-Stack without collecting any logs.

To make this happen, we just have to add

```
    compile('net.logstash.logback:logstash-logback-encoder:3.5')
```

to our gradle depencies in each service, and also a logback configuration:

``` xml src/main/resources/logback.xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration debug="false">
    <include resource="org/springframework/boot/logging/logback/base.xml" />
    <appender name="UDP2LOGSTASH" class="net.logstash.logback.appender.LogstashSocketAppender">
        <host>elk</host>
        <port>5000</port>
    </appender>

    <root level="INFO">
        <appender-ref ref="UDP2LOGSTASH"/>
    </root>
</configuration>
```

Now bootRepackage all the services and

``` sh
$ docker-compose build
$ docker-compose up -d # start all containers daemonized
```

And you are done!


### Conclusion

You know can acces Kibana on http://localhost:8200/ and explode its features. If there are more different services to send to logstash, you may use a shared location to fetch logfiles, passing them through filters.

Have a great weekend!
