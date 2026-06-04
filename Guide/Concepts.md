# Docker Concepts for Inception

This document explains the most important Docker concepts needed to understand the **Inception** project.

---

# 1. Why Do We Need Docker?

Imagine that we create a WordPress website on our computer.

For that website to work, we need several things installed and configured correctly:

* A Linux system.
* Nginx.
* PHP.
* PHP-FPM.
* MariaDB.
* WordPress files.
* Database users.
* Configuration files.
* Correct ports.
* Correct permissions.
* Environment variables.
* TLS certificates.

If everything is installed directly on the system, the project may work on our machine but fail on another machine.

For example, on our computer we may have:

```text
PHP 8.2
MariaDB installed
Nginx configured correctly
Correct permissions
```

But on another computer, there may be:

```text
Different PHP version
Missing PHP extensions
No MariaDB installed
Wrong Nginx configuration
Different filesystem permissions
```

The application itself may be correct, but the environment is different. That is the problem Docker solves.

Docker allows us to describe the environment needed by each service and package it in a reproducible way.

Instead of saying:

> “Install PHP, configure MariaDB, install Nginx, copy these files, fix permissions, create users manually...”

we write Dockerfiles and a `docker-compose.yml`.

Then Docker can recreate the same environment again and again.

The important idea is:

```text
The project should not depend on what happens to be installed on the host.
The project should define its own environment.
```

For Inception, this is essential because the evaluator must be able to build and run the project in a clean VM.

---

# 2. What Is Docker?

Docker is a platform that allows us to run applications inside isolated environments called **containers**.

A container is like a small, controlled environment created specifically for one application or one service.

For example, in Inception, instead of installing MariaDB, Nginx and WordPress and PHP-FPM directly on the Debian VM, we create their containers.

So the Debian VM contains Docker, and Docker runs the services.

The structure is:

```text
Debian VM
└── Docker Engine
    ├── MariaDB container
    ├── WordPress container
    └── Nginx container
```

Each container is isolated.

This means that MariaDB has its own filesystem, WordPress has its own filesystem, and Nginx has its own filesystem.

They are not completely separate machines, but they behave like separate environments for most practical purposes.

Technically, containers are not virtual machines. They do not emulate a full operating system.

Instead, containers use the host Linux kernel, but Docker isolates their processes, filesystems, networks, and resources using Linux features such as namespaces and cgroups.

Simple explanation:

```text
Virtual Machine = full operating system inside another operating system
Container       = isolated process using the host kernel
```

That is why containers are usually lighter and faster than virtual machines.

---

# 3. Docker Is Not a Virtual Machine

This is a very important concept.

A lot of people first think that a container is the same thing as a virtual machine. It is not.

A virtual machine includes a complete operating system with its own kernel.

For example:

```text
Physical computer
└── VirtualBox
    └── Debian VM
        └── Linux kernel
```

The VM has its own operating system. A Docker container does not contain a full independent kernel.
A container uses the kernel of the host system.

For Inception, the host is the Debian VM. So the containers use the Linux kernel of the Debian VM.

That means:

```text
Debian VM kernel
├── MariaDB container process
├── WordPress container process
└── Nginx container process
```

From the outside, containers feel like small machines. But technically, they are isolated processes.

This is why containers start quickly. Docker does not need to boot a full OS every time.
It only starts a process inside an isolated environment.

---

# 4. What Is a Docker Image?

A Docker image is a template used to create containers.

A simple way to understand it:

```text
Image      =  recipe
Container  =  cake made from the recipe
```

The image contains all the instructions and files needed to create a container.

For example, a MariaDB image may contain:

* Debian base system.
* MariaDB installed.
* MariaDB configuration file.
* Initialization script.
* Correct startup command.

But the image itself is not running. It is only stored on disk.

When we run a container from that image, Docker creates a running instance of it.

Example: ``docker build -t mariadb`` builds an image, then ``docker run mariadb`` creates and starts a container from that image.

In programming terms:

```text
Class   =  Image
Object  =  Container
```

One image can create many containers.

For example, one Nginx image could create several Nginx containers.

In Inception, we normally create one container per service.

---

# 5. What Is a Docker Container?

A Docker container is a running instance of an image.

If the image is the recipe, the container is the actual running application.

For example:

```text
MariaDB image
    |
    v
MariaDB container
```

The container has:

* Its own filesystem.
* Its own main process.
* Its own environment variables.
* Its own network interface.
* Its own mounted volumes.
* Its own runtime state.

However, the container should be treated as temporary. A container can be deleted and recreated at any time.

If important data exists only inside the container, that data can be lost. That is why Inception uses volumes.

