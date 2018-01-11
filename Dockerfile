FROM ruby:1.9.3

ADD / /blog/
WORKDIR /blog
RUN apt-get update && apt-get install -y nodejs && bundle install

EXPOSE 4000
