---
layout: post
title: "JHipster 3.7 Tutorial pt 3: Secure service communication using OAuth2"
date: 2016-09-15 14:17:25 +0200
comments: true
categories: [spring, spring-cloud, development, java, oauth2, jhipster]
---

## Intro

It has been a while since my last article. For those, who might be crazy enough to follow my blog should remember the statement of my last article on how to get started with JHipster microservices, which became a core feature since version 3.0.

My statement was:

> I am considering to implement a UAA using JHipster and spring-cloud-security and spring-cloud-oauth2, as I did in my last tutorial.

To review, how I got to this statement, I was writing about how Ribbon and Hystrix can be used in order to let one microservice being able to request resources from another microservice, without going over the gateway, and being aware of service failure, load balancing and so on. But I left this without any considerations on security, as with the JWT solution, there wasn't any suitable workaround, which would do that job in a proper way.

So, let me quickly what happened the last 6 months:

When my last JHipster arcticle made some rounds over the world wide web, I generated off some demo microservice setup and moved the user domain from the gateway to one microservice I called "jhipster-uaa". After this, I performed the steps from my [spring OAuth2 security article](/blog/2016/02/01/spring-cloud-security-with-oauth2/), so I had an `AuthorizationServerConfigurerAdapter` built in that UAA and turned
the `WebSecurityConfigurerAdapter` from the microservices into a `ResourceServerConfigurerAdapter`. This worked perfectly, so I made some screen:

