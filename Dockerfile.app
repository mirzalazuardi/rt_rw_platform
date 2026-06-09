# syntax=docker/dockerfile:1

FROM ruby:3.3-slim AS base

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

FROM base AS builder
COPY app/Gemfile app/Gemfile.lock ./
RUN bundle install --deployment --without test

FROM base
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY app/ .

EXPOSE 9292
CMD ["bundle", "exec", "rackup", "-p", "9292", "-o", "0.0.0.0"]
