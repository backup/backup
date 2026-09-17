FROM ruby:3.2-bookworm

## 1. Image metadata ##
 LABEL maintainer="stuart@stuartellis.name" \
    version="0.2.1" \
    description="Image for running the backup Rubygem"

## 2. Add operating system packages ##

# Dependencies for developing and running Backup
#  * Some legacy notifier dependencies contain native extensions.
ENV APP_DEPS build-essential ca-certificates curl git libarchive-tools openssl

RUN apt-get update && apt-get install -y --no-install-recommends $APP_DEPS

## 3. Set working directory ##

ENV APP_HOME /usr/src/backup
WORKDIR $APP_HOME
