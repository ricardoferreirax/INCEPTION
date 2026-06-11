# NGINX Dockerfile

## Dockerfile

```Dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*

COPY ./tools/init_nginx.sh /usr/local/bin/init_nginx.sh

RUN chmod +x /usr/local/bin/init_nginx.sh

EXPOSE 443

ENTRYPOINT ["init_nginx.sh"]
```

---

# Introduction

This Dockerfile builds the custom NGINX image used by the NGINX service in the Inception project.

NGINX is the public entry point of the whole infrastructure. This means that it is the first service contacted when a user opens the website in a browser.

For example, when the user opens ``https://rmedeiro.42.fr``, the browser does not connect directly to WordPress. The browser also does not connect directly to MariaDB. The browser connects to NGINX. This is important because, in the Inception architecture, only one service should be publicly exposed to the host machine: that service is NGINX.

WordPress and MariaDB are internal services. They communicate through the Docker network, but they should not be directly accessible from outside. NGINX is responsible for:

* receiving HTTPS requests from the browser;
* handling TLS/SSL encryption;
* using the SSL certificate and private key;
* serving static files when possible;
* forwarding PHP requests to WordPress/PHP-FPM;
* returning the final response to the browser.

The complete request flow is:

> Browser ---- HTTPS request on port 443---> NGINX ----- FastCGI request to wordpress:9000 ---> WordPress / PHP-FPM ---- SQL queries to mariadb:3306 ----> MariaDB

Each container has a specific responsibility.

```text
NGINX
    receives public HTTPS traffic and routes requests

WordPress
    executes PHP code and generates dynamic pages

MariaDB
    stores persistent website data
```

NGINX does not execute PHP code itself.

NGINX does not store WordPress posts, users, comments or settings.

NGINX does not manage the database.

Its main role is to act as the web server, HTTPS endpoint and gateway to the WordPress service.

---

# What Is NGINX?

NGINX is a web server. A web server is a software that receives requests from clients, usually browsers, and returns responses.

In a normal website, the client is usually a browser. The browser sends an HTTP or HTTPS request asking for a resource. That resource can be a page, an image, a CSS file, a JavaScript file, a PHP page or another type of file.

For example, when the user writes ``https://rmedeiro.42.fr``, the browser creates a request and sends it to the server responsible for that domain.

In the Inception project, that server is NGINX.

NGINX is the first container that receives traffic from outside Docker. This is why it is called the public entry point of the infrastructure.

The browser does not connect directly to WordPress and does not connect directly to MariaDB. 

The browser connects to NGINX on port 443. Then NGINX decides what should happen with the request.

A simplified architecture is:

```text
Browser
   │
   │ HTTPS request
   ▼
NGINX
   │
   ├── Static file? Serve directly
   │
   └── PHP file? Forward to WordPress/PHP-FPM
```

This makes NGINX the front door of the application.

# Why Do We Need NGINX?

NGINX is needed because it performs tasks that WordPress and MariaDB should not perform directly.

WordPress is a PHP application.

MariaDB is a database server.

Neither of them should be directly exposed to the browser.

NGINX is designed to receive web traffic safely and efficiently.

In this project, NGINX is responsible for:

* receiving HTTPS requests;
* listening on port 443;
* applying the server configuration;
* using the SSL/TLS certificate and private key;
* serving static files directly;
* forwarding PHP requests to WordPress/PHP-FPM;
* returning the final response to the browser;
* acting as the only public container.

If the browser could connect directly to WordPress/PHP-FPM, PHP-FPM would be exposed publicly. That is not the expected design. PHP-FPM expects FastCGI requests from a web server, not direct browser requests.

If the browser could connect directly to MariaDB, the database would be exposed publicly. That would be a serious security problem.

So the correct design is:

```text
Public:
    NGINX

Internal:
    WordPress / PHP-FPM
    MariaDB
```

Only NGINX should have a published port to the host machine.

# What Does NGINX Actually Do With a Request?

When NGINX receives a request, it checks its configuration and decides how to handle it. 

For example, if the browser requests ``https://rmedeiro.42.fr/wp-content/uploads/logo.png`` this is a static file. A static file is a file that does not need code execution.

Examples include:

```text
.png;
.jpg;
.css;
.js;
.ico;
.html;
fonts.
```

NGINX can serve static files directly from the filesystem.

If the file exists inside ``/var/www/html``, NGINX can read it and return it to the browser.

The flow is:

> Browser asks for logo.png  -> NGINX checks /var/www/html/wp-content/uploads/logo.png  -> File exists  -> NGINX returns the file directly

