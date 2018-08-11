FROM php:7.2.8-fpm

ARG INSTALL_DIR="/opt"

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install developer dependencies
RUN apt-get update \
      && apt-get install -y -q --no-install-recommends \
          bison \
          libicu-dev \
          libfreetype6-dev \
          libjpeg62-turbo-dev \
          libpng-dev \
          libcurl4-gnutls-dev \
          libbz2-dev \
          libssl-dev \
          libmcrypt-dev \
          libmagickwand-dev \
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

# Install php extensions
RUN docker-php-ext-install pdo_mysql \
      opcache \
      calendar \
      bcmath \
      zip \
      bz2 \
      intl

# Install GD extension
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
RUN docker-php-ext-install gd

# Install PECL extensions
RUN pecl install xdebug mcrypt-1.0.1 imagick
RUN docker-php-ext-enable xdebug mcrypt imagick

# Installing dependencies
COPY . $INSTALL_DIR

COPY docker/xdebug.conf /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
COPY docker/php.dev.ini /usr/local/etc/php/conf.d/php.dev.ini
COPY docker/php-debug /usr/local/bin/phpxdbg
COPY docker/sf-debug /usr/local/bin/sfdbg
RUN chmod 755 /usr/local/bin/phpxdbg && chmod 755 /usr/local/bin/sfdbg

WORKDIR $INSTALL_DIR
