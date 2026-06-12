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

# What Is HTTP?

HTTP means ``HyperText Transfer Protocol``.

HTTP is the protocol used by browsers and web servers to exchange web content.

A protocol is a set of rules that defines how two systems communicate.

For example, when a browser requests a page, it sends an HTTP request:

```text
GET / HTTP/1.1
Host: rmedeiro.42.fr
```

The server then responds with an HTTP response:

```text
HTTP/1.1 200 OK
Content-Type: text/html

<html>
	<body>
		<h1>Hello</h1>
	</body>
</html>
```

HTTP defines the structure of these requests and responses. It defines things such as:

* request methods like GET and POST;
* headers;
* status codes;
* response bodies;
* cookies;
* content types.

However, plain HTTP has a major weakness: ``HTTP is not encrypted``. That means the data travels over the network as readable text. If someone intercepts the traffic, they may be able to read:

* requested URLs;
* form data;
* cookies;
* login credentials;
* page content.

A simplified HTTP flow is:

> Browser --- plain text request ---> Network ---- readable traffic ---> NGINX

This is why HTTP is considered insecure for websites that handle logins, passwords, cookies or private data.

# What Is HTTPS?

HTTPS means: ``HTTP Secure``. Technically, HTTPS is ``HTTP over TLS``.

This means the browser and the server still use HTTP, but the HTTP data is sent inside an encrypted TLS connection.

The HTTP protocol still exists.

The difference is that the HTTP request and response are protected by encryption before travelling through the network.

A simplified HTTPS flow is:

> Browser  ---- encrypted TLS connection ---> Network --- encrypted traffic ---> NGINX

So HTTPS protects the communication between the browser and the server.

With HTTPS, someone intercepting the network traffic cannot easily read the actual content being exchanged.

They may see that a connection exists, but they cannot normally read the protected HTTP data inside it.

# Main Differences Between HTTP and HTTPS

The main differences are:

```text
HTTP
    uses no encryption
    usually uses port 80
    sends readable data
    does not prove server identity
    unsafe for passwords and sessions

HTTPS
    uses TLS encryption
    usually uses port 443
    protects data in transit
    uses certificates
    helps prove server identity
    required for secure login pages
```

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

---

## The openssl package

```bash
openssl
```

The openssl package installs the OpenSSL command-line tool.

OpenSSL is a tool used to work with cryptography. In this project, it is mainly used to generate the files required for HTTPS:

* a certificate file;
* a private key file.

NGINX needs these files because the Inception subject requires the website to be served over HTTPS, not plain HTTP.

In simple terms:

```text
``HTTP`` - sends data without encryption.

``HTTPS`` - sends data through an encrypted TLS connection
```

So, without OpenSSL, the script would not be able to generate the certificate and private key required by NGINX.

Without the certificate and private key, NGINX could still serve HTTP, but it could not correctly serve HTTPS on port 443.

The initialization script can generate the certificate and private key using something like:

```text
openssl req -x509 -nodes -days 365 \
	-newkey rsa:2048 \
	-keyout /etc/nginx/ssl/inception.key \
	-out /etc/nginx/ssl/inception.crt \
	-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=rmedeiro.42.fr"
```

This command creates both:

* /etc/nginx/ssl/inception.key
* /etc/nginx/ssl/inception.crt

The ``req`` command is used to create certificate requests and certificates. In this case, it is used to generate a self-signed certificate directly.

The ``-x509`` tells OpenSSL to output a self-signed X.509 certificate. X.509 is the standard format used for TLS certificates.

The ``-nodes`` means the private key should not be encrypted with a passphrase. This is useful in Docker because NGINX must be able to start automatically. If the private key required a passphrase, NGINX would ask for it at startup. That would block container automation.
So ``-nodes`` allows NGINX to read the private key without human input.

The ``-days 365`` sets the certificate validity period to 365 days. After that period, the certificate expires.

The ``-newkey rsa:2048`` creates a new RSA private key with a size of 2048 bits. The key size controls the strength of the key. 2048 bits is commonly used for local development and basic TLS setups.

The ``-keyout /etc/nginx/ssl/inception.key`` tells OpenSSL where to write the private key.

The ``-out /etc/nginx/ssl/inception.crt`` tells OpenSSL where to write the certificate.

The ``-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=rmedeiro.42.fr"`` provides certificate subject information without interactive prompts.

The fields mean:

```text
C   = Country
ST  = State or region
L   = Locality or city
O   = Organization
OU  = Organizational unit
CN  = Common Name
```

###  What Is TLS?

TLS means ``Transport Layer Security``.

TLS is the modern encryption protocol used by HTTPS. It provides three important security properties:

* Encryption
* Authentication
* Integrity

``Encryption`` means that the data is transformed into unreadable information while it travels through the network.

