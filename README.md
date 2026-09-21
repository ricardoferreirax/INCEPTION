*This project has been created as part of the 42 curriculum by rmedeiro.*

# Inception

## Description

**Inception** is a system administration project developed as part of the 42 curriculum. Its main objective is to introduce the concepts of containerization, service isolation, networking, persistent storage and infrastructure configuration using **Docker** and **Docker Compose**.

The project consists of building a complete web infrastructure inside a **virtual machine**. Instead of installing and running every application directly on the same operating system, the infrastructure is divided into multiple services, with each service running inside its own Docker container.

The mandatory infrastructure is composed of three main services:

* **NGINX** — acts as the public entry point and provides secure HTTPS access using TLS 1.2 and TLS 1.3.
* **WordPress + PHP-FPM** — provides the dynamic website and administration interface.
* **MariaDB** — provides the relational database used by WordPress.

The main communication flow is:

```text
 User
  |
  | HTTPS :443
  v
NGINX
  |
  | FastCGI :9000
  v
WordPress + PHP-FPM
  |
  | SQL :3306
  v
MariaDB
```

When a user accesses the website, the request first reaches NGINX. Static content can be served directly, while PHP requests are forwarded to the WordPress container through PHP-FPM. WordPress communicates with MariaDB whenever information must be read from or written to the database.

The services communicate through a Docker bridge network instead of depending on fixed container IP addresses. Docker's internal DNS allows containers to locate each other using their service names.

Persistent information is stored outside the containers. The MariaDB database and WordPress files are mapped to directories on the host, allowing containers to be stopped, removed and recreated without automatically losing application data.

All service images are built from the project's own Dockerfiles using **Debian 12 (Bookworm)** as their base image. Docker Compose brings these individual services together by defining their configuration, networking, volumes, secrets, dependencies and startup behavior.

---

## Project Structure

Inception's project separates the infrastructure configuration, individual services, credentials and documentation:

```text
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   ├── db_root_password.txt
│   ├── db_password.txt
│   ├── wp_admin_password.txt
│   ├── wp_user_password.txt
│   └── ftp_password.txt
└── srcs/
    ├── docker-compose.yml
    ├── .env
    └── requirements/
        ├── mariadb/
        ├── nginx/
        ├── wordpress/
        └── bonus/
            ├── redis/
            ├── adminer/
            ├── ftp/
            ├── static/
            └── portainer/
```

This structure keeps each service independent while Docker Compose provides a single configuration for the complete infrastructure.

---

## Design Choices

The infrastructure uses several Docker features to provide isolation, security, networking and persistence. Understanding why these mechanisms are used and how they differ from their alternatives is an important part of the project.

### Virtual Machines vs Docker

A **Virtual Machine (VM)** virtualizes an entire computer. A hypervisor provides virtual hardware such as CPU, memory, storage and network interfaces, and each VM runs its own operating system with its own kernel. It virtualizes a complete machine.

```text
Physical Machine
│
├── Host OS
│
└── Hypervisor
    └── Virtual Machine
        ├── Guest OS
        ├── Guest Kernel
        └── Applications
```

Because every VM contains a complete operating system environment, virtual machines require more memory, disk space and startup time. However, they provide strong isolation because the guest environment is separated from the host operating system.

A **Docker container** does not normally contain a complete operating system kernel. Containers run isolated applications/processes while sharing the kernel of the host system. Containers contain the application and dependencies required by the service, but they rely on the host kernel.

```text
Host OS
│
├── Docker Engine
│
├── Container A
│   └── Application + dependencies
│
├── Container B
│   └── Application + dependencies
│
└── Container C
    └── Application + dependencies
```

This makes containers generally:

* Smaller than virtual machines.
* Faster to create and start.
* Easier to destroy and recreate.
* More efficient in terms of system resources.

In Inception, both technologies are used together. The complete project runs inside a virtual machine, while Docker runs inside that VM and separates the infrastructure into individual services.

