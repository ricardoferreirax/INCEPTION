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


# This Dockerfile builds the custom WordPress image used by the WordPress container.
# The image is built from Debian Bookworm and contains only the packages and files
# needed to run WordPress inside the Inception Docker network.

# debian:bookworm means that the container image starts from Debian 12, also known as Bookworm. 
# This gives the image a Linux filesystem, the Debian package manager apt, and the base 
# environment needed to install PHP, WordPress tools, and system utilities.
# In Inception, this is important because each service must be built from a base operating system 
# image, not from a ready-made WordPress image. So instead of using something like FROM wordpress
# we build the WordPress container from Debian.


# RUN commands are executed only during image creation. They are not executed every time the container 
# starts. The result of this command becomes part of the final image.
# installs the packages needed by the WordPress container.
# > php-fpm installs PHP-FPM, which is the FastCGI Process Manager for PHP. WordPress is written in PHP, 
#   so the container needs PHP to execute WordPress code. PHP-FPM is the service that receives PHP requests 
#   from NGINX and executes the PHP files.
# > php-mysql installs the PHP extension that allows PHP applications to connect to MySQL or MariaDB databases. 
#   Without this package, WordPress would not be able to communicate with the MariaDB container.
# > mariadb-client installs the MariaDB command-line client. The WordPress script uses it to wait until MariaDB 
#   is ready before running the WordPress installation.
# > curl is used to download files from the internet. In this Dockerfile, it is used to download WP-CLI.
# > ca-certificates installs trusted Certificate Authority certificates. These are needed when making HTTPS 
#   requests. Since WP-CLI is downloaded from an HTTPS URL, ca-certificates helps curl verify the remote server 
#   securely.
#
# rm -rf /var/lib/apt/lists/* removes the cached package lists created by apt-get update. It reduces the final 
# image size. After the packages are installed, the package index files are no longer needed inside the final image.


# The third block installs WP-CLI. WP-CLI is the command-line tool for managing WordPress. Instead of opening the 
# WordPress installation page in a browser, the script can install and configure WordPress automatically.
# Downloads the WP-CLI.phar file from the official WP-CLI GitHub repository and then makes it executable. Without
# this permission, the container would not be able to run WP-CLI commands. 
# Finally, moves the executable WP-CLI file to /usr/local/bin, and renames it to wp. This allows the script to run 
# WP-CLI commands simply by typing wp instead of php wp-cli.phar from anyhwhere inside the container.


# Creates the directories needed by WordPress and PHP-FPM, and sets the correct ownership.
# > /var/www/html: this is the web root directory. A web root is the directory from which a web server serves files 
#                  to users. We can think of it as the main folder of the website, when someone accesses: https://login.42.fr,
#                  NGINX will look inside /var/www/html for the files that make up the website. This is where the WordPress 
# 			       files are stored. After WordPress is installed, this directory will contain files such as:
#
#                  - index.php: the main entry point for WordPress. When a user visits the website, NGINX serves this file, 
#                               which then loads the rest of WordPress.
#				  - wp-config.php: contains the WordPress configuration. Inside this file, WordPress stores the database hostname, 
#                                  databse name, database user, database password and site configuration.
#								   Without this file WordPress cannot connect to the database and will not work.
#				  - wp-content/ : contains content such as plugins, themes, uploads, and cache files. Everything that makes the
#                                 website customizable is stored in this directory.
#
# 	This directory is also mounted as a Docker volume in docker-compose.yml, so WordPress files persist even if the container 
# 	is destroyed and recreated.
# > /run/php: is the runtime directory used by PHP-FPM to store temporary runtime process files, sockets and PID files.
#             Runtime data means files that only exist while the service is running.
#             A PID file contains the process ID of a running process. For example, php-fpm.pid may contain: 42 meaning PHP-FPM 
#             is currently running as process 42.
#             A socket file is a special file used for communication between processes. Although PHP-FPM configuration uses:
#             listen = 0.0.0.0:9000, which creates a TCP socket, many PHP-FPM installations instead use: /run/php/php-fpm.sock,
#             which is a Unix socket. Both approaches allow communication between NGINX and PHP-FPM.
# 
# chown -R www-data:www-data: changes the owner and group of the directories to www-data.
# Imagine that WordPress tries to upload an image. The image must be written into: wp-content/uploads. If PHP-FPM is 
# running as: www-data but the directory belongs to: root, then PHP may receive: Permission denied and the upload will fail.
# This is why ownership is critical. Changes: Owner -> www-data and Group -> www-data, for every file and directory inside:
# /var/www/html and /run/php .
# This is important because PHP-FPM runs WordPress PHP code as www-data. If the files are owned by root and not writable, 
# WordPress may fail to create or modify files in wp-content, such as plugins, themes, uploads, or cache files.
# In the end, the permissions are set so that the www-data user can read, write, and execute files in /var/www/html and /run/php, 
# which allows WordPress to function properly.


# This copies the custom WordPress initialization script into the image.
# The host filesystem is the Debian machine.
# During the image build, Docker cannot automatically access files from the host. If a file is needed inside the image, it must 
# be explicitly copied. This is exactly what the COPY instruction does. The source: ./tools/init_wordpress.sh is relative to the 
# build context. The destination: /usr/local/bin/init_wordpress.sh is inside the image filesystem.
# After the image is built, the file exists inside the container exactly as if it had been created there manually.
# The directory: /usr/local/bin is traditionally used in Linux for custom executables installed by the administrator.
# Anything placed in this directory can usually be executed directly because it belongs to the system PATH.
# The script is responsible for the runtime setup of WordPress, such as: reading Docker secrets;
#																	     validating environment variables;
#																		 generating the PHP-FPM configuration;
#																		 waiting for MariaDB;
#																		 downloading WordPress;
#																		 creating wp-config.php;
#																		 installing WordPress;
#																		 creating users;
#																		 fixing permissions;
#																		 starting PHP-FPM.
# This script becomes the brain of the WordPress container. The Dockerfile itself only installs software.
# The script performs all runtime logic.
# Docker image build time happens once (example: docker build) and Container runtime happens every time: (example, docker run 
# and docker compose up).
# During build time: Docker secrets do not exist;
#                    volumes are not mounted;
#                    environment variables may not exist;
#                    MariaDB is not running.
#
# Therefore WordPress cannot be configured during image creation. It must be configured when the container starts.
# It happens in init_wordpress.sh. It configures the container based on secrets, environment variables and volumes.
# Dockerfile builds the machine. init_wordpress.sh configures the machine.


# ENTRYPOINT: defines the command executed every time a container starts.
# This means: Container starts -> init_wordpress.sh runs -> WordPress is configured -> PHP-FPM starts
# When a Docker launches the container, it executes init_wordpress.sh automatically. This is why the container becomes self-configuring.
# No manual intervention is required.
# The final line of the script is: exec php-fpm8.2 -F . The exec command replaces the shell process with the PHP-FPM process. 
# The shell disappears and PHP-FPM takes its place. This means: PID 1 = php-fpm , inside the container.
# Docker expects a single main process. This main process is always PID 1.
# The option: -F means foreground mode. Without it, PHP-FPM would daemonize itself and move to the background.
# Then PID 1 would immediately terminate and Docker would stop the container.
