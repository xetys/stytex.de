---
layout: post
title: "From script web developer to kickstart into Java and Spring"
date: 2016-01-16 13:42:28 +0100
comments: true
published: false
categories: 
 - development
 - java
 - spring
 - web development
---

In this article I am going to focus on some issues I've experienced during change from script developer to something more "enterprise". I show, how to make directly a Spring Boot application.
So lets begin...

# Motivation
I am working on web development more than ten years at the moment, heavily focussed on the scripting language PHP. But also other languages with their frameworks got some straight ways to kickstart.
As a lazy script kiddie (I think this pretty much is, what a lot of Java/C#/C++ devs think about that), I am used to have either a really simple language or mighty frameworks, maybe with built in generators.
Well, there are a lot of tools in Java, much more I know about. But while reading books or tutorials, I felt like "why do they start somewhere in the center to tell?". Especially during studying Spring.
I don't mean basic Java, there is a lot. I think it is a difference, being familar with just a languages syntax and semantics or being able to build something really on it. And exactly here, they all starting from the center.

Why? There are a lot things you just have to read about, think about and did some experiments, then you got a "feeling" of it. A lot of people treat this as hard work, which is hard to share. 
So it's like "if you don't know, what this is about, you should inform yourself better, and then return to this".

I will try to give a better direction for this.

# Why Java and Spring?
I don't want to start of a Java vs. the rest comparison or something like this. Java just is my personal preference, because it is a lower language then I had learned before, comfortable enough in comparison to C and mighty. To say it in a childish way: "Java is more serious then scripting". This is partly correct, because here, you should better know, what you are doing.

## failfast
One aspect of generally working in lower languages is failfast. This just means, the compiler will not forgive you mistakes you would do in scripting. Really often, you will even be not able to compile a project or it fails immediatly on startup. This is okay, it's usually like this when you start learning all this :)

As Java is a type strict language, you can't just throw things into arrays and on-the-fly objects, but I assume this is not a real problem, since learning the basic language is trivial for someone reading articles like this. 

## recommended preparation
I am using IntelliJ IDEA for all experiments!

When I started studying Java, I was sure I will focus on the Spring framework. I had read a lot of articles weeks before I finally decided to do so. By comparing Spring and JEE, I felt Spring is more focussing on state of the art technology, while JEE has a hard learning curve (as spring also :D). But at that moment, it felt more trendy, and I have to admit, that this was one factor to my decision.
And I don't regret it. Spring is a powerfull lightweight framework with all the power of Java enterprise, including technologies, which are more state of the art. Just one example: 
In Ruby on Rails when you start with

``` 
rails n my_project
rails s
```

you start a builtin web server called WebRick, which serves you the fresh generated project. When you do the similar with the smallest spring boot application, you start with an embedded tomcat application server. But while WebRick is just a development solution, tomcat is an application server, which you could use in production. You don't even have thing about servlets if you keep on deploying jars.
With JEE you should first come in touch with java application servers. Compare the benefits and disadvantages and choose one for starting.

I prefer books over tutorials when it comes to learning a heavyweight knowledge. Reading a lot of "tutorials" by one person (or just a few), is more efficiant then reading a lot of different writers with different opinions. So after reading reviews, I've buyed "Spring in Action" by Craig Walls. Like a lot of readers before, I recommend this book to start with spring, really! But nevertheless, he was also a in-the-center-starter for me. Well, here is the best time to get to the point :)

# Build Management Tools
This topic is really trivial for any Java developer, but not for a student or pure script developer. Of course, I had used tools like bower or gem, and even ANT for automating PHP enterprise applications, but I am used to having something like a direct way for backend. How to start off a rails, I already mentioned. If you are going to start a plain PHP on a Apache...it's just:

```
<?php echo "Hello World"; 
```

Or similar ways during Symfony generators. 

Building Java Applications require to wire all dependencies for your app during compilation. To manage this, there are tools like ANT, Maven or Gradle. They basicly manage the dependencies (libraries you or your libraries use) and allow to use and (re-)define tasks. Build or running your app is one common task. I prefer to use Gradle, since you can code inside your task, if you want, instead of accomplish this in a more complex way.

You find a lot of examples on how to use Gradle at [spring.io](http://spring.io) and in Spring in Action.

## Starting of with Gradle
I had asked myself, how can I efficiantly start of with Gradle? Do I have to install it? Do I have to download it and put it into /usr/bin with the right permissions? 
Here is how I do.

- download latest Gradle binaries [here](http://gradle.org/gradle-download/)
- cd into your project directory

And then:

```
/path/to/your/gradle-X.Y/bin/gradle wrapper
```

Now you can proceed with 

```
./gradlew <task>
```

You can also use the [Spring Initialzr](https://start.spring.io/), which results in the same.


# General Spring Boot Application Structure
There is so much to learn about Spring, Spring Boot, Spring Web and so on. But how to make just a simple starting and working Spring Boot Application? With knowing the basics, you will be able to build a Spring Boot application with just 2 Files at all. For this, you have to know 2 subtopics for know:

## dependencies
All Gradle plugins and dependencies are defined in a "build.gradle"
You can treat dependencies like packages you know from linux. They actually bring you the libraries. Some of these dependencies, just contain dependencies inside...
For a quick setup, you will need to specify the version of Spring Boot you are going to use, the plugins for gradle and the spring-boot-starter-web dependencie, which itself contains spring-boot-starter, which again contains the spring framework and so on. Additionally, we take the spring-boot-starter-test dependency, for having the option JUnit test your spring boot application out of the box.

So this is how our minimal build.gradle looks like:

``` groovy
buildscript {
	ext {
		springBootVersion = '1.3.1.RELEASE'
	}
	repositories {
		mavenCentral()
	}
	dependencies {
		classpath("org.springframework.boot:spring-boot-gradle-plugin:${springBootVersion}") 
	}
}

apply plugin: 'java'
apply plugin: 'idea'
apply plugin: 'spring-boot' 

jar {
	baseName = 'demo'
	version = '0.0.1-SNAPSHOT'
}
sourceCompatibility = 1.8
targetCompatibility = 1.8

repositories {
	mavenCentral()
}


dependencies {
	compile('org.springframework.boot:spring-boot-starter-web')
	testCompile('org.springframework.boot:spring-boot-starter-test') 
}



task wrapper(type: Wrapper) {
	gradleVersion = '2.10'
}
```


## File structure

I will call the base package "com.example.demo". First we need to place a main class somewhere. This is the default file structure of a Spring Boot Application:

``` 
.
+-- src
    +-- main
        +-- java
            +-- com
                +-- example
                    +-- demo
                        +-- Demo.java
        +-- resources
    +-- test
+-- build.gradle

```


Now we define a simple Spring Boot application with these lines of code:

``` java
@SpringBootApplication
public class Demo {
	public static void main(String[] args) {
		SpringApplication.run(Demo.class, args);
	}
}
```

As spring-boot-starter-web is an dependeny containig dependencies, the @SpringBootApplication annotation is an analog annotation containing annotation, for at least

- @ComponentCan (automatic lookup of @Service and @Component annotated classes for Springs IoC)
- @EnableAutoConfiguration (allows wired beans automatically configure them selves with default attributes)
- @Configuration (allows do configure other beans to be wired automatically)

This class will just start a embedded tomcat server, listening per default on 8080, having no controllers listening on it.

To give the class a greeting controller, you just annotate the class with @RestController and add the following method:

´´´ java
@RequestMapping("/")
public String hello() { return "Hello"; } 
```

and start your application with

``` 
./gradlew bootRun
```

Well, that it is! 
