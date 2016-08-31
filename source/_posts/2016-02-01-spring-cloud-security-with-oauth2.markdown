---
layout: post
title: "Securing spring cloud microservices with OAuth2"
date: 2016-02-01 16:17:42 +0100
comments: true
categories:
 - spring cloud
 - spring
 - java
 - microservices
 - oauth2
 - development
---

## From Zero to OAuth2 in Spring cloud

Today I am presenting hours of research about a (appearently) simple question: "How can I maintain security in my cloud?". The task is to enable a simple but mightful possibility to secure spring cloud services down to method invocation level, having a central point of where users and authorities can be assigned.

To achieve this as efficient as possible, OAuth2 is the solution.

In this article we are going to implement a authorization service holding user authorities and client information, and a resource service with protected resources, using Spring OAuth2 and JSON Web Tokens (JWT). I will demonstrate how the resource server can host a RESTful resource, having different security levels, which is defined in example authorities "FOO_READ" and "FOO_WRITE".

The implementation can be downloaded and tested on my [GitHub Repository](https://github.com/xetys/spring-cloud-oauth2-example).


Since I am really new to Spring and Spring Cloud including all its concepts, this was a quite hard way of research. This might sound weird, but at the beginning I couldn't get, why they are all talking about Facebook/GitHub authentication in context of how to secure internal data. It was leading to an obvious question:


### Why OAuth2?

Despite microservices are a rather new topic in modern software development, OAuth2 is a well known authorization technology. It is widely used, to give developers of web application to access users data at Google/Facebook/GitHub directly from the foreign services in a secure way. But before I explain more details, I will first refocus, what we initially want to achieve: cloud security.

So, what could we do generally, to gain/forbid access to resources inside the cloud to users? Let's take some dumb stupid ways.

We could secure the edge server, assuming all the acces to our data will go through it. This is nearly the same as you would do with classic Spring Mvc Security. But there is no way of method mscurity and, what is the most important: your data is insecure from inside.

Other way: We share the user credential database for all services and authenticate the user on each service before access. Sounds somehow really stupid, but it's actually a working approach with all the spring security features avaible.

Better way: The user authenticates on a authorization service, which maps the user session to a token. Any further API call to the resource services can provide this token. The services are able to recognize the provided token and ask the authorization service, which authorities this token grants, and who is the owner of this token.

This sounds like a good solution, doesn't it? But what's about secure token transmission? How to distinguish between access from a user and access from another service (and this is also something we could need!)

So this leads us to: OAuth2. Accessing sensible data from Facebook/Google is pretty much the same as accessing protected data from the own cloud. Since they are working for some years on this solution, we can apply this battleground approved solution for our needs.

## How OAuth2 works

Implementation of OAuth2 in Spring is quite easy, when you understand the concept of OAuth2. Let us describe the scenario "AwesomeApp wants Peters profile data from facebook for Peters profile in AwesomeApp"

OAuth2 defines 4 roles in this process:

 - Resource Owner - this is Peter
 - Resource Server - this is Facebook
 - Authorization Server - this is also Facebook, because it knows Peter and its Session and data
 - Client - the AwesomeApp

When Peter tries to sign up with Facebook Login, Awesome App redirects him to FBs authorization server. This knows about Peter, whether he is logged in, and even if Peter already was here before and already aproved it's data. When Peter vists this page for the first time, he has to allow AwesomeApp to access his email and profile data. These two sources are defined as scopes, which AwesomeApp defines in Facebooks AwesomeApp Facebook-app. The developer of AwesomeApp provided to ask exactly for these two permissions.

Peter gives his permission, and is redirected to AwesomeApp with a access token. AwesomeApp then uses the access token to retrieve Peters email and profile data directly from Facebook, with no need to authenticate with Peters credentials. More than that, each time Peter signs in to AwesomeApp, he visit the authorization page again, which already knows his decision and directly responds with a token.


So far...but how to apply this on our brutal real world? In springs OAuth2 implementation as well as in all examples, they are talking about clients and scope.

> Are OAuths "clients and scopes" the same as our classical "user and authorities"?

> Do I have to map authorities to scopes?

> Why do I need clients?

You are maybe trying to map the roles from the first scenario to the real world. This is tricky!

Second scenario: Any kind of application provides user login. This login results in a exchange of user credentials to access token. All further API calls provide this token in its HTTP header. The services inside are asking the authorization server to ask for permission of access. In the other direction, the services may ask the authorization service about the user who is accessing the data.

As you see, the four OAuth2 roles depend of the direction in which data is requested. For asking protected business data from resource server, the authorization server is what it is, the resource servers also, the application is the client and a service, holding the permissions, is the owner. When asking the users data, the authorization service becomes a resource server, but resource server the client.

### Scopes and Roles, Clients and Users

With OAuth2 you can define, which application (web, mobile, desktop, additional website) can access which resources. So there is one dimension, where we have to decide which user can access which data, but also which application or service, can access which resource.

In a web shop, the frontend may act as an client, having access to products, orders and customers, but the backend also about logistics, contracts and more, independent of the users authorities. In the other way, a user may have potential access to a service but no access to all its data, because he is using a web application, where other users are permitted to access while he is not. This "maschine based" access, is our other dimension. If you are familiar with math, I can say: the client-scope-relation is linear independent to the user-authority-relation in OAuth2.

### Why JWT?
I was frustratingly trying to bring it up working while exchanging tokens over userInfoUri. But this seems to be buggy at the moment. Implementing the same using JWT makes it working.

## implementing the authorization service

For the later token exchange we first generate a JWT token keystore

``` sh
keytool -genkeypair -alias jwt -keyalg RSA -dname "CN=jwt, L=Berlin, S=Berlin, C=DE" -keypass mySecretKey -keystore jwt.jks -storepass mySecretKey
```

Then execute

``` sh
$ keytool -list -rfc --keystore jwt.jks | openssl x509 -inform pem -pubkey
Keystore-Kennwort eingeben:  mySecretKey
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwR84LFHwnK5GXErnwkmD
mPOJl4CSTtYXCqmCtlbF+5qVOosu0YsM2DsrC9O2gun6wVFKkWYiMoBSjsNMSI3Z
w5JYgh+ldHvA+MIex2QXfOZx920M1fPUiuUPgmnTFS+Z3lmK3/T6jJnmciUPY1pe
h4MXL6YzeI0q4W9xNBBeKT6FDGpduc0FC3OlXHfLbVOThKmAUpAWFDwf9/uUA//l
3PLchmV6VwTcUaaHp5W8Af/GU4lPGZbTAqOxzB9ukisPFuO1DikacPhrOQgdxtqk
LciRTa884uQnkFwSguOEUYf3ni8GNRJauIuW0rVXhMOs78pKvCKmo53M0tqeC6ul
+QIDAQAB
-----END PUBLIC KEY-----
-----BEGIN CERTIFICATE-----
MIIDGTCCAgGgAwIBAgIEOkszIDANBgkqhkiG9w0BAQsFADA9MQswCQYDVQQGEwJE
RTEPMA0GA1UECBMGQmVybGluMQ8wDQYDVQQHEwZCZXJsaW4xDDAKBgNVBAMTA2p3
dDAeFw0xNjAyMDExNzQwMTlaFw0xNjA1MDExNzQwMTlaMD0xCzAJBgNVBAYTAkRF
MQ8wDQYDVQQIEwZCZXJsaW4xDzANBgNVBAcTBkJlcmxpbjEMMAoGA1UEAxMDand0
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwR84LFHwnK5GXErnwkmD
mPOJl4CSTtYXCqmCtlbF+5qVOosu0YsM2DsrC9O2gun6wVFKkWYiMoBSjsNMSI3Z
w5JYgh+ldHvA+MIex2QXfOZx920M1fPUiuUPgmnTFS+Z3lmK3/T6jJnmciUPY1pe
h4MXL6YzeI0q4W9xNBBeKT6FDGpduc0FC3OlXHfLbVOThKmAUpAWFDwf9/uUA//l
3PLchmV6VwTcUaaHp5W8Af/GU4lPGZbTAqOxzB9ukisPFuO1DikacPhrOQgdxtqk
LciRTa884uQnkFwSguOEUYf3ni8GNRJauIuW0rVXhMOs78pKvCKmo53M0tqeC6ul
+QIDAQABoyEwHzAdBgNVHQ4EFgQUxebRVICNPg65T2RgrOe2J5qDMXMwDQYJKoZI
hvcNAQELBQADggEBAAHBF3JQ2ZsEjuYYwU5cp9BzBJoTQyChF37AA76EorrcSeqo
Rui1dUIfXbImIOZ5PBNk34IFWROTwpw80zBCZQ7NQ81ITzuhsxjbX7Wxj6iCq3u9
TDN+IxiaZMvJ2PDfeRqr93HOwMTMttxyW4KVa3geQ+yMMSZrxagEpqMA1Fviqa6T
5u8DNqfXQ8Hg+yG2bMNQs6GleAFkRprkHjR6yY7ehmIVMZ7iBkkXh8IO8fKy2WNK
uWa+DO2lXJj1W7HLXeaeT0twAqwyoNj2/pxMuv/JrTlNkhcUTmP+UBAJZih0KSGD
9TSKs5HlBGsIUpILuauNzZk1VS2RCyVtD1zf7vM=
-----END CERTIFICATE-----
```

You will be prompted to enter your secret key. Copy the public key (including the dashed lines) into a file named "public.cert".

Copy this file to src/main/resources.

### the plan

In this example we will define a resource "foo", which can be read with authority FOO_READ and can be written with FOO_WRITE.

On the authentication service we have the user "reader", who can read a foo, and a "writer". To make the resource server accessible by a web application, we define a "web_app" client.

First we define our gradle file. Use [start.spring.io](http://start.spring.io) to generate a gradle boot application with "Web" dependency.

*this gradle file will be used for resource server also!*


Now we adjust the dependencies to this

```
dependencies {
	compile('org.springframework.boot:spring-boot-starter-web')
	compile('org.springframework.security.oauth:spring-security-oauth2:2.0.8.RELEASE')
	compile('org.springframework.security:spring-security-jwt:1.0.3.RELEASE')
	testCompile('org.springframework.boot:spring-boot-starter-test')
}
```

To make the configuration non-confusing, I will use separate configurations instead of mixing all in inside the Application class. In both examples they are as they roll out from spring initialzr.


### OAuth2Configuration

We begin with the following configuration

``` java

@Configuration
@EnableAuthorizationServer
public class OAuth2Configuration extends AuthorizationServerConfigurerAdapter {

}
```

To define a default spring configuration, and enable the current application as an OAuth2 authorization server.

We inherit the class from AuthorizationServerConfigurerAdapter, to configure the details.

``` java
    @Override
    public void configure(ClientDetailsServiceConfigurer clients) throws Exception {
        clients.inMemory()
                .withClient("web_app")
                .scopes("FOO")
                .autoApprove(true)
                .authorities("FOO_READ", "FOO_WRITE")
                .authorizedGrantTypes("implicit","refresh_token", "password", "authorization_code");
    }
```

We assume FOO as resource access identity (so we can check this with #oauth2.hasScope('FOO') to apply client access permission), auto approve for the scope for code authorization and pass the authorities for resource server.

Now we configure the OAuth2 endpoints to adjust the authentication manager (which will represent the web-security users), and JWT token store configuration:

``` java
    @Override
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
        endpoints.tokenStore(tokenStore()).tokenEnhancer(jwtTokenEnhancer()).authenticationManager(authenticationManager);
    }

    @Autowired
    @Qualifier("authenticationManagerBean")
    private AuthenticationManager authenticationManager;

    @Bean
    public TokenStore tokenStore() {
        return new JwtTokenStore(jwtTokenEnhancer());
    }

    @Bean
    protected JwtAccessTokenConverter jwtTokenEnhancer() {
        KeyStoreKeyFactory keyStoreKeyFactory = new KeyStoreKeyFactory(new ClassPathResource("jwt.jks"), "mySecretKey".toCharArray());
        JwtAccessTokenConverter converter = new JwtAccessTokenConverter();
        converter.setKeyPair(keyStoreKeyFactory.getKeyPair("jwt"));
        return converter;
    }
```

We define another configuration for the web security.

``` java
@Configuration
class WebSecurityConfig extends WebSecurityConfigurerAdapter {

    @Override
    @Bean
    public AuthenticationManager    authenticationManagerBean() throws Exception {
        return super.authenticationManagerBean();
    }

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
                .exceptionHandling()
                .authenticationEntryPoint((request, response, authException) -> response.sendError(HttpServletResponse.SC_UNAUTHORIZED))
            .and()
                .authorizeRequests()
                .antMatchers("/**").authenticated()
            .and()
                .httpBasic();
    }

    @Override
    protected void configure(AuthenticationManagerBuilder auth) throws Exception {
        auth.inMemoryAuthentication()
                .withUser("reader")
                .password("reader")
                .authorities("FOO_READ")
                .and()
                .withUser("writer")
                .password("writer")
                .authorities("FOO_READ", "FOO_WRITE");
    }
}
```

Note that there is no "@EnableWebSecurity", because it's automatically applied through @EnableAuthorizationServer.
We also declare the authenticationManagerBean as a bean, which will be injected in the OAuth configuration above. HttpSecurity and user definition is quite straight forward, and can be implemented in various ways like UserDetailsService.

We configure the application to run on port 9999 for now.

### get access tokens

I will show how to get access token directly via username/password. There are other authorization types such as auth code, implicit, client credentials.

To get a token, just

``` sh
$ curl "web_app:@localhost:9999/oauth/token" -d "grant_type=password&username=reader&password=reader"
{"access_token":"eyJhbGciOiJSUzI1NiJ9.eyJleHAiOjE0NTQ0MDA3MzQsInVzZXJfbmFtZSI6InJlYWRlciIsImF1dGhvcml0aWVzIjpbIkZPT19SRUFEIl0sImp0aSI6IjU1MWI4MTY4LTMwZmItNDZlNS1iMzJlLTc4ODRjNjJlNzZlYiIsImNsaWVudF9pZCI6IndlYl9hcHAiLCJzY29wZSI6WyJGT08iXX0.cKcgkLcbBECSWlz5fllb5V0EkfvrIq6RxjId34mNvhifS5bseQD5c8SlsQ_MvLf6unmosIHT_WL9TP56UUPX5TFrQpT09c2RPvnyhKD5PLlrf9o2RAAL5xS1yQqAWoSoNlx73m8cs8xOjIEix3mthNzEDlLYgsBbQci0ZWBCQHwnRE3OW4oykm4YH5X59X-8Juq1enztbdcjcyt4aFQOG7KVstW5M0MN3y3MMD4O9QgsatzBWDL2lPoazhKuYkR9LcoBZrKF_WzQgwolMhK_ousOxLEHNbKoWxOWJPJnayi6NW8o_2SlkTs7ykDh_GEGOSswpMGhkw98DI5dwFcTQg","token_type":"bearer","refresh_token":"eyJhbGciOiJSUzI1NiJ9.eyJ1c2VyX25hbWUiOiJyZWFkZXIiLCJzY29wZSI6WyJGT08iXSwiYXRpIjoiNTUxYjgxNjgtMzBmYi00NmU1LWIzMmUtNzg4NGM2MmU3NmViIiwiZXhwIjoxNDU2OTQ5NTM0LCJhdXRob3JpdGllcyI6WyJGT09fUkVBRCJdLCJqdGkiOiI0MTBlZWNjMS01NTRiLTQ0OGQtOGUyOC1iMGE3NTg5N2JlNzMiLCJjbGllbnRfaWQiOiJ3ZWJfYXBwIn0.Rw5ASYQjsJtPfWMMNIQ1TQA53VAqMSoDze8RHzbdRgXkn_BS-Qc84rTNg5deICL_Qdz6D3OtRL2pXgAkOn6ImCDJGaKcroZscZ1Mpy7lmBbsBf1pOolqOsXbCItOPh7h8CpB41ZipTeq-v_-5LQ7wNqwMTOzW_zL8On7bc0ZLF66PY-HK8BlFYUaiJRdJqP1PjfCh8hmOUMYnX8slQcdVMP4V1m6ZzdVFuhywKi3LD6tzrU-q1s2FEUVIpOCKJ6pKv9ts6tSK_lcjLjFO0rRzjTSdtywKE5Gc1rvC4BJALN_ZOn_uiskzo8IIztDUefZJV5OCAZ41igDUXbJHb1NSA","expires_in":43199,"scope":"FOO","jti":"551b8168-30fb-46e5-b32e-7884c62e76eb"}
```



## implementing the resource server

We generate anouther Spring Boot application with Web starter and take the same gradle dependencies we used for the authorization server before.
Copy the public.cert file into src/main/resources.

First, we have to implement the resource itself:

``` java
@RestController
@RequestMapping("/foo")
public class WebController {

    @RequestMapping(method = RequestMethod.GET)
    public String readFoo() {
        return "read foo " + UUID.randomUUID().toString();
    }

    @RequestMapping(method = RequestMethod.POST)
    public String writeFoo() {
        return "write foo " + UUID.randomUUID().toString();
    }
}
```
This is a simple controller. I use UUID random strings to be sure every response will be unique (for cache things).

Since we use JWT tokens, we have to configure the token store and token converter for JWT.

``` java
@Configuration
public class JwtConfiguration {
    @Autowired
    JwtAccessTokenConverter jwtAccessTokenConverter;


    @Bean
    @Qualifier("tokenStore")
    public TokenStore tokenStore() {
        return new JwtTokenStore(jwtAccessTokenConverter);
    }

    @Bean
    protected JwtAccessTokenConverter jwtTokenEnhancer() {
        JwtAccessTokenConverter converter =  new JwtAccessTokenConverter();
        Resource resource = new ClassPathResource("public.cert");
        String publicKey = null;
        try {
            publicKey = new String(FileCopyUtils.copyToByteArray(resource.getInputStream()));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        converter.setVerifierKey(publicKey);
        return converter;
    }
}
```

Now lets configure the resource server security:

``` java
@Configuration
@EnableResourceServer
public class ResourceServerConfiguration extends ResourceServerConfigurerAdapter{

    @Override
    public void configure(HttpSecurity http) throws Exception {
        http
                .csrf().disable()
                .authorizeRequests()
                .antMatchers("/**").authenticated()
                .antMatchers(HttpMethod.GET, "/foo").hasAuthority("FOO_READ");
                //.antMatchers(HttpMethod.POST, "/foo").hasAuthority("FOO_WRITE");
                //you can implement it like this, but I show method invocation security on write
    }


    @Override
    public void configure(ResourceServerSecurityConfigurer resources) throws Exception {
        resources.resourceId("foo").tokenStore(tokenStore);
    }

    @Autowired
    TokenStore tokenStore;

    @Autowired
    JwtAccessTokenConverter tokenConverter;
}
```

Note I commented the access rule for write requests on foo. I will show how to secure this via method invocation level security.

### adding method security

To enable method security we just create a configuration like this:

``` java
@Configuration
@EnableGlobalMethodSecurity(prePostEnabled = true)
public class GlobalMethodSecurityConfiguration {
}
```

and change the writeFoo method in our rest controller:

``` java
    @PreAuthorize("hasAuthority('FOO_WRITE')")
    @RequestMapping(method = RequestMethod.POST)
    public String writeFoo() {
        return "write foo " + UUID.randomUUID().toString();
    }
```

You may ask why I didn't use "secureEnabled = true" and the @Secured annotation. Sadly, this doesn't work at the moment.


We run this application on port 9090.

### testing

Now copy the access token from our last curl command and create a local variable TOKEN:

``` sh
$ TOKEN=eyJhbGciOiJSUzI1NiJ9.eyJleHAiOjE0NTQ0MDA3MzQsInVzZXJfbmFtZSI6InJlYWRlciIsImF1dGhvcml0aWVzIjpbIkZPT19SRUFEIl0sImp0aSI6IjU1MWI4MTY4LTMwZmItNDZlNS1iMzJlLTc4ODRjNjJlNzZlYiIsImNsaWVudF9pZCI6IndlYl9hcHAiLCJzY29wZSI6WyJGT08iXX0.cKcgkLcbBECSWlz5fllb5V0EkfvrIq6RxjId34mNvhifS5bseQD5c8SlsQ_MvLf6unmosIHT_WL9TP56UUPX5TFrQpT09c2RPvnyhKD5PLlrf9o2RAAL5xS1yQqAWoSoNlx73m8cs8xOjIEix3mthNzEDlLYgsBbQci0ZWBCQHwnRE3OW4oykm4YH5X59X-8Juq1enztbdcjcyt4aFQOG7KVstW5M0MN3y3MMD4O9QgsatzBWDL2lPoazhKuYkR9LcoBZrKF_WzQgwolMhK_ousOxLEHNbKoWxOWJPJnayi6NW8o_2SlkTs7ykDh_GEGOSswpMGhkw98DI5dwFcTQg
```

and peform a call to read the foo resource

``` sh
$ curl -H "Authorization: Bearer $TOKEN" "localhost:9090/foo"
```

and you should get a positive result, while

``` sh
$ curl -XPOST -H "Authorization: Bearer $TOKEN" "localhost:9090/foo"
```

should result in access denied. To get access to write on foo, we must get a token as "writer".


## Conclusion

This should be a very brief introduction into how you can use OAuth2 in spring cloud microservices. If I explained something wrong, please be free to correct me. I am open to any kind of critics :)

The most important is, this sample works so you can try it out and change it in a way you need.
May someone find this article useful :)


Have a great week.