The VM therefore isolates the complete Inception environment from the physical host, while Docker provides service-level isolation inside the VM.

Without Docker, the different services would have to be installed and configured directly in the same VM environment. Their dependencies, processes, configuration files and ports would all coexist in the same system.

With Docker, each service has its own image, filesystem and runtime environment and can be built, started, stopped or recreated independently.

---

### Secrets vs Environment Variables

An **environment variable** is a value to a process through its execution environment. They are used for non-sensitive configuration, such as ports, usernames, email addresses, etc. They are useful because the same Docker image can be configured differently without modifying or rebuilding the image. However, environment variables belong to the process environment and can be exposed through container configuration mechanisms. For this reason, storing passwords directly in `.env` would mix sensitive credentials with normal application configuration.

**Docker secrets** are used to separate sensitive information from that configuration. Docker Compose declares which services require each secret. This means that passwords do not need to be written directly into Dockerfiles, initialization scripts, Docker images or env. Another important advantage is that secrets can be assigned only to the services that require them. For example, WordPress needs the database password to connect to MariaDB, but NGINX does not need that password.

---

### Docker Network vs Host Network

Containers need networking to communicate with each other and, in some cases, with users outside Docker. There are different ways to provide this connectivity.

With **host networking**, a container uses the host's network stack directly instead of receiving an isolated Docker network namespace in the normal way. This means the service uses the host's network interfaces and ports. For example, if several services wanted to listen on the same host port, they could conflict with each other. Host networking also reduces the network isolation between the container and the host and the services share the host networking environment.

**Docker network** creates a private virtual network managaed by Docker and attaches the containers to it. Containers connected to the same network can communicate internally without exposing every service to the host. Docker also provides internal DNS resolution on the network, which means that containers can communicate using **service names instead of container IP addresses**. For example, WordPress does not need to know the IP address assigned to the MariaDB container. It only needs to know **mariadb:3306**. This is important because container IP addresses are dynamic and may change when containers are recreated. Docker's internal DNS resolves the service name to the correct container.

The dedicated bridge network is appropriate for Inception because the services need to communicate with each other while remaining isolated from unnecessary external access.

---

### Docker Volumes vs Bind Mounts

Docker containers are designed to be disposable. A container can be stopped, removed and recreated from its image. For that reason, important application data should not depend only on the container's writable filesystem. For example, if MariaDB stored its database only inside the container filesystem and the container was permanently removed, that database could be lost with the container. Persistent storage solves this problem. Docker provides different storage mechanisms, including **Docker volumes** and **bind mounts**.

A **Docker volume** is a persistent storage object managed by Docker. Docker manages where that volume is physically stored on the host. The container only needs to know where the volume is mounted. Volumes are independent of the lifecycle of an individual container. A container can be removed and another container can mount the same volume.

A **bind mount** works differently. Instead of allowing Docker to choose and manage the physical storage location, a bind mount maps a specific host path directly into the container.

In this project, the configuration combines both concepts. Docker Compose defines **named volumes**, but the `local` volume driver is configured with bind mount options. From Docker Compose's perspective, the service uses the named volume **wp_database_store** but that volume points to the host directory **/home/<user>/data/mariadb**.

For example, removing and recreating the MariaDB container does not automatically delete `/home/<user>/data/mariadb`. When a new MariaDB container starts, the same persistent directory is mounted again at `/var/lib/mysql`, allowing MariaDB to continue using the existing database. The same principle applies to WordPress files. This is why commands that remove only containers can preserve the website, while a complete cleanup such as `make fclean` removes the persistent host directories.

---

## Instructions

### Requirements

The project is intended to run inside a virtual machine. The required tools are:

* Docker.
* Docker Compose.
* GNU Make.
* Git.

Before starting the infrastructure, verify that Docker is available:

```bash
docker --version
docker compose version
docker ps
```

The project also requires the configuration files and secret files to be prepared before the first startup.

Detailed setup instructions are available in `DEV_DOC.md`.

