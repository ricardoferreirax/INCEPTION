# WordPress Dockerfile

## Dockerfile

```Dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y php-fpm php-mysql mariadb-client curl \
	ca-certificates && rm -rf /var/lib/apt/lists/*

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

RUN mkdir -p /var/www/html /run/php && chown -R www-data:www-data /var/www/html /run/php

COPY ./tools/init_wordpress.sh /usr/local/bin/init_wordpress.sh

RUN chmod +x /usr/local/bin/init_wordpress.sh

EXPOSE 9000

ENTRYPOINT ["init_wordpress.sh"]
```

---

# Introduction

This Dockerfile builds the custom WordPress image used by the WordPress service in the Inception project.

To understand this Dockerfile properly, we first need to understand what WordPress actually is and what role it plays in the full infrastructure.

WordPress is a Content Management System, commonly called a CMS.

A CMS is software that allows users to create, edit, organize and publish website content without manually writing every HTML page by hand.

For example, with WordPress, an administrator can log into the dashboard and create:

* posts;
* pages;
* users;
* comments;
* media uploads;
* site settings;
* themes;
* plugin configuration.

All of this content is dynamic. That means it can change while the website is running.

For example, if an administrator creates a new post, WordPress does not create a new static HTML file manually written by the developer. Instead, it stores the post content in the database. Later, when a visitor opens the website, WordPress retrieves that content from the database and generates the final HTML response dynamically.

This is one of the most important ideas to understand:

* WordPress files contain the application logic.
* MariaDB contains the website data.

The WordPress container contains the PHP code that knows how to build the website.

The MariaDB container contains the information that the website displays.

Without MariaDB, WordPress would still have PHP files, but it would not have meaningful data to show.

It would not know:

* the site title;
* which users exist;
* which administrator account exists;
* which posts exist;
* which pages exist;
* which comments exist;
* which plugins are active;
* which theme is selected.

So WordPress depends directly on MariaDB.

When a browser opens ``https://login.42.fr`` the browser does not simply receive one static HTML file. Instead, a complete chain of operations happens.

WordPress is not just static files. A static website is made of fixed files.

For example:

* index.html
* about.html
* style.css
* script.js

When a user opens the website, the web server simply returns one of those files. The content is already written. The server does not need to ask a database for information.

WordPress works differently. WordPress is a dynamic PHP application. Most of the final HTML page is generated at request time. That means the page is built when the user asks for it.

For example, when a browser opens: ``https://login.42.fr`` the browser does not simply receive one fixed HTML file.

Instead, a complete chain of operations happens. ``NGINX`` receives the HTTPS request. If the request points to a PHP page, ``NGINX`` forwards that request to ``PHP-FPM`` inside the WordPress container.

PHP-FPM executes the WordPress PHP code. WordPress reads its configuration from: ``/var/www/html/wp-config.php``.
Inside that file, WordPress finds the database connection information:

* database host;
* database name;
* database user;
* database password.

Then WordPress connects to MariaDB.

MariaDB returns the requested data.

WordPress uses that data to generate the final HTML page.

NGINX sends that generated page back to the browser.

The user only sees the final web page.

The WordPress container:

* It does not expose the public website directly to the host machine.
* It does not store the database files.
* It does not terminate HTTPS.
* Its job is to run the PHP application and communicate with MariaDB.

Therefore, this Dockerfile creates an image that contains:

* PHP-FPM;
* the PHP MySQL/MariaDB extension;
* the MariaDB client;
* curl;
* CA certificates;
* WP-CLI;
* the custom WordPress initialization script;
* the required WordPress runtime directories.

Instead of using the official WordPress image, this service is built manually from Debian Bookworm. This follows the Inception subject requirements and gives complete control over the installation, configuration, permissions and startup process.

---

# Understanding What WordPress Needs

WordPress needs several components to work correctly inside the Inception infrastructure.

WordPress is not just a folder with website files. It is a dynamic PHP application. This means that WordPress does not simply return a fixed HTML file every time a user visits the website. Instead, WordPress executes PHP code, connects to the database, retrieves information, builds the page dynamically, and then returns the generated HTML.

Each component has a specific responsibility.

NGINX receives the HTTPS request from the browser.

PHP-FPM executes the PHP code.

WordPress contains the application logic.

MariaDB stores the dynamic data.

The WordPress Dockerfile prepares the container so it can perform the PHP application role.


