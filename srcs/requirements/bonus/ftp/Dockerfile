FROM debian:bookworm

RUN apt-get update && apt-get install -y vsftpd && rm -rf /var/lib/apt/lists/*

COPY ./tools/init_ftp.sh /usr/local/bin/init_ftp.sh

RUN chmod +x /usr/local/bin/init_ftp.sh

ENTRYPOINT ["init_ftp.sh"]