MariaDB data must not live only inside the MariaDB container.
WordPress files must not live only inside the WordPress container.

They must be stored in persistent volumes mapped to:

```text
/home/rmedeiro/data/mariadb
/home/rmedeiro/data/wordpress
```

The container can disappear. The data must remain.

---

# 6. What Is a Dockerfile?

A Dockerfile is a text file that contains instructions for building a Docker image.

It tells Docker how to prepare the environment.

Example:

```dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/init_mariadb.sh /bin/init_mariadb.sh

RUN chmod +x /bin/init_mariadb.sh

ENTRYPOINT ["/bin/init_mariadb.sh"]
```

`FROM` defines the base image.

```dockerfile
FROM debian:bookworm
```

This means the image starts from Debian Bookworm.

`RUN` executes commands during the build.

```dockerfile
RUN apt-get update && apt-get install -y mariadb-server
```

This installs MariaDB inside the image.

`COPY` copies files from the project into the image.

```dockerfile
COPY tools/init_mariadb.sh /bin/init_mariadb.sh
```

This places the initialization script inside the image.

`ENTRYPOINT` defines the command that runs when the container starts.

```dockerfile
ENTRYPOINT ["/bin/init_mariadb.sh"]
```

This means that when the container starts, Docker executes the script.

A Dockerfile does not run the final application immediately.
It describes how to build the image that will later run the application.

---

# 7. Build Time vs Runtime

This is one of the most important Docker concepts.

There is a difference between what happens when the image is built and what happens when the container starts.

## Build Time

Build time happens when we run: ``docker compose build``

At build time, Docker reads the Dockerfile and creates the image.

Examples of build-time actions:

* Installing packages.
* Copying configuration files.
* Copying scripts.
* Creating folders.
* Setting permissions.
* Preparing the base filesystem.

Example: ``RUN apt-get install -y nginx`` happens during image creation.

## Runtime

Runtime happens when we start a container.

Example: ``docker compose up``

At runtime, the container starts its main process.

Examples of runtime actions:

* Reading secrets from `/run/secrets`.
* Reading environment variables.
* Starting MariaDB.
* Starting PHP-FPM.
* Starting Nginx.
* Creating a database if it does not exist.
* Installing WordPress if files are missing.

This distinction matters a lot.

Passwords should not be copied into the image at build time.

Why?

Because images can be inspected later.
If a password is copied into an image, it may remain in the image layers.
That is why secrets are read at runtime, not build time.

Bad idea:

```dockerfile
ENV MYSQL_PASSWORD=1234
```

Better idea:

```bash
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
```

This reads the password only when the container starts.

---

# 8. What Is Docker Compose?

Running one container manually is easy.

For example: ``docker run nginx``

But Inception does not have only one container.
It has several services:

* Nginx.
* WordPress.
* MariaDB.

Each service needs configuration.

MariaDB needs:

* A database volume.
* Environment variables.
* Secrets.
* A network.

WordPress needs:

* Access to MariaDB.
* WordPress files volume.
* PHP-FPM.
* Secrets.
* Environment variables.

Nginx needs:

* Access to WordPress.
* TLS configuration.
* Port 443 exposed.

Managing all of this manually with `docker run` commands would be difficult.
Docker Compose solves this.

Docker Compose allows us to define the whole infrastructure in one file: ``docker-compose.yml``

Instead of writing many long commands, we write a structured configuration file.
Then we can start everything with ``docker compose up``.

Compose reads the file and creates:

* Containers.
* Networks.
* Volumes.
* Secret mounts.
* Port mappings.
* Service relationships.

For Inception, Docker Compose is mandatory because the project is a multi-container infrastructure.

---

# 9. What Is a Service in Docker Compose?

In Docker Compose, a service is the definition of a container.

Example:

```yaml
services:
  mariadb:
    build: ./requirements/mariadb
    container_name: mariadb
```

Here, `mariadb` is a service.

It tells Docker Compose:

* How to build the image.
* What container name to use.
* Which volumes to mount.
* Which networks to connect to.
* Which secrets to provide.
* Which environment variables to use.

A service is not exactly the same thing as a container, but in Inception, each service normally creates one container.

So we can think like this:

```text
Compose service definition → container created from that definition
```

Example:

```yaml
services:
  nginx:
    build: ./requirements/nginx
    container_name: nginx
```

This defines the Nginx service.

When we run ``docker compose up`` Compose creates the `nginx` container from this service definition.

---

# 10. Why Inception Uses Three Containers

Inception separates the infrastructure into multiple containers because each service has a different responsibility.

## MariaDB Container

MariaDB is responsible for storing data.

WordPress stores posts, users, settings, comments, and metadata in MariaDB.

