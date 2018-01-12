---
layout: post
title: "JHipster 3.0 Tutorial pt 1+2: Intro + basic service communication"
date: 2016-03-25 14:35:42 +0100
comments: true
categories: [spring, spring-cloud, development, java, oauth2, jhipster]
---

## Introduction

It has been a while since my last post, so since JHipster 3.0 was releases during past week, it's a perfect time to talk about microservices, and how JHipster can help.

The subtopics today are:

 1. scaffolding a microservice architecture with JHipster 3.0
 2. communication between services with decentralized load balancing (Ribbon) and optional circuit switching (Hystrix)
 3. (maybe in next article) applying the full power of OAuth2 client credential grant to apply fine-grained securing (with possible use cases for this)

<!--more-->

## Part 1: Scaffolding a microservice application using JHipster

For those who didn't know: [JHipster](https://jhipster.github.io) is a great project for creating awesome applications with Spring, Spring Cloud OSS and more tools for backend, as well as AngularJS, Bower and Gulp on the frontend. Basicly it is a set of yeoman generators, providing creation and modification of a standard setup width all these tools wired up in a working project. It would take to long to list all things inside the box of JHipster, so I follow directly to making our hands dirty :)

Prepare your system with all the tools mentioned in the [Installation Guide](https://jhipster.github.io/installation/) from JHipster. In short you will need a JDK, npm, docker and gradle working.

And of course: a bit of patency! It took me nearly half of a day to let all the npm installs and gradle builds and IntelliJ 2016.1 monster slow indexing :)

### Definition of Done: the basic mircoservice setup

We will generate an application containing a JHipster gateway (which contains Netflix Zuul and the AngularJS frontend), 2 service applications "foo" and "bar", which will have one entity "Foo" or "Bar" with a field named "value".

``` sh
$ mkdir foobar
$ cd foobar
$ mkdir foo-service bar-service gateway docker
```

These commands will create a basic directory structure. "docker" will contain a docker-compse.yml to start all the services, the other directories for the services themself.

So first we start with foo-service:

``` sh
$ cd foo-service
$ yo jhipster
```