This is efficient because WordPress and PHP-FPM do not need to be involved.

However, if the browser requests ``https://rmedeiro.42.fr/index.php`` or a WordPress route that eventually needs PHP execution, NGINX cannot execute the PHP code. NGINX is not a PHP interpreter.
So NGINX forwards the request to PHP-FPM inside the WordPress container.

The flow becomes:

> Browser asks for a dynamic WordPress page  -> NGINX receives the request  -> NGINX forwards it to PHP-FPM  -> PHP-FPM executes WordPress PHP code  -> WordPress queries MariaDB if needed  -> HTML is generated  -> NGINX sends the generated HTML to the browser

This is why NGINX is often described as a ``request router``. It receives the request first and routes it to the correct place.

---

# NGINX and WordPress

WordPress is written in PHP. PHP files are not sent directly to the browser as source code. They must be executed on the server.

For example, a PHP file may contain:

```text
<?php
echo get_bloginfo('name');
?>
```

The browser does not understand PHP. The browser only understands the final output. Therefore, something on the server must execute the PHP code before the browser receives the response. That component is ``PHP-FPM``.

NGINX receives the browser request, but PHP-FPM executes the PHP code.

The connection between NGINX and WordPress works like this:

```text
 NGINX
   │
   │ FastCGI request
   |
   ▼
 PHP-FPM
   │
   │ executes PHP
   |
   ▼
WordPress
```

In the Docker Compose network, the WordPress service is reachable by its service name (wordpress) and  PHP-FPM listens on port 9000. So NGINX forwards PHP requests to wordpress:9000.
This is an internal Docker network address. The browser never sees this address. The browser only sees ``https://rmedeiro.42.fr``.

The request flow is:

```text
     NGINX receives a request
                │
                ▼
    Request needs PHP execution
                │
                ▼
NGINX sends FastCGI request to wordpress:9000
                │
                ▼
  PHP-FPM executes WordPress PHP code
                │
                ▼
WordPress connects to MariaDB if database data is needed
                │
                ▼
PHP-FPM returns generated HTML to NGINX
                │
                ▼
NGINX sends HTML response to the browser
```

So NGINX is the public web server that connects the browser to WordPress.

# What Is FastCGI?

FastCGI is the protocol used by NGINX to communicate with PHP-FPM.

A protocol is a set of rules that defines how two programs exchange information.

When NGINX forwards a PHP request to PHP-FPM, it sends information such as:

```text
SCRIPT_FILENAME=/var/www/html/index.php
REQUEST_METHOD=GET
QUERY_STRING=
DOCUMENT_ROOT=/var/www/html
SERVER_NAME=rmedeiro.42.fr
```

The most important value is ``SCRIPT_FILENAME``. This tells PHP-FPM which PHP file must be executed. For example, ``SCRIPT_FILENAME=/var/www/html/index.php``.

PHP-FPM receives that FastCGI request, executes the PHP file, and returns the generated output to NGINX. NGINX then sends the final HTTP response back to the browser. So NGINX does not generate the WordPress page by itself. It delegates PHP execution to PHP-FPM.

---

# FROM debian:bookworm

```Dockerfile
FROM debian:bookworm
```

This instruction defines the base image from which the NGINX image will be built.

Instead of using the official NGINX image ``FROM nginx``, the project starts from ``FROM debian:bookworm``. This means the container starts from Debian 12, also known as Bookworm. Debian provides the basic Linux environment required to install and run NGINX. It provides:

* a Linux filesystem hierarchy;
* the apt package manager;
* basic shell utilities;
* system libraries;
* users and groups;
* file permissions;
* networking support;
* process management tools.

Every instruction after ``FROM`` is executed on top of this Debian base. The final image becomes:

```text
Debian Bookworm
   │
   ├── NGINX package
   ├── OpenSSL package
   ├── init_nginx.sh
   ├── generated NGINX configuration
   └── generated SSL certificate files
```

---

## Why Not Use the Official NGINX Image?

The Inception subject requires building services manually instead of relying on ready-made service images.

Using ``FROM nginx`` would already provide:

* NGINX installed;
* default configuration files;
* predefined entrypoint logic;
* predefined filesystem layout;
* ready-to-run server behavior.

That would make the project easier, but it would hide important learning. By using Debian and installing NGINX manually, we learn:

* how NGINX is installed;
* which packages are required;
* where NGINX configuration files are stored;
* how HTTPS certificates are generated;
* how NGINX listens on port 443;
* how NGINX forwards PHP requests to PHP-FPM;
* how Docker networking allows NGINX to reach WordPress;
* why only NGINX should expose a public port;
* how the container startup process works;
* how ENTRYPOINT starts the service.

