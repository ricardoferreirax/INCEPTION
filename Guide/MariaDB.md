# MariaDB Dockerfile

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

To fully understand what this Dockerfile does, it is important to first understand what problem MariaDB solves and why a database server is required in a modern web application.

WordPress is not a collection of static HTML pages. Instead, it is a dynamic application. Every time a visitor opens the website, WordPress generates the page dynamically by retrieving information stored inside a database.

For example, when a user visits ``https://login.42.fr`` WordPress may need to retrieve:

* website settings;
* administrator information;
* registered users;
* blog posts;
* comments;
* uploaded content;
* plugin settings;
* theme settings.

This information cannot simply be stored inside PHP files because it changes continuously.
Instead, WordPress stores its data inside a relational database managed by MariaDB.

MariaDB is a Database Management System (DBMS).

A Database Management System is software designed to organize, store, retrieve, update and protect large amounts of structured information.

Think of a database as a giant digital filing cabinet.
Without MariaDB, WordPress would have to manually:

* open files;
* search for information;
* update information;
* protect data integrity;
* recover from crashes.

MariaDB performs all of these tasks automatically.

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

NGINX is responsible for handling incoming HTTP and HTTPS requests.

WordPress is responsible for generating dynamic content.

MariaDB is responsible for storing and retrieving data.

Because each service specializes in a single task, the overall system becomes easier to maintain, more secure and more scalable.

---

### Understanding Docker Images

Before MariaDB can run inside a container, Docker must first create an image.

A Docker image can be thought of as a blueprint or template used to create containers.

The image contains:

* operating system files;
* libraries;
* installed software;
* configuration files;
* scripts.

A container is simply a running instance of an image.

The relationship can be visualized as: Dockerfile -> Docker Image -> Docker Container

The Dockerfile contains instructions.
Docker executes those instructions and creates an image.
The image is then used to create containers.

The image itself never runs.
The container runs.

An image is comparable to a class in programming.

A container is comparable to an object created from that class.

---

### Understanding Filesystems

Before MariaDB can be installed, Docker first needs an operating system environment.

That environment includes one of the most fundamental components of any operating system: The ``Filesystem``.

A filesystem is the structure used by an operating system to organize, store and retrieve files on a storage device.

Without a filesystem, the operating system would have no way to know:

* where files are stored;
* how files are organized;
* how directories relate to each other;
* which users own which files.

A filesystem solves this problem by organizing storage into a hierarchical structure of directories and files.

For example:

/
├── bin
├── etc
├── home
├── usr
├── var
└── tmp

This structure is known as the Linux filesystem hierarchy.
Every file inside Linux ultimately exists somewhere inside this tree.

MariaDB itself stores its databases inside: ``/var/lib/mysql``.

Configuration files are usually stored inside: ``/etc/mysql``.

Temporary runtime files are stored inside: ``/run/mysqld``.

One of Docker's most important features is filesystem isolation.
When Docker starts a container, it creates a separate filesystem for that container.

The container sees:

/
├── bin
├── etc
├── usr
├── var
└── ...

just like a normal Linux machine.

However, this filesystem is isolated from the host system.

For example:

Host: ``/home/rmedeiro``

Container: ``/var/lib/mysql``

The MariaDB container cannot automatically access files from the host machine.
It only sees its own filesystem.

This isolation improves:

* security;
* portability;
* reliability.

Each container behaves like a small independent Linux system.

Even though multiple containers may run on the same machine, each one has its own filesystem, processes, network interfaces and runtime environment.

This is one of the core ideas behind Docker and one of the reasons containers are so powerful.

---

# FROM debian:bookworm

```Dockerfile
FROM debian:bookworm
```

This instruction defines the base image from which the MariaDB image will be built.

Instead of downloading a pre-configured MariaDB image from Docker Hub, the entire service is built manually from a Debian base image. The image is built from Debian Bookworm and contains only the packages and files needed to run MariaDB inside the Inception Network. 

