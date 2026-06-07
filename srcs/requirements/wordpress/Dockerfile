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

# The fourth block creates the directories needed by WordPress and PHP-FPM, and sets the correct ownership.
# > /var/www/html is the web root directory. THis is where the WordPress files are stored.
# 	Files such as index.php, wp-config.php, wp-admin/, wp-content/ and wp-includes/ will be inside this directory.
# 	This directory is also mounted as a Docker volume in docker-compose.yml, so WordPress files persist even if the container 
# 	is destroyed and recreated.
# > /run/php is the runtime directory used by PHP-FPM to store temporary process files, socket and PID files.
# 
# chown -R www-data:www-data: changes the owner and group of the directories to www-data.
# This is important because PHP-FPM runs WordPress PHP code as www-data. If the files are owned by root and not writable, 
# WordPress may fail to create or modify files in wp-content, such as plugins, themes, uploads, or cache files.
# In the end, the permissions are set so that the www-data user can read, write, and execute files in /var/www/html and /run/php, 
# which allows WordPress to function properly.

# The fifth block copies the custom WordPress initialization script into the image.
# The source path: ./tools/init_wordpress.sh is relative to the Docker build context. Since the Dockerfile is
# inside: srcs/requirements/wordpress/ , means the script is located at: srcs/requirements/wordpress/tools/init_wordpress.sh.
# The destination path is: /usr/local/bin/init_wordpress.sh . This places the script inside the container.
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
# This logic belongs in the script because it must run when the container starts, not when the image is built.
# Dockerfile build time creates the image.
# init_wordpress.sh runtime configures the container based on secrets, environment variables, and volumes.

# ENTRYPOINT: defines the command that runs when the container starts. When Docker creates a container from this image, 
# it automatically executes init_wordpress.sh because the script was moved to: /usr/local/bin/init_wordpress.sh
# where is normally in the PATH, Docker can find it by name.
# This entrypoint is what makes the container self-configuring. When the container starts, the script runs and runs exec php-fpm8.2 -F.
# That final exec is important because it replaces the shell script process with PHP-FPM. As a result, PHP-FPM becomes the main process 
# of the container. In Docker, the main process should stay in the foreground. If it exits, the container stops.