## WordPress Needs PHP

WordPress is written in PHP. PHP is a server programming language. This means PHP code is executed on the server, not inside the user's browser.

The browser understands:

* HTML;
* CSS;
* JavaScript;
* images;
* fonts.

The browser does not execute PHP.

The PHP code must be executed by a PHP interpreter before the browser receives the final page.

So WordPress needs a PHP runtime because all of its main files are PHP files.

When WordPress runs, PHP loads these files, executes the WordPress logic, queries the database when necessary, and generates the final HTML response.

Without PHP, the WordPress files would just be text files. They would exist on disk, but nothing would execute them.

## WordPress Needs PHP-FPM

The Dockerfile installs: ``php-fpm``.

PHP-FPM means: ``PHP FastCGI Process Manager``. 

PHP-FPM is a service that manages PHP worker processes.

Its job is to receive requests for PHP execution, run the PHP code, and return the generated result.

This is necessary because NGINX does not execute PHP by itself.

NGINX is excellent at:

* receiving HTTP/HTTPS requests;
* serving static files;
* handling TLS/SSL;
* forwarding requests;
* managing many simultaneous connections.

But NGINX is not a PHP interpreter. If NGINX receives a request for ``/index.php`` it cannot interpret the PHP code directly. Instead, NGINX forwards the PHP request to PHP-FPM.

The flow is:

> NGINX receives /index.php -> sends FastCGI request to PHP-FPM -> PHP-FPM executes WordPress PHP code -> PHP-FPM returns generated HTML -> NGINX sends HTML to the browser

So PHP-FPM acts as the bridge between NGINX and PHP execution.

## WordPress Needs php-mysql

The Dockerfile installs: ``php-mysql``.
This package provides the PHP extension that allows PHP applications to communicate with MySQL databases, including MariaDB.

WordPress needs this because the WordPress PHP code must connect to MariaDB.

Without php-mysql, PHP would not have the necessary database driver. WordPress might fail with an error similar to:

This package is the link between: PHP code -> MariaDB database

When WordPress runs database operations, it uses PHP database functions internally. Those functions depend on the MySQL/MariaDB extension.

Without this extension, WordPress can execute PHP code, but it cannot access the database.

That would make WordPress unusable because almost all WordPress content is stored in MariaDB.

## WordPress Needs MariaDB

WordPress depends heavily on MariaDB because most dynamic content is stored in the database.

The files in ``/var/www/html`` contain the WordPress application code.

The actual website data is stored in MariaDB.

This distinction is important:

```text
/var/www/html
    WordPress code and files

MariaDB
    users, posts, pages, settings, comments
```

For example, WordPress files contain code that says Load the latest posts. But the posts themselves are stored in MariaDB.
When a visitor opens the homepage, WordPress may query MariaDB. MariaDB responds with the requested data. WordPress then uses that data to generate the final HTML page.

## WordPress Needs a Persistent Web Root Directory

WordPress files are stored in: ``/var/www/html``.

It contains files such as:

* index.php
* wp-config.php
* wp-admin/
* wp-content/
* wp-includes/

The most important directory is: ``wp-content/`` because it contains:

* uploaded media;
* themes;
* plugins;
* cache files.

In Docker Compose, ``/var/www/html`` should be mounted as a volume. This allows WordPress files to persist when the container is removed and recreated.

Without persistence, WordPress could lose installed files, uploads, plugins and themes after rebuilds.

---

# What Is FastCGI?

FastCGI is a protocol used by a web server to communicate with an external application process.

In this project, the web server is NGINX.

The external application process is PHP-FPM.

The protocol between them is FastCGI.

A protocol is simply a set of rules that defines how two programs communicate.

For example:

```text
HTTP -> browser communicates with web server
SQL -> application communicates with database
FastCGI -> NGINX communicates with PHP-FPM
```

FastCGI allows NGINX to say something like: Please execute this PHP file SCRIPT_FILENAME=/var/www/html/index.php

PHP-FPM receives that request, executes the file, and returns the generated HTML output.

NGINX does not need to know how PHP works internally.

PHP-FPM does not need to handle HTTPS directly.

Each one does its own job.


# Understanding Filesystems

Before WordPress can be installed, Docker needs an operating system environment. That environment includes a filesystem.

A filesystem is the structure used by an operating system to organize, store and retrieve files.