MariaDB should not serve web pages.
It should only manage the database.

## WordPress Container

The WordPress container usually runs PHP-FPM.

PHP-FPM executes PHP code.

WordPress itself is a PHP application, so when a request needs PHP processing, Nginx passes that request to PHP-FPM.

The WordPress container should not expose HTTPS directly.
It should focus on running PHP.

## Nginx Container

Nginx is the web server.

It receives browser requests.

It handles TLS.

It serves static files when possible.

It forwards PHP requests to WordPress/PHP-FPM.

Nginx is the only service that should expose port `443` to the outside.

This separation creates a clean architecture:

```text
Browser
  -> Nginx
  -> WordPress / PHP-FPM
  -> MariaDB
```

Technically, this is a common web architecture:

* Nginx handles HTTP/HTTPS.
* PHP-FPM executes PHP.
* MariaDB stores persistent data.

---

# 11. What Is Nginx?

Nginx is a web server.

A web server receives requests from browsers and sends responses back.

For example, when we open:

```text
https://rmedeiro.42.fr
```

the browser sends an HTTPS request.

Nginx receives that request.

Then Nginx decides what to do.

If the request is for a static file, like an image or CSS file, Nginx can serve it directly.

If the request needs PHP execution, Nginx forwards it to PHP-FPM in the WordPress container.

Nginx does not execute PHP itself.
That is why PHP-FPM is needed.

In Inception, Nginx also handles TLS.
This means Nginx is responsible for HTTPS encryption.
The browser communicates securely with Nginx using TLS.

---

# 12. What Is PHP-FPM?

PHP-FPM means **PHP FastCGI Process Manager**.

It is a service that runs PHP code.

Nginx cannot execute PHP directly.
So when Nginx receives a request for a PHP file, it sends that request to PHP-FPM.
PHP-FPM executes the PHP code and returns the result to Nginx.
Then Nginx sends the final response to the browser.

For WordPress, this is essential because WordPress is written in PHP.
The flow is:

```text
Browser asks for WordPress page
Nginx receives request
Nginx sends PHP request to PHP-FPM
PHP-FPM executes WordPress code
WordPress talks to MariaDB if needed
PHP-FPM returns generated HTML
Nginx sends HTML to browser
```

This is why the WordPress container usually runs PHP-FPM instead of Nginx.
Nginx and PHP-FPM are separated into different containers.

---

# 13. What Is MariaDB?

MariaDB is a relational database management system.

WordPress uses MariaDB to store most of its important information.

Examples:

* Users.
* Password hashes.
* Posts.
* Pages.
* Comments.
* Site settings.
* Plugin settings.
* Theme settings.

The database is not just optional.
Without MariaDB, WordPress cannot work correctly.

When WordPress starts, it needs database credentials:

* Database host.
* Database name.
* Database user.
* Database password.

In Docker Compose, the database host is usually the service name: ``mariadb``

This works because Docker networks provide internal DNS.
So WordPress can connect to MariaDB using: ``mariadb:3306`` instead of using an IP address.

---

# 14. What Are Docker Networks?

Docker networks allow containers to communicate with each other.

By default, containers are isolated.
If WordPress needs to connect to MariaDB, both containers must be on the same Docker network.

Docker Compose usually creates a network automatically.

Example:

```yaml
networks:
  inception:
    driver: bridge
```

Then services can use it:

```yaml
services:
  mariadb:
    networks:
      - inception

  wordpress:
    networks:
      - inception

  nginx:
    networks:
      - inception
```

When containers are on the same Compose network, they can reach each other by service name.
That means WordPress can use: ``mariadb`` as the database host. Nginx can use: ``wordpress`` as the PHP-FPM host.

This is better than using IP addresses because container IPs can change. Service names remain stable.

Important idea:

```text
Inside Docker network:
service name  =  hostname
```

So if the service is called `mariadb`, other containers can connect to `mariadb`.

---

# 15. What Are Docker Volumes?

Containers are temporary.

If we delete a container, its internal filesystem is deleted too.

This is dangerous for services that store data.

MariaDB stores database files.
WordPress stores website files.

If those files exist only inside containers, deleting containers would delete the website.

Volumes solve this problem.

A volume stores data outside the container lifecycle.

For Inception, the subject requires data under:

```text
/home/login/data
```

For this project:

```text
/home/rmedeiro/data
```

Usually:

```text
/home/rmedeiro/data/mariadb
/home/rmedeiro/data/wordpress
```

MariaDB data is stored in:

```text
/home/rmedeiro/data/mariadb
```

WordPress files are stored in:

```text
/home/rmedeiro/data/wordpress
```

