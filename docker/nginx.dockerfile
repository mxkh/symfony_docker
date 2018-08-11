FROM nginx:1.15

ARG INSTALL_DIR="/opt"

COPY docker/nginx.dev.conf /etc/nginx/nginx.conf

# Installing dependencies
COPY . $INSTALL_DIR
COPY docker/nginx.run.sh /var
RUN chmod 0777 /var/nginx.run.sh

WORKDIR $INSTALL_DIR

ENTRYPOINT "/var/nginx.run.sh"
