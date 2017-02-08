FROM ruby:2.3-slim

# Install basic packages
RUN apt-get update && apt-get install -y build-essential wget nodejs git libpq-dev 

ENV app /app
RUN mkdir $app
WORKDIR $app

ENV BUNDLE_PATH /box

ADD . $app
