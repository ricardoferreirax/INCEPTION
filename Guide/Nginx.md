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

---

# Why Do We Need NGINX?

NGINX is needed because it is the public entry point of the Inception infrastructure. 

NGINX performs tasks that WordPress and MariaDB should not perform directly.

In this project, the browser must not communicate directly with WordPress or MariaDB.

WordPress is a PHP application. Its job is to execute application logic and generate dynamic pages.

MariaDB is a database server. Its job is to store persistent data such as users, posts, comments, passwords, settings and metadata.

Neither WordPress/PHP-FPM nor MariaDB should be directly exposed to the host machine or browser.

NGINX is designed to receive web traffic safely and efficiently. NGINX receives the HTTPS request from the browser, handles the TLS/SSL connection, checks its configuration, and decides how the request should be processed. If the request is for a static file, NGINX can serve it directly. If the request needs PHP execution, NGINX forwards it to PHP-FPM inside the WordPress container.

So NGINX is responsible for:

* receiving HTTPS requests;
* listening on port 443;
* applying the server configuration;
* using the SSL/TLS certificate and private key;
* serving static files directly;
* forwarding PHP requests to WordPress/PHP-FPM;
* returning the final response to the browser;
* acting as the only public container.

Only NGINX should have a published port to the host machine.

If the browser could connect directly to WordPress/PHP-FPM, PHP-FPM would be exposed publicly. That is not the expected design. PHP-FPM expects FastCGI requests from a web server, not direct browser requests.

If the browser could connect directly to MariaDB, the database would be exposed publicly. That would be a serious security problem.

In Docker Compose, this means NGINX uses:

```text
ports:
  - "443:443"
```

while WordPress and MariaDB should only use internal networking.

---

# What Does NGINX Actually Do With a Request?

When a browser opens https://rmedeiro.42.fr, it sends an HTTP request inside an encrypted HTTPS connection.

A simplified HTTP request looks like:

```text
GET / HTTP/1.1
Host: rmedeiro.42.fr
```

This is called an HTTP request. 

NGINX receives this request and checks its configuration. The request contains information such as:

* Requested resource URL
* Requested file
* Requested method
* Domain name
* Headers
* Server configuration
* Authentication data

Then it decides what to do.

NGINX can:

* Serve the requested file directly
* Forward the request to PHP-FPM
* Redirect the request
* Deny the request
* Return an error page

This decision happens for every request. That is why NGINX can be understood as a ``request router``. It receives the request first and sends it to the correct destination.

```text
The browser sends a request.
			│
        	▼
NGINX receives that request.
			│
            ▼
NGINX analyzes the request.
			│
            ▼
NGINX decides how the request should be handled.
```

Example:

```text
GET /index.php - means "I want the file index.php".

GET /wp-content/uploads/logo.png - means "I want the image logo.png".
```

NGINX receives these requests and begins analyzing them. Think of NGINX as a receptionist in a large company. People arrive at the reception desk. The receptionist asks: What do you need? Depending on the answer, the receptionist sends the visitor to the correct department. NGINX does exactly the same thing. Every request arrives at NGINX first. NGINX examines and then decides: Can I handle this myself? or Do I need to forward this elsewhere?

This is why NGINX is often called a:

* Reverse Proxy
* Gateway
* Request Router
* Traffic Controller

In the Docker Compose network, the WordPress service is reachable by its service name (wordpress) and  PHP-FPM listens on port 9000. So NGINX forwards PHP requests to wordpress:9000. This is an internal Docker network address. The browser never sees this address. The browser only sees ``https://rmedeiro.42.fr``.

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

---

# Understanding Static Content

It is important to understand that not all website content is generated in the same way. Some content already exists on disk and can be sent immediately to the browser. Other content must be generated dynamically every time a request arrives.

Static content is content that already exists as a real file on disk. No application logic needs to run, no PHP code needs to execute and no database query is required. The web server simply reads the file and sends it to the browser. Examples:

```text
logo.png
background.jpg
style.css
main.js
favicon.ico
```
These files physically exist inside the filesystem. NGINX can serve static files directly from the filesystem. 

The easiest requests are ``static requests``. Static means: ``The file already exists. No code needs to run. No database query is needed``.

For example, this file: ``/var/www/html/wp-content/uploads/logo.png``, already contains all the image data. Nothing needs to be calculated or to be generated. The file simply exists. NGINX does not need WordPress, PHP or MariaDB. It simply reads the file and sends it back.

Suppose the browser requests: https://rmedeiro.42.fr/wp-content/uploads/logo.png. The request flow becomes:

> Browser -> NGINX receives request -> NGINX searches: /var/www/html/wp-content/uploads/logo.png -> File found -> NGINX reads the file from disk -> NGINX sends the file to browser -> Browser displays the image

Notice something important:

* PHP-FPM was not used
* WordPress was not loaded
* MariaDB was not queried

Only NGINX is involved. This is extremely efficient.

---

# Understanding Dynamic Content

