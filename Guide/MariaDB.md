# MariaDB Dockerfile — Complete Technical Explanation for Inception

## Dockerfile

```Dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/mysqld /var/lib/mysql && chown -R mysql:mysql /run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql

COPY ./tools/init_mariadb.sh /usr/local/bin/init_mariadb.sh

RUN chmod +x /usr/local/bin/init_mariadb.sh

EXPOSE 3306

ENTRYPOINT ["init_mariadb.sh"]
```

---

# Introduction

This Dockerfile builds the custom MariaDB image used by the MariaDB service in the Inception project.

Instead of downloading a pre-configured MariaDB image from Docker Hub, the entire service is built manually from a Debian base image. The image is built from Debian Bookworm and contains only the packages and files needed to run MariaDB inside the Inception Network. 

This follows the Inception subject requirements and gives complete control over the installation, configuration, startup process, permissions, and security settings.

The purpose of this image is to provide a database server that will store all WordPress data, including:

* users
* passwords
* posts
* pages
* comments
* settings
* plugins metadata
* themes metadata

Without MariaDB, WordPress would have nowhere to store persistent information.

NGINX serves web requests.

WordPress generates dynamic content.

MariaDB stores the data used by WordPress.

---

# FROM debian:bookworm

```Dockerfile
FROM debian:bookworm
```

Here, is defined the base image from which the MariaDB image will be built.

Docker images are layered. Every image starts from another image.

In this case: ``debian:bookworm`` means that the container image starts from ``Debian 12 (Bookworm)`` will be used as the operating system inside the container.

We can think of this as installing a fresh Linux machine.
Before MariaDB can exist, Docker needs:

* a filesystem
* libraries
* package manager
* shell
* Linux utilities

Debian provides all of these. Debian gives the image a Linux filesystem, the Debian package manager apt, and the base environment needed to install MariaDB and the required system utilities.

---

## Why Not Use the Official MariaDB Image?

Because the subject explicitly requires building our own services.

Using: ``FROM mariadb`` would already include:

* MariaDB
* initialization scripts
* entrypoints
* configuration files

which defeats the educational purpose of the project.

The goal of Inception is understanding how services are built and configured, not simply using pre-built containers.

---

# Installing MariaDB

```Dockerfile
RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*
```

``RUN`` commands are executed only during image creation. They are not executed every time the container starts. The result of this command becomes part of the final image.

This instruction executes during image creation.
It is executed only once: ``docker build``.

---

## apt-get update

```bash
apt-get update
```

Debian stores package information in remote repositories.
Before installing software, Debian must know:

* what packages exist
* where they are located
* which versions are available

This command downloads the latest package repository indexes from Debian repositories. This allows apt to know which packages are available and where they can be downloaded from. Without this command: ``apt-get install mariadb-server``, may fail because Debian does not know where to find the package.

---

## apt-get install -y mariadb-server

```bash
apt-get install -y mariadb-server
```

Installs the MariaDB database server and the tools required to initialize and run a database server.

The package includes several important programs.

### mariadbd

The ``MariaDB server daemon`` is the main database process that:

* listens for connections
* manages databases
* authenticates users
* executes SQL queries
* stores data

This will eventually become PID 1 inside the container.

---

### mariadb

The ``MariaDB Client`` is a command-line tool. The ``init_mariadb.sh`` script can use it to connect to the temporary MariaDB server and execute SQL commands, such as, CREATE DATABASE, CREATE USER and GRANT.

Example: ``mariadb -u root``

---

### mariadb-install-db

Creates the internal MariaDB system tables.
These tables store:

* users accounts
* privileges/permissions
* database metadata
* internal server data

Without them MariaDB cannot function.

---

### mariadb-admin

Is an administration tool used by the init script to stop the temporary MariaDB server safely.

Example: ``mariadb-admin shutdown``

---

## Why Remove apt Cache?

```bash
rm -rf /var/lib/apt/lists/*
```

After installation, package indexes are no longer needed.
Keeping them increases image size.

This removes the cached package lists created by apt-get update.
This does not remove MariaDB. It only removes package index files that are no longer needed after installation.

