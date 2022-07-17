FROM ruby:2.6-bullseye

## 1. Image metadata ##
LABEL maintainer="engineering@zenjoy.be" \
  version="0.0.1" \
  description="Image for running the backup Rubygem with Proxmox Backup Server"

## 2. Add operating system packages ##

# Dependencies for developing and running Backup
#  * The Nokogiri gem requires libxml2
#  * The unf_ext gem requires the g++ compiler to build
ENV APP_DEPS ca-certificates curl g++ git libjemalloc-dev gcc make redis-tools \
  libxml2 libxslt1.1 libyaml-0-2 openssl proxmox-backup-client

RUN wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
RUN echo "deb http://download.proxmox.com/debian/pbs-client bullseye main" > /etc/apt/sources.list.d/pbs-client.list

RUN apt-get update && apt-get install -y $APP_DEPS

RUN wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-debian11-x86_64-100.5.3.deb -O /tmp/mongodb-database-tools-debian11-x86_64-100.5.3.deb && \
  dpkg -i /tmp/mongodb-database-tools-debian11-x86_64-100.5.3.deb && \
  rm /tmp/mongodb-database-tools-debian11-x86_64-100.5.3.deb

## 3. Set working directory ##
COPY . /usr/src/backup
ENV APP_HOME /usr/src/backup
WORKDIR $APP_HOME

RUN gem install bundler mongo redis
RUN bundle install

# RUN cd /tmp && wget http://download.redis.io/redis-stable.tar.gz -O /tmp/redis-stable.tar.gz && \
#   tar xvzf redis-stable.tar.gz && \
#   cd redis-stable && \
#   make && \
#   cp src/redis-cli /usr/local/bin/ && \
#   chmod 755 /usr/local/bin/redis-cli

ENV PATH="/usr/src/backup/bin:/usr/local/bin/:${PATH}"