Dynamic content is the opposite of static content.

The content does not already exist as a complete file. Instead, it must be generated when the request arrives. So :

* Code must execute.
* Database may be queried.
* Content must be generated.

Suppose we open https://rmedeiro.42.fr. The homepage may contain:

* Latest posts
* Latest comments
* Current user
* Menus
* Theme settings
* Plugin data

This information changes constantly. The homepage cannot simply be stored as: homepage.html, because the content depends on:

* Database contents
* User session
* WordPress settings
* Plugins
* Theme configuration

So the page must be generated dynamically. That's why WordPress pages are dynamic.

The homepage itself is usually NOT stored as a ready-made HTML file. Instead, WordPress stores PHP code inside files such as:

* index.php
* wp-blog-header.php
* theme files
* plugin files

and stores the actual content inside MariaDB:

* posts
* pages
* comments
* users
* settings

When someone requests the homepage, WordPress combines: PHP code + Database data to generate HTML. Only then does the page exist.

NGINX can't generate dynamic content, because NGINX is not a PHP interpreter. NGINX understands:

* HTTP or HTTPS
* Files
* Directories
* Networking
* TLS

If NGINX opened a PHP file, it would simply see text. It would not know how to execute PHP instructions. That is not its job.

For example,  suppose someone requests https://rmedeiro.42.fr/index.php. Now NGINX encounters PHP. NGINX cannot execute PHP.

So, if the browser requests a WordPress route that eventually needs PHP execution, NGINX cannot execute the PHP code. NGINX is not a PHP interpreter. So NGINX forwards the request to PHP-FPM inside the WordPress container. 

NGINX is a web server. NGINX is NOT a PHP interpreter !

That is why PHP-FPM exists.

---

# How NGINX Knows When To Use PHP-FPM

As WordPress is written in PHP, PHP files are not sent directly to the browser as source code, they must be executed on the server.

The browser does not understand PHP. The browser only understands the final output. Therefore, something on the server must execute the PHP code before the browser receives the response. That component is ``PHP-FPM``.

PHP-FPM means: ``PHP FastCGI Process Manager``. PHP-FPM is the component responsible for executing PHP code. Its entire purpose is:

* Receive PHP requests
* Execute PHP code
* Generate output
* Return results

NGINX acts as the receptionist and PHP-FPM acts as the worker that actually performs the task.

NGINX knows when to forward a request to PHP-FPM because of its configuration file. The important part is usually:

```text
location ~ \.php$ {
	include fastcgi_params;
	fastcgi_pass wordpress:9000;
	fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}
```

This block means: If the requested file ends in .php, send the request to PHP-FPM.

Examples of PHP files:

```text
/index.php
/wp-login.php
/wp-admin/index.php
```

NGINX cannot execute PHP code itself. NGINX is a web server, not a PHP interpreter. PHP-FPM is responsible for executing PHP code. So, when NGINX detects a PHP request, it forwards that request to: wordpress:9000. Here, 9000 is the port where PHP-FPM is listening. Docker internal DNS allows NGINX to resolve wordpress to the IP address of the WordPress container.

The flow becomes:

> Browser asks for a dynamic WordPress page  -> NGINX receives the request  -> NGINX forwards it to PHP-FPM  -> PHP-FPM executes WordPress PHP code  -> WordPress queries MariaDB if needed  -> HTML is generated  -> NGINX sends the generated HTML to the browser

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

---

# What Is FastCGI?

FastCGI is the protocol used by NGINX to communicate with PHP-FPM.

A protocol is a set of rules that defines how two programs communicate and exchange information.

In this project:

```text
HTTP/HTTPS
    Browser communicates with NGINX

FastCGI
    NGINX communicates with PHP-FPM

SQL
    WordPress communicates with MariaDB
```

When NGINX forwards a PHP request to PHP-FPM, it sends FastCGI parameters. For example:

```text
SCRIPT_FILENAME=/var/www/html/index.php
REQUEST_METHOD=GET
QUERY_STRING=
DOCUMENT_ROOT=/var/www/html
SERVER_NAME=rmedeiro.42.fr
```

SCRIPT_FILENAME tells PHP-FPM which PHP file must be executed. PHP-FPM receives the FastCGI request, executes the PHP file, and returns the generated output to NGINX. NGINX then sends the final HTTP response back to the browser.

---

# What Is HTTP?

HTTP means ``HyperText Transfer Protocol``.

HTTP is the protocol used by browsers and web servers to exchange web content.

A protocol is a set of rules that defines how two systems communicate.

HTTP is the communication language used by browsers and web servers. When a browser requests a page, it sends an HTTP request. When a server responds, it sends an HTTP response.

HTTP defines the structure of these requests and responses. It defines things such as:

* request methods like GET and POST;
* headers;
* status codes;
* response bodies;
* cookies;
* content types.

Without HTTP, the communication between Browser ↔ Server would not exist.

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

