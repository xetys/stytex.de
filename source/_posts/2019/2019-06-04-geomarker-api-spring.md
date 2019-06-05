---
layout: post
title: "Building a image endpoint for geo markers in Spring Boot"
date: 2019-06-04 23:06:09 +0000
comments: true
categories:
 - java
 - spring boot
 - microservices
 - development
---


## Introduction

{% img right /images/marker-012345-offline-10.png 120 160 'geo marker' %}
Today we had a funny task for our company internal Google Maps powered system. We should show simple geo markers on a map, having specific colors. So our designer created markers for three colors. However, we needed markers for a lot of more colors, which an admin can configure. So should we let our designer draw a geo marker every time an admin adds new colors?

We found a more elegant way how to solve that little problem:

### Idea

We need an API which produces an image containing a geo marker. A basic idea would be to control colors using GET parameters, such as `marker.png?color=ff0000`, or include the color in the image name, like `marker-ff0000.png`.
Another task was, to have the color of the inner dot of the marker stating 'online', 'offline', or something different. For example green for 'online' and red for 'offline'.

So we built a Spring Boot application with a single controller action called `marker-{fillColor}-{state}-{scale}.png`, which draws and outputs an image. A few notes on the convention:

* we don't use a leading dash (#) in `fillColor`, as that is a URI specific char
* `state` can be 'online' for green, 'offline' for red, or yellow for all other values
* scale is an integer factor which is applied to all sizes. The default image height should be 30x40.

## Implementation

First, we use [start.spring.io](https://start.spring.io) (or the corresponding project initializer in IntelliJ) to generate a simple [Spring Boot Application](https://spring.io/projects/spring-boot)

### Returning images in Spring Boot

Usually we can specify a return type of an controller action like this

``` java
@GetMapping
public String greet(@PathVariable String greeter) {
  return "Hello, " + greeter;
}
```

However, given the case, we want to return a PNG image, we don't return anything, but write our content to the output buffer stream of our response by:

``` java
@GetMapping(value = "image.png", produces = MediaType.IMAGE_PNG_VALUE)
public void image(HttpServletResponse response) {
  // ...
  StreamUtils.copy(imgFile.getInputStream(), response.getOutputStream());
}
```


### Draw graphics in Java

For this simple task, we didn't use any third party image library, but used only Java native tools like `java.awt.image.BufferedImage` and `java.awt.Graphics2D`.

Using `Graphics2D`, we built our geo marker generator using the following controller action:

``` java
    @GetMapping(value = "/marker-{fillColor}-{state}-{scale}.png", produces = MediaType.IMAGE_PNG_VALUE)
    public void drawMarker(
            @PathVariable String fillColor,
            @PathVariable String state,
            @PathVariable Integer scale,
            HttpServletResponse response
    ) throws IOException {
        BufferedImage bufferedImage = new BufferedImage(30 * scale, 40 * scale, BufferedImage.TYPE_INT_ARGB);

        Graphics2D g2d = bufferedImage.createGraphics();

        // set transparent background
        g2d.setComposite(AlphaComposite.Clear);
        g2d.fillRect(0, 0, 30 * scale, 40 * scale);
        g2d.setComposite(AlphaComposite.Src);

        // draw marker body
        g2d.setColor(parseColor(fillColor));
        g2d.fillOval(0, 0, 30 * scale, 30 * scale);

        QuadCurve2D q = new QuadCurve2D.Float();
        q.setCurve(1 * scale, 20 * scale, 15 * scale, 60 * scale, 29 * scale, 20 * scale);
        g2d.fill(q);

        // draw outer white circle as border
        g2d.setColor(Color.white);
        g2d.fillOval(7 * scale, 7 * scale, 16 * scale, 16 * scale);

        // draw inner state circle
        g2d.setColor(getColorByState(state));
        g2d.fillOval(10 * scale, 10 * scale, 10 * scale, 10 * scale);


        // Disposes of this graphics context and releases any system resources that it is using.
        g2d.dispose();

        // set content type and write image to output stream
        response.setContentType(MediaType.IMAGE_PNG_VALUE);
        ImageIO.write(bufferedImage, "png", response.getOutputStream());
    }

    private Color getColorByState(String state) {
        switch (state) {
            case "online":
                return Color.green;
            case "offline":
                return Color.red;
            default:
                return Color.yellow;
        }
    }

    private Color parseColor(String hex) {
        return new Color(
                Integer.valueOf(hex.substring(0, 2), 16),
                Integer.valueOf(hex.substring(2, 4), 16),
                Integer.valueOf(hex.substring(4, 6), 16));
    }

```

We used a simple quadratic curve to make a round bottom corner. The resulting API can now produce images like these:

calling `marker-012345-online.png` will produce
{% img center /images/marker-012345-online-10.png 300 400 'geo marker' %}

calling `marker-ff5555-online-10.png` will produce
{% img center /images/marker-ff5555-online-10.png 300 400 'geo marker' %}


## Conclusion

This is my first article since a very long time, in particular about Java and Spring Boot. It was a funny little project on this very hot day at work (33 °C are not easy!!), and I hope someone might find this useful.

Cheers