This follows the Inception subject requirements and gives complete control over the installation, configuration, startup process, permissions, and security settings.

Every Docker image starts from another image.
Images are layered.

Each instruction in the Dockerfile creates a new layer on top of the previous one.

The first layer in this project is: ``debian:bookworm`` which corresponds to Debian 12 (Bookworm).

Debian is one of the most widely used Linux distributions in the world.

By using Debian Bookworm, the container gains:

* a Linux kernel interface;
* a filesystem hierarchy;
* system libraries;
* shell utilities;
* package management through apt;
* networking tools;
* process management capabilities.

Without these components, MariaDB could not be installed or executed.

Every instruction that follows in the Dockerfile will be executed on top of this Debian environment.

As a result, the final MariaDB image becomes:

Debian
   │
   ├── MariaDB packages
   ├── Configuration files
   ├── Initialization script
   └── Runtime settings

---

## Why Not Use the Official MariaDB Image?

The Inception subject explicitly requires to build services instead of relying on pre-configured application images.

At first glance, using the official MariaDB image may seem easier because it already contains everything required to run a database server. 

For example: ``FROM mariadb`` would immediately provide:

* MariaDB already installed;
* default configuration files;
* startup scripts;
* entrypoints;
* database initialization logic;
* predefined filesystem structure.

The container would be ready to run with very little work.
However, the purpose of Inception is not simply running services.
The purpose is understanding how those services are built, configured and managed.

For example, we would not learn:

* how MariaDB is installed;
* which packages are required;
* where database files are stored;
* how initialization works;
* how users and databases are created;
* how permissions are configured;
* how the startup sequence works;
* how Docker entrypoints work.

---

# Installing MariaDB

```Dockerfile
RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*
```

This Dockerfile instruction installs MariaDB inside the custom MariaDB image.

It is one of the most important lines in the Dockerfile because this is the point where the image stops being only a basic Debian image and starts becoming a database server image.

Before this line runs, the image is essentially just Debian Bookworm.

After this line runs, the image contains the MariaDB server, MariaDB client tools, initialization tools, administration tools, default configuration files, libraries, dependencies, and system users required by MariaDB.

``RUN`` is a Dockerfile instruction.
It executes commands only during the image build process. They are not executed every time the container starts. The result of this command becomes part of the final image.
This means the command runs when Docker is building the image, for example when you execute: ``docker build`` .

A ``RUN`` command does not run every time the container starts.

The Dockerfile builds the image.
The container is created later from that image.
So this instruction belongs to build time, not runtime.

---

## apt-get update

```bash
apt-get update
```

Debian uses the apt package manager to install software.
However, apt does not automatically know what packages are available.
It needs package lists.

Before installing anything, Debian needs to know:

* which packages exist;
* which versions are available;
* where they can be downloaded from;
* which dependencies they require.

apt-get update downloads this information. It does not install software. It only updates the local package index.

For example, without apt-get update, this command: ``apt-get install -y mariadb-server`` may fail because Debian may not have an updated list of packages.

So before installing MariaDB, we refresh the package information.

This command downloads the latest package repository indexes from Debian repositories. This allows apt to know which packages are available and where they can be downloaded from.

---

## apt-get install -y mariadb-server

```bash
apt-get install -y mariadb-server
```

This command installs the MariaDB server package. MariaDB is the database management system used by WordPress.
WordPress needs a database because it stores dynamic data.

Examples of WordPress data stored in MariaDB:

* users;
* posts;
* pages;
* comments;
* site URL;
* admin settings;
* plugin settings;
* theme settings.

Without MariaDB, WordPress could still have PHP files, but it would not have persistent site data.
It could not remember users, posts, settings or comments.

The mariadb-server package installs the core software required to run a MariaDB database server.
It also installs dependencies automatically.
A dependency is another package required by the main package to work correctly.

Installs the MariaDB database server and the tools required to initialize and run a database server.

