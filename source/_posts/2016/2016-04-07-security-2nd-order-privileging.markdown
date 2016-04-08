---
layout: "post"
title: "Security in applications: 2nd order privileging"
date: "2016-04-07 23:23"
categories: [development, security]
---
## A word on security

While developing modern web or even cloud applications, using tools like
[Spring](https://spring.io), [JHipster](https://jhipster.github.io) or Rails or
whatever, security comes in many different facets. This article is not bound on a
specific framework. This is a general concept.

Today I am going to talk about how to bring access management in a easy business
friendly, but mighty concept. It's about, how to organize access grant to your
business resources. You maybe think, this is "authorization". While authorization
is a technological implementation of bringing authorizing information when it's needed,
"privileging" is the way of what authorities exists and how they are related to the system users.

## Definitions

It's much easier to talk about these thinks, when there are exact terms, so lets
define some!

### user and authorities
Users of the system are allowed to do things, defined by authorities or roles.
An authority is nothing more than a word, which may have some convention as
"RESOURCE_READ" or "RESOURCE_WRITE". So developers can use these words, to secure
or restrict access to resources, forcing users to have certain authorities.

### authentication, authorization
The process, which exchanges user login credentials (username and password) into a
set of user details and authorities, is called authentication.

The implementation of giving access, by analyzing authorities, is authorization.

### privileging
While we got users and authorities, and a cool system to implement any kind of authentication and authorization, there is still a system missing, which defines
"who can do what, depending on authorities".

## first order privileging
This is what I call the most plain way to accomplish this. Behind this scary name is
a very usual process:

In application logic, business data or processes are defined as resources. A resource
can be a noun like "article" or "product", or a proccess like "invoice", "billing".
We can perform actions on these resources. But for simplicity, lets everything
to do with resources, just call resource.

> many users has many authorities

There is a flat n to m relation between users and authorities.

> a resource may be secured by zero to many authorities

A resource may be secured by a set of several authorities. But how many of them the
user should have, to get access granted?

### disjunctive restriction policy
> user is having any of the authorities

This is the most common use case of restriction. Suppose you secure the resource
"employee" with "EMPLOYEE_READ, STAFF_READ". A user will be able to get employee data,
by having one of these authorities.

In Spring Security, this would be

``` java
antMatchers("/employee").hasAuthorities("EMPLOYEE_READ, STAFF_READ")
```

### conjunctive restriction policy
The same as disjunctive, but now the user have to hold all of the securing
authorities.

### custom restriction policy
Suppose resource R has to be secured by the authorities "A", "B" and "C".

disjunctive is: user own A or B or C
conjunctive is: user own A and B and C
custom would then be something more specific like: user own (A or B) and C

### restriction types
We are living in a world, where CRUD APIs are ruling the day. More ore less, but we
actually perform CRUD on some resources all the time. Or more general,
we read and write them. So there are exactly 2 types of restriction: read and write.

It clearly makes sense, to force a naming convention with suffixes "X_READ" and "X_WRITE", to distinguish these.

### implementation
> There are resources, users and authorities.
>
> many users have many authorities
>
> many resources are secured by many authorities by a restriction policy

That's all about first order privileging. It's time to focus first on

### Advantages
It's a little bit of theory, but actually a very simple system, which can be
easily communicated between product owner and development team.
Nearly any kind of access restriction can be modeled with this pattern.

The most commonly used web frameworks offer tools, which are perfect to apply this
kind of privileging, since an disjunctive restriction can be implemented as one line
of code. One line of code making a whole resource secured :D

### Disadvantages
With first order privileging, is still one major question open:
> Who decides, which user gets which authorities?

So with first order privileging, the authorities are also a resource of your business
domain. In a very simple use case, there are two authorities "AUTHORITY_READ" and "AUTHORITY_WRITE". But at the moment, when there is a need of individual users being
granted to write to only certain authorities, things get ugly.

Of course you can hold several resources, aggregating them together into your authorities. You could have different entities or a per-row access restriction.

But isn't there a more elegant way?

## second order privileging
An alternate term would also be: hierarchical access restriction. So like members of
companies or organizations are structured in a hierarchy, the same
often happens by restricting access to the business domain depending on its users.

Suppose an CRM application, managing commission contracts and customer relation to these.
So here the data model itself may have to be secured in tree style.

Boss can open and change every contract, having his partners, which only can open their own contracts, or contracts done by partners working for them. The good old pyramid. Of course, boss doesn't want the partner of his partner of his partner to
lookup his commissions.
More on that, he employs some trainees, managing the built in CMS service. His chief
content manager should be able to decide without boss, which pages of the CMS may be managed by his trainees.

And so on...you know what I mean, I hope!

Let's dive into a little bit of theoretical computer science for this:

### the "grant" restriction type and parent grant authority relation
Now two more things are applied to the authority model. First is straight forward:

> a "grant" authority is responsible for being able to grant subsequent authorities

Or just: a user having "RESOURCE_GRANT" can give other users "RESOURCE_READ" and "RESOURCE_WRITE". But not because there is a "RESOURCE_" in the authorities title.
It's because of the second thing: "RESOURCE_READ" and "RESOURCE_WRITE" have "RESOURCE_GRANT" as their *parent grant authority*

Here is an example:

{% img center /images/2016/04/authority_tree.png 664 552 content authorities %}

As you see, the second order privileging can be visualized as an authority tree.

In this setup, a user having "CONTENT_GRANT" can permit users (including himself)
all authorities in the tree, but a "blog manager" having "BLOG_GRANT" only for blogs.
But a user with "CONTENT_WRITE" can only write all the content, and cannot decide
who else is permitted to write a blog or a page.

Back to securing resources, nothing have changed. The new grant type is not affecting
the read/write access to the resource, so this would be a spring style setup:

``` java

.antMatchers(HttpMethod.GET, "/blogs").hasAuthorities("CONTENT_READ", "BLOG_READ")
.antMatchers(HttpMethod.POST, "/blogs").hasAuthorities("CONTENT_WRITE", "BLOG_WRITE")
.antMatchers(HttpMethod.GET, "/pages").hasAuthorities("CONTENT_READ", "PAGES_READ")
.antMatchers(HttpMethod.POST, "/pages").hasAuthorities("CONTENT_WRITE", "PAGES_WRITE")
```

### forcing implicit authorities
What if there is a grant authority called "SYSTEM_GRANT", which is on top of the
authority tree, and a user, having just only this authority.
When he attempts to change a page, he should be allowed to do so, because if not, he
just could give himself the proper authority and repeat his attempt.

So in this concept, it makes sense to say:

> a user is permitted to do every thing, what he can grant to himself

For me there are at least two approaches to accomplish this:
check the tree during access request, or during access granting. Doing it while the
user is already awaiting a result from your application, might be a hard task.

The other way is, to give the user all implicit authorities, when they are changed.

The advantage of access request analyzing is, a user always get access grant to new
sub authorities, when they are created, but may be complex and time wasting process.

Giving implicit authorities is the fastest solution during access request, because
at this moment it's the same as in first order privileging. But when the
authorities change, the rights have to be recalculated.

### authority tree traversal

In general, a tree traversal is a mapping from a tree into a ordered set or a list.
Although there some different kinds of traversal, the most of them fit the needs
of authority implication. So we just pickup pre-order tree traversal. You just go
from left to right, starting from a node.

Giving a user a grant authority, is the same as applying a subtree of your
authority tree to him. Since we want a list, the tree traversal of this subtree
is the set of implicit authorities.

Need some examples?

The pre-order tree traversal of the content authorities (see fig.) would be
```
"CONTENT_GRANT", "CONTENT_READ", "PAGES_GRANT", "PAGES_READ", "PAGES_WRITE",
"BLOG_GRANT", "BLOG_READ", "BLOG_WRITE", "CONTENT_WRITE"

```

This are pretty much all authorities, what makes sense, if you grant the root authority of the tree.

Traversing starting from "BLOG_READ" would only give

```
"BLOG_GRANT", "BLOG_READ", "BLOG_WRITE"
```

### top-bottom grant, top-bottom revoke, bottom-top revoke

Let authorityTraversal be a mapping (a function) from node in your tree into a list of authorities.

top-bottom grant is actually what I was talking about the last sub chapter:
granting a authority having authority children, generates a list of authorities using

```
implcitAuthorites = authorityTraversal(authority)
newUserAuthorities = UNION(userAuthorities, implcitAuthorites)
```

*union means combining two list without duplicates*

This is mandatory to second order privileging.

top-bottom-revoke is

> When you revoke a authority, you should also revoke it's children

or:

```
implcitAuthorites = authorityTraversal(authority)
newUserAuthorities = userAuthorities - implcitAuthorites
```

bottom-top-revoke is
> When you revoke an authority, go from parent to parent in the users authorities list, and revoke the traversal of it

or: when a user has BLOG_GRANT and CONTENT_GRANT, you should revoke also CONTENT_GRANT, when revoking BLOG_GRANT.
or:

```
topAuthority = authority
while(topAuthority.parent != null and topAuthority.parent in userAuthorities)
  topAuthority = topAuthority.parent

implcitAuthorites = authorityTraversal(topAuthority)
newUserAuthorities = userAuthorities - implcitAuthorites

```

The two revoke styles could be optional, for comfortable performing of access changes
when having a massive authority database.

### Advantages
This concept now can model a very specific access restriction model, which allows
fine-grained privileging. During access request, second order privileging behaves like first order privileging,
when the implicit authorities were computed while granting.

Once the privileging of an application is designed, it also can be easily explained
to the product owner, and gives the developers the possibility of quick response to
new requests on business logic security.

### Disadvantages
More complex :-)


### why that freaky?
I am a big fan of mighty concepts, which can model simple cases at the beginning
and are open to become very complex, without breaking them.

One important thing is, the very most popular frameworks are offering all the tools
needed for that out of the box. So it's independent from the concrete implementation
and doesn't need to develop complex libraries, just using common tools.
It takes the power of trees, which can be easily prepared during on-write time and also
fast on-read analyzing, using modern document based or even better: graph based DMBS like Neo4j.

This little concept might be more a conclusion of current practices in web
application development or security design, then a new innovating concept.
It's packaging it into a bit of theory and some kind of a recipe for your next security design.


## closing words

I promised some actions in my [last article](/blog/2016/03/25/jhipster3-microservice-tutorial/) for positive feedback, which was awesome! I was actually
very busy with contributing the promised UAA solution directly to JHipster. I will write about this later!

If some fans of JHipster or the developers themselves would like to see a prototype
inside the generators or as module, I might consider to implement this also :)

My aim was to share my complex thoughts on this in a article which is
easy to understand, and I hope I did accomplish this. If not, I am open to critics and
suggestions. Be free to give feedback.

Have a great weekend!