Without encryption, for example, ``password=abc123`` could travel as readable text. With encryption, it becomes something unreadable, conceptually like: ``8fA92ksLq0Zx...==``. Only the browser and the server can understand the encrypted communication.

``Authentication`` means the browser can verify the identity of the server. When the browser connects to ``https://rmedeiro.42.fr`` the server presents a certificate. The certificate says: ``I am the server for rmedeiro.42.fr``. In production, the browser trusts this certificate only if it was signed by a trusted Certificate Authority. In Inception, the certificate is self-signed, so the browser may show a warning.

``Integrity`` means the data cannot be modified silently while travelling through the network. If someone tries to alter the encrypted traffic, the TLS verification will fail. This protects against tampering.

### What Is SSL?

SSL means ``Secure Sockets Layer``.

SSL was the older protocol used before TLS. Today, SSL is obsolete and should not be used. TLS replaced SSL. However, people still commonly say "SSL certificate" even though modern HTTPS uses TLS.

So, in practice, ``SSL certificate`` usually means ``TLS certificate``.

The name "SSL" remains common, but the modern protocol is TLS.

In an NGINX configuration, directives still use names like:

```text
ssl_certificate
ssl_certificate_key
ssl_protocols TLSv1.2 TLSv1.3;
```

Even though the directive says ssl_, the actual secure protocols used should be TLS versions.

### What Happens During an HTTPS Connection?

When a browser connects to NGINX using HTTPS, a TLS happens before normal HTTP data is exchanged.

A simplified flow is:

Browser connects to https://rmedeiro.42.fr
                 │
                 ▼
    NGINX presents its certificate
                 │
                 ▼
    Browser checks the certificate
                 │
                 ▼
Browser and NGINX agree on encryption keys
                 │
                 ▼
   Encrypted connection is established
                 │
                 ▼
HTTP request is sent inside the encrypted TLS tunnel

After the TLS connection is established, the browser can safely send normal HTTP requests through the encrypted channel. This is why HTTPS is often described as ``HTTP over TLS``.


### What Is a Certificate?

A certificate is a file that contains information about the server identity and its public key.

In this project, the certificate file is usually ``/etc/nginx/ssl/inception.crt``. The NGINX configuration points to it with ``ssl_certificate /etc/nginx/ssl/inception.crt;``.

A certificate usually contains:

* domain name;
* public key;
* validity period;
* issuer information;
* signature;
* organization or location metadata.

The certificate is public. It is sent to the browser during the TLS handshake.

The certificate does not need to be secret. Its purpose is to allow the browser to know which server it is talking to and to obtain the public key used in the TLS process.

### What Is a Private Key?

The private key is the secret key that belongs to the server.

In this project, the private key file is usually ``/etc/nginx/ssl/inception.key``. The NGINX configuration points to it with ``ssl_certificate_key /etc/nginx/ssl/inception.key;``.

The private key must remain private. It should never be shared publicly. It should never be committed to a public repository. It should never be exposed to users.

The private key is linked to the public key inside the certificate.

During the TLS handshake, NGINX uses the private key to prove that it is the legitimate owner of the certificate.

The certificate can be public. The private key must be secret.

A simple analogy:

```text
Certificate
    public identity card

Private key
    secret proof that you own that identity
```

### Certificate and Private Key Together

NGINX needs both files.

The certificate and private key alone is not enough.

Together they allow NGINX to serve HTTPS.

```text
Certificate
    tells the browser who the server claims to be

Private key
    proves the server owns that certificate

TLS
    uses them to establish encrypted communication
```

In NGINX:

```text
ssl_certificate /etc/nginx/ssl/inception.crt;
ssl_certificate_key /etc/nginx/ssl/inception.key;
```

If one of these files is missing or mismatched, NGINX may fail to start or HTTPS may not work.


### What Is a Self-Signed Certificate?

A self-signed certificate is a certificate that is signed by its own private key instead of being signed by a trusted Certificate Authority.

In simple terms:

```text
Trusted CA certificate:
    A trusted authority says: this server is legitimate.

Self-signed certificate:
    The server says: trust me, I am legitimate.
```

The encryption can still work with a self-signed certificate. The browser can still establish an encrypted connection. However, the browser does not automatically trust the identity because no trusted external authority verified it. That is why browsers usually show a warning for self-signed certificates. This warning does not necessarily mean the connection cannot be encrypted. It means the browser cannot verify the identity through a trusted CA.

For Inception, this is acceptable because:

* the project runs locally;
* the domain is mapped manually in /etc/hosts;
* the goal is to configure TLS/HTTPS manually;
* a public CA certificate is not required.

Without a certificate and private key, NGINX could not serve HTTPS on port 443.

### Why NGINX Depends on WordPress