HTTPS is still HTTP. The HTTP protocol still exists. This means the browser and the server still use HTTP, but the HTTP data is sent inside an encrypted TLS connection. The communication channel becomes encrypted.

The HTTP request and response are protected by encryption before travelling through the network.

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

---

# Understanding the Shared WordPress Volume

In the Inception project, the WordPress files are stored inside ``/var/www/html``.

This path is used by both:

* WordPress container
* NGINX container

The WordPress container writes files there. For example, during installation, WordPress creates:

* index.php
* wp-config.php
* wp-admin/
* wp-content/
* wp-includes/

NGINX needs to read those same files. That is why both containers mount the same WordPress volume.

The idea is:

```text
WordPress container
    writes WordPress files into /var/www/html

NGINX container
    reads WordPress files from /var/www/html
```

The shared volume allows both containers to see the same website files.

---

# Why WordPress Needs MariaDB

WordPress needs MariaDB because WordPress is dynamic. The WordPress files contain the application logic, but the actual website data is stored in MariaDB.

For example:

```text
/var/www/html
    WordPress PHP files

MariaDB
    posts, users, comments, settings, passwords, metadata
```

When WordPress executes, it often needs data from the database. For example, to generate the homepage, WordPress may ask MariaDB for:

* site title
* active theme
* latest posts
* menus
* users
* plugin settings

The flow is:

```text
PHP-FPM executes WordPress
        │
        ▼
WordPress reads wp-config.php
        │
        ▼
WordPress connects to MariaDB
        │
        ▼
MariaDB returns data
        │
        ▼
WordPress generates HTML
```

So NGINX depends on WordPress/PHP-FPM for PHP execution.

WordPress depends on MariaDB for dynamic data.

MariaDB stores the persistent content.

---

## Why NGINX Depends on WordPress

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

In this project, NGINX is responsible for receiving the browser request and forwarding it to the correct internal service. The NGINX package gives the container the ability to:

* open and listening on port 443;
* accept HTTPS connections;
* using the SSL certificate and private key;
* read configuration files (WordPress files) from /var/www/html;;
* serve files from /var/www/html;
* forwarding PHP requests to WordPress/PHP-FPM;
* returning the final response to the browser.

---

## The openssl package

```bash
openssl
```

The openssl package installs the OpenSSL command-line tool.

OpenSSL is a tool used to work with cryptography. In this project, it is mainly used to generate the files required for HTTPS:

* a certificate file;
* a private key file.

NGINX needs these files because the Inception subject requires the website to be served over HTTPS, not plain HTTP. So, without OpenSSL, the script would not be able to generate the certificate and private key required by NGINX. Without the certificate and private key, NGINX could still serve HTTP, but it could not correctly serve HTTPS on port 443.

---

##  What Is TLS?

TLS means ``Transport Layer Security``.

TLS is the modern security protocol used by HTTPS to protect communication between a client and a server.

In this project, the client is usually the browser, and the server is NGINX.

TLS exists because normal network communication is not automatically private. When data travels from a browser to a server, it may pass through many points:

> Browser ->  Local network -> Router -> ISP -> Internet -> Server

Without encryption, data can potentially be inspected or modified by someone with access to part of the network path.

When the browser opens https://rmedeiro.42.fr, the browser does not immediately send the HTTP request in plain text. First, the browser and NGINX establish a secure TLS connection. Only after that secure connection exists does the browser send the HTTP request through it. This is why HTTPS is often described as ``HTTP over TLS``. That means HTTP is still used and TLS protects the HTTP communication.

Without TLS, the browser would communicate with the server using plain HTTP, where the data can be read if intercepted.

With TLS, the data is encrypted before travelling through the network.

TLS provides three important security properties:

* ``Encryption`` means transforming readable data into unreadable data before sending it through the network. Someone looking at the encrypted traffic cannot easily understand the original content. Only the browser and NGINX can understand the communication because they establish shared encryption keys during the TLS handshake. For a WordPress website, encryption is important because requests may contain login credentials, administrator actions, form submissions and personal data. Without TLS, that data could travel as readable text. With TLS, it is protected while travelling between the browser and NGINX.

* ``Authentication`` means the browser can verify the identity of the server. In this context, the browser wants to know something like: ``Am I really talking to rmedeiro.42.fr?`` This is where the certificate is used. When the browser connects to https://rmedeiro.42.fr, NGINX presents a certificate. That certificate says, conceptually: ``This server is rmedeiro.42.fr. Here is my public key. Here is information about who issued this certificate``. In a real production website, the certificate is signed by a trusted Certificate Authority. A Certificate Authority is an organization trusted by browsers and operating systems to verify domain ownership. The browser checks whether the certificate was signed by a trusted authority. If yes, the browser trusts the server identity. If not, the browser may show a warning. In Inception, the certificate is usually self-signed. That means the server generated and signed the certificate itself. The connection can still be encrypted, but the browser cannot verify the identity through a trusted external authority. That is why a browser may show a warning for local Inception website.