Without a filesystem, Linux would not know:

* where WordPress files are stored;
* where PHP-FPM configuration files are located;
* where runtime files are created;
* which user owns each file;
* which files can be executed.

In the WordPress container, the important paths are:

* ``/var/www/html``, where WordPress files are stored.
* ``/etc/php/8.2/fpm/pool.d``, where PHP-FPM pool configuration files are stored.
* ``/usr/local/bin``, where custom executable scripts are placed.

The script generates ``/etc/php/8.2/fpm/pool.d/www.conf``. This file tells PHP-FPM:

* which user to run as;
* which group to run as;
* which address and port to listen on;
* how many worker processes to manage;
* whether environment variables should be cleared.

This is where PHP-FPM can create runtime files such as PID files or sockets.

The container stores: ``/usr/local/bin/wp`` and ``/usr/local/bin/init_wordpress.sh``.

When Docker starts the container, the container sees its own isolated filesystem.
It behaves like a small independent Linux system, with its own files, directories and processes.
This isolation makes the container predictable.

The WordPress container does not directly see the MariaDB files in ``/var/lib/mysql``.
It only communicates with MariaDB through the Docker network.

That separation is important:

* WordPress container filesystem: ``/var/www/html``.
* MariaDB container filesystem: ``/var/lib/mysql``.

WordPress does not read MariaDB files directly.

It sends SQL queries over the network.

MariaDB is the only service responsible for reading and writing database files.

---

# FROM debian:bookworm

```Dockerfile
FROM debian:bookworm
```

This instruction defines the base image from which the WordPress image will be built.
This means the WordPress service starts from Debian 12, also known as Bookworm.

Debian provides:

* a Linux filesystem hierarchy;
* the `apt` package manager;
* system libraries;
* shell utilities;
* networking support;
* process management tools.

Every instruction after `FROM` is executed on top of this Debian base.

The final image becomes:

```text
Debian
   │
   ├── PHP-FPM packages
   ├── PHP MySQL extension
   ├── MariaDB client
   ├── WP-CLI
   ├── Initialization script
   └── Runtime configuration
```

---

## Why Not Use the Official WordPress Image?

The Inception subject requires building services manually instead of using pre-configured service images.

Using:

```Dockerfile
FROM wordpress
```

would already provide:

* WordPress files;
* PHP;
* PHP extensions;
* default entrypoint scripts;
* predefined configuration;
* built-in WordPress startup logic.

That would make the project easier, but it would hide most of the learning.

If the official image were used, we would not properly learn:

* how PHP-FPM is installed;
* why WordPress needs PHP-FPM;
* how PHP connects to MariaDB;
* why `php-mysql` is required;
* how WP-CLI installs WordPress;
* where WordPress files are stored;
* how file ownership affects WordPress;
* how the container startup sequence works;
* how NGINX communicates with PHP-FPM.

The goal of Inception is not only to make WordPress work.

The goal is to understand the infrastructure behind WordPress.

---

# What Is a Runtime Dependency?

A runtime dependency is software that an application needs while it is running.

For example, WordPress needs PHP while it is running because WordPress is written in PHP. Therefore PHP-FPM is a runtime dependency.

WordPress also needs to connect to MariaDB while it is running. Therefore the PHP MySQL/MariaDB extension is a runtime dependency.

This is different from a build-time dependency. A build-time dependency is only needed to build or prepare the image.

A runtime dependency is needed when the container is actually executing.

In this Dockerfile, the installed packages are runtime dependencies because the WordPress service needs them during container execution.

---

RUN is a Dockerfile instruction that executes commands during image build time. This means it runs when Docker builds the image, for example: ``docker compose build``. It does not run every time the container starts.

When the container starts later, Docker does not reinstall php-fpm, php-mysql, mariadb-client, curl or ca-certificates.

They are already part of the image.

The image is like a prepared machine.

The container is the running machine.

The Dockerfile prepares the machine.

The entrypoint script configures and starts the service.

A clean separation is:

Build time:
    install packages
    download WP-CLI
    copy scripts
    set permissions

Runtime:
    read secrets
    validate environment variables
    wait for MariaDB
    install WordPress
    create users
    start PHP-FPM

---

# Installing WordPress Runtime Dependencies

```Dockerfile
RUN apt-get update && apt-get install -y php-fpm php-mysql mariadb-client curl \
	ca-certificates && rm -rf /var/lib/apt/lists/*
```

