FROM ruby:2.3.3

## 1. Image metadata ##

MAINTAINER Tom de Bruijn, tom@tomdebruijn.com
LABEL version="0.1.0" \
    description="Image for running the backup Rubygem"

## 2. Add operating system packages ##

# Dependencies for developing and running Backup
#  * The Nokogiri gem requires libxml2
#  * The unf_ext gem requires the g++ compiler to build
ENV APP_DEPS ca-certificates curl g++ git \
    libxml2 libxslt1.1 libyaml-0-2 openssl \
    libldap2-dev ldap-utils \
    mongodb-clients \
    mysql-client-5.5 libmysqlclient-dev \
    postgresql-client-9.4 redis-tools \
    libsqlite3-dev sqlite3

RUN apt-get update && apt-get install -y --no-install-recommends $APP_DEPS

## 3. Set working directory ##

ENV APP_HOME /usr/src/backup
WORKDIR $APP_HOME

## 4. Add Ruby gem packages ##

COPY Gemfile* $APP_HOME/
RUN bundle config build.nokogiri --use-system-libraries && \
    bundle install