* ``Integrity`` means ensuring that the data was not modified silently while travelling through the network. If someone modifies encrypted TLS traffic, the browser and server can detect that the data has been altered. The connection will fail instead of accepting corrupted or modified data. This is important because encryption alone is not enough. TLS must also ensure that the encrypted data was not manipulated.

---

## What Is a Self-Signed Certificate?

A self-signed certificate is a certificate signed by its own private key instead of being signed by a trusted Certificate Authority.

In production, the trust chain is usually:

```text
Trusted Certificate Authority
        │
        ▼
Signs certificate
        │
        ▼
Browser trusts the CA
        │
        ▼
Browser trusts the certificate
```

For example, if Let's Encrypt signs a certificate for a domain, the browser trusts it because the browser already trusts Let's Encrypt.

With a self-signed certificate, the chain is different:

```text
Server creates certificate
        │
        ▼
Server signs its own certificate
        │
        ▼
Browser does not know whether to trust it
```

So the server is essentially saying: ``Trust me, I am who I say I am``. The encryption can still work. The TLS tunnel can still be established. But the browser cannot verify the server identity through a trusted third party. That is why browsers usually show a warning. The warning means: The certificate is not trusted by a known Certificate Authority. It does not necessarily mean: There is no encryption.

For Inception, a self-signed certificate is acceptable because:

* the project runs locally
* the domain is mapped manually in /etc/hosts
* the goal is to configure HTTPS manually
* a public trusted certificate is not required

---

## What Is SSL?

SSL means ``Secure Sockets Layer``.

SSL was the older security protocol used before TLS. Today, SSL is obsolete and should not be used. TLS replaced SSL. However, people still commonly say "SSL certificate" even though modern HTTPS uses TLS.

So, in practice, ``SSL certificate`` usually means ``TLS certificate``.

The name "SSL" remains common, but the modern protocol is TLS.

In an NGINX configuration, directives still use names like:

```text
ssl_certificate
ssl_certificate_key
ssl_protocols TLSv1.2 TLSv1.3;
```

Even though the directive says ssl_, the actual secure protocols used should be TLS versions.

---

## What Happens During an HTTPS Connection?

When the browser connects to NGINX using HTTPS, a TLS handshake happens before normal HTTP data is exchanged.

A handshake is a negotiation phase. During this phase, the browser and NGINX agree on how to communicate securely.

A simplified flow is:

```text
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
```

After the TLS connection is established, the browser can safely send normal HTTP requests through the encrypted channel. This is why HTTPS is often described as ``HTTP over TLS``.

---

## What Is a Certificate?

A certificate is a public file that identifies the server and contains its public key.

In this project, the certificate file is usually ``/etc/nginx/ssl/inception.crt``. 

The NGINX configuration points to it with ``ssl_certificate /etc/nginx/ssl/inception.crt;``.

A certificate usually contains:

* domain name - tells the browser which domain the certificate belongs to.
* public key - is used during the TLS process.
* issuer information and signature - tell the browser who signed the certificate.
* validity period
* organization or location

The certificate is public. It is sent to the browser during the TLS handshake. It does not need to be secret. Its purpose is to allow the browser to know which server it is talking to and to obtain the public key used in the TLS process.

A certificate is similar to an identity card. It says: ``This server claims to be rmedeiro.42.fr. Here is the public key associated with this identity``.

---

## What Is a Private Key?

The private key is the secret key that belongs to the server.

In this project, the private key file is usually ``/etc/nginx/ssl/inception.key``.

The NGINX configuration points to it with ``ssl_certificate_key /etc/nginx/ssl/inception.key;``.

The private key is linked to the public key inside the certificate. 

The public key can be shared. The private key must remain secret.

The private key is used by NGINX during the TLS handshake to prove that it owns the certificate.

A simple analogy:

```text
Certificate:
    public identity card

Private key:
    secret proof that the identity card belongs to you
```

If someone steals the private key, they may be able to impersonate the server. That is why the private key must not be:

* shared publicly
* copied into public documentation
* exposed to users

In Inception, the private key is generated locally for the container, but the concept is the same.

---

## Certificate and Private Key Together

NGINX needs both files to serve HTTPS.

The certificate alone is not enough because it only contains public information.

The private key alone is not enough because the browser also needs the certificate identity information.

Together they allow NGINX to prove its identity and establish encrypted communication.

```text
Certificate
    tells the browser who the server claims to be
    contains the public key

Private key
    proves the server owns the matching key pair
    must remain secret

TLS
    uses both during the handshake
```

If one file is missing, HTTPS cannot work correctly.

If the certificate and private key do not match, NGINX may fail to start or the TLS handshake may fail.

The certificate answers: Who am I? and the private key answers: Can I prove it?

Think about entering an airport. We show the passport to identify ourselves but anyone could steal a passport. So the airport also needs proof that the passport really belongs to us. The private key is that proof.

The certificate can be seen by everyone. The private key must never be shared.

---