The goal is to reduce the final Docker image size and avoid keeping unnecessary apt cache data inside the image.

Smaller images:

* build faster
* transfer faster
* use less storage

---

# Creating Required Directories

```Dockerfile
RUN mkdir -p /run/mysqld /var/lib/mysql && chown -R mysql:mysql /run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql
```

This prepares the MariaDB filesystem.

---

# /var/lib/mysql

This is the MariaDB data directory. This directory is where MariaDB stores all persistent database files.

Everything MariaDB stores ends up here.

It can contains:

* internal system tables;
* user-created databases;
* privilege information;
* InnoDB files;
* transaction logs;
* metadata;
* the initialization marker used by the script.

Example:

```text
/var/lib/mysql
│
├── mysql/
├── wordpress/
├── ib_logfile0
├── ib_logfile1
└── .mariadb_ready
```

In the Inception project, this directory is mounted as a Docker volume in docker-compose.yml.
That means the database data persists even if the MariaDB container is destroyed and recreated.

For example, when the container restarts, MariaDB can reuse the existing database files instead of creating
the database from zero again.

---

## mysql/ 

Contains MariaDB internal system tables. Stores:

* users
* passwords
* privileges
* metadata

Example:

```sql
SELECT * FROM mysql.user;
```

This information comes from files stored here.

---

## wordpress/

Contains the WordPress database.

Example:

```text
wordpress
│
├── wp_posts.ibd
├── wp_users.ibd
├── wp_comments.ibd
└── ...
```

Every WordPress table eventually becomes files inside this directory.


---

# /run/mysqld

This is the MariaDB runtime directory. Runtime directories are used for temporary files that exist only while the service is running.

Stores temporary files.

Example:

```text
/run/mysqld
│
├── mysqld.sock
└── mysqld.pid
```

---

## mysqld.sock

Is the Unix socket used for local communication between the MariaDB client and the MariaDB server. 

The socket is important because the initialization script uses commands like: ``mariadb --socket=/run/mysqld/mysqld.sock``.
This allows the script to connect locally to the temporary MariaDB server without using the Docker network.

Allows local communication between:

```text
  MariaDB Client
        │
        ▼
   mysqld.sock
        │
        ▼
  MariaDB Server
```

This is faster than TCP because traffic never leaves the machine.

---

## mysqld.pid

Contains the process ID.

Is the PID file that stores the process ID of the running MariaDB server process.

---

# Ownership and Permissions

```bash
chown -R mysql:mysql
```

Changes the owner and group of /run/mysqld and /var/lib/mysql directories to mysql.

This is necessary because MariaDB does not run as root. It runs as the mysql user.

In Linux, every file and directory has an owner, a group and permissions.

If /var/lib/mysql belonged only to root, then the MariaDB process running as mysql would not be able to write
database files, create tables, update logs, or modify internal metadata. That would cause errors such as permission denied or failed to create file. That's why MariaDB must own /run/mysql and /var/lib/mysql. 

The owner and group becomes mysql, and apply this recursively to every file and directory inside /var/lib/mysql.

The same logic applies to /run/mysqld. MariaDB must be able to create its socket and PID file there.
Without correct ownership, the server could fail during startup because it cannot create runtime files.

---

# Copying the Initialization Script

```Dockerfile
COPY ./tools/init_mariadb.sh /usr/local/bin/init_mariadb.sh
```

Copies the custom MariaDB initialization script into the image.

During the image build, Docker cannot automatically access files from the host. If a file is needed inside the image, it must be explicitly copied. This is exactly what the COPY instruction does. The source path: ``./tools/init_mariadb.sh`` is relative to the Docker build context. The destination: ``/usr/local/bin/init_mariadb.sh`` is inside the image filesystem.

After the image is built, the file exists inside the container exactly as if it had been created there manually.
The directory: ``/usr/local/bin`` is traditionally used in Linux for custom executables installed by the administrator.
Anything placed in this directory can usually be executed directly because it belongs to the system PATH.

---