This Dockerfile instruction installs the software required for the WordPress container to work correctly.

Before this line runs, the image is only a basic Debian Bookworm system. It has the Debian filesystem, the apt package manager, basic shell tools and system libraries, but it does not yet have the programs needed to run WordPress.

After this line runs, the image contains the main runtime dependencies required by the WordPress service:

* php-fpm, used to execute PHP code;
* php-mysql, used by PHP/WordPress to connect to MariaDB;
* mariadb-client, used by the startup script to test the MariaDB connection;
* curl, used to download WP-CLI;
* ca-certificates, used to validate HTTPS certificates when downloading files securely.

This line does not install WordPress itself.
It installs the tools that allow WordPress to be downloaded, configured and executed later by the init_wordpress.sh script.

A simplified view is:

> Debian base image -> Install PHP-FPM -> Install PHP database extension -> Install MariaDB client -> Install curl and CA certificates -> Image is ready to configure WordPress at runtime

## apt-get update

```bash
apt-get update
```

Debian uses `apt` to install packages. However, `apt` needs package indexes before it can install software.

These indexes tell Debian:

* which packages exist;
* which versions are available;
* where packages can be downloaded from;
* which dependencies they need.

`apt-get update` downloads these package indexes. It does not install anything by itself.

Without it, the installation may fail because Debian may not know where to find packages such as `php-fpm` or `php-mysql`.

---

## php-fpm

```bash
php-fpm
```

The Dockerfile installs: ``php-fpm``.

PHP-FPM means: ``PHP FastCGI Process Manager``. 

PHP-FPM is a service that manages PHP worker processes. Its job is to receive requests for PHP execution, run the PHP code, and return the generated result.

WordPress is written in PHP. The browser cannot execute PHP. NGINX cannot execute PHP by itself.

PHP files must be executed by a PHP interpreter. PHP-FPM is the service responsible for receiving PHP requests and executing the PHP code.

The relationship is: 

> NGINX -> PHP-FPM -> WordPress PHP files

When a request targets a PHP file, NGINX forwards the request to PHP-FPM using FastCGI.

PHP-FPM executes WordPress and returns the generated result to NGINX.

This is necessary because NGINX does not execute PHP by itself.

### What PHP-FPM Actually Does

PHP-FPM manages a pool of PHP worker processes.

A worker process is a PHP process waiting to handle a request.

When NGINX sends a PHP request, PHP-FPM assigns that request to an available worker.

The worker:

* loads the requested PHP file;
* executes the PHP code;
* lets WordPress connect to MariaDB if needed;
* generates HTML;
* returns the result to PHP-FPM;
* PHP-FPM sends the response back to NGINX.

A simplified diagram:

```text
NGINX
  │
  ▼
PHP-FPM master process
  │
  ├── PHP worker 1
  ├── PHP worker 2
  └── PHP worker 3
```

The PHP-FPM master process manages workers. The workers execute PHP code. This is why the PHP-FPM configuration contains settings like:

