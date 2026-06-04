# Inception Project Setup Guide

A complete guide for preparing the initial structure and configuration of the **Inception** project.

This document explains the project structure, local domain configuration, persistent volumes, environment variables, Docker secrets, and `.gitignore` setup.

---

# 1. Inception Project Structure

Before writing any Dockerfile, the project should have a clean and organized directory structure.

The Inception subject requires each service to have its own Dockerfile.
For the mandatory part, the main services are usually:

* MariaDB
* WordPress with PHP-FPM
* Nginx

Each service should have its own folder inside `srcs/requirements`.

---

## 1.1 Create the Required Directories

<div align="center">

<pre><code class="language-bash">mkdir -p secrets

mkdir -p srcs/requirements/mariadb/conf
mkdir -p srcs/requirements/mariadb/tools

mkdir -p srcs/requirements/wordpress/conf
mkdir -p srcs/requirements/wordpress/tools

mkdir -p srcs/requirements/nginx/conf
mkdir -p srcs/requirements/nginx/tools</code></pre>

</div>


---

## 1.2 Final Expected Structure

The project should look like this:

```text
inception/
├── Makefile
├── .gitignore
├── secrets/
│
└── srcs/
    ├── .env
    ├── docker-compose.yml
    │
    └── requirements/
        │
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        │
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        │
        └── nginx/
            ├── Dockerfile
            ├── conf/
            └── tools/
```

---

## 1.3 Meaning of Each File and Directory

| Path                      | Purpose                                                            |
| ------------------------- | ------------------------------------------------------------------ |
| `Makefile`                | Main entry point used to build, start, stop, and clean the project |
| `.gitignore`              | Prevents sensitive or local files from being committed             |
| `secrets/`                | Stores password files used by Docker secrets                       |
| `srcs/`                   | Main Docker Compose configuration directory                        |
| `srcs/.env`               | Stores environment variables                                       |
| `srcs/docker-compose.yml` | Defines services, networks, volumes, secrets, and build rules      |
| `requirements/mariadb/`   | MariaDB service files                                              |
| `requirements/wordpress/` | WordPress and PHP-FPM service files                                |
| `requirements/nginx/`     | Nginx service files                                                |
| `conf/`                   | Configuration files for each service                               |
| `tools/`                  | Startup scripts and helper scripts                                 |

---

# 2. Recommended Development Order

Do not write the whole project at once. The safest method is to build the infrastructure layer by layer.

This avoids having many broken services at the same time.

---

## Step 1 — Create Volumes

First, we create the host directories where persistent data will stay.

For Inception:

```text
/home/rmedeiro/data/mariadb
/home/rmedeiro/data/wordpress
```

MariaDB data and WordPress files must survive the container deletion and recreation.

---

## Step 2 — Create `.env`

We create the environment file used by Docker Compose and containers.

The `.env` file stores configuration values such as:

* Domain name
* Database name
* Database user
* WordPress title
* WordPress admin username
* WordPress emails

It should not store passwords.

---

## Step 3 — Create Docker Secrets

Create password files inside the `secrets/` directory.

Examples:

