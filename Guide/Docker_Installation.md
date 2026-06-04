# Docker Engine Installation

This guide explains how to install Docker Engine on Debian for the Inception project.

The goal is not only to install Docker, but also to understand what each command does, why it is necessary, and how to verify that the installation is correct.

---

## Table of Contents

* [1. Update the System](#1-update-the-system)
* [2. Install Required Dependencies](#2-install-required-dependencies)
* [3. Create the APT Keyrings Directory](#3-create-the-apt-keyrings-directory)
* [4. Add Docker Official GPG Key](#4-add-docker-official-gpg-key)
* [5. Set GPG Key Permissions](#5-set-gpg-key-permissions)
* [6. Add Docker Official Repository](#6-add-docker-official-repository)
* [7. Update APT Package Index](#7-update-apt-package-index)
* [8. Check Docker Repository](#8-check-docker-repository)
* [9. Install Docker Engine](#9-install-docker-engine)
* [10. Start Docker Service](#10-start-docker-service)
* [11. Enable Docker at Boot](#11-enable-docker-at-boot)
* [12. Add User to Docker Group](#12-add-user-to-docker-group)
* [13. Apply Group Changes](#13-apply-group-changes)
* [14. Check Group Membership](#14-check-group-membership)
* [15. Test Docker Installation](#15-test-docker-installation)
* [16. Check Docker Version](#16-check-docker-version)
* [17. Check Docker Compose Version](#17-check-docker-compose-version)
* [18. Check Docker Service Status](#18-check-docker-service-status)
* [19. Display Docker Information](#19-display-docker-information)
* [20. Final Verification Checklist](#20-final-verification-checklist)

---

# 1. Update the System

<div align="center">

<pre><code class="language-bash">sudo apt-get update && sudo apt-get upgrade -y</code></pre>

</div>

Before installing Docker, the system should be updated.

We update the local APT package.

The package index is a local database used by Debian to know:

* Which packages are available.
* Which versions exist.
* Where each package can be downloaded from.
* Which dependencies each package requires.

This command does not install or upgrade packages by itself. It only refreshes the list of available packages.

Then, upgrades the already installed packages to their newest available versions.

This is useful because Docker installation depends on system packages, HTTPS support, certificates, and APT repository configuration. Using outdated packages can cause installation problems.

---

# 2. Install Required Dependencies

<div align="center">

<pre><code class="language-bash">sudo apt-get install ca-certificates curl gnupg -y</code></pre>

</div>

This installs the basic tools required to securely add Docker's official repository to Debian.

Docker is not installed directly from the default Debian repositories in this setup. Instead, we add Docker's official repository, verify it with Docker's official GPG key, and then install Docker packages from there.

This command installs three important packages:

| Package           | Purpose                                          |
| ----------------- | ------------------------------------------------ |
| `ca-certificates` | Allows the system to verify HTTPS certificates   |
| `curl`            | Downloads files from the internet                |
| `gnupg`           | Verifies cryptographic signatures using GPG keys |

---

## 2.1 ca-certificates

`ca-certificates` allows Debian to trust HTTPS connections.

When downloading Docker packages from: ``https://download.docker.com``

the system must verify that the website is really Docker's server and not a fake or intercepted server.

HTTPS verification depends on trusted Certificate Authorities. Without `ca-certificates`, secure downloads may fail because Debian may not be able to validate the remote certificate.

---

## 2.2 curl

`curl` is a command-line tool used to download data from URLs.

In this installation, it is used to download Docker's official GPG key: ``https://download.docker.com/linux/debian/gpg``

Without `curl`, we would not be able to easily fetch the Docker signing key from the terminal.

---

## 2.3 gnupg

`gnupg` provides GPG tools.

APT uses GPG keys to verify that packages come from a trusted source.

When we add Docker's repository, we also add Docker's official GPG key. This allows APT to verify the authenticity of Docker packages before installing them. This protects the system from installing modified or untrusted packages.

---

# 3. Create the APT Keyrings Directory

<div align="center">

<pre><code class="language-bash">sudo install -m 0755 -d /etc/apt/keyrings</code></pre>

</div>

This command creates the directory where APT repository keys are stored.

The command uses `install` instead of `mkdir` because `install` can create the directory and set permissions at the same time.

Command breakdown:

| Part                | Meaning                                               |
| ------------------- | ----------------------------------------------------- |
| `sudo`              | Run the command with administrator privileges         |
| `install`           | Create files or directories with specific permissions |
| `-m 0755`           | Set permissions to `0755`                             |
| `-d`                | Create a directory                                    |
| `/etc/apt/keyrings` | Directory to create                                   |

For a directory, execute permission means users can enter the directory.

So `/etc/apt/keyrings` can be read by the system, but only root can modify it.

This is important because APT must be able to read the GPG key stored inside this directory.

---

# 4. Add Docker Official GPG Key

<div align="center">

<pre><code class="language-bash">curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg</code></pre>

</div>

This command downloads Docker's official GPG key, converts the key into binary GPG format and writes it to ``/etc/apt/keyrings/docker.gpg`` and saves it in a format that APT can use.

APT repositories are signed. This means the packages provided by the repository are cryptographically verified. The GPG key is used to confirm that Docker packages really come from Docker.

---

# 5. Set GPG Key Permissions

<div align="center">

<pre><code class="language-bash">sudo chmod a+r /etc/apt/keyrings/docker.gpg</code></pre>

</div>

This command allows the Docker GPG key to be readable by APT.

Command breakdown:

| Part                           | Meaning                           |
| ------------------------------ | --------------------------------- |
| `chmod`                        | Change file permissions           |
| `a+r`                          | Give read permission to all users |
| `/etc/apt/keyrings/docker.gpg` | Target file                       |

APT needs read access to the key when updating package lists and verifying repository signatures.

This does not mean everyone can modify the key. It only gives read permission. Writing is still restricted.

---

# 6. Add Docker Official Repository

<div align="center">

<pre><code class="language-bash">echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null</code></pre>

</div>

This command adds Docker's official Debian repository to APT.

APT uses repository files to know where packages can be downloaded from.

The new repository file will be created here: ``/etc/apt/sources.list.d/docker.list``

---

## Why Use Docker's Official Repository?

Using Docker's official repository is preferred because it provides Docker Engine packages maintained by Docker.

This gives access to:

* Docker Engine
* Docker CLI
* containerd
* Buildx plugin
* Docker Compose plugin

This also avoids using old or incomplete Docker packages from default Debian repositories.

---

# 7. Update APT Package Index

<div align="center">

<pre><code class="language-bash">sudo apt-get update</code></pre>

</div>

After adding a new repository, the package index must be updated again.

The first update refreshed Debian's existing repositories.

This second update is necessary because we added a new source: ``/etc/apt/sources.list.d/docker.list``

APT now needs to download the package list from Docker's repository.

Without this command, Debian may not know that Docker packages are available.

---

# 8. Check Docker Repository

<div align="center">

<pre><code class="language-bash">apt-cache policy docker-ce</code></pre>

</div>

This command shows package information for `docker-ce`.

It allows us to verify that Docker packages will be installed from Docker's official repository.

`docker-ce` means Docker Community Edition.

This confirms that APT sees Docker's official repository.

---

## Why This Check Is Important

Before installing Docker, it is useful to confirm that the package comes from the correct source.

If the repository was not added correctly, APT may say:

```text
Candidate: (none)
```

This means APT cannot find the package.

If the repository is correct, APT should show an available candidate version.

---

# 9. Install Docker Engine

<div align="center">

<pre><code class="language-bash">sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin</code></pre>

</div>

This command installs Docker Engine and its main components.

It installs:

| Package                 | Purpose                          |
| ----------------------- | -------------------------------- |
| `docker-ce`             | Docker Engine daemon             |
| `docker-ce-cli`         | Docker command-line interface    |
| `containerd.io`         | Container runtime used by Docker |
| `docker-buildx-plugin`  | Advanced image build support     |
| `docker-compose-plugin` | Docker Compose v2 plugin         |

---

## 9.1 docker-ce

`docker-ce` is the main Docker Engine package.

It provides the Docker daemon, usually called: ``dockerd``

The Docker daemon is the background service that manages:

* Containers
* Images
* Volumes
* Networks
* Builds
* Runtime state

When you run a command such as ``docker ps``, the Docker CLI communicates with the Docker daemon.

---

## 9.2 docker-ce-cli

`docker-ce-cli` provides the `docker` command.

This is the command-line interface used to interact with Docker.

The CLI itself does not run containers. It sends commands to the Docker daemon.

---

## 9.3 containerd.io

`containerd` is the lower-level container runtime used by Docker.

Docker Engine uses containerd to manage container execution.

We normally do not interact with `containerd` directly during Inception, but Docker needs it to run containers.

---

## 9.4 docker-compose-plugin

This package installs Docker Compose v2. With Docker Compose v2, the command is:

```bash
docker compose
```

not:

```bash
docker-compose
```

For example:

```bash
docker compose up
docker compose build
docker compose down
```

This is the modern Compose syntax.

---

# 10. Start Docker Service

<div align="center">

<pre><code class="language-bash">sudo systemctl start docker</code></pre>

</div>

This starts the Docker service immediately.

When Docker is running, the Docker daemon is active and ready to receive commands.

Without the Docker daemon running, commands such as ``docker ps`` may fail with an error similar to
``Cannot connect to the Docker daemon``.

---

# 11. Enable Docker at Boot

<div align="center">

<pre><code class="language-bash">sudo systemctl enable docker</code></pre>

</div>

This makes Docker start automatically whenever the system boots.

Starting Docker and enabling Docker are different operations.

| Command                   | Meaning                             |
| ------------------------- | ----------------------------------- |
| `systemctl start docker`  | Starts Docker now                   |
| `systemctl enable docker` | Starts Docker automatically at boot |

If Docker is enabled, we do not need to manually start it every time the VM restarts.

---

# 12. Add User to Docker Group

<div align="center">

<pre><code class="language-bash">sudo gpasswd -a $USER docker</code></pre>

</div>

This command adds the current user to the `docker` group.

By default, Docker commands usually require root privileges because Docker controls containers, networks, volumes, and system resources.

Adding a user to the Docker group gives that user powerful permissions.

A user in the Docker group can control Docker and potentially gain root level access through containers. Inside a local 42 VM, this is usually acceptable and convenient for development. On a real production server, Docker group membership should be handled carefully.

Without being in the `docker` group, we may need to run: ``sudo docker ps``

After adding your user to the Docker group, we can run: ``docker ps`` without sudo.

---

## Command Breakdown

| Part      | Meaning                 |
| --------- | ----------------------- |
| `sudo`    | Run as administrator    |
| `gpasswd` | Manage group membership |
| `-a`      | Add a user to a group   |
| `$USER`   | Current logged-in user  |
| `docker`  | Target group            |

---

# 13. Apply Group Changes

<div align="center">

<pre><code class="language-bash">newgrp docker</code></pre>

</div>

The command ``newgrp docker`` starts a new shell with the `docker` group active.

This allows us to use Docker without rebooting or logging out.

---

# 14. Check Group Membership

<div align="center">

<pre><code class="language-bash">groups</code></pre>

</div>

This command prints all groups associated with the current user session.

Expected output:

```text
rmedeiro sudo docker
```

The important part is:

```text
docker
```

If `docker` appears, the current shell has Docker group permissions.

If `docker` does not appear, Docker commands may still require `sudo`.

---

# 15. Test Docker Installation

<div align="center">

<pre><code class="language-bash">docker run hello-world</code></pre>

</div>

This command tests whether Docker is installed and working correctly.

It runs a small test container called `hello-world`.

If the image is not available locally, Docker downloads it automatically.

The expected output contains:

```text
Hello from Docker!
```

This message confirms that:

* Docker CLI works.
* Docker daemon is running.
* The current user can access Docker.
* Docker can download images.
* Docker can create and run containers.
* The container runtime is working.

---

# 16. Check Docker Version

<div align="center">

<pre><code class="language-bash">docker --version</code></pre>

</div>

This command prints the installed Docker CLI version.

Example output:

```text
Docker version 28.x.x, build xxxxxxx
```
---

# 17. Check Docker Compose Version

<div align="center">

<pre><code class="language-bash">docker compose version</code></pre>

</div>

This checks whether Docker Compose v2 is installed.

Expected output:

```text
Docker Compose version v2.x.x
```

---

# 18. Check Docker Service Status

<div align="center">

<pre><code class="language-bash">systemctl status docker</code></pre>

</div>

This command displays the current status of the Docker service.

Expected status: ``active (running)`` means the Docker daemon is currently running.

---

# 19. Display Docker Information

<div align="center">

<pre><code class="language-bash">docker info</code></pre>

</div>

This command displays detailed information about the Docker installation.

It shows information about:

* Docker client.
* Docker server.
* Storage driver.
* Cgroup driver.
* Docker root directory.
* Images.
* Containers.
* Networks.
* Volumes.
* Runtime.
* Operating system.
* Kernel version.

This command is more detailed than `docker --version`.

Important fields:

| Field              | Meaning                           |
| ------------------ | --------------------------------- |
| `Server Version`   | Docker Engine version             |
| `Storage Driver`   | Filesystem driver used by Docker  |
| `Cgroup Driver`    | Linux control group driver        |
| `Docker Root Dir`  | Where Docker stores internal data |
| `Containers`       | Number of containers              |
| `Images`           | Number of images                  |
| `Operating System` | Host OS                           |
| `Architecture`     | CPU architecture                  |

For Inception, `docker info` is useful to verify that Docker is not only installed, but also running correctly.

---