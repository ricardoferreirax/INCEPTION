# DEV_DOC

## Purpose

This document explains how to configure, build, run, debug and maintain the Inception infrastructure.

It is intended for developers who need to understand the project structure, Docker configuration, service deployment, container management and data persistence.

---

## Prerequisites

The project was developed and tested inside a Linux virtual machine using:

* **Debian 12 (Bookworm)** — development environment and base image used by the services.
* **Docker** — builds images and runs containers.
* **Docker Compose** — orchestrates the multi-container infrastructure.
* **GNU Make** — simplifies project management commands.
* **Git** — provides source code version control.

Install the required packages on Debian 12:

```bash
sudo apt update
sudo apt install docker.io docker-compose-plugin make git
```

Verify the installation:

```bash
docker --version
docker compose version
make --version
git --version
docker ps
```

The last command also verifies that the current user can communicate with the Docker daemon.

---

## Repository Structure

```text
inception/
├── Makefile
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

Each service has its own Dockerfile and runs inside a dedicated container. Docker Compose connects these services through the project network and shared resources.

---

## Environment Setup

### Environment Variables

General non-sensitive configuration is stored in:

```text
srcs/.env
```

The project uses the following variables:

```env
DOMAIN_NAME=
MDB_PORT=
MDB_USER=
PHP_FPM_PORT=
WP_ADMIN=
WP_ADMIN_EMAIL=
WP_USER=
WP_USER_EMAIL=
```

Passwords must not be stored in `.env`; sensitive credentials are handled separately through Docker secrets.

### Domain Configuration

The configured domain must resolve to the machine running the infrastructure.

When accessing the project directly from the virtual machine, add the following entry to `/etc/hosts`:

```text
127.0.0.1 rmedeiro.42.fr
```

The website can then be accessed at:

```text
https://rmedeiro.42.fr/
```

### Secrets Configuration

Sensitive credentials are stored in:

```text
secrets/
```

Required files:

* `db_root_password.txt` — MariaDB root password.
* `db_password.txt` — WordPress database user password.
* `wp_admin_password.txt` — WordPress administrator password.
* `wp_user_password.txt` — additional WordPress user password.
* `ftp_password.txt` — FTP account password.

They can be created with:

```bash
mkdir -p secrets
echo "your_secure_password" > secrets/db_root_password.txt
echo "your_secure_password" > secrets/db_password.txt
echo "your_secure_password" > secrets/wp_admin_password.txt
echo "your_secure_password" > secrets/wp_user_password.txt
echo "your_secure_password" > secrets/ftp_password.txt
```

Different secure passwords should be used for each account. Secret files should not be committed to the Git repository.

Docker Compose provides each secret only to the services that require it. Inside a container, secrets are available under:

```text
/run/secrets/
```

---

## Building and Launching the Project

The infrastructure can be managed from the repository root using the Makefile.

Build and start the complete project:

```bash
make
```

or:

```bash
make up
```

The `up` rule creates the required persistent directories and executes:

```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

This builds the images, creates the containers, network and volumes, loads `.env`, provides the required secrets and starts the services in detached mode.

To build the images without starting the containers:

```bash
make build
```

This executes:

```bash
docker compose -f srcs/docker-compose.yml build
```

---

## Using Docker Compose

Docker Compose can also be used directly. From the repository root:

```bash
cd srcs
```

Common commands are:

```bash
docker compose build
docker compose up -d
docker compose up --build -d
docker compose stop
docker compose start
docker compose down
docker compose ps
docker compose logs
docker compose logs -f
```

To remove the containers, network and Docker volumes:

```bash
docker compose down -v
```

Persistent host directories under `/home/<user>/data/` are not automatically deleted by this command.

---

## Docker Compose Configuration

The complete infrastructure is defined in:

```text
srcs/docker-compose.yml
```

Docker Compose coordinates:

