FROM debian:bookworm

RUN apt-get update && apt-get install -y curl ca-certificates tar && rm -rf /var/lib/apt/lists/*

RUN curl -L https://github.com/portainer/portainer/releases/download/2.21.5/portainer-2.21.5-linux-amd64.tar.gz \
    -o /tmp/portainer.tar.gz && tar -xzf /tmp/portainer.tar.gz -C /opt && rm /tmp/portainer.tar.gz

COPY ./tools/init_portainer.sh /usr/local/bin/init_portainer.sh

RUN chmod +x /usr/local/bin/init_portainer.sh

ENTRYPOINT ["init_portainer.sh"]
