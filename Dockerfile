FROM ruby:2.4.10

## 1. Image metadata ##
 LABEL maintainer="stuart@stuartellis.name" \
    version="0.2.1" \
    description="Image for running the backup Rubygem"

## 2. Add operating system packages ##

# Dependencies for developing and running Backup
#  * The Nokogiri gem requires libxml2
#  * The unf_ext gem requires the g++ compiler to build
ENV APP_DEPS bsdtar ca-certificates curl g++ git \
    libxml2 libxslt1.1 libyaml-0-2 openssl

RUN apt-get update && apt-get install -y --no-install-recommends $APP_DEPS

## 3. Set working directory ##

ENV APP_HOME /usr/src/backup
WORKDIR $APP_HOME