The package installs several important programs and files.
It does not only install one binary.
It installs an entire database server environment.

Important components include:

mariadbd
mariadb
mariadb-install-db
mariadb-admin
system user mysql
libraries

Each one has a different role.

### mariadbd

Correspond to the MariaDB server ``daemon``.
A daemon is a long-running background service.
In normal Linux systems, daemons are services that continue running and wait for requests.

Examples:

sshd       waits for SSH connections
nginx      waits for HTTP/HTTPS requests
mariadbd   waits for database connections

In the container, mariadbd is the main database process.
It is responsible for:

* starting the database engine;
* opening the configured port;
* creating the socket file;
* loading database files;
* reading configuration files;
* authenticating users;
* executing SQL queries;
* writing data to disk;
* recovering data after crashes.

This will eventually become PID 1 inside the container.

---

### mariadb

mariadb is the MariaDB client command-line tool.
It is not the server.
It is a program used to connect to the server.

The relationship is:

Example: ``mariadb -u root``

This attempts to connect to the MariaDB server as the root database user.

The ``init_mariadb.sh`` script can use it to connect to the temporary MariaDB server and execute SQL commands, such as, CREATE DATABASE, CREATE USER and GRANT.

---

### mariadb-install-db

Is used to create the internal MariaDB system tables.

These are not WordPress tables.
They are internal tables that MariaDB needs to operate.

They are stored inside: ``/var/lib/mysql/mysql``.
This internal database contains information such as:

* users;
* passwords;
* authentication plugins;
* privileges;
* host access rules;
* database metadata.

For example, when a user tries to connect, MariaDB must check:

* Does this user exist?
* Is the password correct?
* Is this host allowed?
* What permissions does this user have?

That information comes from internal system tables.
Without these tables, MariaDB would not know:

* who can connect;
* which databases exist;
* which permissions users have.

So MariaDB cannot properly function without system tables.

---

## Why Remove apt Cache?

```bash
rm -rf /var/lib/apt/lists/*
```

This command removes the package lists downloaded by: ``apt-get update``.
These files are stored in: ``/var/lib/apt/lists/``

They are useful during package installation, but after MariaDB has been installed, they are no longer needed.
Keeping them would make the Docker image larger.

This does not remove MariaDB.

It does not remove installed packages.

It only removes temporary package index files.

The result is a cleaner and smaller image.

The goal is to reduce the final Docker image size and avoid keeping unnecessary apt cache data inside the image.

Smaller Docker images are better because they:

* take less disk space;
* build faster;
* transfer faster;
* reduce unnecessary files;
* make the final project cleaner.

A good Dockerfile should not keep unnecessary cache files inside the final image.

---

# Creating Required Directories

```Dockerfile
RUN mkdir -p /run/mysqld /var/lib/mysql && chown -R mysql:mysql /run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql
```

This block prepares the filesystem that MariaDB will use inside the container.

At this point in the Dockerfile, MariaDB has already been installed, but it still needs a place to store its data and runtime files.

A database server cannot operate using only its executable files.

It also needs directories where it can:

* store databases;
* store internal system tables;
* create temporary files;
* create communication sockets;
* store process information.

The purpose of this block is therefore to create the filesystem structure that MariaDB expects to find when it starts.

---

## Understanding MariaDB Storage

A common misconception is that MariaDB stores everything in memory.
This is not true.
MariaDB stores its data on disk.

When WordPress creates:

* a user;
* a post;
* a comment;
* a page;

that information must survive on container restarts and system reboots.

To achieve this, MariaDB writes data into files stored on disk.
Those files are located inside: ``/var/lib/mysql``.
This directory is therefore one of the most important directories in the entire MariaDB installation.

If this directory is lost, the database is lost.

## Understanding /var/lib/mysql

This is the MariaDB data directory. This directory is where MariaDB stores all persistent database files.

Everything MariaDB stores ends up here.

