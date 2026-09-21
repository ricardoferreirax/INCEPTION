# User Documentation

## Services Provided by the Stack

The Inception infrastructure is built around three mandatory services: **NGINX**, **WordPress with PHP-FPM**, and **MariaDB**. Each service runs in its own Docker container and has a specific responsibility.

From the user's perspective, WordPress provides the website and administration interface, NGINX provides secure access to the infrastructure, and MariaDB stores the information required by WordPress.

The main communication flow is:

```text
User
  |
  | HTTPS
  v
NGINX
  |
  | PHP requests
  v
WordPress + PHP-FPM
  |
  | Database queries
  v
MariaDB
```

### NGINX

NGINX is the public entry point of the infrastructure.

Its main responsibilities are:

* Accept external HTTPS connections on port `443`.
* Secure connections using TLS 1.2 and TLS 1.3.
* Serve the WordPress website.
* Serve static WordPress files.
* Forward PHP requests to WordPress through PHP-FPM.
* Provide access to additional web services through reverse proxy routes.

The project uses a self-signed TLS certificate, so the browser may display a security warning. This is expected for the project.

---

### WordPress + PHP-FPM

WordPress provides the main website and its administration interface, while PHP-FPM executes the PHP code required to generate dynamic pages.

Administrators can use WordPress to manage:

* Posts and pages.
* Comments.
* Media and uploaded files.
* Themes and plugins.
* Website configuration.

WordPress communicates with MariaDB whenever database information is required and uses Redis to cache frequently accessed objects.

Its files are stored in persistent storage, allowing them to remain available when the container is recreated.

---

### MariaDB

MariaDB provides the database used by WordPress. It stores information such as:

* WordPress users.
* Posts and pages.
* Comments.
* Website settings.
* Plugin and theme configuration.
* WordPress metadata.

WordPress communicates with MariaDB through the private Docker network.

The database files are stored outside the container in persistent storage, ensuring that recreating the MariaDB container does not remove the existing WordPress database.

---

### How the Mandatory Services Work Together

When a visitor accesses the website:

1. The browser connects to NGINX using HTTPS.
2. NGINX handles the secure TLS connection.
3. Static files can be served directly by NGINX.
4. PHP requests are forwarded to WordPress through PHP-FPM.
5. WordPress requests information from MariaDB when required.
6. MariaDB returns the requested database information.
7. WordPress generates the page.
8. NGINX returns the response to the user's browser.

This separation allows the web server, application and database to run independently while communicating through the Docker network.

---

## Additional Services

The project also includes several additional services that extend the functionality of the mandatory infrastructure.

### Redis

Redis provides object caching for WordPress.

Instead of repeatedly requesting the same information from MariaDB, WordPress can retrieve cached objects from Redis when available. This helps reduce unnecessary database queries.

Redis runs internally on port:

```text
6379
```

It is not directly exposed to users outside the Docker network.

---

### Adminer

Adminer provides a web-based interface for inspecting and managing the MariaDB database.

It can be used to:

* Browse databases and tables.
* Inspect WordPress records.
* Execute SQL queries.
* Insert, update or remove database records.
* Verify that WordPress is correctly communicating with MariaDB.

---

### FTP

The FTP service provides file transfer access to the persistent WordPress filesystem.

It can be used to:

* Upload files.
* Download files.
* Modify files stored in the shared WordPress volume.

The FTP container shares the WordPress persistent storage, so files transferred through FTP are available to WordPress.

---

### Static Website

The static service provides an additional website composed of static content.

It demonstrates that a separate web service can run inside the infrastructure and be made accessible through the main NGINX server.

---

### Portainer

Portainer provides a graphical interface for viewing and managing Docker resources.

It can be used to inspect:

* Containers.
* Images.
* Networks.
* Volumes.
* Container status and logs.

It communicates with the Docker daemon through the Docker socket.

---

## Starting and Stopping the Project

The Makefile provides simple commands for managing the complete infrastructure without requiring users to execute Docker Compose commands manually.

### Starting the Project

Build and start the complete infrastructure with:

```bash
make
```

or:

```bash
make up
```

The containers continue running in the background after startup.

Check their status with:

```bash
docker ps
```

### Stopping the Project

Stop the containers without removing them:

```bash
make stop
```

Start them again with:

```bash
make start
```

This keeps the containers, volumes and persistent data available.

### Removing the Running Infrastructure

Stop and remove the containers and Docker Compose network with:

```bash
make clean
```

The persistent WordPress, MariaDB and Portainer data remains stored on the host and can be reused the next time the project starts.

### Performing a Complete Cleanup

Remove the containers, volumes and persistent project data with:

```bash
make fclean
```

