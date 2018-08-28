FROM nginx:1.15

ARG INSTALL_DIR="/opt"

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install developer dependencies
RUN apt-get update \
      && apt-get install -y -q --no-install-recommends \
          bison \
          apt-transport-https \
          build-essential \
          ca-certificates \
          curl \
          python \
          rsync \
          cron \
          wget \
          ssh-import-id \
          locales \
          software-properties-common \
          zlib1g-dev \
          haproxy \
          telnet \
      && rm -rf /var/lib/apt/lists/*

COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Installing dependencies
COPY docker/nginx/nginx.run.sh /var
RUN chmod 0777 /var/nginx.run.sh

WORKDIR $INSTALL_DIR

ENTRYPOINT "/var/nginx.run.sh"