---

### Building and Starting

From the root of the repository, build and start the complete infrastructure with:

```bash
make
```

The same operation can be executed explicitly with:

```bash
make up
```

The Makefile creates the required persistent host directories before executing Docker Compose.

The main Docker Compose command used to build and launch the project is:

```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

The `--build` option builds or rebuilds the required Docker images, while `-d` starts the containers in detached mode.

After startup, verify the containers with:

```bash
docker ps
```

The stack should contain the mandatory and additional services:

```text
nginx
wordpress
mariadb
redis
adminer
ftp
static
portainer
```

---

### Stopping and Restarting

Stop all project containers without removing them:

```bash
make stop
```

Start the existing containers again:

```bash
make start
```

To remove the containers and Docker Compose network while preserving persistent application data:

```bash
make clean
```

The existing database and WordPress files will be reused when the project is started again.

---

### Cleaning and Rebuilding

To completely remove the project containers, Docker volumes and persistent host data:

```bash
make fclean
```

> **Warning:** This removes the existing MariaDB database, WordPress files and Portainer persistent data.

To perform a complete cleanup and rebuild:

```bash
make re
```

Since `make re` executes `fclean` before rebuilding, it also removes the existing persistent project data.

---

## Resources

The development of Inception required research across several areas, including containerization, Docker Compose orchestration, networking, persistent storage, web servers, databases, WordPress, caching and service configuration.

Whenever possible, official documentation was used as the primary reference. Additional articles and tutorials were used to better understand specific concepts, implementation details and debugging scenarios.

### Docker

The Docker documentation was the main reference for understanding images, containers, Dockerfiles, storage, networking and container lifecycle.

#### Dockerfiles and Images

* [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
* [Dockerfile Overview](https://docs.docker.com/build/concepts/dockerfile/) 
* [Writing a Dockerfile](https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/)
* [Building, and Publishing Images](https://docs.docker.com/get-started/docker-concepts/building-images/build-tag-and-publish-an-image/)
* [Docker image build Reference](https://docs.docker.com/reference/cli/docker/image/build/)
* [What is a Dockerfile?](https://www.geeksforgeeks.org/cloud-computing/what-is-dockerfile/)

#### Containers and Lifecycle

* [Docker Container Lifecycle](https://last9.io/blog/docker-container-lifecycle/)
* [Container Lifecycle Management](https://k21academy.com/kubernetes/docker-container-lifecycle-management/)
* [Start Containers Automatically](https://docs.docker.com/engine/containers/start-containers-automatically/)
* [Docker container restart](https://docs.docker.com/reference/cli/docker/container/restart/)

### Docker Storage and Persistence

* [Docker Volumes](https://docs.docker.com/engine/storage/volumes/)
* [Docker Storage Overview](https://docs.docker.com/engine/storage/)
* [Persisting Container Data](https://docs.docker.com/get-started/docker-concepts/running-containers/persisting-container-data/)
* [What is a Docker Volume?](https://www.geeksforgeeks.org/devops/what-is-docker-volume/)
* [Docker Volumes and Networking](https://noalabs.org/docker/volumes-and-networking)

### Docker Networking

* [Docker Networking Overview](https://docs.docker.com/engine/network/)
* [Docker Bridge Network Driver](https://docs.docker.com/engine/network/drivers/bridge/)
* [Docker Bridge Network](https://www.geeksforgeeks.org/devops/what-is-docker-network-bridge/)

### Docker Compose

* [Docker Compose Documentation](https://docs.docker.com/compose/)
* [Multi-container Applications](https://docs.docker.com/get-started/docker-concepts/running-containers/multi-container-applications/)
* [Docker Build Context](https://docs.docker.com/build/concepts/context/)
* [Docker Compose Services](https://docs.docker.com/reference/compose-file/services/)
* [Setting Environment Variables](https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/)
* [Docker `.env` Files](https://thenewstack.io/what-is-the-docker-env-file-and-how-do-you-use-it/)
* [Docker Compose Secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
* [Compose Secrets Reference](https://docs.docker.com/reference/compose-file/secrets/) 
* [Docker Compose `depends_on`](https://www.warp.dev/terminus/docker-compose-depends-on)

### Healthchecks

* [Docker HEALTHCHECK — GeeksforGeeks](https://www.geeksforgeeks.org/devops/docker-healthcheck-instruction/) 
* [Docker Health Checks — Practical Guide](https://www.dash0.com/guides/docker-health-check-a-practical-guide) 

### NGINX

* [NGINX Documentation](https://nginx.org/en/docs/) 
* [NGINX Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html) 
* [Configuring HTTPS Servers](https://nginx.org/en/docs/http/configuring_https_servers.html)
* [NGINX Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) 
* [NGINX HTTP Proxy Module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) 
* [Understanding FastCGI Proxying in NGINX — DigitalOcean](https://www.digitalocean.com/community/tutorials/understanding-and-implementing-fastcgi-proxying-in-nginx) 
* [CGI, FastCGI and PHP-FPM](https://medium.com/@jayprakash01/understanding-cgi-fastcgi-and-php-fpm-in-nginx-with-php-applications-a6a6c0b7b91d) 
* [Configuring NGINX as a Reverse Proxy — DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04) 

### WordPress and PHP-FPM

* [WordPress Developer Resources](https://developer.wordpress.org/) 
* [WordPress with Docker Compose — DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-install-wordpress-with-docker-compose) 
* [WordPress and Containers — WP Engine](https://wpengine.com/blog/containers-clusters-wordpress/)

### MariaDB

MariaDB provides the persistent relational database used by WordPress.

* [MariaDB Server Documentation](https://mariadb.com/docs/server/) 
* [Understanding MariaDB Architecture](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/migrating-to-mariadb/migrating-to-mariadb-from-sql-server/understanding-mariadb-architecture) 
* [Administering a MariaDB Database](https://medium.com/@sahaayushioe/administering-mariadb-database-7ea26f225601) 

### Redis

* [Redis Documentation](https://redis.io/docs/latest/) 
* [Run Redis with Docker](https://redis.io/docs/latest/operate/oss_and_stack/install/install-stack/docker/) 
* [Redis with a Custom Docker Configuration](https://oneuptime.com/blog/post/2026-03-31-redis-docker-custom-config/view) 

---

### Use of AI

AI tools were used as a supporting resource throughout the development and documentation of the project.

AI assistance was used for:

* Explaining concepts.
* Reviewing Dockerfiles and initialization scripts.
* Investigating container fucntionality and service dependency problems.
* Understanding and configuring healthchecks.
* Debugging permissions, persistent storage and container communication.
* Reviewing NGINX, WordPress, MariaDB, Redis, FTP, Adminer and Portainer configurations.
* Suggesting commands for testing and debugging individual services.
* Reviewing and improving the structure and clarity of the project documentation.

AI was particularly useful during debugging to help identify possible causes of errors and suggest areas of the infrastructure to inspect.

All AI-generated suggestions were reviewed and adapted to the specific requirements of the project.

AI was therefore used as a development and learning aid, not as a replacement for understanding, implementing or validating the project.

---

## Further Documentation

The README provides an overview of the project and the information required to get started. More detailed documentation is available in the repository.

### USER_DOC.md

Contains user and administrator documentation, including:

* Overview of the available services.
* Starting and stopping the infrastructure.
* Accessing WordPress and administration interfaces.
* Credential management.
* Service verification.
* Troubleshooting and healthcheck commands.

### DEV_DOC.md

Contains detailed developer documentation, including:

* Environment setup.
* Repository structure.
* Docker Compose configuration.
* Service dependencies and healthchecks.
* Direct Docker Compose usage.
* Container and volume management.
* Docker networking.
* Persistent data architecture.
* Debugging commands.

These documents provide additional information without requiring the README to contain every implementation and administration detail.
