FROM --platform=$BUILDPLATFORM alpine:latest

ARG TARGETPLATFORM
ARG BUILDPLATFORM

LABEL maintainer="fr3akyphantom <rokibhasansagar2014@outlook.com>"

ENV LANG=C.UTF-8

RUN set -xe \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

RUN apk add --no-cache --purge -uU bash \
  && rm -rf /var/cache/apk/* /tmp/*