## Why Is This Script Needed?

Docker builds happen before:

* volumes exist
* secrets exist
* environment variables exist

Therefore MariaDB cannot be fully configured during build time (image creation).
It must be configured when the container starts.

The script performs all the runtime logic tasks such as:

* reading Docker secrets;
* validating environment variables;
* creating required directories;
* generating the MariaDB configuration file;
* detecting if the Inception MariaDB setup already exists;
* installing MariaDB system tables if needed;
* starting a temporary MariaDB server;
* creating the WordPress database;
* creating the WordPress database user;
* granting privileges to the WordPress database user;
* setting the MariaDB root password;
* writing the initialization marker;
* stopping the temporary MariaDB server;
* starting the final MariaDB server in foreground mode.

---

# Build Time vs Runtime

## Build Time

Occurs when: ``docker build`` runs.

Example:

* Install packages
* Copy files
* Create image

Only happens once.

---

## Runtime

Occurs when: ``docker compose up`` runs.

Example:

* Read secrets
* Create database
* Create users
* Start MariaDB

Happens every container start.

---

# Making the Script Executable

```Dockerfile
RUN chmod +x /usr/local/bin/init_mariadb.sh
```

Adds execute permission making the script file executable.

Without this permission, DOcker could fail when trying to run the script as the container entrypoint. ``Permission denied`` would occur when Docker tries to execute the script.

---

# EXPOSE 3306

```Dockerfile
EXPOSE 3306
```

``EXPOSE`` documents that the MariaDB container listens on port 3306.

Port 3306 is the default MariaDB/MySQL port. WordPress connects to MariaDB through the Docker network using this port.

In docker-compose.yml, WordPress usually connects with MDB_HOST=mariadb and internally the connection goes to:
``mariadb:3306` .`

``EXPOSE`` does not publish the port to the host machine. It only documents that this container is expected to receive connections on this port.

 This is important for security and architecture:

* NGINX is the only service exposed to the host through port 443.
* WordPress is internal and listens on PHP-FPM port 9000.
* MariaDB is internal and listens on port 3306.

The host machine does not need direct access to MariaDB. Only the WordPress container needs to communicate with MariaDB through the Docker network.

---

## Why Not Publish 3306?

Bad:

```yaml
ports:
  - "3306:3306"
```

Good:

```yaml
expose:
  - "3306"
```

Because only WordPress needs database access. Publishing MariaDB to the host would expose the database unnecessarily.
The outside world should never connect directly to MariaDB.

---

# ENTRYPOINT

```Dockerfile
ENTRYPOINT ["init_mariadb.sh"]
```

``ENTRYPOINT`` defines the command executed every time the container starts.

When Docker launches the MariaDB container, it automatically executes: ``init_mariadb.sh``.

This happens because the script was copied to: ``/usr/local/bin/init_mariadb.sh`` and ``/usr/local/bin`` is normally in the PATH.

> Container starts -> init_mariadb.sh runs -> MariaDB is configured -> MariaDB starts

When a Docker launches the container, it executes init_mariadb.sh automatically. This is why the container becomes self-configuring. No manual intervention is required.

---

# Why exec Is Important

The last line of the script is:

```bash
exec mariadbd --user=mysql --datadir="$MARIADB_DATA_DIR" --socket="$MARIADB_SOCKET"
```

The ``exec`` command replaces the shell script process with MariaDB server process. 

After exec runs, the shell script disappears and mariadbd becomes the main process inside the container.

This means: ``PID 1 = mariadbd``, inside the container.

DOcker expects a single main process. This main process is always PID 1.

Docker containers are designed around one main foreground process.

If PID 1 exits, the container stops. If mariadbd crashes, Docker detects that the main process exited.
Then Docker can restart the container depending on the restart policy.

This is why MariaDB must run in foreground mode. It must not be started as a background daemon for the final container process.

In summary:
 
1) ENTRYPOINT starts the initialization script
2) The initialization script prepares MariaDB.
3) exec replaces the script with the MariaDB server.
4) MariaDB becomes PID 1 and keeps the container alive.

---