```text
secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

Secrets are read inside containers from: ``/run/secrets/<secret_name>``

---

## Step 4 — Create `.gitignore`

The `.gitignore` file must prevent sensitive files from being pushed to GitHub.

At minimum, we ignore:

```gitignore
secrets/
srcs/.env
```

---

## Step 5 — Create `docker-compose.yml`

Start with only the essential infrastructure:

* Network
* Volumes
* MariaDB service

Do not start with Nginx and WordPress immediately.

MariaDB should work perfectly first.

---

## Step 6 — Build MariaDB

Create:

```text
srcs/requirements/mariadb/Dockerfile
srcs/requirements/mariadb/conf/*
srcs/requirements/mariadb/tools/*
```

Goals:

* Container starts correctly.
* Database is created.
* User is created.
* Passwords are read from Docker secrets.
* Data persists in the volume.

---

## Step 7 — Build WordPress and PHP-FPM

Create:

```text
srcs/requirements/wordpress/Dockerfile
srcs/requirements/wordpress/tools/*
```

Goals:

* PHP-FPM starts.
* WordPress is installed automatically.
* WordPress connects to MariaDB.
* WordPress files persist in the volume.

We do not add Nginx until WordPress and MariaDB communicate correctly.

---

## Step 8 — Build Nginx

Create:

```text
srcs/requirements/nginx/Dockerfile
srcs/requirements/nginx/conf/*
srcs/requirements/nginx/tools/*
```

Goals:

* Nginx starts.
* TLS certificate exists.
* Only TLSv1.2/TLSv1.3 are enabled.
* Nginx forwards PHP requests to WordPress/PHP-FPM.

---

## Step 9 — Connect Everything

At this stage, all services should communicate through the Docker network.

---

## Step 10 — Create the Makefile

The `Makefile` should make the project easier to run.

Common targets:

```makefile
all:
	docker compose -f srcs/docker-compose.yml up --build -d

down:
	docker compose -f srcs/docker-compose.yml down

clean:
	docker compose -f srcs/docker-compose.yml down -v

re: clean all
```

---

## Step 11 — Final Testing

Final checks:

<div align="center">

<pre><code class="language-bash">docker ps
docker images
docker volume ls
docker network ls</code></pre>

</div>

Then open:

```text
https://rmedeiro.42.fr
```

Confirm:

* TLS works.
* WordPress loads.
* MariaDB persists data.
* Containers restart correctly.
* No passwords exist inside the Git repository.

---

# 3. Configure the Local Domain

The Inception subject requires the website to be accessible through: ``username.42.fr``

This domain does not exist on the public internet. Because of that, it must be mapped locally using the `/etc/hosts` file.

---

## 3.1 What Is `/etc/hosts`?

The `/etc/hosts` file is a local DNS table.

Before asking an external DNS server, Linux checks this file first.

Example:

```text
rmedeiro.42.fr → 127.0.0.1
```

So when the browser opens: ``https://rmedeiro.42.fr``, Linux redirects that name to the local machine.

---

## 3.2 Edit the Hosts File

<div align="center">

<pre><code class="language-bash">sudo vim /etc/hosts</code></pre>

</div>

We may see something like:

```text
127.0.0.1 localhost
127.0.1.1 debian
```

Add this line:

```text
127.0.0.1 rmedeiro.42.fr
```

Final example:

```text
127.0.0.1 localhost
127.0.0.1 rmedeiro.42.fr
127.0.1.1 debian
```

---

## 3.3 Check the Configuration

<div align="center">

<pre><code class="language-bash">ping rmedeiro.42.fr</code></pre>

</div>

Expected result:

```text
PING rmedeiro.42.fr (127.0.0.1)
```

This confirms that the domain resolves locally.

---

## 3.4 How the Request Flows

When the browser requests:

```text
https://rmedeiro.42.fr
```

the flow is:

```text
rmedeiro.42.fr
      |
      v
127.0.0.1
      |
      v
Nginx container
      |
      v
WordPress / PHP-FPM container
      |
      v
MariaDB container
```

No public DNS server is involved. Everything happens locally inside the VM.

---

# 4. Create Volumes on the Host Machine

One of the Inception requirements is persistent storage.

The subject expects volume data to be stored inside: ``/home/login/data``

---

## 4.1 Why the Debian VM Is the Docker Host

Even though the project runs inside VirtualBox, Docker Engine is installed inside the Debian VM.

Therefore, from Docker's point of view, the Debian VM is the host machine. So ``/home/rmedeiro/data`` means a directory inside the Debian VM.

Docker does not directly see the physical computer outside the VM.

---

## 4.2 Create the Volume Directories

<div align="center">

<pre><code class="language-bash">mkdir -p /home/rmedeiro/data/mariadb
mkdir -p /home/rmedeiro/data/wordpress</code></pre>

</div>

These two directories have different purposes:

| Directory                       | Purpose                        |
| ------------------------------- | ------------------------------ |
| `/home/rmedeiro/data/mariadb`   | Stores MariaDB database files  |
| `/home/rmedeiro/data/wordpress` | Stores WordPress website files |

---

## 4.3 Check That They Exist

<div align="center">

<pre><code class="language-bash">ls -la /home/rmedeiro/data</code></pre>

</div>

Expected result:

```text
mariadb
wordpress
```

---

## 4.4 Why Persistent Volumes Are Needed

Containers are temporary by design.

If a container is removed:

<div align="center">

<pre><code class="language-bash">docker rm mariadb</code></pre>

</div>

its internal filesystem is removed too. Without persistent storage, this would delete:

* MariaDB databases
* WordPress installation files
* Uploaded media
* WordPress users
* Posts and pages
* Themes and plugins
* Configuration generated at runtime

Volumes solve this problem. The container can be destroyed and recreated while the data remains stored in:

```text
/home/rmedeiro/data/mariadb
/home/rmedeiro/data/wordpress
```

This is why volumes are mandatory in Inception.

---

# 5. Create the `.env` File

The `.env` file stores environment variables.

Environment variables are configuration values passed to Docker Compose and containers.

The `.env` file should be located here: ``srcs/.env``

Create it with:

<div align="center">

<pre><code class="language-bash">vim srcs/.env</code></pre>

</div>

---

## 5.1 Why Use a `.env` File?

Without `.env`, values would be hardcoded in multiple places:

* `docker-compose.yml`
* Dockerfiles
* Shell scripts
* Nginx config
* WordPress configuration

Hardcoding makes the project harder to maintain.

With `.env`, values are defined once and reused everywhere.

For example:

```env
DOMAIN_NAME=rmedeiro.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=rmedeiro
WP_TITLE=Inception
```

If the domain changes, only one line needs to be edited.

---

## 5.2 What Should Not Be Inside `.env`

Avoid this:

```env
MYSQL_PASSWORD=1234
WP_ADMIN_PASSWORD=1234
```

Passwords should not be hardcoded in:

* `.env`
* Dockerfiles
* Shell scripts
* `wp-config.php`
* `docker-compose.yml`
* Git repository

Instead, use files in `secrets/`.

---

# 6. Create Docker Secrets

Docker secrets are used to store sensitive information outside the source code.

In this project, secrets are simple local files mounted into containers.

Create the directory:

<div align="center">

<pre><code class="language-bash">mkdir -p secrets</code></pre>

</div>

---

## 6.1 Create Secret Files

<div align="center">

<pre><code class="language-bash">echo "&lt;DB_ROOT_PASSWORD&gt;" &gt; secrets/db_root_password.txt
echo "&lt;DB_PASSWORD&gt;" &gt; secrets/db_password.txt
echo "&lt;WP_ADMIN_PASSWORD&gt;" &gt; secrets/wp_admin_password.txt
echo "&lt;WP_USER_PASSWORD&gt;" &gt; secrets/wp_user_password.txt</code></pre>

</div>

Replace the placeholders with real passwords during local setup or evaluation.

---

## 6.2 Meaning of Each Secret

| Secret file             | Purpose                                                |
| ----------------------- | ------------------------------------------------------ |
| `db_root_password.txt`  | Password for MariaDB root user                         |
| `db_password.txt`       | Password for the normal MariaDB user used by WordPress |
| `wp_admin_password.txt` | Password for the WordPress administrator               |
| `wp_user_password.txt`  | Password for the normal WordPress user                 |

---

## 6.3 How Docker Secrets Work

Declare secrets in `docker-compose.yml`:

```yaml
secrets:
  db_password:
    file: ../secrets/db_password.txt
```

Attach the secret to a service:

```yaml
services:
  wordpress:
    secrets:
      - db_password
```

Inside the container, Docker creates: ``/run/secrets/db_password``.

A shell script can read it like this: ``DB_PASSWORD=$(cat /run/secrets/db_password)``.

This allows the password to be used at runtime without writing it directly in the code.

---

## 6.4 Set Secure Permissions

<div align="center">

<pre><code class="language-bash">chmod 600 secrets/*</code></pre>

</div>

Permission `600` means:

| Digit | Permission                 |
| ----- | -------------------------- |
| `6`   | Owner can read and write   |
| `0`   | Group has no permissions   |
| `0`   | Others have no permissions |

Result:

```text
-rw------- db_password.txt
```

Only the file owner can read and edit the secrets.

---

# 7. Create `.gitignore`

The `.gitignore` file tells Git which files must not be tracked.

Create it at the project root:

<div align="center">

<pre><code class="language-bash">vim .gitignore</code></pre>

</div>

Recommended content:

```gitignore
secrets/
srcs/.env
```

---

## 7.1 Why Ignore `secrets/`?

The `secrets/` directory contains passwords.

If it is committed to GitHub, the passwords become exposed.

This must be avoided.

---

## 7.2 Why Ignore `srcs/.env`?

The `.env` file may contain:

* Domain name
* Database name
* Usernames
* Emails
* Machine-specific configuration

Even if it does not contain passwords, it should usually remain local.

---

## 7.3 Recommended `.env.example`

Instead of committing the real `.env`, create an example file:

```text
srcs/.env.example
```

Example:

```env
DOMAIN_NAME=<DOMAIN_NAME>

MYSQL_DATABASE=<MYSQL_DATABASE>
MYSQL_USER=<MYSQL_USER>

WP_TITLE=<WP_TITLE>
WP_ADMIN_USER=<WP_ADMIN_USER>
WP_ADMIN_EMAIL=<WP_ADMIN_EMAIL>

WP_USER=<WP_USER>
WP_USER_EMAIL=<WP_USER_EMAIL>
```

This shows which variables are required without exposing real values.

---