## Generating the Certificate and Private Key With OpenSSL

The initialization script can generate the certificate and private key using OpenSSL:

```text
openssl req -x509 -nodes -days 365 \
	-newkey rsa:2048 \
	-keyout /etc/nginx/ssl/inception.key \
	-out /etc/nginx/ssl/inception.crt \
	-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=rmedeiro.42.fr"
```

This command is actually performing one very specific task:

* Generate a private key
* Generate a certificate
* Link them together
* Store them on disk

After execution, two files are both created:

* /etc/nginx/ssl/inception.key
* /etc/nginx/ssl/inception.crt

### openssl req

The ``req`` command is used to create certificate requests and certificates. Normally, a production workflow could be:

* Create certificate signing request
* Send request to Certificate Authority
* Certificate Authority signs it
* Receive trusted certificate

In this project, we skip the external Certificate Authority. We generate a self-signed certificate directly.

### -x509

The ``-x509`` tells OpenSSL to generate a self-signed X.509 certificate. X.509 is the standard format used for TLS certificates. Browsers, servers and TLS libraries understand this format.

### -nodes

This tells OpenSSL not to encrypt the private key with a passphrase. This is useful in Docker because NGINX must start automatically.

If the private key required a passphrase, NGINX would ask for it and stop at startup for manual input. That would break container automation.

So -nodes allows NGINX to read the private key without human interaction input.

### -days 365

This sets the certificate validity period to 365 days. After that, the certificate expires. An expired certificate will usually produce browser warnings.

### -newkey rsa:2048

This creates a new RSA private key with a size of 2048 bits. For Inception, it is mainly used for server authentication and TLS certificate generation. RSA is an asymmetric cryptography algorithm. Asymmetric means it uses a key pair:

* public key
* private key

The number 2048 defines the key size. Larger keys are usually stronger but more computationally expensive. For a local Inception project, 2048 is acceptable.

### -keyout

The ``-keyout /etc/nginx/ssl/inception.key`` tells OpenSSL where to write the private key. Writes the private key to ``/etc/nginx/ssl/inception.key``.

This file contains secret cryptographic information. NGINX uses this file internally during TLS handshakes.

### -out

The ``-out /etc/nginx/ssl/inception.crt`` tells OpenSSL where to write the certificate. Writes the certificate key to ``/etc/nginx/ssl/inception.crt``.

Unlike the private key, the certificate is public. Every browser that connects to NGINX receives a copy of the certificate. It does NOT contain the private key. Only the public key.

### -subj

The ``-subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=rmedeiro.42.fr"`` fills the certificate indentity information without interactive prompts. Normally OpenSSL would ask questions interactively:

* Country?
* State?
* Organization?
* Common Name?

The -subj option answers them automatically.

The fields mean:

```text
C   = Country
ST  = State or region
L   = Locality or city
O   = Organization
OU  = Organizational Unit
CN  = Common Name
```

The most important field is ``CN=rmedeiro.42.fr``, because it identifies the domain name.

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

This instruction copies the custom NGINX initialization script from the project directory on the host machine into the Docker image.

At this point in the Dockerfile, the image already contains the base operating system, NGINX and OpenSSL. However, having NGINX installed is not enough. NGINX is only the web server program. It still needs to be configured for the specific needs of the Inception project.

The role of this script is to prepare NGINX when the container starts.

The Dockerfile installs the tools and the script configures the service.

A good way to separate the responsibilities is:

```text
Dockerfile
    installs NGINX
    installs OpenSSL
    copies the init script
    makes the init script executable

init_nginx.sh
    checks required environment variables
    creates SSL/TLS certificate files if needed
    creates the NGINX configuration file
    tells NGINX how to reach WordPress/PHP-FPM
    starts NGINX in the foreground
```

Without this script, the container would have NGINX installed, but it would not know how to serve the Inception website correctly.

It would not know:

* which domain name to use
* which port to listen on
* where the WordPress files are stored
* where the SSL certificate is located
* where the private key is located
* where PHP-FPM is running
* how to forward PHP requests to WordPress

That specific configuration is created by init_nginx.sh.

The syntax is: COPY <source> <destination>

In this case:

```text
Source:
	./tools/init_nginx.sh

Destination:
	/usr/local/bin/init_nginx.sh
```

The source file exists in the project directory on the host machine. During the image build, Docker reads this file and physically copies it from the host machine into the Docker image filesystem. After the copy, the image contains: ``/usr/local/bin/init_nginx.sh``. Every container created from this image will contain this script.

The directory ``/usr/local/bin`` is commonly used in Linux for custom executable scripts installed manually by the developer or administrator. It is normally included in the system PATH. PATH is an environment variable that contains the list of directories where Linux searches for commands.
The Linux shell automatically searches these directories when a command is executed.

So, as the script is inside /usr/local/bin, Docker can later execute ``ENTRYPOINT ["init_nginx.sh"]`` instead of needing the full path. The script becomes available as a normal command inside the container.