NGINX can start without WordPress, but the website will not fully work unless WordPress/PHP-FPM is reachable.

NGINX depends on WordPress for dynamic PHP pages. 

For static files, NGINX can respond alone.

For PHP pages, NGINX must forward the request to: ``wordpress:9000``.

If WordPress is down, PHP requests will fail. The user may see: ``502 Bad Gateway``. This usually means NGINX is running, but the upstream service, PHP-FPM, is not reachable.

So the dependency is:

* NGINX needs WordPress/PHP-FPM for PHP execution.
* WordPress needs MariaDB for dynamic data.
* MariaDB stores the persistent data.

Full dependency chain:

> Browser ---> NGINX  ---- depends on ---> WordPress / PHP-FPM ---- depends on ---> MariaDB

NGINX needs OpenSSL-generated certificate files to serve securely over HTTPS. The flow becomes:

> Browser  ----- HTTPS / TLS ---> NGINX ----- FastCGI ----> WordPress / PHP-FPM ---- SQL ---> MariaDB

OpenSSL does not serve the website. NGINX serves the website.

OpenSSL only helps create the cryptographic files that allow NGINX to serve HTTPS.

---

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

This instruction copies the custom NGINX initialization script from the host machine into the Docker image.

The Source path ``./tools/init_nginx.sh`` exists on the host machine during image creation. Inside the project:

```text
srcs/
└── requirements/
    └── nginx/
        ├── Dockerfile
        └── tools/
            └── init_nginx.sh
```

Docker reads this file while building the image.

The file is physically copied into the image.

The Destination Path ``/usr/local/bin/init_nginx.sh`` exists inside the image filesystem. 

The path ``/usr/local/bin`` has a special meaning in Linux. Traditionally, here, is where the custom executables are installed manually.
The Linux shell automatically searches these directories when a command is executed.

Linux automatically finds the script.


After the copy:

```text
Container
│
├── /usr/local/bin/
│       └── init_nginx.sh
│
└── ...
```

The script now becomes part of the image itself. Every container created from this image will automatically contain that script.

So, this line transforms a generic Debian container with NGINX installed into a fully configured web server capable of serving the Inception website.

Without this script, the image would contain:

```text
Debian
    │
    ├── NGINX installed
    ├── OpenSSL installed
    └── Default NGINX files
```

but nothing would configure:

* HTTPS;
* SSL certificates;
* WordPress integration;
* FastCGI forwarding;
* server_name;
* custom NGINX configuration.

The image would contain software, but it would not know how to use it. This is exactly why the initialization script exists.

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

## Why The Configuration Must Be Generated At Runtime

The NGINX configuration depends on values that only exist when the container starts.

Examples:

```text
DOMAIN_NAME=rickymercury.42.fr
PHP_FPM_HOST=wordpress
PHP_FPM_PORT=9000
```

These values come from:

* .env
* docker-compose.yml
* container environment

The Dockerfile cannot use these values during build time. The initialization script can.

The same image can work with different domains and services.

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
	server_name rmedeiro.42.fr;

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

### server

The block:

```text
server {

}
```

Defines a virtual server. It is a website definition. 

NGINX can host multiple websites. 

Each website normally has its own server block.

### listen 443 ssl

Tells NGINX to accept connections on port 443 (Use HTTPS).

Without this: No HTTPS support.

### server_name

``server_name rmedeiro.42.fr;`` defines which domain belongs to this server block.

When NGINX receives: ``Host: rmedeiro.42.fr``, it knows this configuration should handle the request.

### root

``root /var/www/html;`` defines the website root directory.

NGINX searches files here.

Example:

Request: ``/logo.png``.
NGINX searches: ``/var/www/html/logo.png``.

### index

``index index.php index.html;`` defines default files.

Example:

``https://rmedeiro.42.fr/`` becomes: ``index.php`` or ``index.html``.


### ssl_certificate

``ssl_certificate /etc/nginx/ssl/inception.crt;`` tells NGINX where the TLS certificate is stored. This certificate is sent to the browser during the TLS handshake.

### ssl_certificate_key

``ssl_certificate_key /etc/nginx/ssl/inception.key;`` tells NGINX where the private key is stored.

Without this key: TLS cannot work.

### location /

Matches normal website requests.

### try_files

``try_files $uri $uri/ /index.php?$args;``

WordPress URLs often look like:

```text
/about
/contact
/blog/my-post
```

These files do not physically exist. WordPress generates them dynamically.

This directive tells NGINX: ``Try real file``. If not found, send request to index.php, which allows WordPress routing to work.

### location ~ .php$

Matches PHP files.

Examples:

```text
index.php
wp-login.php
wp-admin/index.php
fastcgi_pass
fastcgi_pass wordpress:9000;
```

This is where NGINX connects to PHP-FPM.

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
