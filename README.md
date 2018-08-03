Docker + Docker-Sync + NGINX + PHP7.2-FPM + xDEBUG + Symfony example
========================
I spent a lot of time in order to configure performancive and comfortable development on the local environment using docker and
with all development tools and I want to share this manual with you.

Problem
-------
If you know, docker for mac has performance problem with OSXFS filesystem.
You can find more about this issue on [GitHub](https://github.com/docker/for-mac/issues/77).

In order to solve this problem, it was created [docker-sync](http://docker-sync.io/).
_I highly recommend reading about docker-sync, for a better understanding of what will happen in the next steps of this How-To_

Configure project from scratch
------------------------------
In this example, I'll show you my local docker ecosystem configuration with external
containers. External containers very useful when you have a lot of projects you work on.

All of my projects stores under **~/PhpstormProjects** folder with next structure

- **~/PhpstormProjects/docker/mysql** - path to mysql docker external container
- **~/PhpstormProjects/docker/nginx-proxy** - path to nginx-proxy docker external container
- **~/PhpstormProjects/docker/symfony_docker** - path to example project

###Configuration steps
**Install docker-sync**

`gem install docker-sync` more details in [documentation](https://github.com/EugenMayer/docker-sync/wiki/1.-Installation)

**Install composer**

For macOS just run `brew install composer` for other OS follow official documentation.

**Install symfony project** 

`composer create-project symfony/framework-standard-edition symfony_docker`

**Install php packages**
`composer install`

**Prepare mariadb container**
- Create docker-compose file `touch ~/PhpstormProjects/docker/mysql/docker-composer.yml`
and add next lines
```
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
```
- Create external volume `docker volume create mysql-data` for data persistence
- Create and run container by `docker-compose up -d`

**Prepare nginx-proxy container**
- Create docker-compose file `touch ~/PhpstormProjects/docker/nginx-proxy/docker-composer.yml`
and add next lines
```
version: "3"
services:
    nginx-proxy:
        image: jwilder/nginx-proxy
        ports:
        - "80:80"
        volumes:
        - /var/run/docker.sock:/tmp/docker.sock:ro
```
- Create and run container by `docker-compose up -d`

Now you have two detached containers, check it by

`docker ps -a`

You will see something like that
```
d168c6ab7dbb        jwilder/nginx-proxy               "/app/docker-entrypo…"    24 hours ago        Up 24 hours                   0.0.0.0:80->80/tcp       nginx-proxy_nginx-proxy_1
5e29e93963a1        mariadb:10.3                      "docker-entrypoint.s…"    40 hours ago        Up 40 hours                   0.0.0.0:3306->3306/tcp   mysql_db_1
```

**Create compose files for project**
- `touch ~/PhpstormProjects/docker/symfony_docker/docker-composer.yml`
- `touch ~/PhpstormProjects/docker/symfony_docker/docker-composer-dev.yml`

You can find content of this compose files in this project

**Create docker-sync file**
- `touch ~/PhpstormProjects/docker/symfony_docker/docker-sync.yml`

You can find content of docker-sync file in this project

**Create docker folder with script and config files**
- `mkdir ~/PhpstormProjects/docker/symfony_docker/docker`
- `touch ~/PhpstormProjects/docker/symfony_docker/docker/nginx.conf`
- `touch ~/PhpstormProjects/docker/symfony_docker/docker/nginx.dockerfile`
- `touch ~/PhpstormProjects/docker/symfony_docker/docker/nginx.run.sh`
- `touch ~/PhpstormProjects/docker/symfony_docker/docker/php.dockerfile`
- `touch ~/PhpstormProjects/docker/symfony_docker/docker/xdebug.conf`

You can find content of this files in this project under the docker folder

###Configure xDebug in PHPStorm

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

Create PHP remote debug

![PHP Remote Debug](https://monosnap.com/image/kmoUyTuHDrJSbiKg0piJLlfDb62Qvh.png)

In Server choose already created server from previous steps

Check xDebug and add breakpoint in controller

![Listen xDebug connections](https://monosnap.com/image/ndEJk3HzqooHCCtsb8PCRt03zmQMbO.png)

**Create and build our docker stack**
`docker-sync-stack start`

wait a bit and run this command
`curl "http://symfony-docker.local?XDEBUG_SESSION_START=PHPSTORM"`

if everything is OK, the PHPStorm window will opening at the specified breakpoint


FIN 
===