> **Warning:** `make fclean` permanently removes the persistent MariaDB, WordPress and Portainer data stored by the project.

To rebuild the project from a clean state:

```bash
make re
```

Because `make re` performs `fclean` first, it also removes the existing persistent data before rebuilding the infrastructure.

---

## Accessing the Website and Administration Panel

### WordPress Website

The public website is available at:

```text
https://rmedeiro.42.fr/
```

The connection uses HTTPS with TLS 1.2 or TLS 1.3.

Because the project uses a self-signed TLS certificate, the browser may display a security warning. After accepting the certificate, the website can be accessed normally.

### WordPress Administration

The administration panel is available at:

```text
https://rmedeiro.42.fr/wp-admin/
```

The administrator must authenticate using the WordPress administrator credentials configured during installation.

The dashboard can be used to manage posts, pages, comments, media, themes, plugins and other website settings.

### Additional web services

Additional web services can be checked at:

```text
https://rmedeiro.42.fr/adminer
https://rmedeiro.42.fr/static
https://rmedeiro.42.fr/portainer
```

---

## Credentials Management

Sensitive credentials are stored separately from Docker images and normal configuration files.

Password files are located in:

```text
secrets/
```

The project uses:

```text
db_root_password.txt
db_password.txt
wp_admin_password.txt
wp_user_password.txt
ftp_password.txt
```

Non-sensitive configuration is stored in:

```text
srcs/.env
```

This file contains values such as the domain name, service ports, usernames and WordPress account information.

Docker provides each secret only to the containers that require it.

Credentials should be changed in their corresponding secret files rather than being placed directly inside Dockerfiles or initialization scripts.

> **Note:** Changing a secret file after MariaDB or WordPress has already been initialized does not necessarily update credentials stored in the existing persistent data.

---

## Checking the Services

After starting the infrastructure, check the running containers with:

```bash
docker ps
```

The complete stack should contain:

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

MariaDB, WordPress and Redis have Docker healthchecks. After initialization, their status should appear as:

```text
healthy
```
---

## Troubleshooting and Debugging

### Check Health Status

Display the health information together with the normal container status:

```bash
docker ps
```

For detailed healthcheck information:

```bash
docker inspect --format='{{json .State.Health}}' mariadb
docker inspect --format='{{json .State.Health}}' wordpress
docker inspect --format='{{json .State.Health}}' redis
```

To display only the current health status:

```bash
docker inspect --format='{{.State.Health.Status}}' mariadb
docker inspect --format='{{.State.Health.Status}}' wordpress
docker inspect --format='{{.State.Health.Status}}' redis
```

Expected result after successful startup:

```text
healthy
```

---

### Test MariaDB

Execute the same type of query used to verify that MariaDB can process requests:

```bash
docker exec mariadb sh -c 'mariadb -h localhost -u rmedeiro -p$(cat /run/secrets/db_password) -e "SELECT 1"'
```

A successful result confirms that MariaDB is running and accepting SQL queries.

The database can also be opened interactively with:

```bash
docker exec -it mariadb mariadb -u rmedeiro -p
```

---

### Test WordPress and PHP-FPM

Check that PHP-FPM is running as the main WordPress process:

```bash
docker exec wordpress grep -a php-fpm /proc/1/cmdline
```

The output should contain:

```text
php-fpm
```

---

### Test Redis

Check that Redis is accepting connections:

```bash
docker exec redis redis-cli ping
```

Expected response:

```text
PONG
```

Check the WordPress Redis connection with:

```bash
docker exec wordpress wp redis status --allow-root
```

---

### Test NGINX

Check the NGINX configuration:

```bash
docker exec nginx nginx -t
```

Test the HTTPS endpoint:

```bash
curl -k -I https://rmedeiro.42.fr/
```

The `-k` option accepts the self-signed certificate.

---

### Test Adminer

Open:

```text
https://rmedeiro.42.fr/adminer/
```

Adminer should display its database login interface.

The MariaDB server name used from Adminer is:

```text
mariadb
```

---

### Test FTP

Check that the FTP container is running:

```bash
docker ps --filter name=ftp
```

Its logs can be inspected with:

```bash
docker logs ftp
```

The service should listen on port `21` and use the passive port range `40000-40010`.

---

### Test the Static Website

Send a request to:

```bash
curl -k -I https://rmedeiro.42.fr/static/
```

A successful HTTP response confirms that NGINX can reach the static service.

---

### Test Portainer

Send a request to:

```bash
curl -k -I https://rmedeiro.42.fr/portainer/
```

The Portainer interface should also be accessible from the browser at:

```text
https://rmedeiro.42.fr/portainer/
```