{% img  https://pbs.twimg.com/media/Cep2ZK_WEAAGqIW.jpg   'UAA-screen' %}

and Julien Dubois, lead developer of JHipster, asked me to document this. I did a little more than that: contributing the entire setup including further updates for declarative service communication and testing tools directly to JHipster, as my aim was to make this overcomplex stuff adaptable easily for all developers.

In other was, I want to:

> I want to have secure microservices, which can scale

be open and easy to use for all JHipster users, as well as spring developers, who just can generate JHipster code to look how it works.
So after 6 months of contributing, JHipster released my [official documentation on using JHipster UAA](https://jhipster.github.io/using-uaa/),
so I can proudly sum up my thoughts from late march this year, because now it is really simple to use.


## Setup

To use the new features, the service generation differs from the way I described it in march. Let's walk to the major differences:

1. It's now required to generate one more service, called "uaa". The very first question of `yo jhipster` will provide a new type of application: JHipster UAA server
2. For **all** other services, there will be a question: "which kind of authentication" to use. Here the "uaa" option is required.
3. As for now, it is better to use Hazelcast as hibernate cache (I will explain this a bit more below)

You can find the final project [in my GitHub repository](https://github.com/xetys/jhipster-uaa-setup)

To start of quickly, first use the build script in root:

``` sh
$ ./build-all.sh
```

and then just start the whole setup using:


``` sh
$ cd docker/
$ docker-compose up -d
```

Using these settings, the gateway will not contain the user and account endpoints anymore, since they are now in the UAA. Furthermore, spring cloud security is used in order to provide security. At this point, there isn't a big difference to the JWT authentication type, to do all the other stuff, which was possible until today.

## secure service-to-service communication

In part 2 I showed how to use Ribbon and Hystrix manually with `RestTemplate`, to let the "foo-service" request data from "bar-service". To make this secure, now the UAA can be used. I will first describe, how we could that in theory, following the pattern as we did it last time.

First, we would need a new `RestTemplate` (with Ribbon and Hystrix) to communicate with the UAA. In addtion, we need to setup basic authentication with username and password "internal", to call the following url: http://uaa/oauth/token using POST and one field "grant_type" with value "client_credentials". As you might recognize, we are about authenticating the microservice for the OAuth client named "internal". The response will be an access token. Now, we get back to our REST client for "bar-service", and add an authorization header with that access token as "Bearer".
Despite this is a lot of work, we now achieved a secure communication, as the foo service is now authenticated as a service principal, which
has an valid access token. The "bar-service" now is able to setup access controll configuration based on roles and scope.

This sounds awesome, doesn't it? I thought of this is not straight forward enough, since security is basic, and should not be a leg braking task for development. This is where the Feign project comes into play. When thinking about feign, I always have an association with the moment, when I firstly realized, how "spring-data-jpa" is working, when only an interface has to be defined as repository, without doing any real implementation.

Something similar does feign to you. We just define some interface, using exactly the same `@RequestMapping` annotations as used for the endpoints in the service we are going to consume, and voila: some magic does the implementation for us...including Ribbon, Hystrix **and** (with some additional support from JHipster UAA) access token requesting for uaa.

Assuming we got an JHipster UAA generated application setup as it is out of the box, there are now two steps, to get it working

### making a representation of "Bar" in "Foo"

Ok, this is really obvious, but we need that less code, that I keep some extra lines in my article on that :)

``` java com/example/client/Bar.java

class Bar {
  private String value;

  public Bar() {}

  public Bar(String value) {
    this.value = value;
  }

  //getters, setters..
}
```

You just can copy&paste that from Foo, by removing the JPA and validation annotations.

and finally:

### declaring a authorized feign client

``` java com/example/client/BarClient.java

@AuthorizedFeignClient(name = "bar")
interface BarClient {
  @RequestMapping(value = "/api/bars", method = HttpMethod.GET)
  List<Bar> getBars();
}
```

and we are done. We now can just `@Inject` that client to get things working. In order to make some demo endpoint on "foo-service", we may define a REST controller like this:

``` java
@RestController
class SomeController {
  @Inject
  private BarClient barClient;


  //I have to mention I am a big fan of these cool new annotation from Spring Boot 1.4.0, which is now also part of JHipster!!
  @GetMapping("/api/client/bar")
  public List<Bar> getBars() {
    return barClient.getBars();
  }
}
```

Of cause, this is just one example. This can be done with some services and so on.

Now, what is that `@AuthorizedFeignClient` annotation? This is some JHipster magic in order to call the UAA server to get a token (if needed, it's stored in memory until it expires). If it is still not clear: it is possible to use `@FeignClient` without any predefined configuration as it is, without any JHipster magic, for every other purpose. This is a nice side affect of my contribution, if you are already familiar with feign.

One more note on `@AuthorizedFeignClient`, I used the "name" property of feign client declaration, in order to make it working. For now, the other notations, such as `@AuthorizedFeignClient("bar")` or `@AuthorizedFeignClient(value = "bar")` are **not** working, due to a bug inside spring.

## Advanced topics

Despite this solution is quite new to the official JHipster release, it is already battle tested in several application, where I used my own JHipster branch to generate the application. This led to two advanced topics about testing, which made the UAA feature set usable in production.


### Component testing

As we can assume, feign clients are generally working, it makes no sense to enable then during test (what would mean we are testing that feign itself works). Instead of this, we use some simple mocking technique, to fake the client, to actually test the components using them.

Lets consider some service like this:

``` java

@Service
class FooBarService {
  @Inject
  private BarClient barClient;

  @Inject
  private FooRepository fooRepository;

  public void syncFoosWithBars() {
        barClient.getBars().forEach(bar ->
            fooRepository.save(fooRepository.findOneByValue(bar.getValue())
                .orElseGet(() -> new Foo(bar.getValue()))));
    }
}
```
***note: the FooRepository should have a findOneByValue method returning `Optional<Foo>` and Foo should have an extra constructor `Foo(String value)`***

This service looks up for existing "bars", and syncs "foos" with the same value.

To test that this service is working properly, we need to write the following test:

``` java

@RunWith(SpringRunner.class)
@SpringBootTest(classes = {FooApp.class, SecurityBeanOverrideConfiguration.class})
public class FooBarServiceUnitExTest {

    @Inject
    private FooRepository fooRepository;

    @Inject
    private FooBarService fooBarService;

    @MockBean
    private BarClient barClient;

    @Test
    public void testSync() {
        given(barClient.getBars()).willReturn(
            Arrays.asList(new Bar("one"), new Bar("two"), new Bar("three"))
        );
        fooBarService.syncFoosWithBars();
        List<Foo> synced = fooRepository.findAll();

        assertFalse(
            synced.stream()
                .map(Foo::getValue)
                .collect(Collectors.toList())
                .retainAll(Arrays.asList("one", "two", "three"))
        );
    }
}


```



Obviously, this test would fail the most time in a real environment without the mocking, as it logically depends on the contents of bar service, if not exactly these value exists. We use `@MockBean` to overwrite the actual injection of the bar client, and mock the return behavior using `given(...).willReturn(...)` from Mockito.

### Security testing using `@WithMockOAuth2Authentication`

Another desired testing technique is, to test how the application behaves when access control configuration is applied.
In order to make not to much work on this scenario, we look into the `UaaConfiguration` and see, that per default internal clients get the scope "web-app" granted. To make a RBAC style restriction, we need to apply the following rule in `MictoserviceSecurityConfiguration`:

`.antMatchers("/api/foos").access("#oauth2.hasScope('web-app')")`

which enforces all request to "/api/foos" exclusively granted for internal clients.

To test this configuration holds, we write the following test class.

```java

@RunWith(SpringRunner.class)
@SpringBootTest(classes = {FooApp.class, SecurityBeanOverrideConfiguration.class})
public class SecurityIntTest {

    @Inject
    private WebApplicationContext context;

    @Inject
    private OAuth2TokenMockUtil oAuth2TokenMockUtil;

    private MockMvc restMockMvc;

    @PostConstruct
    public void setup() {
        this.restMockMvc = MockMvcBuilders
            .webAppContextSetup(context)
            .apply(springSecurity())
            .build();

    }

    @Test
    public void testUnauthorizedAccess() throws Exception {
        restMockMvc.perform(get("/api/foos")
            .with(oAuth2TokenMockUtil.oauth2Authentication("test")))
            .andExpect(status().isForbidden());
    }

    @Test
    public void testAuthorizedAccess() throws Exception {
        restMockMvc.perform(get("/api/foos")
            .with(oAuth2TokenMockUtil.oauth2Authentication("test", Sets.newSet("web-app"))))
            .andExpect(status().isOk());
    }
}
```

## Conclusion

I really hope "my considering of writing some UAA for JHipster" lead to some mighty tools, which demystify the usage of OAuth 2 in context of microservice security solution, which easily can be used for JHipster (or just spring based) applications.

This contribution also lead finally to a positive voting for my membership at the JHipster core developer team, which is a great honor to me.

As usual I am open for questions and feedback in the comments section as well as on StackOverflow using the "jhipster" or "spring-cloud-security" tag or on GitHub.

For the further articles the following topics are in my pipeline:

* GitLab CI + dokku setup (complete deployment pipeline)
* spring cloud consul as alternative to Eureka

Have a great upcoming weekend!