```text
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

These settings control how many PHP worker processes may exist.

### Why NGINX Cannot Execute PHP Alone

NGINX is a web server. It is very good at:

* receiving HTTP/HTTPS requests;
* serving static files;
* handling many connections efficiently;
* handling TLS/SSL;
* forwarding requests to other services.
* managing many simultaneous connections.

But NGINX is not a PHP interpreter. If NGINX receives a request for: ``/index.php`` it does not know how to execute PHP code by itself. It must pass the request to another process that understands PHP. That process is ``PHP-FPM``. So, NGINX forwards the PHP request to PHP-FPM.

The flow is:

> NGINX receives /index.php -> sends FastCGI request to PHP-FPM -> PHP-FPM executes WordPress PHP code -> PHP-FPM returns generated HTML -> NGINX sends HTML to the browser

So PHP-FPM acts as the bridge between NGINX and PHP execution.

### What Is FastCGI?

FastCGI is a communication protocol.

A protocol is a set of rules that defines how two programs exchange information.

In this project: 

NGINX communicates with PHP-FPM using FastCGI.

NGINX receives an HTTP request from the browser.

But NGINX does not send the exact same HTTP request to PHP-FPM.

Instead, it translates the request into FastCGI parameters.

For example, NGINX may send information such as:

```text
SCRIPT_FILENAME=/var/www/html/index.php
REQUEST_METHOD=GET
QUERY_STRING=
SERVER_NAME=rickymercury.42.fr
DOCUMENT_ROOT=/var/www/html
```

PHP-FPM receives this FastCGI request and knows which PHP file to execute.

The most important parameter is: SCRIPT_FILENAME because it tells PHP-FPM the exact PHP file to run.

Example:

SCRIPT_FILENAME=/var/www/html/index.php. Then PHP-FPM executes that file. The output is returned to NGINX.
NGINX then sends it back to the browser as an HTTP response.

---

## php-mysql

```bash
php-mysql
```

This package installs the PHP extension that allows PHP applications to connect to MySQL-compatible databases, including MariaDB.

WordPress needs this extension because almost all dynamic WordPress content is stored inside MariaDB.

Examples:

* users;
* posts;
* pages;
* comments;
* site title;
* plugin settings;
* theme settings.

Without php-mysql, WordPress PHP code could execute, but it could not connect to the database.
That would make WordPress unusable.
A typical error would be:

> Your PHP installation appears to be missing the MySQL extension which is required by WordPress.

So php-mysql is not optional. It is essential.

It allows WordPress PHP code to communicate with MariaDB.

---

## mariadb-client

```bash
mariadb-client
```

This package installs the MariaDB command-line client.

The WordPress container does not run the MariaDB server. MariaDB runs in its own container.

This package installs only the client tools, not the MariaDB server.

The WordPress container must not run the database server.

The database server belongs to the MariaDB container.

However, the WordPress container still needs a way to test the MariaDB connection.

That is why the client is installed.

The script uses something like:

```text
mariadb -h "$MDB_HOST" -u "$MDB_USER" -p"$DB_PASSWORD" "$MDB_DATABASE" -e "SELECT 1"
```

This command means:

* Connect to host stored in MDB_HOST.
* Use database user stored in MDB_USER.
* Use password stored in DB_PASSWORD.
* Select the database stored in MDB_DATABASE.
* Execute SELECT 1.

It checks whether MariaDB is reachable and usable.
This is important because Docker Compose depends_on only starts containers in order.
It does not guarantee that MariaDB is fully ready.
MariaDB may still be initializing when WordPress starts.
So WordPress must wait until MariaDB accepts connections.

Without `mariadb-client`, this readiness check would not work.

---

## ca-certificates

```bash
ca-certificates
```

This package installs trusted Certificate Authority certificates.

When curl connects to an HTTPS URL, it must verify that the server certificate is valid.

HTTPS uses certificates to prove that the remote server is really who it claims to be.

Without ca-certificates, curl may fail with certificate verification errors.

Since WP-CLI is downloaded through HTTPS, this package is needed for a secure and reliable download.

---

## Why Remove apt Cache?

```bash
rm -rf /var/lib/apt/lists/*
```

``apt-get update`` downloads package indexes into: ``/var/lib/apt/lists/``.

These files are useful only during package installation.
After the packages are installed, they are no longer needed.
Removing them reduces the final image size.

This does not remove installed packages.
It only removes temporary apt cache data.
The result is a cleaner image.

Smaller images:

* use less disk space;
* build faster;
* transfer faster;
* contain less unnecessary data.

---

# Installing WP-CLI

```Dockerfile
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp
```

This instruction installs ``WP-CLI``, the official command-line interface for WordPress.

## What Is WP-CLI?

WP-CLI stands for: ``WordPress Command Line Interface``. It is a tool that allows WordPress to be managed entirely from the terminal.

Normally, when installing WordPress manually, a person must open the browser and complete the installation page.
This works on a traditional server but creates problems inside Docker.

Docker containers are supposed to be:

* automatic;
* reproducible;
* self-configuring;
* deployable without human interaction.

Imagine recreating WordPress container ten times. If each container required manually opening the browser and completing the installer again, automation would be impossible. ``WP-CLI`` solves this problem.

Instead of using a browser, ``wp core install`` can perform the entire installation automatically.

## Why Is WP-CLI Important In Inception?

The Inception project is heavily focused on automation.

When the WordPress container starts, the initialization script must be capable of:

* downloading WordPress;
* generating wp-config.php;
* connecting WordPress to MariaDB;
* installing the site;
* creating the administrator account;
* creating additional users.

WP-CLI makes all of this possible.

Without WP-CLI the script would have no easy way to configure WordPress automatically.

The startup sequence becomes:

> Container Starts -> init_wordpress.sh -> WP-CLI Downloads WordPress -> WP-CLI Creates wp-config.php -> WP-CLI Installs WordPress -> WP-CLI Creates Users -> PHP-FPM Starts

This is why WP-CLI is one of the most important tools in the WordPress container.

## Downloading WP-CLI

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
```

This command downloads the ``WP-CLI PHAR`` file. A PHAR file is a ``PHP archive``.
It bundles ``PHP code`` into a single executable file.

The download happens during image build time.

The `-O` option tells `curl` to save the downloaded file using its original filename: ``wp-cli.phar``.

## What Is A PHAR File?

The downloaded file is: ``wp-cli.phar``. ``PHAR`` stands for: ``PHP Archive``.

A PHAR file bundles many PHP files into a single executable package. Instead of distributing hundreds of files:

```text
wp-cli/
├── file1.php
├── file2.php
├── file3.php
└── ...
```

all code is packed into: ``wp-cli.phar``. This makes distribution easier.

The entire WP-CLI application exists inside this single file.

## Making WP-CLI Executable

```bash
chmod +x wp-cli.phar
```

Linux files have permissions. A file can have:

* read permission;
* write permission;
* execute permission.

The operating system refuses to run such a file as a command. 

Adding execute permission: ``chmod +x``, Linux recognizes it as an executable file.

Without this step, ``./wp-cli.phar`` would fail with ``Permission denied``.

## Moving WP-CLI Into The PATH

```bash
mv wp-cli.phar /usr/local/bin/wp
```

This command performs moves the wp-cli.phar file and renames it.

Linux uses PATH which contains directories where executable programs are searched.

Since ``/usr/local/bin`` belongs to PATH, moving wp-cli.phar into that path, we rename it to ``wp`` so when we run ``wp`` command, Linux searches the PATH directories and now this file works from anywhere and the script can run from anywhere inside the container: 

```bash
wp core download
wp config create
wp core install
wp user create
```

So, after execution, ``wp-cli.phar`` becomes ``/usr/local/bin/wp``.

---

# Creating Required Directories

```Dockerfile
RUN mkdir -p /var/www/html /run/php && chown -R www-data:www-data /var/www/html /run/php
```
This block prepares the filesystem required by WordPress and PHP-FPM.

Before WordPress can run, Linux needs places where files can be stored.

Think of WordPress as a complete application. Applications need directories for:

* source code;
* configuration files;
* uploaded files;
* runtime files;
* logs;
* temporary files.

This instruction creates those locations.

## Understanding /var/www/html

``/var/www/html`` is the traditional Linux WordPress web root directory.

A web root is the directory from which a web server serves website files. Think of it as the main folder of the website. Everything that makes WordPress exist lives here.

After installation:

```text
/var/www/html
│
├── index.php
├── wp-config.php
├── wp-admin/
├── wp-content/
├── wp-includes/
└── hundreds of WordPress files
```

## index.php

This is the entry point of WordPress.

Almost every request eventually reaches ``index.php`` which loads WordPress.


## wp-config.php

This file contains WordPress configuration.

Most importantly:

* DB_NAME
* DB_USER
* DB_PASSWORD
* DB_HOST

Without it WordPress cannot connect to MariaDB.

This file acts as the bridge between: WordPress and MariaDB.

## wp-content

It contains:

* Themes
* Plugins
* Uploads
* Cache files

User-generated content lives here.

## Why Is /var/www/html Mounted As A Volume?

Inside Docker Compose:

This ensures persistence.

Without a volume:

Container deleted
      │
      ▼
All WordPress files disappear

With a volume:

Container deleted
      │
      ▼
Files remain on disk

This is critical because WordPress installations must survive container recreation.

## Understanding /run/php

``/run/php`` is the PHP-FPM runtime directory.

Runtime means files that only exist while the service is running.

Typical contents:

```text
/run/php
│
├── php-fpm.pid (PID files)
├── php-fpm.sock (socket files)
└── temporary files
```

These files are not application data. They only help PHP-FPM operate.

When the container stops, runtime files disappear, which is completely normal.

They exist only while PHP-FPM is running.

## www-data Ownership

```bash
chown -R www-data:www-data /var/www/html /run/php
```

Changes owner and group to `www-data`.

Linux does not run everything as root. Services usually run using dedicated users.

Examples:

```text
mysql     -> MariaDB
nginx     -> NGINX
www-data  -> Web Applications
```

PHP-FPM executes WordPress as ``www-data`` not as root.

Imagine ``wp-content/uploads`` belongs to ``root`` but PHP-FPM runs as ``www-data``, and now a user uploads an image. WordPress tries to create a file inside ``wp-content/uploads``. Linux checks permissions. Linux sees ``www-data`` is not the owner. Result: Permission denied. Upload fails.
This is why ownership is critical.

``chown -R www-data:www-data`` means:

```text
Owner  -> www-data
Group  -> www-data
```

The option -R means recursive, which apply the change to:

* every directory;
* every file;
* every subdirectory.

Example:

```text
Before: root:root /var/www/html

After: www-data:www-data /var/www/html
```

This allows PHP-FPM to:

* create files;
* modify files;
* delete files;
* upload images;
* install plugins;
* update themes;
* generate cache files.

Without this ownership configuration, many WordPress features would break.

---

# Copying the Initialization Script

```Dockerfile
COPY ./tools/init_wordpress.sh /usr/local/bin/init_wordpress.sh
```

Copies the custom WordPress initialization script into the image.

Without this script, the container would contain PHP-FPM and WP-CLI, but it would not know how to configure WordPress for the project.

The script performs runtime tasks such as:

* reading Docker secrets;
* validating environment variables;
* generating PHP-FPM configuration;
* waiting for MariaDB;
* downloading WordPress;
* creating `wp-config.php`;
* installing WordPress;
* creating users;
* setting ownership;
* starting PHP-FPM.

These tasks must happen at runtime, not build time, because they depend on secrets, environment variables, volumes and the MariaDB container.

---

# Making the Script Executable

```Dockerfile
RUN chmod +x /usr/local/bin/init_wordpress.sh
```

Gives execution permission to the initialization script.

Without this, Docker could fail with:

```text
Permission denied
```

when trying to execute the entrypoint.

---

# EXPOSE 9000

```Dockerfile
EXPOSE 9000
```

Documents that the WordPress container listens on port 9000.

This is the PHP-FPM port.

NGINX uses this port to send PHP requests to WordPress.

The flow is:

```text
NGINX
  │
  ▼
wordpress:9000
  │
  ▼
PHP-FPM
```

This port should normally not be published to the host.

Only NGINX needs to reach it through the internal Docker network.

---

# Understanding ENTRYPOINT

```Dockerfile
ENTRYPOINT ["init_wordpress.sh"]
```

ENTRYPOINT defines the command executed when the container starts.

In this case, Docker starts:

```bash
init_wordpress.sh
```

The script prepares WordPress and then starts PHP-FPM.

The startup flow is:

```text
Container starts
       │
       ▼
init_wordpress.sh
       │
       ▼
Validate secrets and environment
       │
       ▼
Wait for MariaDB
       │
       ▼
Install WordPress if needed
       │
       ▼
Start PHP-FPM
```

The container becomes self-configuring.

---

# Why exec Is Important

The final line of the script should be:

```bash
exec php-fpm8.2 -F
```

`exec` replaces the shell script with the PHP-FPM process.

Without exec:

```text
PID 1 -> init_wordpress.sh
PID 14 -> php-fpm
```

With exec:

```text
PID 1 -> php-fpm
```

Docker monitors PID 1.

If PHP-FPM exits, the container stops and Docker can restart it according to the restart policy.

The `-F` option runs PHP-FPM in foreground mode.

This is required because Docker containers must keep their main process running in the foreground.

If PHP-FPM daemonized into the background, the script would finish and the container would stop.

---

# Complete WordPress Startup Sequence

```text
docker compose up
        │
        ▼
WordPress container starts
        │
        ▼
ENTRYPOINT runs init_wordpress.sh
        │
        ▼
Secrets are loaded
        │
        ▼
Environment variables are validated
        │
        ▼
PHP-FPM configuration is generated
        │
        ▼
Script waits for MariaDB
        │
        ▼
WordPress is downloaded if missing
        │
        ▼
wp-config.php is created
        │
        ▼
WordPress site is installed
        │
        ▼
Users are created
        │
        ▼
PHP-FPM starts in foreground
        │
        ▼
NGINX can forward PHP requests to wordpress:9000
```
