# Local development with Docker
I spent a lot of time in order to configure comfortable development on the local environment using docker
with all development tools and I want to share this manual with you.

In this example, I'll show you my local folder configuration with external
containers. External containers very useful when you have a lot of projects you work on.

All of my projects stores under **~/PhpstormProjects** folder with next structure

- **~/PhpstormProjects/docker/mysql** - path to mysql docker external container
- **~/PhpstormProjects/docker/nginx-proxy** - path to nginx-proxy docker external container
- **~/PhpstormProjects/docker/symfony_docker** - path to example project

Content

- Problem
- Docker sync
- External containers
- Sync stack
- Containers configuration

## Problem
As you know, docker is the excellent tool for an application virtualization, that makes him a good for a local development. You don't have to care about application configuration, just run `docker-compose up` and your application is ready for a development.

This sounds cool, but in fact, Docker works fine only on Linux systems, on Windows and MacOS Docker has an issue with file system performance. You can read more about this issue on [GitHub](https://github.com/docker/for-mac/issues/77).

[Docker-sync](http://docker-sync.io) was created for solving this issue. I highly recommend to read about this library, for a better understanding of what will happen in the next steps of this How-To.

In the following chapters, we will configure a basic Symfony application from scratch.

### Docker sync
So, first, we need to install docker-sync

`gem install docker-sync` - more details about installation on your system you can read in the official [Wiki](https://github.com/EugenMayer/docker-sync/wiki/1.-Installation) page.

Next, we need to install on the host machine a composer or other tools for a local development such as NPM, etc.

*I will omit installation guide of this tools, you can use official documentation of tool which you need.*

Of course, you can install all of this development tools inside the docker container and don't pollute your host machine, but, we have some constraints. All folders like `vendor` for PHP packages or `npm modules` will be synced by rsync.

Unfortunately, rsync don't support two-way sync, if we create a file inside the container it won't be synced to the host machine. So we need to install all the packages from the host machine for a correct sync. All other folders could be synced by unison and osxfs, docker-sync will automatically combine those sync types depends on the situation.

## External containers

OK, we already installed docker-sync and know some slick moments about sync, what's next?

We need to configure external containers for proxy and persistent database

*Hint: These containers will be as external, you don't need to create those compose files inside your project.*

**Configure proxy**

First thing, we need to configure domains for our local projects instead of ip and port for a more comfortable work. As you know, `/etc/hosts` file doesn't support ports. We need to configure nginx for a proxy. Too hard? Nope! [Nginx-proxy](https://github.com/jwilder/nginx-proxy) will help!

- Create `docker-compose.yml` file with the following content

      version: "3"
      services:
          nginx-proxy:
              image: jwilder/nginx-proxy
              ports:
              - "80:80"
              volumes:
              - /var/run/docker.sock:/tmp/docker.sock:ro

- Run `docker-compose up -d`

That's all! This container automatically create proxy for our future projects, all we need to do, add env variable inside the project compose file like an `VIRTUAL_HOST=symfony-docker.local`

Awesome, right?  😎

**Configure persistent database**

The second thing - database, we must create one persistent storage for all projects. I will use the latest version of MariaDB.

- We must to create volume `docker volume create mysql-data`
- Create `docker-compose.yml` file with the following content

      version: "3"
      services:
          db:
              image: mariadb:10.3
              ports:
              - "3306:3306"
              volumes:
              - mysql-data:/var/lib/mysql
              environment:
                  MYSQL_ROOT_PASSWORD: 123
                  MYSQL_USER: root
                  MYSQL_PASSWORD: 123
      volumes:
          mysql-data:
              external: true

- Run `docker-compose up -d`

Excellent! Now we have an external containers that will be used for future projects.

**Summary of this topic:**

- We automated and simplified the process of adding a proxy for domains
- Have created persistent database storage that can be used for multiple projects. That's help us to solve some issues like
  - Saving the resources of host machine - all projects stores their data in one container, but if you want, you can create a database container special for the project
  - Share database - if you have two projects but they use one database you can easily connect one database to the two, or more, projects
  - Persistent - if you reboot your computer or laptop, don't worry, all your data will be saved on your host machine, just run container again
  - Easy to connect from GUI - no ssh tunnels, just run `docker ps -a` and copy\paste ip and port of container and fill it in your client

## Docker sync stack

In this chapter we will consider configuration of docker sync stack.

First, we need to create a file where we will store environment variables

`touch web-variables.env`

And fill it with the following content

    APP_MODE=dev
    NGINX_APP_MODE=dev
    NGINX_APP_BOOTSTRAP=app_dev.php
    VIRTUAL_HOST=symfony-docker.local

Next things, we should create a docker compose files.

- `docker-compose.yml` - main file that can be used in production

      version: '3'
      services:
        php:
          build:
            context: .
            dockerfile: docker/php.dockerfile
        nginx:
          build:
            context: .
            dockerfile: docker/nginx.dockerfile
          env_file:
            - web-variables.env

- `dokcer-compose-dev.yml` - for development mode

      version: "3"
      services:
          php:
              external_links:
              - mysql_db_1:db
              networks:
              - default
              - mysql_default
              volumes:
              - reporting-api-vendor-sync:/opt/vendor:nocopy
              - reporting-api-app-sync:/opt:nocopy
              environment:
                  XDEBUG_CONFIG: "remote_host=192.168.31.231"
                  PHP_IDE_CONFIG: "serverName=docker"
          nginx:
              external_links:
              - nginx-proxy_nginx-proxy_1:nginx-proxy
              links:
              - php
              depends_on:
              - php
              networks:
              - default
              - nginx-proxy_default
              expose:
              - 80
              volumes:
              - reporting-api-vendor-sync:/opt/vendor:nocopy
              - reporting-api-app-sync:/opt:nocopy
      networks:
          mysql_default:
              external: true
          nginx-proxy_default:
              external: true
      volumes:
          reporting-api-vendor-sync:
              external: true
          reporting-api-app-sync:
              external: true
          mysql-data:
              external: true

- `docker-sync.yml` - contains folders sync information

      options:
          compose-file-path: './docker-compose.yml'
          compose-dev-file-path: './docker-compose-dev.yml'
          verbose: true
      
      version: '2'
      syncs:
          reporting-api-vendor-sync:
              src: './vendor/'
              sync_strategy: 'rsync'
              sync_args: '--delete'
              sync_host_port: 10874
              sync_excludes: ["bin/"]
              notify_terminal: true
          reporting-api-app-sync:
              src: './'
              sync_host_port: 10877
              sync_userid: '33'
              sync_args: '-prefer newer -copyonconflict'
              sync_excludes: ["var/cache", "var/logs", "var/sessions", "vendor", ".idea", ".git"]
              notify_terminal: true

It is all we need to do, but PHP and NGINX containers are not configured, hmm, OK! I will describe the container's configuration in the next chapter.

## Configure containers

As we remember, we still need to configure PHP and NGINX containers. This is Symfony application, so wee need to configure containers in accordance with the requirements of this framework. Let's start!

**PHP container**

We will use official Docker PHP & NGINX containers but with custom configuration

- `mkdir docker && cd docker && touch xdebug.conf`

      zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20170718/xdebug.so
      [XDEBUG]
      xdebug.remote_enable=on
      xdebug.remote_autostart=off
      xdebug.remote_connect_back=off
      xdebug.remote_handler=dbgp
      xdebug.profiler_enable=0
      xdebug.profiler_output_dir="/opt/web"
      xdebug.remote_port=9000

- `touch php.dev.ini`

      memory_limit = 512M
      upload_max_filesize = 512M
      post_max_size = 512M
      max_execution_time = 600

- `touch php-debug` - helper for debug in CLI mode

      #!/bin/sh
      
      php -d xdebug.remote_host=192.168.31.231 -d xdebug.remote_autostart=1 $@

- `touch sf-debug` - wrapper over the php-debug file for symfony

      #!/bin/sh
      
      php -d xdebug.remote_host=192.168.31.231 -d xdebug.remote_autostart=1 bin/console $@

- `touch php.dockerfile`

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

**NGINX container**

- `touch nginx.dev.conf`

      user www-data;
      worker_processes 4;
      worker_rlimit_nofile 65535;
      pid /var/run/nginx.pid;
      
      events {
          use epoll;
          worker_connections 1024;
          multi_accept on;
      }
      
      http {
          tcp_nopush on;
          tcp_nodelay on;
          keepalive_timeout 600;
          keepalive_requests 600;
          types_hash_max_size 2048;
          # server_tokens off;
      
          proxy_connect_timeout 600s;
          proxy_read_timeout 600;
          server_names_hash_bucket_size 64;
          client_max_body_size 150M;
      
          include       /etc/nginx/mime.types;
          default_type  application/octet-stream;
      
          log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                            '$status $body_bytes_sent "$http_referer" '
                            '"$http_user_agent" "$http_x_forwarded_for"';
      
          sendfile        on;
      
          gzip  on;
          gzip_http_version 1.1;
          gzip_vary on;
          gzip_comp_level 6;
          gzip_proxied any;
          gzip_types text/plain text/css application/json application/javascript application/x-javascript text/javascript text/xml application/xml application/rss+xml application/atom+xml application/rdf+xml;
      
          # make sure gzip does not lose large gzipped js or css files
          # see http://blog.leetsoft.com/2007/07/25/nginx-gzip-ssl.html
          gzip_buffers 16 8k;
      
          # Disable gzip for certain browsers.
          gzip_disable âMSIE [1-6].(?!.*SV1)â;
      
          server {
              listen 80 default_server;
              server_name _;
      
              set_real_ip_from  0.0.0.0/0;
      
              real_ip_header    X-Forwarded-For;
              real_ip_recursive on;
      
              proxy_buffers 62 1024k;
              proxy_busy_buffers_size 12048k;
              proxy_buffer_size 10048k;
              proxy_read_timeout 720;
      
              access_log /var/log/nginx/access.log;
              error_log /var/log/nginx/error.log notice;
      
              set $www_root /opt/web;
              set $bootstrap ##NGINX_APP_BOOTSTRAP##;
      
              root $www_root;
              charset utf-8;
              index index.html $bootstrap;
      
              add_header 'Access-Control-Allow-Origin' $http_origin always;
              add_header 'Access-Control-Allow-Methods' 'POST, GET, PUT, DELETE' always;
              add_header 'Access-Control-Allow-Credentials' 'true' always;
              add_header 'Access-Control-Expose-Headers' 'X-Api-Token, X-Total-Count, X-Page, X-Page-Size, X-Http-Method-Override' always;
      
              location ~ /\. {
                  deny all;
              }
      
              location ~ ^(.+\.(js|css|jpg|jpeg|gif|png|ico|swf|mp3|html|eot|woff2|map|woff|ttf|svg|zip|pdf|apk|json))$ {
                  access_log off;
                  expires max;
                  try_files $uri /$bootstrap?$args;
              }
      
              location = /favicon.ico {
                  log_not_found off;
                  access_log off;
              }
      
              location = /robots.txt {
                  allow all;
                  log_not_found off;
                  access_log off;
              }
      
              location ~ (/\.ht|\.git) {
                  deny all;
              }
      
              location ~ ^/(.+)/$ {
                  return 301 /$1$is_args$args;
              }
      
              location ~ .* {
                  set $fsn /$bootstrap;
      
                  if (-f $document_root$fastcgi_script_name){
                      set $fsn $fastcgi_script_name;
                  }
      
                  fastcgi_pass php:9000;
                  include fastcgi_params;
      
                  fastcgi_param   SCRIPT_FILENAME  $realpath_root$fsn;
                  fastcgi_param   PATH_INFO        $fastcgi_path_info;
                  fastcgi_param   PATH_TRANSLATED  $realpath_root$fsn;
                  fastcgi_param   DOCUMENT_ROOT    $realpath_root;
                  ## fastcgi_param   BUILD_NUMBER     ##BUILD_NUMBER##;
              }
        }
      }

- `touch nginx.run.sh`

      #!/bin/bash
      
      export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
      
      echo "Setting nginx config for env..."
      : "${NGINX_APP_MODE:?Need to set NGINX_APP_MODE non-empty}"
      : "${NGINX_APP_BOOTSTRAP:?Need to set NGINX_APP_BOOTSTRAP non-empty}"
      
      sed -i.bak "s/##NGINX_APP_BOOTSTRAP##/${NGINX_APP_BOOTSTRAP}/g" /etc/nginx/nginx.conf
      
      echo "Check nginx config..."
      nginx -t
      
      echo "Starting nginx..."
      nginx
      
      tail -F "/var/log/nginx/access.log"

- `touch nginx.dockerfile`

      FROM nginx:1.15
      
      ARG INSTALL_DIR="/opt"
      
      COPY docker/nginx.dev.conf /etc/nginx/nginx.conf
      
      # Installing dependencies
      COPY . $INSTALL_DIR
      COPY docker/nginx.run.sh /var
      RUN chmod 0777 /var/nginx.run.sh
      
      WORKDIR $INSTALL_DIR
      
      ENTRYPOINT "/var/nginx.run.sh"

Looks good! Now we finally can start our stack!

## Run stack!

- `composer install`
- `docker-sync-stack start` and wait, it will create containers for syncing data between our host machine and project containers, created PHP and NGINX containers.

*Don't forget to add domain name into the `/etc/hosts` file*

    ### Docker
    127.0.0.1 symfony-docker.local

If all is good we can type `[http://symfony-docker.local](http://symfony-docker.local)` in browser address field and see the Symfony welcome page.

### Configure xDebug in PHPStorm

Add next lines to your php service in docker-compose-dev.yml
```
environment:
    XDEBUG_CONFIG: "remote_host=192.168.56.1"
    PHP_IDE_CONFIG: "serverName=docker"
```

Where remote_host equals your local ip address and serverName equals your server name in PHPStorm

For getting local ip address use next command (macOS)
`ifconfig | grep 'inet 192'`

**Create php server in PHPStorm**

Open preferences and navigate to
`Languages & Frameworks > PHP > Servers` and create your server

![PHP xDebug server](https://monosnap.com/image/GohOPdpbFKsrmffjMP6yXfWnQFZT2D.png)

**Create configuration**

![Configuration](https://monosnap.com/image/J25i63NMGtXt4wD02klLEBsEjFXLUQ.png)

**Create PHP remote debug**

![PHP Remote Debug](https://monosnap.com/image/kmoUyTuHDrJSbiKg0piJLlfDb62Qvh.png)

In Server choose already created server from previous steps

Check xDebug and add breakpoint in controller

![Listen xDebug connections](https://monosnap.com/image/ndEJk3HzqooHCCtsb8PCRt03zmQMbO.png)

Debug it!
`curl "http://symfony-docker.local?XDEBUG_SESSION_START=PHPSTORM"`

if everything is OK, the PHPStorm window will opening at the specified breakpoint

### CLI debugging
In our docker stack, we copy two interesting files into the PHP container, `php-debug` aka `phpxdbg` and `sf-debug` aka `sfdbg`.

These files can helps you to debug your PHP code in CLI mode.
For example, you made a new Symfony command, let's say `my:awesome:command` and you want to debug code by xDebug
creating a breakpoint in PHPStorm, just run command `sfdbg my:awesome:command` and the PHPStorm window
will opening at the specified breakpoint.

That's all, enjoy! 🖤

# FIN
_I hope this guide helps you better understand docker and save time!_