The goal of Inception is not simply to make NGINX run. The goal is to understand how NGINX fits into a multi-container web infrastructure.

---

# Installing NGINX Runtime Dependencies

```Dockerfile
RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*
```

This instruction installs the packages needed by the NGINX container.

Before this line runs, the image is only a basic Debian system. 

After this line runs, the image contains the software required to receive HTTPS requests and serve the website.

The installed packages are:

* nginx;
* openssl.


## The nginx Package

```bash
nginx
```

This package installs the NGINX web server inside the image.

Before this package is installed, the image is only Debian.

After installation, the image contains the NGINX binary, default configuration directories, service files and supporting files.

In this project, NGINX is responsible for receiving the browser request and forwarding it to the correct internal service.

The NGINX package gives the container the ability to:

* open and listening on port 443;
* accept HTTPS connections;
* using the SSL certificate and private key;
* read configuration files (WordPress files) from /var/www/html;;
* serve files from /var/www/html;
* forwarding PHP requests to WordPress/PHP-FPM;
* returning the final response to the browser.

The most important NGINX configuration concepts are:

* server block
* listen
* server_name
* root
* index
* location
* fastcgi_pass
* ssl_certificate
* ssl_certificate_key

Each one controls part of the web server behavior.


### listen

The listen tells NGINX which port to accept connections on.

For Inception: ``listen 443 ssl;`` means Listen for HTTPS connections on port 443.

Port 443 is the standard HTTPS port.

### server_name

The server_name tells NGINX which domain this configuration applies to.

Example: ``server_name rmedeiro.42.fr;``. When the browser requests ``https://rmedeiro.42.fr``, NGINX can match that request to this server block.

### root

The root tells NGINX where the website files are stored.

Example: ``root /var/www/html;`` means NGINX will look for files inside ``/var/www/html``. This directory is shared with the WordPress container through a Docker volume. WordPress writes files there.
NGINX reads files from there.

### index

The index tells NGINX which file to try first when a directory is requested.

Example: ``index index.php index.html;``. If the browser requests ``https://rmedeiro.42.fr/``, NGINX tries to load ``index.php`` or ``index.html`` depending on what exists and how the configuration routes the request.

### location /

A location block defines how NGINX should handle certain request paths.

Example:

```text
location / {
	try_files $uri $uri/ /index.php?$args;
}
```

This is very important for WordPress.

It means:

* Try to serve the exact requested file.
* If that does not exist, try the requested directory.
* If neither exists, send the request to index.php.

This allows WordPress permalinks to work.

### location ~ \.php$

This block handles PHP files. Example:

```text
location ~ \.php$ {
	include fastcgi_params;
	fastcgi_pass wordpress:9000;
	fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}
```

This means: If the requested file ends in .php, send it to PHP-FPM.

The directive: ``fastcgi_pass wordpress:9000;`` tells NGINX to forward the request to PHP-FPM inside the WordPress container.

The directive: ``fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;`` tells PHP-FPM the exact PHP file to execute. For example: ``/var/www/html/index.php``.

Without this parameter, PHP-FPM might not know which file to run.




---

## openssl

```bash
openssl
```

This package installs the OpenSSL command-line tool.

OpenSSL is used to generate the SSL/TLS certificate and private key required for HTTPS.

HTTPS requires encryption. For encryption to work, NGINX needs:

* a certificate file;
* a private key file.

The initialization script can generate those files with a command similar to:

```text
openssl req -x509 -nodes -days 365 \
	-newkey rsa:2048 \
	-keyout /etc/nginx/ssl/inception.key \
	-out /etc/nginx/ssl/inception.crt \
	-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=rmedeiro.42.fr"
```

This creates a self-signed certificate. A self-signed certificate is signed by itself instead of being signed by a public Certificate Authority.

For a real public production website, this would not be ideal because browsers do not automatically trust self-signed certificates.

For Inception, it is acceptable because the goal is to configure HTTPS locally and understand how TLS works.

Without OpenSSL, the script could not generate the certificate.

Without a certificate and private key, NGINX could not serve HTTPS on port 443.

## What Is TLS/SSL?

The website must be accessible through HTTPS. HTTPS is HTTP over TLS.

TLS is the modern protocol that encrypts communication between the browser and the server.

SSL is the older name that is still commonly used in conversation.