The containers can be destroyed and recreated, but the data remains.

This is the difference:

```text
Container filesystem = temporary
Volume data          = persistent
```

This is why volumes are one of the most important parts of Inception.

---

# 16. Named Volumes vs Bind Mounts

Docker supports different ways to store persistent data.

Two important concepts are:

* Named volumes.
* Bind mounts.

A named volume is managed by Docker.

Example:

```yaml
volumes:
  mariadb:
```

Docker decides where to store it internally.

A bind mount maps a specific host directory into a container.

Example:

```yaml
volumes:
  mariadb:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/rmedeiro/data/mariadb
```

In this case, Docker uses the real host path:

```text
/home/rmedeiro/data/mariadb
```

This is important for Inception because the subject expects persistent data under `/home/login/data`.

So even if we declare a named volume called `mariadb`, we configure it as a bind mount to the required host directory.

The result is:

```text
Docker volume name: mariadb
Real location:     /home/rmedeiro/data/mariadb
```

This satisfies the idea of Docker volumes while storing data in the required path.

---

# 17. What Is TLS?

TLS is the protocol used to encrypt HTTPS traffic.

When a website uses:

```text
https://
```

the connection is encrypted with TLS.

In Inception, Nginx must serve the website using HTTPS.

This means Nginx needs:

* A certificate.
* A private key.
* TLS configuration.

Usually, for a local project, we use a self-signed certificate.

A self-signed certificate is not trusted by browsers by default, because it was not issued by a public certificate authority.

The browser may show a warning.

That is normal for this project.

The important part is that the connection uses TLS.

In the Nginx configuration, we usually allow:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

This means only TLS 1.2 and TLS 1.3 are accepted.

Older protocols such as SSLv3, TLS 1.0, and TLS 1.1 should not be used.

---

# 18. What Is Port Mapping?

Containers have their own internal network.

A service inside a container can listen on a port, but that does not automatically expose it to the host machine.

Port mapping connects a port on the host to a port inside the container.

For Inception, Nginx should expose port `443`.

Example:

```yaml
ports:
  - "443:443"
```

This means:

```text
Host port 443 -> Container port 443
```

So when the browser accesses:

```text
https://rmedeiro.42.fr
```

the request reaches port `443` on the host, and Docker forwards it to port `443` inside the Nginx container.

MariaDB should not expose port `3306` to the outside.

WordPress/PHP-FPM should not expose port `9000` to the outside.

They only need to communicate internally through the Docker network.

That is an important security and architecture concept.

Only Nginx should be public.

---

# 22. What Is `depends_on`?

In Docker Compose, `depends_on` defines startup order.

Example:

```yaml
services:
  wordpress:
    depends_on:
      - mariadb
```

This means Docker Compose starts MariaDB before WordPress.

However, this does not guarantee that MariaDB is fully ready to accept connections.

It only means the MariaDB container was started first.

That is why WordPress startup scripts often need to wait until MariaDB is actually ready.

For example, the script may retry connecting to MariaDB before installing WordPress.

Important distinction:

```text
Container started ≠ service ready
```

MariaDB may be started but still initializing.

So `depends_on` is useful, but it is not a complete readiness check.

---

# 23. What Is a Restart Policy?

A restart policy tells Docker what to do if a container stops.

Example:

```yaml
restart: always
```

This means Docker should restart the container if it crashes or if the Docker daemon restarts.

For Inception, this is useful because services should recover automatically.

Common policies:

| Policy           | Meaning                                           |
| ---------------- | ------------------------------------------------- |
| `no`             | Do not restart automatically                      |
| `always`         | Always restart the container                      |
| `on-failure`     | Restart only if the container exits with an error |
| `unless-stopped` | Restart unless the user manually stopped it       |

For Inception, many students use:

```yaml
restart: always
```

This helps ensure that services remain running after failures or VM restarts.

---

# 24. How the Whole Inception Stack Works

When everything is correctly configured, the project works like this.

The browser opens:

```text
https://rmedeiro.42.fr
```

The system checks `/etc/hosts` and resolves the domain to:

```text
127.0.0.1
```

The request reaches the Debian VM on port `443`.

Docker forwards port `443` to the Nginx container.

Nginx receives the HTTPS request.

If the request needs PHP, Nginx forwards it to PHP-FPM in the WordPress container.

WordPress executes PHP code.

If WordPress needs data, it connects to MariaDB using the hostname:

```text
mariadb
```

MariaDB reads or writes data in its persistent volume.

The response travels back:

```text
MariaDB -> WordPress/PHP-FPM -> Nginx -> Browser
```

The user sees the WordPress page.

This is the final goal of Inception.

---