The script now becomes part of the image itself. Every container created from this image will automatically contain that script.

So, this line transforms a generic Debian container with NGINX installed into a fully configured web server capable of serving the Inception website.

---

## Why the Initialization Script Is Needed

The script is needed because NGINX needs configuration that depends on runtime values.

Runtime means the moment when the container is actually started with: docker compose up. So, the script runs when the container starts. Otherwise, the Dockerfile runs during image build time.

During image build time, Docker does not yet have the final runtime context and some important values do not exist. They only exist when Docker Compose starts the container. Examples:

```text
DOMAIN_NAME
PHP_FPM_HOST
PHP_FPM_PORT
WordPress container name
Mounted WordPress volume
Generated SSL certificate path
SSL certificate path
SSL private key path
WordPress volume mounted at /var/www/html
Docker network
```

These values may come from:

```text
.env
docker-compose.yml
container environment variables
Docker volumes
Docker network
```

The script can use these values to generate a correct NGINX configuration. For example:

```text
server_name rmedeiro.42.fr;
fastcgi_pass wordpress:9000;
ssl_certificate /etc/nginx/ssl/inception.crt;
ssl_certificate_key /etc/nginx/ssl/inception.key;
```

It depends on how the Docker Compose services are named and how the domain is configured.

That is why this logic belongs in the script, not directly in the Dockerfile. Without this script, the image would contain:

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

## Why NGINX Needs a Configuration File

NGINX is controlled by configuration files.

The NGINX binary itself is only the program.

The configuration file tells the program how to behave.

Without a configuration file, NGINX does not know:

* which port to listen on 
* which domain to serve 
* where the website files are 
* whether HTTPS should be enabled 
* where the certificate is stored 
* where the private key is stored 
* how PHP files should be handled 
* where PHP-FPM is running

In this project, the script usually creates a file such as: ``/etc/nginx/conf.d/default.conf``.

This file becomes the main website server configuration for the container.

The NGINX configuration depends on values that only exist when the container starts.

---

## Example NGINX Configuration

```text
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

This configuration connects four important parts of the infrastructure:

```text
Browser
    connects to NGINX on HTTPS port 443

NGINX
    reads files from /var/www/html

NGINX
    uses certificate and private key for TLS

NGINX
    forwards PHP requests to WordPress/PHP-FPM on wordpress:9000
```

This configuration connects the public web server to the internal WordPress container.

``root /var/www/html``: This lets NGINX read the WordPress files from the shared volume.

``try_files $uri $uri/ /index.php?$args``: This allows WordPress routes and permalinks to work.

``fastcgi_pass wordpress:9000``: This forwards PHP execution to PHP-FPM inside the WordPress container.

``fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name``: - This tells PHP-FPM which file to execute.

Together, they create the request flow:

```text
Browser
   │
   │ HTTPS
   ▼
NGINX
   │
   ├── Static file?
   │       └── Serve directly from /var/www/html
   │
   └── PHP or dynamic route?
           └── Send to WordPress/PHP-FPM
                    │
                    ▼
                WordPress executes PHP
                    │
                    ▼
                MariaDB may be queried
                    │
                    ▼
                HTML is generated
                    │
                    ▼
                NGINX returns response
```

NGINX is the secure public gateway that knows how to receive browser requests and route them correctly to the internal services.

Without this configuration file, NGINX would not know how to act as the front server of the Inception project.

---

## server

The block:

```text
server {
	...
}
```

The server block defines a virtual server. A virtual server is basically a website definition.

NGINX can host multiple websites at the same time. Each website can have its own server block.

For example:

```text
server {
	server_name site1.com;
}

server {
	server_name site2.com;
}
```

In Inception, one server block is enough because the Inception website uses one domain, so we usually only need one website, so we create one server block for ``rmedeiro.42.fr``.  This block tells NGINX: ``When a request for this domain arrives, use these rules``.

Everything inside this block tells NGINX how to serve that website.

### listen 443 ssl

The listen directive tells NGINX which port it should accept connections on. This tells NGINX to listen for incoming connections on port 443. Port 443 is the standard port for HTTPS.

The ssl part tells NGINX that this server block uses TLS/SSL. So this line means: ``Accept HTTPS connections on port 443``.

Without this line, NGINX would not listen for HTTPS traffic on port 443.

If we only had: ``listen 80;``, then NGINX would listen for plain HTTP instead.

In Inception, the subject expects HTTPS, so the important port is 443. The browser connects to: https://rmedeiro.42.fr and because HTTPS normally uses port 443, the request reaches this server block, which reaches NGINX on port 443.

### server_name

``server_name rmedeiro.42.fr;`` tells NGINX which domain name this server block belongs to.

When a browser sends a request, it includes the domain name in the Host header.

Example:

```text
GET / HTTP/1.1
Host: rmedeiro.42.fr
```

NGINX reads the Host header and compares the value with the configured server_name. If it matches:

```text
Host header:
    rmedeiro.42.fr