When a browser connects to ``https://rmedeiro.42.fr`` the connection is encrypted. This means that the data exchanged between the browser and NGINX cannot be read easily by someone intercepting the traffic.

To support HTTPS, NGINX needs two files:

* SSL certificate
* Private key

The certificate identifies the server.

The private key is used during the encryption.

In a real production website, the certificate is usually issued by a trusted Certificate Authority.

In Inception, a self-signed certificate is acceptable for the local project environment.

That certificate can be generated with OpenSSL inside the NGINX container.

# Why Remove apt Cache?

```bash
rm -rf /var/lib/apt/lists/*
```

``apt-get update`` downloads package indexes into ``/var/lib/apt/lists/``. These files are needed only while installing packages.

After nginx and openssl are installed, these package index files are no longer useful inside the final image. Removing them:

* reduces the final image size;
* removes unnecessary metadata;
* keeps the image cleaner.

This command does not remove NGINX and does not remove OpenSSL.

It only removes temporary apt package lists.

The result is a smaller and cleaner Docker image.

---

# Copying the Initialization Script

```Dockerfile
COPY ./tools/init_nginx.sh /usr/local/bin/init_nginx.sh
```

This instruction copies the custom NGINX initialization script into the image.

At this point, the image contains NGINX and OpenSSL, but it still does not know how to configure NGINX for the Inception project.

That is the role of:

```text
init_nginx.sh
```

The Dockerfile installs the tools.

The script configures and starts the service.

A useful separation is:

```text
Dockerfile
    installs NGINX and OpenSSL

init_nginx.sh
    generates SSL certificate
    generates NGINX configuration
    starts NGINX
```

---

## Why the Script Is Needed

The script is needed because some configuration depends on runtime values.

For example:

* `DOMAIN_NAME`;
* `PHP_FPM_HOST`;
* `PHP_FPM_PORT`;
* generated SSL certificate path;
* generated NGINX configuration.

These values may come from the `.env` file and only exist when Docker Compose starts the container.

The script can use those values to generate the final NGINX configuration dynamically.

For example, it can create a config containing:

```nginx
server_name rickymercury.42.fr;
fastcgi_pass wordpress:9000;
ssl_certificate /etc/nginx/ssl/inception.crt;
ssl_certificate_key /etc/nginx/ssl/inception.key;
```

This is runtime-specific configuration.

It should not be hardcoded blindly inside the Dockerfile.

---

# Why NGINX Needs a Configuration File

NGINX behavior is controlled by configuration files.

The script usually creates a file such as:

```text
/etc/nginx/conf.d/default.conf
```

This file tells NGINX:

* which port to listen on;
* which domain name to accept;
* where the website files are stored;
* where the SSL certificate is located;
* how to handle PHP files;
* where to forward PHP requests.

A simplified configuration looks like:

```nginx
server {
	listen 443 ssl;
	server_name rickymercury.42.fr;

	root /var/www/html;
	index index.php index.html;

	ssl_certificate /etc/nginx/ssl/inception.crt;
	ssl_certificate_key /etc/nginx/ssl/inception.key;

	location / {
		try_files $uri $uri/ /index.php?$args;
	}

	location ~ \.php$ {
		include fastcgi_params;
		fastcgi_pass wordpress:9000;
		fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	}
}
```

This configuration is what connects NGINX to WordPress.

---

# How NGINX Serves WordPress

The most important directive is: ``root /var/www/html``. This tells NGINX that the website files are inside: ``/var/www/html``. This is the same volume mounted in both:

* WordPress container;
* NGINX container.

The WordPress container writes the WordPress files there.

The NGINX container reads those files there.

This shared volume allows NGINX to see:

```text
index.php
wp-config.php
wp-content/
wp-admin/
wp-includes/
```

NGINX then decides how to handle each request.

---

## Static Files

Static files do not need PHP execution.

Examples:

* CSS;
* JavaScript;
* images;
* fonts.

If the browser requests:

```text
/wp-content/uploads/image.png
```

NGINX can serve that file directly from the volume.

This is efficient because PHP-FPM does not need to be involved.

---

## PHP Files

PHP files must be executed.

If the browser requests:

```text
/index.php
```

NGINX forwards the request to:

```text
wordpress:9000
```

using FastCGI.

That means PHP-FPM inside the WordPress container executes the PHP file and returns generated HTML.

---

# Making the Script Executable

```Dockerfile
RUN chmod +x /usr/local/bin/init_nginx.sh
```

This instruction gives execution permission to the initialization script.

Copying a script into the image does not automatically make it executable.

Linux permissions determine whether a file can be run as a program.

