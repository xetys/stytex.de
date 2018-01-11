FROM ruby:1.9.3

ADD / /blog/
WORKDIR /blog
RUN apt-get update && apt-get install -y nodejs locales && bundle install
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen en_US.UTF-8 && echo 'LANG="en_US.UTF-8"' >> /etc/default/locale && update-locale en_US.UTF-8

EXPOSE 4000