server_name:
    rmedeiro.42.fr
```

then NGINX knows this server block should handle the request and uses this configuration. 

This is especially useful when one NGINX instance hosts multiple websites. In Inception, it makes the configuration explicit and tied to the project domain.

So this directive connects the domain name to the correct website configuration.

### root

The root directive: ``root /var/www/html;`` defines the website root directory. This is the directory where NGINX will look for website files.

In this project, WordPress files are stored in ``/var/www/html``. This directory is shared between the WordPress container and the NGINX container through a Docker volume

For example, if the browser requests ``/logo.png``, NGINX will look for ``/var/www/html/logo.png``. If the browser requests ``/wp-content/uploads/image.png``, NGINX will look for ``/var/www/html/wp-content/uploads/image.png``. 

This is why /var/www/html is important. It is the shared WordPress directory. The WordPress container writes WordPress files there and the NGINX container reads WordPress files from there.

The shared volume makes this possible:

```text
WordPress container
    writes /var/www/html/index.php

NGINX container
    reads /var/www/html/index.php
```

Without the shared volume, NGINX would not see the WordPress files.

So root defines the base directory used to resolve requested files.

### index

``index index.php index.html;`` tells NGINX which default files to use when the browser requests a directory.

For example, when the browser requests https://rmedeiro.42.fr/, it is requesting for the root directory ``/`` of the site. NGINX then tries for default index files such as:

* index.php
* index.html

inside the configured root. So it checks:

* /var/www/html/index.php
* /var/www/html/index.html

For WordPress, index.php is very important because it is the main entry point of the application. Most dynamic WordPress requests eventually pass through index.php.

### ssl_certificate

``ssl_certificate /etc/nginx/ssl/inception.crt;`` tells NGINX where the TLS certificate is stored. The certificate is sent to the browser during the TLS handshake. It identifies the server and contains the public key. In this project, the certificate is generated by the initialization script using OpenSSL. Without a certificate, NGINX cannot properly serve HTTPS.

### ssl_certificate_key

``ssl_certificate_key /etc/nginx/ssl/inception.key;`` tells NGINX where the private key is stored. 

The private key is used together with the certificate during the TLS handshake. NGINX uses this key during the TLS handshake to prove that it owns the certificate. The certificate is public and the private key must remain secret.

NGINX needs both files. If the certificate and private key do not match, HTTPS will fail. If the private key is missing, NGINX cannot complete the TLS setup.

So these two directives work together. They enable NGINX to serve HTTPS.

### location /

```text
location / {
	try_files $uri $uri/ /index.php?$args;
}
```

A location block tells NGINX how to handle specific request paths. The ``location /`` block handles general website requests. The ``/`` means it applies to normal requests under the root of the site.

Examples:

```text
/
 /about
 /contact
 /blog/my-post
 /wp-content/uploads/logo.png
```

Inside this block, the most important directive is ``try_files $uri $uri/ /index.php?$args;``.

### try_files

``try_files $uri $uri/ /index.php?$args;`` tells NGINX to try three different possibilities in order.

First: ``$uri``, NGINX tries to find the exact requested path as a real file.

```text
Request:
    /wp-content/uploads/logo.png

NGINX tries:
    /var/www/html/wp-content/uploads/logo.png
```

If the file exists, NGINX serves it directly. This is how static files are served efficiently.

Second: ``$uri/``, NGINX tries to find the requested path as a directory if the exact file does not exist.

```text
Request:
    /wp-admin

NGINX tries:
    /var/www/html/wp-admin/
```

If that directory exists, NGINX can continue processing according to index rules.

Third: ``/index.php?$args``, if neither a file nor a directory exists, NGINX forwards the request to index.php.

This is what allows WordPress permalinks to work.

```text
Request:
    /about
```

There is usually no real file /var/www/html/about. These path usually do not exist as real file inside /var/www/html, but WordPress can generate dynamically the /about page. So NGINX sends the request to /index.php and WordPress decides what content to show and preserves query arguments using $args. For example, /search?s=nginx keeps s=nginx. This allows WordPress to receive the original request information and decide which page to generate.

Without try_files, many WordPress URLs and permalinks would not work correctly.

### location ~ .php$

```text
location ~ \.php$ {
	include fastcgi_params;
	fastcgi_pass wordpress:9000;
	fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}