Without execute permission, Docker could fail with:

```text
Permission denied
```

when trying to execute the entrypoint.

The command:

```bash
chmod +x /usr/local/bin/init_nginx.sh
```

adds execute permission.

---

# EXPOSE 443

```Dockerfile
EXPOSE 443
```

This instruction documents that the NGINX container listens on port `443`.

Port `443` is the standard HTTPS port.

This is the only service that should be exposed publicly in the Inception project.

The browser connects to:

```text
https://rickymercury.42.fr
```

which reaches NGINX on port 443.

The flow is:

```text
Browser
   │
   │ HTTPS :443
   ▼
NGINX
   │
   │ FastCGI
   ▼
WordPress :9000
   │
   │ SQL
   ▼
MariaDB :3306
```

NGINX exposes port 443.

WordPress only exposes port 9000 internally.

MariaDB only exposes port 3306 internally.

---

## EXPOSE vs ports

`EXPOSE` only documents the port inside the image.

It does not publish the port to the host machine by itself.

To make NGINX reachable from the host, Docker Compose must use:

```yaml
ports:
  - "443:443"
```

This maps:

```text
Host port 443 -> Container port 443
```

For NGINX, using `ports` is correct because it is the public entry point.

For WordPress and MariaDB, `ports` should usually not be used because they are internal services.

---

# Understanding ENTRYPOINT

```Dockerfile
ENTRYPOINT ["init_nginx.sh"]
```

`ENTRYPOINT` defines the command executed every time the container starts.

When Docker starts the NGINX container, it runs:

```bash
init_nginx.sh
```

This script becomes the first process executed inside the container.

The startup flow is:

```text
Container starts
       │
       ▼
ENTRYPOINT executes
       │
       ▼
init_nginx.sh runs
       │
       ▼
Environment variables are checked
       │
       ▼
SSL certificate is created if needed
       │
       ▼
NGINX configuration is generated
       │
       ▼
NGINX starts
```

Without this script, the container would have NGINX installed, but it would not know the project-specific domain, SSL certificate or PHP-FPM upstream.

---

# Why Not Start NGINX Directly?

Someone might ask:

```Dockerfile
ENTRYPOINT ["nginx"]
```

Why not start NGINX directly?

Because NGINX needs project-specific configuration before it starts.

Before starting NGINX, the container must:

* validate `DOMAIN_NAME`;
* validate `PHP_FPM_HOST`;
* validate `PHP_FPM_PORT`;
* generate or reuse SSL certificates;
* generate the server block configuration;
* configure FastCGI forwarding to WordPress.

NGINX itself only reads configuration files.

It does not automatically know the WordPress service name or project domain.

The initialization script prepares those files first.

Then it starts NGINX.

---

# Why exec Is Important

The final line of the script should be:

```bash
exec nginx -g "daemon off;"
```

This starts NGINX as the main process of the container.

The `exec` command replaces the shell script process with the NGINX process.

Without `exec`, the process tree could be:

```text
PID 1 -> init_nginx.sh
          └── PID 14 -> nginx
```

With `exec`, the script is replaced:

```text
PID 1 -> nginx
```

Docker monitors PID 1.

If PID 1 exits, the container stops.

Therefore, NGINX should become PID 1 because NGINX is the actual service that must keep running.

---

## Why `daemon off;` Is Needed

By default, NGINX usually runs as a daemon.

That means it starts and then moves into the background.

On a traditional Linux system, that is normal because a service manager such as `systemd` controls it.

Docker containers work differently.

Docker expects the main process to remain in the foreground.

If NGINX daemonizes, the entrypoint script may finish, PID 1 exits, and Docker stops the container.

The option:

```bash
nginx -g "daemon off;"
```

forces NGINX to stay in the foreground.

So:

```bash
exec nginx -g "daemon off;"
```

means:

```text
Replace the script with NGINX and keep NGINX in the foreground.
```

This keeps the container alive.

---

# Complete NGINX Startup Sequence

```text
docker compose up
        │
        ▼
NGINX container starts
        │
        ▼
ENTRYPOINT runs init_nginx.sh
        │
        ▼
Environment variables are validated
        │
        ▼
SSL directory is created
        │
        ▼
Self-signed certificate is generated if missing
        │
        ▼
NGINX configuration is generated
        │
        ▼
Configuration points PHP requests to wordpress:9000
        │
        ▼
exec nginx -g "daemon off;"
        │
        ▼
PID 1 becomes NGINX
        │
        ▼
Browser can access https://rickymercury.42.fr
```