* Images and containers.
* Environment variables and secrets.
* Networks and service communication.
* Persistent volumes.
* Published and internal ports.
* Service dependencies and healthchecks.
* Restart policies.

Each service runs in an isolated container and communicates through the private `inception_bridge` network. Docker's internal DNS allows service names to be used instead of fixed IP addresses:

```text
wordpress -> mariadb:3306
wordpress -> redis:6379
nginx     -> wordpress:9000
```

Services use `restart: on-failure` so they can restart when their main process exits because of an error.

### Startup Dependencies

A running container does not necessarily mean that its service is ready.

The project therefore combines `depends_on` conditions with healthchecks.

```text
MariaDB --- healthy ---> WordPress --- healthy ---> NGINX
                         
```

MariaDB must accept database requests and Redis must respond before WordPress starts. WordPress then completes its initialization and starts PHP-FPM.

NGINX starts after WordPress becomes healthy, preventing startup race conditions such as requests being forwarded before PHP-FPM or MariaDB are ready.

---

## Docker Network

All containers communicate through the dedicated bridge network:

```text
inception_bridge
```

Docker service names act as internal DNS hostnames:

```text
NGINX
  └──► wordpress:9000

WordPress
  ├──► mariadb:3306
  └──► redis:6379

Adminer
  └──► mariadb:3306

NGINX
  ├──► adminer:8080
  ├──► static:8081
  └──► portainer:9000
```

The network can be inspected with:

```bash
docker network ls
docker network inspect inception_bridge
```

---

## Managing Containers and Volumes

### Containers

Display running or all containers:

```bash
docker ps
docker ps -a
```

Manage a specific container:

```bash
docker stop <container_name>
docker start <container_name>
docker restart <container_name>
docker inspect <container_name>
```

Display or follow logs:

```bash
docker logs <container_name>
docker logs -f <container_name>
```

Execute a command or open a shell:

```bash
docker exec <container_name> <command>
docker exec -it <container_name> bash
```

For example:

```bash
docker exec redis redis-cli ping
docker exec -it mariadb bash
```

### Volumes

Display and inspect Docker volumes:

```bash
docker volume ls
docker volume inspect <volume_name>
```

The main persistent volumes are:

```text
wp_database_store
wp_content_store
portainer_data
```

A container or volume can be removed with:

```bash
docker rm <container_name>
docker volume rm <volume_name>
```

A running container must be stopped before it can normally be removed.

---

## Data Storage and Persistence

Containers can be removed or recreated, so persistent application data is stored outside their writable filesystems.

Host data is stored under:

```text
/home/<user>/data/
├── mariadb/
├── wordpress/
└── portainer/
```

These directories are created by the Makefile before Docker Compose starts the infrastructure.

### MariaDB Data

MariaDB uses:

```text
Host:       /home/<user>/data/mariadb
Volume:     wp_database_store
Container:  /var/lib/mysql
```

This stores the persistent WordPress database. Recreating the MariaDB container therefore does not recreate or erase the existing database.

### WordPress Data

WordPress uses:

```text
Host:       /home/<user>/data/wordpress
Volume:     wp_content_store
Container:  /var/www/html
```

This directory contains the persistent WordPress installation, including its files, plugins, themes and uploads.

The volume is shared by WordPress, NGINX and FTP, allowing these services to access the same filesystem.

### Portainer Data

Portainer uses:

```text
Host:       /home/<user>/data/portainer
Volume:     portainer_data
Container:  /data
```

This preserves Portainer application data when its container is recreated.

### How Persistence Works

Persistent volumes are defined in `srcs/docker-compose.yml` using the Docker `local` driver with bind mount options.

For example:

```yaml
wp_database_store:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /home/${USER}/data/mariadb
```

The actual persistent data remains under `/home/<user>/data/`. When a container is recreated, Docker mounts the same host data into the new container.

Therefore:

```text
Container deletion ≠ Persistent data deletion
```

Persistent data is permanently removed only when the corresponding host directories are explicitly deleted.