The generator will ask you for a lot of things, but this is how we answer: We want a *microservice application* on port *8081* with any *SQL* based Database, *no Cache* (don't make things harder then needed, we just start off :D ), we want *gradle building*!

Remember these settings, we will generate the bar-service the same way. This will take some time, but then we get an application with a lot of code, but actually no entities. Therefore we do:

``` sh
$ yo jhipster:entity Foo
$ ./gradlew build -Pprod buildDocker
```

with exactly one field "value" of type "String", no validations and no relation ships.

The gradle command will fetch all the fancy dependencies for spring and finally generates a docker image, which will be saved to our local image registry (I will write some words about that in the docker part).

We are done here, so we to exactly the same with bar-service on port 8082:

``` sh
$ cd ../bar-service
$ yo jhipster
[...]
$ yo jhipster:entity Bar
[...]
$ ./gradlew build -Pprod buildDocker
```

Arriving here we got 2 docker images ready for serving their resources, without having any GUI to show them. This is where the gateway comes into play. We generate it in our gateway directory by answering *microservices gateway* in the generator, routing it to port *8080* and also going with a *SQL based* Database, with *gradle* selected as build tool.

Well, we now can directly import the previously generated entities here, by doing:

``` sh
$ yo jhipster:entity Foo
[...]
$ yo jhipster:entity Bar
$ ./gradlew build -Pprod -x test buildDocker
```

The generator will ask if we want to generate them from our microservices and of course were to find them (../foo-service and ../bar-service).

I have skipped the tests, because I expierenced some issues in this phase using the frontend test frameworks...

Now we got all our applications ready. But we need more of the microservice ecosystem to start it right off. At a very minimum we need a JHipster Registry", a service discovery and configuration server. We could check it out from their [GitHub](https://github.com/jhipster/jhipster-registry) and run the registry and all three services each in a terminal. Since the ports are unique, this will give us a possible (and sometimes very comfortable) option, to test your application.

### Using Docker Compose to start the cloud
But there is the more elegant way using docker. Docker provides lightweight virtual machines called "containers". A container may consists of an entire OS like ubuntu or CentOS, but fully running on its hosts kernel. So you can isolate complete environments inside a single docker image and starting your application on them.

This is not just very usefull during development, you can also deploy these images in production.

A very powerful tool is Docker Compose, which configures several docker containers at once and start them together, wiring things like network and shared volumes, which can be configured in a single YAML.

Long text, quick solution:

``` sh
$ cd docker
$ yo jhipster:docker-compose
```

Here you submit "../" as directory, select the three services and finally:

``` sh
$ docker-compose up -d
```

Depending on how many you or your company spent on your current computer and your network...this takes some time :D

But after a while, you will get a Eureka running on http://localhost:8761, your application running on http://localhost:8080 and a very cool Kibana dashboard on http://localhost:5601 (if you choosed to use it in the docker-compose sub-generator, I spent about an hour of clicking inside it the first time :) )

### Howto: Configuring IntelliJ IDEA

After a long fight with 2016.1 and final downgrade to IDEA 15.0.2, I found out the most pleasant way is to have a central gradle configuration. Go to our root folder and add these files:

``` text build.gradle
repositories {
    mavenCentral()
}

apply plugin: 'java'
```

and

``` text settings.gradle
include 'foo-service'
include 'bar-service'
include 'gateway'
```

Now you can point IDEA to the central gradle file and use it for its indexing.

### End of the lazy part
We didn't code a lot till here, only generating. Since you can use JHipsters domain language [JDL](https://jhipster.github.io/jdl/) for modelling your entities or even UML, this is really huge. You just scaffolded a working cloud API with basic security, API documentation and completelly tested in this generated state.

Even if you don't consider to use it in a real application development, JHipster is a good tool to see how things work.

## Part 2: inter-service communication
A lot of questions come up when playing arround with all these tools. One quite obvious is:

> How do services can communicate with each other?

This question was asked also on the JHipster 3.0 night in Singapore, and the answer was like

> You should design your services in a way, so they won't have to communicate. But you always can access them using the gateway

This actually, is a solution. But it doesn't fit the microservice idea really, because this will turn the gateway into a centralized proxy and load balancer, which becomes a single point of failure.

One other point is, that each services has the tools, to get the service hosts by their own, using Eureka Discovery Client. The gateway to the same thing, using its built in routing. Suppose you have got 4 Services A,B,C,D and a gateway, so the worst call chain were A asks B,C and D would be like

A > GW > B, GW > C, GW > D

were it would be like

A > B, A > B, A > D

when would use discovery clients inside the services.

With this, every service has its own loadbalancer!

### Definition of Done: Ribbon loadbalancing

Suppose, we want service "foo" to communicate with "bar". For this we define a "BarClient", which acts as a service for later using (similar to the internal repositories and services). This client will use Netflix Ribbon for load balancing client and retrieve the Bar API with RestTemplates.


Or let just an integration test explain, what should work:

``` java src/test/java/de.stytex.foo/BarClientTest.java

@RunWith(SpringJUnit4ClassRunner.class)
@SpringApplicationConfiguration(classes = FooApp.class)
@WebAppConfiguration
@IntegrationTest
public class BarClientTest {
    Logger log = LoggerFactory.getLogger(BarClientTest.class);

    @Inject
    BarClient barClient;

    @Test
    public void testContextLoads() throws Exception {
        //should be loaded

    }

    @Test
    public void testEntityLifeCycle() throws Exception {
        Collection<Bar> bars = barClient.findAll();
        int barCount = bars.size();

        Bar myBar = new Bar();
        myBar.setValue("my awesome bar!");

        //test creating
        Bar result = barClient.create(myBar);

        assert result.getId() > 0;
        log.info("created bar entity with id {}", result.getId());


        //test entity get
        myBar = barClient.getOne(result.getId());

        assertEquals(myBar.getId(), result.getId());

        //test collection get
        bars = barClient.findAll();
        assertEquals(barCount + 1, bars.size());

        //test entity update
        myBar.setValue("my changed value");
        result = barClient.update(myBar);

        assertEquals(myBar.getValue(), result.getValue());

        //test delete
        barClient.delete(result.getId());
    }
}
```

This is what the bar client should be capable of after this part. We just do normal CRUD things here.
You may notice, we use the Bar class in our foo service, which never was generated. We have to add this of course and only as a POJO, not as an entity bean.

``` java src/main/java/de.stytex.foobar.domain/Bar.java
public class Bar {
    private long id;
    private String value;

    public String getValue() {
        return value;
    }

    public void setValue(String value) {
        this.value = value;
    }

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }
}
```



To have a general toolset of a load balancing client, lets define:

``` java src/main/java/de.stytex.client/AbstractMicroserviceClient.java
public abstract class AbstractMicroserviceClient<E> {
    private String serviceName;

    @Inject
    protected ObjectMapper mapper;


    /**
     * force the descendants to call super("SERVICE_NAME")
     *
     * @param serviceName the service name known by service discovery client
     */
    public AbstractMicroserviceClient(String serviceName) {
        this.serviceName = serviceName.toUpperCase();
    }

    abstract public Collection<E> findAll();

    abstract public E getOne(long id);

    abstract public E create(E object);

    abstract public E update(E object);

    abstract public void delete(long id);

    protected RestOperations restTemplate;

    private LoadBalancerClient loadBalancerClient;

    /**
     * let lately inject the client to retrieve host and port of the target service
     *
     * @param loadBalancerClient autowire parameter
     */
    @Autowired(required = false)
    public void setLoadBalancerClient(LoadBalancerClient loadBalancerClient) {
        this.loadBalancerClient = loadBalancerClient;
    }

    /**
     * Constructs a url for rest template
     *
     * @param path resource path on the service
     * @return a url String for use in RestTemplate
     */
    protected String getUrl(String path) {
        String url;
        ServiceInstance instance = loadBalancerClient.choose(serviceName);
        String prefix = instance.isSecure() ? "https://" : "http://";

        url = prefix + instance.getHost() + ":" + instance.getPort() + "/api/" + path;


        return url;
    }

    /**
     * Helper method, because getUrl("resource", 1) is cooler than getUrl("resource/" + 1)
     *
     * @param path the resource entities path
     * @param id a numeric resource identifier
     * @return a url String for use in RestTemplate
     */
    protected String getUrl(String path, long id) {
        return getUrl(path + "/" + id);
    }

    @Inject
    public void setRestTemplate(RestOperations restTemplate) {
        this.restTemplate = restTemplate;
    }

    /**
     * generates a JSON string for entity of type E
     *
     * @param entity the entity to be converted
     * @return a JSON representation of the entity
     * @throws JsonProcessingException
     */
    protected HttpEntity<String> getJsonEntity(E entity) throws JsonProcessingException {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        String entityJson = mapper.writeValueAsString(entity);

        return new HttpEntity<>(entityJson, headers);
    }
}
```

Ok, this is a bit more source now. This is an abstract class, so we force an concrete implementation. It is a generic typed class, so you can use this implementation for different resources. We use springs IoC container to give us all we need. The LoadBalancerClient interface will be injected with ribbon, which uses its Eureka configuration to ask for services. As a result it picks one available instance and prepares the url. All this is done with the getUrl helper method. This method can be used to access the resource straight by passing it's path like

``` java
getUrl("bars", 123);
```

So here comes the implementation for Bar Client

``` java src/main/java/de.stytex.foobar.client/BarClient.java
public class BarClient extends AbstractMicroserviceClient<Bar> {
    public BarClient() {
        super("BAR");
    }

    /**
     * A reduced version of a Bar, with ignoring id on Jacksons serialization
     */
    @JsonIgnoreProperties({"id"})
    static class NewBar extends Bar {
        public NewBar(Bar base) {
            this.setValue(base.getValue());
        }
    }


    @Override
    public Collection<Bar> findAll() {
        return Arrays.asList(restTemplate.getForEntity(getUrl("bars"), Bar[].class).getBody());
    }

    @Override
    public Bar getOne(long id) {
        return restTemplate.getForObject(getUrl("bars", id),Bar.class);
    }

    @Override
    public Bar create(Bar object) throws JsonProcessingException {
        HttpEntity<String> entity = getJsonEntity(new NewBar(object));
        ResponseEntity<Bar> responseEntity = restTemplate.postForEntity(getUrl("bars"), entity, Bar.class);

        return responseEntity.getBody();
    }

    @Override
    public Bar update(Bar object) throws IOException {
        HttpEntity<String> entity = getJsonEntity(object);
        ResponseEntity<String> responseEntity = restTemplate.exchange(getUrl("bars"), HttpMethod.PUT, entity, String.class);

        return mapper.readValue(responseEntity.getBody(), Bar.class);
    }

    @Override
    public void delete(long id) {
        restTemplate.delete(getUrl("bars", id));
    }
}
```

> Can we already test this?

No we can't, because JHipster is configured to run with eureka disabled in tests. We need to comment this fields out in

``` yaml src/test/resources/config/application.yml
#eureka:
#    client:
#        enabled: false
```

and there is no default bean for RestOperations, so we either just create a new RestTemplate inside AbstractMicroservicesClient or add a configuration like this:



``` java src/main/de.stytex.foobar.config/RestTemplateConfiguration.java
@Configuration
public class RestTemplateConfiguration {
    @Bean
    public RestOperations restTemplate() {
        return new RestTemplate();
    }
}
```

Urgh, can we test it? Lets test!

If everything was wired up correctly, you still get a

> org.springframework.web.client.HttpClientErrorException: 403 Forbidden

So, what is wrong? We are requesting the service api, which is secured by JWT tokens. So we must provide a token when consuming the bar resource. I will come back to this topic in my later part, since it is not that easy. For testing purposes we just can open up bars resource by modifying its SecurityConfiguration like this:

``` java src/main/java/de.stytex.foobar.config/MicroservicesSecurityConfiguration.java
...
@Override
    public void configure(WebSecurity web) throws Exception {
        web.ignoring()
            .antMatchers(HttpMethod.OPTIONS, "/**")
            .antMatchers("/api/**")     //FOR TESTING!
            .antMatchers("/app/**/*.{js,html}")
            .antMatchers("/bower_components/**")
            .antMatchers("/i18n/**")
            .antMatchers("/content/**")
            .antMatchers("/swagger-ui/index.html")
            .antMatchers("/test/**")
            .antMatchers("/h2-console/**");
    }

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .csrf()
            .disable()
            .headers()
            .frameOptions()
            .disable()
        .and()
            .sessionManagement()
            .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
        .and()
            .authorizeRequests()

            .antMatchers("/api/logs/**").hasAuthority(AuthoritiesConstants.ADMIN)
            .antMatchers("/api/**").permitAll() //FOR TESTING!
            //.antMatchers("/api/**").authenticated()
            .antMatchers("/metrics/**").permitAll()
...
```

And now the integration test should pass.

### The good news are...

Using this pattern, each service inside the project can communicate directly with each other using a simple RestTemplate.

> Is that all?

No! You also can directly add Hystrix circuit switchting easily here. Suppose your foo service experience a lot of timeouts when asking for bar service. In a real world scenario this could happen, because some bug on bar service shows up on massive traffic, which rapidly reaches the service in production. It causes the bar service to crash. This would usually provoke errors on the foo service and maybe also the gateway, so one service fail lead to the fail of the whole request chain. Now comes the second part: since foo service is down, no request reach bar service anymore, so it returns from crash. But this will let a whole wall of holded "bar requests", which now reach bar at one time and the circle starts again.

Hystrix stores your results in a cache and use it, when the origin service is down. When the origin service returns from downtime, hystrix still will use the local cache for a while to put up traffic slowly on bar over time.


> This is a great feature of spring cloud...but how to use it?

Just add @EnableCircuitBreaker on FooApp like this:

``` java src/main/java/de.stytex.foobar/FooApp.java
@ComponentScan
@EnableAutoConfiguration(exclude = { MetricFilterAutoConfiguration.class, MetricRepositoryAutoConfiguration.class })
@EnableConfigurationProperties({ JHipsterProperties.class, LiquibaseProperties.class })
@EnableCircuitBreaker
@EnableEurekaClient
class FooApp {
...
```

and modify the bar client like this:


``` java src/main/java/de.stytex.foobar.client/BarClient.java
@Component
public class BarClient extends AbstractMicroserviceClient<Bar> {

    Collection<Bar> barCache;

    public Collection<Bar> getBarCache() {
        return barCache;
    }

    public BarClient() {
        super("BAR");
    }

    /**
     * A reduced version of a Bar, with ignoring id on Jacksons serialization
     */
    @JsonIgnoreProperties({"id"})
    static class NewBar extends Bar {
        public NewBar(Bar base) {
            this.setValue(base.getValue());
        }
    }


    @Override

    @HystrixCommand(
        fallbackMethod = "getBarCache",
        commandProperties = {
            @HystrixProperty(name = "circuitBreaker.requestVolumeThreshold", value = "2")
        }
    )
    public Collection<Bar> findAll() {
        barCache = Arrays.asList(restTemplate.getForEntity(getUrl("bars"), Bar[].class).getBody());
        return barCache;
    }

    @Override
    @HystrixCommand(
        fallbackMethod = "getOneCache",
        commandProperties = {
            @HystrixProperty(name = "circuitBreaker.requestVolumeThreshold", value = "2")
        }
    )
    public Bar getOne(long id) {
        return restTemplate.getForObject(getUrl("bars", id),Bar.class);
    }

    public Bar getOneCache(long id) {
        return barCache.stream().filter(bar -> bar.getId() == id).findFirst().get();
    }
...
```

This is just a bit of code doing a huge work.

Following this pattern makes your microservice project as much decentralized as possible. The responsibility of the gateway is reduced, since it is not the central load balancer and circuit breaker, but only one in a row.


### The bad news...

We had to turn off the security on bar services API to make this kind of communication possible. But this is of course a no go to keep our sensible resources open to the whole world, isn't it?

> So how to solve the security problem? Why it is actually a problem?

JHipster uses JWT tokens for *authorization* (not authentication!). Which means, every request should have a bearer access token inside a Authorization header. This JWT can be decrypted on the services side and we can extract the Principal, without querying the gateway, since the gateway is responsible for authentication.

The test just cannot pass, because the very initial request is fired inside the test. You could access some foo service endpoint via the angular frontend, which would add the access token inside the HTTP headers. Spring Cloud Netflix Zuul is able to get this token. So you could store it in a session scoped bean and add on your rest template on output. Then the tests still would fail, but in real world the requests would be authorized.


An other approach would be to make your RestTemplate been wrapped into a bean with this interface:

``` java
interface JHipsterAuthenticatedRest {
	public RestTemplate getTemplate();
	public boolean isAuthenticated();
	public void authenticate(String user, String password);
	public HttpHeaders getHeaders();
}
```

You would add the "system" users credentials or any other "machine" user, to let the service authenticate first, to get a own token. The getTemplate() method could ask isAuthenticated() first, then return a RestTemplate and prepared HttpHeaders for authorized calls, or authenticate before.

Not sweet, but a working solution..

> Can we do that better?

Yes, we can do it with:

## Part 3: OAuth2

Using JWT tokens is a great idea, but the guys reinvented the wheel a bit by implementing a specific authorization mechanism. I can absolutelly understand, why they did it. Some months ago I had that decision, too.

The answer of the question:

> What is a proper way to manage authentication and authorization inside microservices?

When I first faced OAuth2, it looked to complicated and complex for a simple thing I wanted. But security inside services can get quite complex as well, so using OAuth2 perfectly fits the needs.

> Which needs? What does the built in authentication cannot what OAuth2 can?

In my second approach to apply security on the services I mentioned usage of a machine user. The current implementation does not support distinction between "user access" and "machine access".

There are a lot use cases, where to use it. For example: trust machines, don't trust users. So you allow a machine to do everything, and apply just privileges on user sessions. If you don't like this, you can apply the authorities from user session to the machine call, getting the same roles as the user has. You can use "scopes" to even distinguish between users privilges, called "authorities", and machine privileges, called "scopes"

Performing service calls could be done using OAuth2 client credential grant type, so we never need a user authentication, to get secure priveleged by the resource servers.


Let me say, this is not a trivial step anymore, and this article is growing a bit huge right now. I am considering to implement a UAA using JHipster and spring-cloud-security and spring-cloud-oauth2, as I did in my last tutorial.

***update***: This "consideration" has an happy end: read on on my [article about secure service communication](/blog/2016/08/31/jhipster-3-dot-6-secure-service-communication/)

## Conclusion

Yes, it was sayed a lot of times: JHipster is a great job! There is a lot of work you can save just by generating. This is very interesting to me, and I hope this article gives some a good introduction into some practices.

Please be free to comment, criticize or ask questions in the comments. If some one likes this work, my motivation of implementing an authorization service will grow exponential :)


Have a great week  

## Resources

* [Demo Application on my GitHub account](https://github.com/xetys/jhipster-ribbon-hystrix)
* [JHipster 3.0: Introducing Microservices](http://www.ipponusa.com/blog/jhipster-3-0-introducing-microservices/)
* [JHipster](https://jhipster.github.io)
