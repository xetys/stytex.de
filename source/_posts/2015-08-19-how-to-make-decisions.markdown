---
layout: post
title: "How to make decisions?"
date: 2015-08-19 18:19:40 +0100
comments: true
categories: [fun, development, javascript]
---


I was stucked on the question: "What do I going todo now? SW:ToR or some music creation?".



I just couldn't decide. But I assumed, I had wish to play some SW:ToR PvPs to about 70%, and I would like to drop a 7/3 coin instead of a classic 1/1 coin.



A bit of quick JavaScript helped me through:


``` javascript
decide = function (x) { return Math.random() * 100 < x; }
```

This should return true with a probality of x %....



I was quite sure, the random number must be less then x, but did some tests to prove it:


``` javascript
n=100;l = []; for(i=0;i<n;i++) l[i] = decide(70); s=0; for(i=0;i<n;i++) s+=l[i]; s / n
=> 0.64
```
``` javascript
n=1000;l = []; for(i=0;i<n;i++) l[i] = decide(70); s=0; for(i=0;i<n;i++) s+=l[i]; s / n
=> 0.716
n=1000;l = []; for(i=0;i<n;i++) l[i] = decide(70); s=0; for(i=0;i<n;i++) s+=l[i]; s / n
=> 0.685
```

and the big ones :D


``` javascript
n=10000;l = []; for(i=0;i<n;i++) l[i] = decide(70); s=0; for(i=0;i<n;i++) s+=l[i]; s / n
=> 0.7039
n=10000;l = []; for(i=0;i<n;i++) l[i] = decide(70); s=0; for(i=0;i<n;i++) s+=l[i]; s / n
=> 0.6986
n=10000;l = []; for(i=0;i<n;i++) l[i] = decide(70); s=0; for(i=0;i<n;i++) s+=l[i]; s / n
=> 0.6971
```

And for fairness, my very first result of decide(70) is qualified for my final decision. Happily, it was


``` javascript
decide = function (x) { return Math.random() * 100 < x; }
decide(x)
decide(70)
true
```

:D





P.S.:

You can sometimes take a look at my [twitch channel](https://twitch.tv/xetys)