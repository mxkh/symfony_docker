FROM nginx:1.15

ARG INSTALL_DIR="/opt"

COPY docker/nginx.conf /etc/nginx/nginx.conf

# Installing dependencies
COPY . $INSTALL_DIR
COPY docker/nginx.run.sh $INSTALL_DIR
RUN chmod 0777 /opt/nginx.run.sh

WORKDIR $INSTALL_DIR

ENTRYPOINT "/opt/nginx.run.sh"
