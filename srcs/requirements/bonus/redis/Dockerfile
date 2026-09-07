FROM debian:bookworm

RUN apt-get update && apt-get install -y redis-server && rm -rf /var/lib/apt/lists/*

COPY ./tools/init_redis.sh /usr/local/bin/init_redis.sh

RUN chmod +x /usr/local/bin/init_redis.sh

ENTRYPOINT ["init_redis.sh"]