Linux filesystems follow a standard hierarchy.
The directory: ``/var`` stands for Variable Data.
Variable data is information that changes while the system runs.

Examples include:

* logs;
* cache files;
* databases;

MariaDB data constantly changes because:

* users are created;
* posts are published;
* comments are added;
* settings are modified.

In the Inception project, this directory is mounted as a Docker volume in docker-compose.yml.
That means the database data persists even if the MariaDB container is destroyed and recreated.

For example, when the container restarts, MariaDB can reuse the existing database files instead of creating
the database from zero again.

---

## mysql/ 

This directory contains the MariaDB internal system database.

This database is created by: ``mariadb-install-db`` during initialization.

It contains critical information used by MariaDB itself.

Examples include:

* database users;
* passwords;
* permissions;
* authentication settings;
* internal metadata.

Without these tables MariaDB cannot determine:

* who is allowed to connect;
* what databases exist;
* what privileges each user has.

This is why the script creates them during initialization.

---

## wordpress/

This directory contains the WordPress database.

When WordPress creates tables such as:

* wp_posts
* wp_users
* wp_comments
* wp_options
* wp_terms

their data is stored inside files located here.

For example: ``wp_users`` contains:

* usernames;
* emails;
* password hashes;
* roles.

While: ``wp_posts`` contains:

* blog posts;
* pages;

When a visitor loads the website, MariaDB retrieves information from these files and sends it back to WordPress.

---

# Understanding /run/mysqld

Unlike /var/lib/mysql, this directory does not contain persistent data.
It contains runtime data.

Runtime data exists only while MariaDB is running. Think of it as MariaDB's temporary workspace.

Typical contents:

/run/mysqld
│
├── mysqld.sock
└── mysqld.pid

When MariaDB stops, these files are no longer useful.

---

## mysqld.sock

This file is a Unix socket. A Unix socket is a special file used for local communication between processes.

Is the Unix socket used for local communication between the MariaDB client and the MariaDB server. 

It is not a network port. It acts as a communication endpoint.

Example:

MariaDB Client -> mysqld.sock -> MariaDB Server

The initialization script uses commands such as: ``mariadb --socket=/run/mysqld/mysqld.sock`` to allow the client to connect directly to MariaDB without using the Docker network.

No Docker network is involved. No TCP connection is involved.

Everything happens locally inside the container.

### Why Use a Socket Instead of TCP?

Sockets are:

* faster;
* simpler;
* more secure for local communication.

Instead of: 127.0.0.1:3306, the client connects directly through: ``/run/mysqld/mysqld.sock``.

This avoids network overhead.

---

## mysqld.pid

This file stores the process ID of the running MariaDB server.

Other programs can read this file to know which process belongs to MariaDB.

---

# Ownership and Permissions

```bash
chown -R mysql:mysql
```

Changes the owner and group of /run/mysqld and /var/lib/mysql directories to mysql.

The command: ``chown`` stands for ``Change Owner``.

Linux assigns every file and directory:

* an owner;
* a group;
* permissions.

## Why MariaDB Cannot Run As Root

For security reasons, MariaDB normally runs as: ``mysql`` not ``root``.

Running database servers as root would be dangerous because any vulnerability would gain full system privileges.

Instead, MariaDB Process runs as mysql user. This limits what the process can access.

## Why Ownership Is Required

Suppose: ``/var/lib/mysql`` belongs to ``root:root`` but MariaDB runs as ``mysql:mysql``.

Then MariaDB may not be allowed to:

* create databases;
* create tables;
* write logs;
* update files.

By assigning ownership, MariaDB gains permission to manage its own files.

So, this is necessary because MariaDB does not run as root. It runs as the mysql user.

If /var/lib/mysql belonged only to root, then the MariaDB process running as mysql would not be able to write
database files, create tables, update logs, or modify internal metadata. 

That would cause errors such as permission denied or failed to create file. That's why MariaDB must own /run/mysql and /var/lib/mysql. 

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
