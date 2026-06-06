# Docker Commands

A complete collection of useful Docker and Docker Compose commands commonly used during the Inception project.

---

## Table of Contents

* [1. Build Commands](#1-build-commands)
* [2. Starting Containers](#2-starting-containers)
* [3. Stopping Containers](#3-stopping-containers)
* [4. Listing Containers](#4-listing-containers)
* [5. Logs](#5-logs)
* [6. Container Cleanup](#6-container-cleanup)
* [7. Images](#7-images)
* [8. Volumes](#8-volumes)
* [9. Networks](#9-networks)
* [10. Managing Bind Mount Directories](#10-managing-bind-mount-directories)
* [11. Entering Containers and MariaDB Commands](#11-entering-containers-and-mariadb-commands)

---

# 1. Build Commands

Build commands are used to create Docker images.

A Docker image is like a blueprint or template. It contains everything needed to create a container: the operating system base, installed packages, copied configuration files, scripts, dependencies, and the command that should run when a container starts.

In the Inception project, each service must have its own image. Usually, the project contains at least three services:

* MariaDB
* WordPress
* Nginx

Each one has its own Dockerfile, and Docker Compose builds each image using the information written in `docker-compose.yml`.

---

## 1.1 Build All Images

<div align="center">

<pre><code class="language-bash">docker compose build</code></pre>

</div>

This command reads the `docker-compose.yml` file and builds every service that contains a `build:` section.

Example:

```yaml
services:
  mariadb:
    build:
      context: ./requirements/mariadb
      dockerfile: Dockerfile

  wordpress:
    build:
      context: ./requirements/wordpress
      dockerfile: Dockerfile

  nginx:
    build:
      context: ./requirements/nginx
      dockerfile: Dockerfile
```

In this example, Docker Compose sees three services with build instructions:

* `mariadb`
* `wordpress`
* `nginx`

When running `docker compose build`, Docker Compose enters each build context and builds the image using the corresponding Dockerfile.

The `context` tells Docker where the files for that image are located. For example:

```yaml
context: ./requirements/mariadb
```

means that Docker will use the directory `./requirements/mariadb` as the build directory.

The `dockerfile` field tells Docker which Dockerfile to use inside that context:

```yaml
dockerfile: Dockerfile
```

This command only builds the images. It does not start containers.

We use this command when:

* We want to prepare all images.
* We changed Dockerfiles.
* We changed scripts copied into the images.
* We want to check if every image builds correctly.
* We want to validate the project before running it.

---

## 1.2 Build Only One Service

<div align="center">

<pre><code class="language-bash">docker compose build mariadb</code></pre>

</div>

This command builds only the `mariadb` image.

Instead of rebuilding every service, Docker Compose only looks at the service named `mariadb` in the `docker-compose.yml` file and builds that specific image.

This is useful during development because rebuilding every service can waste time.

For example, if we are only changing MariaDB files, such as:

* `requirements/mariadb/Dockerfile`
* `requirements/mariadb/conf/50-server.cnf`
* `requirements/mariadb/tools/init_mariadb.sh`

then there is no need to rebuild WordPress or Nginx.

We use this command when:

* We are working on only one service.
* One Dockerfile changed.
* One startup script changed.
* We want to isolate errors from a single service.

---

Important difference:

| Command                                   | Meaning                                     |
| ----------------------------------------- | ------------------------------------------- |
| `docker compose build`                    | Builds images using cache when possible     |
| `docker compose build --no-cache`         | Builds images from zero without using cache |
| `docker compose build mariadb`            | Builds only MariaDB                         |
| `docker compose build --no-cache mariadb` | Rebuilds only MariaDB from zero             |

---

# 2. Starting Containers

Starting commands create and run containers from images.

An image is only a template. A container is the running instance of that image.

For example:

* `mariadb image` contains MariaDB installed and configured.
* `mariadb container` is the actual running database process.

Docker Compose uses the `docker-compose.yml` file to know:

* Which containers to create.
* Which images to use.
* Which ports to expose.
* Which volumes to mount.
* Which networks to attach.
* Which environment variables to pass.
* Which services depend on each other.

---

## 2.1 Start All Services

<div align="center">

<pre><code class="language-bash">docker compose up</code></pre>

</div>

This command starts all services defined in the `docker-compose.yml` file.

This command reads the `docker-compose.yml` file and starts all services. Creates the complete application stack defined inside it.

When executed, Docker Compose performs multiple operations:

```text
1. Reads docker-compose.yml
2. Creates missing networks
3. Creates missing volumes
4. Creates containers if do not exist
5. Starts containers
```

Internally, Docker communicates with the Docker daemon (`dockerd`) through the Docker API.

The daemon then creates all resources required by the application.

If the **required images** do not exist yet, Docker Compose may build them first if a `build:` section exists.

This command also attaches the terminal to the logs of all services. That means the terminal will display output from:

* MariaDB
* WordPress
* Nginx

This is very useful for debugging because errors appear immediately. For example, if MariaDB fails to start because of a wrong configuration file, the error appears directly in the terminal.

Pressing **CTRL + C** stops the containers started by `docker compose up`.

We use this command when:

* We are testing the project.
* We want to see logs immediately.
* We are debugging startup errors.
* We want to check if all services start correctly.

---

## 2.2 Start One Service Only

<div align="center">

<pre><code class="language-bash">docker compose up mariadb</code></pre>

</div>

This command starts only the `mariadb` service.

Docker Compose reads the service named `mariadb` from the Compose file and starts only that container.

This is useful when testing one service independently. For example, during MariaDB development, we may want to verify only:

* Whether MariaDB starts.
* Whether the init script runs.
* Whether the database is created.
* Whether the user is created.
* Whether the permissions are correct.

We use this command when:

* We want to test a single service.
* We are debugging one container only.
* We do not want to start the full stack.

---

## 2.3 Build and Start All Services

<div align="center">

<pre><code class="language-bash">docker compose up --build</code></pre>

</div>

This command builds the images first and then starts the containers.

It is equivalent to running:

<div align="center">

<pre><code class="language-bash">docker compose build
docker compose up</code></pre>

</div>

The difference is that `docker compose up --build` does both steps in one command.

We use this after modifying:

* Dockerfiles
* Shell scripts
* Configuration files
* `docker-compose.yml`
* Files copied into the image during build

This command is very useful because it avoids the mistake of changing files but starting old containers based on old images.

Important detail: if the container already exists, Docker Compose may recreate it if the image or configuration changed.

We use this command when:

* We changed project files.
* We want to rebuild before starting.
* We are testing the full project.
* We want to make sure containers are using the latest image.

---

## 2.4 Build and Start One Service

<div align="center">

<pre><code class="language-bash">docker compose up --build mariadb</code></pre>

</div>

This command rebuilds and starts only the `mariadb` service.

It is useful during focused development. For example, if we are editing: **requirements/mariadb/tools/init_mariadb.sh**, we can rebuild and restart only MariaDB instead of rebuilding everything.

We use this command when:

* We changed only one service.
* We want a faster development cycle.
* We want to debug one container.
* We want to avoid rebuilding unrelated images.

---

## 2.5 Start Containers in Background

<div align="center">

<pre><code class="language-bash">docker compose up -d</code></pre>

</div>

The `-d` flag means detached mode.

Detached mode means the containers run in the background and the terminal becomes available immediately.

Without `-d`, the terminal stays attached to the logs.

With `-d`, Docker starts the containers and then returns control to the terminal.

Example for one service:

<div align="center">

<pre><code class="language-bash">docker compose up -d mariadb</code></pre>

</div>

We use detached mode when:

* The project is already working.
* We do not need to watch logs directly.
* We want containers running while we use the terminal.

---

Difference:

| Command                        | Behavior                                               |
| ------------------------------ | ------------------------------------------------------ |
| `docker compose up`            | Starts containers and shows logs in the terminal       |
| `docker compose up -d`         | Starts containers in the background                    |
| `docker compose up --build`    | Builds images and starts containers with logs attached |
| `docker compose up --build -d` | Builds images and starts containers in the background  |

---

# 3. Stopping Containers

Stopping commands are used to pause, stop, remove, or reset containers.

It is important to understand the difference between stopping a container and removing a container.

A stopped container still exists. It can be started again.

A removed container no longer exists. Docker must create it again from the image.

Persistent data is usually stored in volumes or bind mounts, not inside the container itself.

---

## 3.1 Stop Containers Without Removing Them

<div align="center">

<pre><code class="language-bash">docker compose stop</code></pre>

</div>

This command stops running containers but does not remove them.

The containers remain available in Docker. We can start them again with:

<div align="center">

<pre><code class="language-bash">docker compose start</code></pre>

</div>

This is useful when we want a temporary pause. For example, if the project is running but we want to stop it without deleting containers, we use `docker compose stop`.

What remains after this command:

* Containers remain.
* Images remain.
* Volumes remain.
* Networks usually remain.
* Data remains.

We use this command when:

* We only want to pause the project.
* We want to restart the same containers later.
* We do not want Docker Compose to recreate containers.
* We do not want to remove networks or volumes.

---

## 3.2 Stop and Remove Containers

<div align="center">

<pre><code class="language-bash">docker compose down</code></pre>

</div>

This command stops and removes the containers created by Docker Compose.

It also removes the default Compose network.

However, it does not remove volumes by default.

This is the normal clean shutdown command for a Compose project.

What this command removes:

* Containers
* Default Compose network

What this command keeps:

* Images
* Volumes
* Bind-mounted data
* Files under `/home/rmedeiro/data`

This means that after running `docker compose down`, MariaDB data and WordPress files should still exist if they are stored in volumes or bind mounts.

We use this command when:

* We want to cleanly stop the project.
* We want containers to be recreated next time.
* We changed container configuration.
* We changed networks.
* We want a clean restart without deleting persistent data.

---

## 3.3 Stop and Remove Containers and Volumes

<div align="center">

<pre><code class="language-bash">docker compose down -v</code></pre>

</div>

The `-v` flag means volumes.

This command stops and removes:

* Containers
* Networks
* Named volumes declared in the Compose file

This is more destructive than `docker compose down`.

It is useful when we want to reset persistent data.

For Inception, this can be useful when we want MariaDB to initialize again from zero.

However, there is an important detail: if we are using bind mounts to `/home/rmedeiro/data`, the real files may still exist on the VM filesystem.

Example bind mount path: ``/home/rmedeiro/data/mariadb``

If MariaDB data exists there, removing Docker volumes may not be enough. We may also need to delete the files manually: ``sudo rm -rf /home/rmedeiro/data/mariadb/*``

We use `docker compose down -v` when:

* We want to reset the project state.
* We want MariaDB initialization to run again.
* We want to remove old database volume data.
* We want a clean database.

---

Important difference:

| Command                                     | Result                                                |
| ------------------------------------------- | ----------------------------------------------------- |
| `docker compose down`                       | Removes containers and network, keeps data            |
| `docker compose down -v`                    | Also removes named Docker volumes                     |
| `sudo rm -rf /home/rmedeiro/data/mariadb/*` | Removes real MariaDB files from the VM host directory |

---

# 4. Listing Containers

Listing commands allow us to see which containers exist, which are running, and which stopped because of an error.

---

## 4.1 Show Running Containers

<div align="center">

<pre><code class="language-bash">docker ps</code></pre>

</div>

This command shows only containers that are currently running.

Example output:

```text
CONTAINER ID   IMAGE       COMMAND                  STATUS       NAMES
abc123         mariadb     "/bin/init_mariadb.sh"   Up 2 min     mariadb
def456         wordpress   "/bin/init_wordpress.sh" Up 2 min     wordpress
ghi789         nginx       "nginx -g daemon off;"   Up 2 min     nginx
```

The most important columns are:

| Column         | Meaning                                   |
| -------------- | ----------------------------------------- |
| `CONTAINER ID` | Internal Docker identifier                |
| `IMAGE`        | Image used to create the container        |
| `COMMAND`      | Main command running inside the container |
| `STATUS`       | Current state                             |
| `NAMES`        | Container name                            |

We use this command when:

* We want to check if the project is running.
6. Attaches logs to the terminal
* We want to verify container names.
* We want to see container status.
* We want to confirm that no service crashed.

---

## 4.2 Show All Containers

<div align="center">

<pre><code class="language-bash">docker ps -a</code></pre>

</div>

This command shows all containers, including stopped containers.

It is more useful than `docker ps` when something failed.

For example, if MariaDB started and then exited immediately, `docker ps` will not show it because it is no longer running. But `docker ps -a` will show it.

Status ``Exited (0)``: The container stopped successfully. This usually means the main process finished without an error.

Status ``Exited (1)``: The container stopped because of an error.

Status ``Restarting``: The container is crashing and Docker is trying to restart it repeatedly.

Status ``Up``: The container is running correctly.

Use this command when:

* A container disappeared from `docker ps`.
* A service is not working.
* We want to inspect stopped containers.
* We want to understand if a container crashed.

---

# 5. Logs

Logs are one of the most important debugging tools in Docker.

A container usually runs one main process. Everything that process prints to standard output or standard error becomes part of the container logs.

For Inception, logs help debug:

* MariaDB initialization
* WordPress installation
* PHP-FPM startup
* Nginx configuration
* TLS certificate errors
* Wrong environment variables
* Permission problems
* Network connection problems

---

## 5.1 Show Logs for All Services

<div align="center">

<pre><code class="language-bash">docker compose logs</code></pre>

</div>

This command prints logs from every service in the Compose project.

It is useful when we want to see the global startup sequence.

For example, we can check whether:

* MariaDB started first.
* WordPress connected to MariaDB.
* Nginx started after WordPress.
* Any service printed an error.

Use this command when:

* We want a global view of all services.
* We do not know which container is failing.
* We want to inspect startup order.
* We want to debug service dependencies.

---

## 5.2 Follow Logs in Real Time

<div align="center">

<pre><code class="language-bash">docker compose logs -f mariadb</code></pre>

</div>

The `-f` flag means follow.

Docker keeps the log open and prints new lines as they appear.

This is useful when a container is starting and we want to observe it live.

We use this command when:

* We are testing startup.
* We want to see live errors.
* We are debugging initialization scripts.
* We want to check if a service keeps restarting.
* We want to monitor logs while opening the website.

---

## 5.3 View Logs Using Container Name

<div align="center">

<pre><code class="language-bash">docker logs mariadb</code></pre>

</div>

This command uses the real container name directly.

Difference:

| Command                       | Uses                 |
| ----------------------------- | -------------------- |
| `docker compose logs mariadb` | Compose service name |
| `docker logs mariadb`         | Container name       |

Both work if the Compose file contains:

```yaml
container_name: mariadb
```

If we did not define `container_name`, Docker Compose may create names like:

```text
srcs-mariadb-1
srcs-wordpress-1
srcs-nginx-1
```

In that case, `docker logs mariadb` would not work because the container is not actually named `mariadb`.

Use this command when:

* We know the exact container name.
* We want to inspect one container directly.
* We are not using Compose-specific commands.
* We want quick access to logs.

---

# 6. Container Cleanup

Cleanup commands remove unused or unwanted containers.

A stopped container still exists on the system. Over time, many stopped containers can accumulate.

Docker provides prune commands to remove unused objects.

---

## 6.1 Remove Stopped Containers

<div align="center">

<pre><code class="language-bash">docker container prune</code></pre>

</div>

This command deletes all stopped containers.

It does not delete running containers.

It does not delete images.

It does not delete volumes.

Use this command when:

* We have many old stopped containers.
* We want to clean the Docker environment.
* `docker ps -a` shows many unused containers.
* We want to free some disk space.

---

## 6.2 Remove One Container

<div align="center">

<pre><code class="language-bash">docker rm mariadb</code></pre>

</div>

This removes one stopped container.

If the container is still running, Docker will refuse to remove it.

In that case, stop it first:

<div align="center">

<pre><code class="language-bash">docker stop mariadb
docker rm mariadb</code></pre>

</div>

We can also force removal:

<div align="center">

<pre><code class="language-bash">docker rm -f mariadb</code></pre>

</div>

The `-f` flag forces Docker to stop and remove the container.

We use this command when:

* One specific container is broken.
* We want Docker Compose to recreate it.
* We changed container configuration.
* We want to remove only one container.

---

# 7. Images

Images are the templates used to create containers.

When we build a Dockerfile, Docker creates an image. For Inception, we normally have local images such as:

* `mariadb`
* `wordpress`
* `nginx`

Images can use a lot of disk space, especially after many rebuilds.

---

## 7.1 List Images

<div align="center">

<pre><code class="language-bash">docker images</code></pre>

</div>

Alternative:

<div align="center">

<pre><code class="language-bash">docker image ls</code></pre>

</div>

Both commands show local Docker images.

Example output:

```text
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
mariadb      latest    abc123         10 minutes ago   450MB
wordpress    latest    def456         10 minutes ago   600MB
nginx        latest    ghi789         10 minutes ago   150MB
```

Important columns:

| Column       | Meaning                          |
| ------------ | -------------------------------- |
| `REPOSITORY` | Image name                       |
| `TAG`        | Image version tag                |
| `IMAGE ID`   | Internal Docker image identifier |
| `CREATED`    | When the image was created       |
| `SIZE`       | Disk space used by the image     |

Use this command when:

* We want to verify that images were built.
* We want to see image names.
* We want to check image sizes.
* We want to remove old images.

---

## 7.2 Remove One Image

<div align="center">

<pre><code class="language-bash">docker rmi mariadb</code></pre>

</div>

This removes the image named `mariadb`.

Docker will refuse to remove an image if a container still uses it. In that case, remove the containers first:

<div align="center">

<pre><code class="language-bash">docker compose down
docker rmi mariadb</code></pre>

</div>

Use this command when:

* We want to force a clean rebuild.
* An image is broken.
* We want to remove old project images.
* We want to free disk space.

Example for all project images:

<div align="center">

<pre><code class="language-bash">docker rmi mariadb wordpress nginx</code></pre>

</div>

---

## 7.3 Remove Unused Images

<div align="center">

<pre><code class="language-bash">docker image prune</code></pre>

</div>

This removes dangling images.

A dangling image is usually an image layer that no longer has a proper name or tag.

More aggressive cleanup:

<div align="center">

<pre><code class="language-bash">docker image prune -a</code></pre>

</div>

The `-a` flag removes all unused images, not only dangling ones.

This means Docker removes images that are not currently used by containers.

Use this command when:

* We rebuilt many times.
* Docker is using too much disk space.
* We want to clean old unused images.
* We understand that unused images may need to be rebuilt later.

---

# 8. Volumes

Volumes are used to persist data outside containers.

Containers are temporary. They can be stopped, removed, and recreated.

If important data is stored only inside a container, it can be lost when the container is removed.

Volumes solve this problem by storing data outside the container lifecycle.

For Inception, persistent data usually includes:

* MariaDB database files
* WordPress website files

---

## 8.1 List Volumes

<div align="center">

<pre><code class="language-bash">docker volume ls</code></pre>

</div>

This command lists all Docker volumes.

Example output:

```text
DRIVER    VOLUME NAME
local     mariadb
local     wordpress
```

Use this command when:

* We want to verify that volumes exist.
* We want to check volume names.
* We want to debug persistent storage.
* We want to remove unused volumes.

---

## 8.2 Inspect a Volume

<div align="center">

<pre><code class="language-bash">docker volume inspect mariadb</code></pre>

</div>

This command displays detailed information about a specific volume.

For a bind-mounted volume, we may see something like:

```json
"Options": {
  "device": "/home/rmedeiro/data/mariadb",
  "o": "bind",
  "type": "none"
}
```

This means Docker stores MariaDB data in: ``/home/rmedeiro/data/mariadb`` on the Debian VM.

Important concepts:

| Concept        | Meaning                                                   |
| -------------- | --------------------------------------------------------- |
| Docker volume  | Storage managed by Docker                                 |
| Bind mount     | A host directory mounted inside a container               |
| Device         | The real path on the host machine                         |
| Container path | The path where the directory appears inside the container |

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

This tells Docker:

* Create a volume named `mariadb`.
* Use the host directory `/home/rmedeiro/data/mariadb`.
* Mount it inside the MariaDB container.
* Keep database files on the VM filesystem.

Use this command when:

* We want to confirm where data is stored.
* We want to check if the bind mount path is correct.
* We want to verify Inception subject requirements.
* We are debugging missing data.

---

## 8.3 Remove a Volume

<div align="center">

<pre><code class="language-bash">docker volume rm mariadb</code></pre>

</div>

This removes the Docker volume named `mariadb`.

If the volume is in use by a container, Docker will refuse to remove it.

Stop and remove containers first:

<div align="center">

<pre><code class="language-bash">docker compose down
docker volume rm mariadb</code></pre>

</div>

Use this command when:

* We want to remove a specific volume.
* We want to reset a service.
* We want to remove old persistent data.
* We are debugging database initialization.

Important: if the volume is a bind mount, removing the Docker volume may not delete the actual files in `/home/rmedeiro/data/mariadb`.

---

## 8.4 Remove Unused Volumes

<div align="center">

<pre><code class="language-bash">docker volume prune</code></pre>

</div>

This removes unused Docker volumes.

A volume is unused when no container is using it.

Use this command only when:

* We want to clean old project data.
* We want to free disk space.

---

# 9. Networks

Docker networks allow containers to communicate with each other.

In Docker Compose, services are usually connected to the same network automatically.

This allows containers to reach each other using service names. For example, WordPress can connect to MariaDB using ``mariadb`` as the database host.

It does not need to know the MariaDB container IP address.

---

## 9.1 List Networks

<div align="center">

<pre><code class="language-bash">docker network ls</code></pre>

</div>

This command lists all Docker networks.

Example:

```text
NETWORK ID     NAME              DRIVER    SCOPE
abc123         bridge            bridge    local
def456         host              host      local
ghi789         none              null      local
jkl012         srcs_inception    bridge    local
```

Docker Compose usually creates a project network.

The name may look like:

```text
srcs_inception
```

Use this command when:

* We want to verify that the Compose network exists.
* We want to inspect networking.
* Containers cannot communicate.
* WordPress cannot connect to MariaDB.
* Nginx cannot connect to WordPress.

---

## 9.2 Inspect a Network

<div align="center">

<pre><code class="language-bash">docker network inspect srcs_inception</code></pre>

</div>

This command displays detailed information about a Docker network.

It shows:

* Which containers are connected.
* Container IP addresses.
* Network driver.
* Network configuration.
* Gateway.
* Subnet.

This is useful to verify that all services are attached to the same network.

Expected services:

* MariaDB
* WordPress
* Nginx

If WordPress cannot connect to MariaDB, inspect the network and confirm that both containers are connected to it.

Use this command when:

* A service cannot reach another service.
* Database connection fails.
* Nginx cannot reach WordPress.
* We want to confirm container networking.
* We want to debug DNS resolution between containers.

---

# 10. Managing Bind Mount Directories

In the Inception project, persistent data must be stored on the VM host.

The subject expects data to be stored under: ``/home/login/data``

Usually, we need at least two directories:

* `/home/rmedeiro/data/mariadb`
* `/home/rmedeiro/data/wordpress`

MariaDB stores database files in the MariaDB directory.

WordPress stores website files in the WordPress directory.

---

## 10.1 Completely Reset Project Data

<div align="center">

<pre><code class="language-bash">docker compose down -v

sudo rm -rf /home/rmedeiro/data

mkdir -p /home/rmedeiro/data/mariadb
mkdir -p /home/rmedeiro/data/wordpress</code></pre>

</div>

This performs a full persistent data reset.

Step by step:

```bash
docker compose down -v
```

Stops containers and removes named volumes.

```bash
sudo rm -rf /home/rmedeiro/data
```

Deletes the real persistent data directory from the VM.

```bash
mkdir -p /home/rmedeiro/data/mariadb
mkdir -p /home/rmedeiro/data/wordpress
```

Recreates the required directories.

Use this only when:

* We want a completely fresh project state.
* We want MariaDB to initialize from zero.
* We want to delete all WordPress files.
* We are debugging installation scripts.
* We accept losing all database and WordPress data.

---

# 11. Entering Containers and MariaDB Commands

We may need to enter a running container and inspect the filesystem, test commands, or connect to MariaDB manually.

Docker allows running commands inside existing containers with `docker exec`.

---

## 11.1 Enter the MariaDB Container

<div align="center">

<pre><code class="language-bash">docker exec -it mariadb sh</code></pre>

</div>

This opens a shell inside the running MariaDB container.

Meaning:

| Part          | Description                                |
| ------------- | ------------------------------------------ |
| `docker exec` | Run a command inside an existing container |
| `-i`          | Interactive mode                           |
| `-t`          | Allocate a terminal                        |
| `mariadb`     | Container name                             |
| `sh`          | Shell to open                              |

This command only works if the container is already running.

Check first with:

<div align="center">

<pre><code class="language-bash">docker ps</code></pre>

</div>

Use this command when:

* We want to inspect files inside the container.
* We want to test MariaDB manually.
* We want to check environment variables.
* We want to verify installed packages.

---

## 11.2 Connect as MariaDB Root

<div align="center">

<pre><code class="language-bash">mariadb -u root -p</code></pre>

</div>

This connects to MariaDB using the `root` user.

Meaning:

| Part      | Description            |
| --------- | ---------------------- |
| `mariadb` | MariaDB client command |
| `-u root` | Connect as user `root` |
| `-p`      | Ask for password       |

MariaDB will ask for the password interactively.

The password should match the content of: ``secrets/db_root_password``

Use this command when:

* We want to inspect the database manually.
* We want to check users.
* We want to check privileges.
* We want to verify the WordPress database exists.
* We want to debug MariaDB initialization.

---

## 11.3 Show Databases

<div align="center">

<pre><code class="language-sql">SHOW DATABASES;</code></pre>

</div>

This SQL command lists all databases inside MariaDB.

Expected output:

```text
information_schema
mysql
performance_schema
sys
wordpress
```

Important databases:

| Database             | Meaning                                  |
| -------------------- | ---------------------------------------- |
| `information_schema` | Internal metadata database               |
| `mysql`              | Internal MariaDB system database         |
| `performance_schema` | Performance monitoring database          |
| `sys`                | Helper views for database administration |
| `wordpress`          | Project database used by WordPress       |

The important database for Inception is: ``wordpress``

If the `wordpress` database does not exist, then the MariaDB initialization script probably failed or did not run.

---

## 11.4 Show Existing Users

<div align="center">

<pre><code class="language-sql">SELECT User, Host FROM mysql.user;</code></pre>

</div>

This command lists MariaDB users and the hosts from which they are allowed to connect.

Example:

```text
root       localhost
rmedeiro   %
```

Meaning:

| User       | Host        | Meaning                                                       |
| ---------- | ----------- | ------------------------------------------------------------- |
| `root`     | `localhost` | Root can connect locally inside the database container        |
| `rmedeiro` | `%`         | User can connect from any host, including WordPress container |

The `%` host is important because WordPress runs in a different container.

If the user is only allowed from `localhost`, WordPress may not be able to connect.

Use this command when:

* We want to verify database users.
* We want to confirm remote container access.
* We want to debug authentication problems.

---

## 11.5 Check User Privileges

<div align="center">

<pre><code class="language-sql">SHOW GRANTS FOR 'rmedeiro'@'%';</code></pre>

</div>

This command displays the privileges assigned to the MariaDB user.

Expected idea:

```text
GRANT ALL PRIVILEGES ON `wordpress`.* TO `rmedeiro`@`%`
```

This means the user `rmedeiro` can use the `wordpress` database.

Use this command when:

* We want to verify the user has access to the correct database.
* We want to confirm the init script created privileges correctly.

---