```

This block handles PHP files. The expression: ``~ \.php$`` means: Match requests that end with .php.

Examples:

```text
/index.php
/wp-login.php
/wp-admin/index.php
```

When such a request is detected, NGINX does not serve the PHP file as plain text. Instead, it forwards the request to PHP-FPM.

If NGINX served PHP files as plain text, users could see PHP source code, which would be a serious security problem.

PHP files must be executed, not displayed.

So, NGINX does not execute PHP itself. So when a PHP file is requested, NGINX forwards it to PHP-FPM.

``include fastcgi_params;`` includes a predefined file containing common FastCGI parameters provided by NGINX. These parameters pass important request information from NGINX to PHP-FPM, such as:

* request method
* query string
* content type
* content length
* server protocol
* server port
* request URI

PHP-FPM needs this information to correctly understand and execute the PHP request.

Without these parameters, PHP-FPM would not receive enough context to execute the PHP request properly.

``fastcgi_pass wordpress:9000;`` tells NGINX where PHP-FPM is located and where to send the PHP requests. 

In this project, ``wordpress`` is the Docker Compose service name of the WordPress container. Docker provides internal DNS, so NGINX can resolve wordpress to the WordPress container IP address. The port 9000 is where PHP-FPM listens inside WordPress container.

So this directive means: Send PHP requests to PHP-FPM inside the WordPress container.

This line is the bridge between NGINX and WordPress.

Without this directive, NGINX would not know where to send PHP files.

``fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;`` tells PHP-FPM the full path of the PHP file that must be executed. 

The variable $document_root contains the value from the root directive. In this case: /var/www/html.

The variable $fastcgi_script_name contains the requested PHP script path. For example: /index.php.

Together, $document_root$fastcgi_script_name, becomes /var/www/html/index.php. So PHP-FPM receives SCRIPT_FILENAME=/var/www/html/index.php. This tells PHP-FPM exactly which PHP file to execute.

PHP-FPM needs this because it receives a FastCGI request, not a normal browser request. It must know the real filesystem path of the PHP file.

Without SCRIPT_FILENAME, PHP-FPM may not know which file to execute, and PHP requests may fail. PHP-FPM might receive the request but not know which file to run.

---

# Making the Script Executable

```Dockerfile
RUN chmod +x /usr/local/bin/init_nginx.sh
```

This instruction gives execution permission to the initialization script.

After the copy, the file physically exists inside the image filesystem:

```text
Container Filesystem
│
└── /usr/local/bin/
        └── init_nginx.sh
```

However, Linux still sees it simply as a file. At this point Linux knows that a file exists, but Linux does not necessarily know that this file should be executed. The file may contain shell commands, but without execute permission Linux treats it as ordinary data. Merely existing is not enough. 

So, copying a script into the image does not automatically guarantee that Linux can execute it. A file can exist and still not be executable.

The operating system must also allow execution.

Linux permissions control what can be done with a file. Without this line, Docker could fail when starting the container with an error like: Permission denied. This would happen because the ENTRYPOINT tries to execute the file directly.

---

# EXPOSE 443

```Dockerfile
EXPOSE 443
```

This instruction declares that the NGINX container is designed to listen for incoming connections on port 443.

As we know, Docker containers have their own isolated networking environment. This means that each container has:

* its own network interfaces;
* its own IP address inside the Docker network;
* its own ports;
* its own routing tables.

For example:

```text
NGINX Container: Port 443

WordPress Container: Port 9000

MariaDB Container: Port 3306
```

EXPOSE does not actually publish the port. EXPOSE helps describe the intended behavior of the container. It tells which ports are expected to be used.

The NGINX container can listen on port 443, the WordPress on port 9000 and MariaDB on port 3306. All simultaneously.

Each container can use the same port numbers without conflict because they are isolated from each other.

As EXPOSE 3306 means: This image runs a database server and EXPOSE 9000 means: This image runs PHP-FPM, EXPOSE 443 means: This image is intended to run an HTTPS service.

When Docker sees EXPOSE 443, it stores metadata inside the image. That metadata essentially says: "The application inside this image is expected to use port 443". This information becomes part of the image description. Docker now knows that the intended network service runs on port 443. 

When we say: NGINX listens on port 443, it means that NGINX is continuously waiting for incoming connections on that port.

Whenever a browser tries to connect:

> Browser -> Port 443 -> NGINX

the operating system delivers that connection to NGINX.

In the Inception project, NGINX listens on 443 because Port `443` is the standard HTTPS port.

A very common misconception is that EXPOSE 443 opens port 443. This is not true.

The EXPOSE instruction does not open any port, does not publish any port to the host machine, and does not make the container reachable from the Internet.

EXPOSE does not:

* Open firewall rules
* Publish the port
* Allow Internet access
* Create host mappings
* Forward traffic
* Make the container reachable

The container remains isolated. External users still cannot connect to it.

---

## What Is A Network Port?

When two computers communicate over a network, they need a way to identify not only the machine they want to reach, but also the specific service running on that machine.

An IP address identifies the machine, for example 192.168.1.50. But a single machine can run many services simultaneously:

```text
NGINX
MariaDB
SSH
FTP
DNS
```

If a request arrives at the machine, how does the operating system know which service should receive it? That is exactly why ports exist. A port identifies a specific service running on a machine. For example:

```text
SSH      192.168.1.50:22

HTTP     192.168.1.50:80

HTTPS    192.168.1.50:443

MariaDB  192.168.1.50:3306
```

Think of the IP address as a building address and the port as an apartment number. The building identifies where the request should go and the apartment identifies who inside the building should receive it.













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
