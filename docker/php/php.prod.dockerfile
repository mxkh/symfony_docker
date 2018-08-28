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
          supervisor \
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
RUN pecl install mcrypt-1.0.1
RUN pecl install imagick

RUN docker-php-ext-enable mcrypt
RUN docker-php-ext-enable imagick

COPY docker/php/php.prod.ini /usr/local/etc/php/conf.d/php.prod.ini

COPY docker/php/php.run.sh /var/php.run.sh
RUN chmod 0777 /var/php.run.sh && chown -R www-data:www-data $INSTALL_DIR

WORKDIR $INSTALL_DIR
ENTRYPOINT "/var/php.run.sh"
