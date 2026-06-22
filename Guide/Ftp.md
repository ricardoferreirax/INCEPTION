# Introduction

FTP is one of the oldest and most widely used protocols for transferring files between computers. Its purpose is to provide a standardized way for a client to connect to a remote server and exchange files through a network.

Before modern services such as Google Drive, Dropbox, OneDrive, or Git repositories became common, FTP was one of the primary methods used to upload websites, transfer backups, and manage files on remote servers. Even today, it is still found in web hosting environments, legacy infrastructures, and systems that require simple file transfer functionality.

In the Inception project, FTP is implemented as a bonus service. Its role is not to serve web pages or execute PHP code, but simply to provide a controlled method for accessing and modifying the WordPress files stored inside a shared Docker volume.

Consider the Inception project. We have a WordPress website running inside Docker. The website files are stored inside: /var/www/html. Without FTP, modifying those files usually requires: docker exec -it wordpress bash.

The FTP container works alongside the existing infrastructure and shares the same WordPress files as the WordPress container. This means that files uploaded through FTP become immediately available to the website without requiring any manual copying between containers.

```text
 FTP Client
     │
     ▼
 FTP Container
     │
     ▼
Shared WordPress Volume
     │
     ▼
 WordPress
     │
     ▼
   NGINX
```

This demonstrates one of the main concepts of Docker: multiple containers can access the same persistent storage while each container remains responsible for a single service.

---

# What Is FTP?

FTP stands for ``File Transfer Protocol``.

A protocol is a set of rules that defines how two systems communicate. FTP defines the commands and procedures required to transfer files between a client and a server over a TCP/IP network.

The machine that initiates the connection is called the ``FTP client``, while the machine receiving the connection is called the ``FTP server``.

```text
 FTP Client
     │
     │ FTP Commands
     ▼
  FTP Server
```

Once connected and authenticated, the client can perform a variety of operations on the remote server:

* Upload files
* Download files
* Browse directories
* Create folders
* Delete files
* Rename files
* Modify existing content

FTP follows a client-server architecture. The server waits for incoming connections, while the client initiates communication whenever file operations are required.

Modern applications such as FileZilla provide a graphical interface for FTP, making it easy to transfer files using drag-and-drop operations. Behind the scenes, however, FileZilla is simply sending FTP commands to the server and receiving responses.

In the Inception project, the FTP container acts as the server, while applications such as FileZilla or the Linux ftp command act as clients that connect to it.

---

# Why FTP Exists

Computers store files locally on their own storage devices. A file located on one machine is not automatically accessible from another machine, even if both machines are connected to the same network.

FTP was created to solve this problem by providing a universal method for transferring files between systems.

Imagine a web developer creating a website on a personal computer:

```text
index.html
style.css
logo.png
```

These files need to be transferred to a web server so that visitors can access them through a browser.

Without FTP, this would require direct access to the server or manual copying through other methods. FTP simplifies the process by allowing the developer to connect remotely and transfer files over the network.

```text
Developer Computer
        │
        ▼
     FTP Client
        │
        ▼
     FTP Server
        │
        ▼
      Website
```

Within Inception, the same principle applies. Instead of uploading files to a traditional web server, files are uploaded to the FTP container, which shares the WordPress volume with the WordPress container.

```text
 FileZilla
     │
     ▼
 FTP Container
     │
     ▼
 Docker Volume
     │
     ▼
  WordPress
```

Because both containers use the same persistent storage, any file uploaded through FTP immediately becomes available to WordPress. This makes FTP a convenient way to manage website content while also demonstrating how Docker volumes can be shared safely between multiple services.

---

# FTP Request Flow

To understand how FTP works, it is important to understand what happens from the moment a user connects to an FTP server until a file is transferred.

Unlike protocols such as HTTP, FTP uses two different connections. One connection is responsible for exchanging commands and responses, while the other is responsible for transferring the actual file data.

The communication process typically follows these steps:

```text
 FTP Client
     │
     │ Connects to port 21
     ▼
 FTP Server
```

The first connection is called the control connection. This connection is established on port 21 and remains open during the entire FTP session. It is used to exchange commands such as USER, PASS, PWD, GET, PUT, QUIT, etc.

For example, when a user logs in:

```text
Client -> USER ftpuser
Server -> 331 Password required

Client -> PASS ********
Server -> 230 Login successful
```

Once authentication succeeds, the client can navigate directories and request file operations. However, the actual file contents are not transferred through this control connection.

Instead, FTP creates a second connection called the data connection.

For example, when the user executes: ``put test.txt``, the following happens:

1. Control connection already exists:

> Client -> Port 21

2. Data connection created:

> Client -> FTP Server

3. File transferred:

> test.txt

The control connection remains open while the data connection is created and destroyed whenever files or directory listings need to be transferred.

This separation between commands and file data is one of the characteristics that makes FTP different from protocols such as HTTP.

---

# Active Mode vs Passive Mode

One of the most important concepts in FTP is the difference between Active Mode and Passive Mode.

Both modes achieve the same goal: creating the data connection required for file transfers.

The difference lies in who initiates that second connection.

---

## Active Mode

In Active Mode, the client first establishes the control connection:

> Client -> Server:21

The client then tells the server: ``Connect back to me on this port``.

The server initiates the data connection:

```text
           Control Connection
Client ----------------------> Server:21

           Data Connection
Client <---------------------- Server:20
```

Notice something important: The server is now trying to connect back to the client. This worked well in the early days of networking, but modern environments often contain:

* Firewalls
* NAT routers
* Docker networks
* Cloud infrastructures

These systems frequently block incoming connections. As a result, Active Mode often fails.

---

## Passive Mode

Passive Mode solves this problem by reversing the process. The client still creates the control connection:

> Client -> Server:21

However, when data transfer is required, the server says: ``I am listening on another port. You connect to me there``.

The client then initiates the second connection as well.

```text
         Control Connection
Client ----------------------> Server:21

           Data Connection
Client ----------------------> Server:40000
```

Now the client initiates both connections. This is much more compatible with modern networks because outgoing connections are usually allowed.

---

# Why Passive Mode Is Required In Docker

When FTP runs inside a Docker container, Passive Mode becomes almost mandatory.

A container does not have direct access to the host network. Instead, Docker creates an isolated network environment.

```text
  Host
    │
    ▼
Docker Network
    │
    ▼
FTP Container
```

The FTP container only exposes specific ports that Docker is instructed to forward. For example:

```text
ports:
  - "21:21"
  - "40000-40005:40000-40005"
```

If Active Mode were used, the FTP server inside the container would attempt to create a connection back to the client.

> FTP Container -> Client

This connection often fails because:

* Docker is behind NAT.
* The client may be behind another NAT.
* Firewalls usually block incoming connections.
* Docker only exposes explicitly mapped ports.

As a result, commands such as ls, dir, put and get, may fail even though login succeeds.

Passive Mode avoids these problems because the client always initiates the data connection.

The workflow becomes:

```text
Client
   │
   ├─────> FTP Server:21
   │
   └─────> FTP Server:40000
```

Since both connections originate from the client, Docker can correctly route them through the published ports. This is why the configuration contains:

```text
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40005
```

These settings tell vsftpd: ``Whenever a data connection is required, use a port between 40000 and 40005``. Docker can then safely expose exactly those ports:

```text
ports:
  - "21:21"
  - "40000-40005:40000-40005"
```

---

# FTP Dockerfile

The FTP Dockerfile is responsible for building the image used by the FTP service.

Just like the other services in Inception, the FTP container must be built manually from a Debian or Alpine base image. We should not use a ready-made FTP image because the purpose of the project is to understand how each service is installed, configured, and started.

A simple FTP Dockerfile can look like this:

```Dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y vsftpd && rm -rf /var/lib/apt/lists/*

COPY ./tools/init_ftp.sh /usr/local/bin/init_ftp.sh

RUN chmod +x /usr/local/bin/init_ftp.sh

ENTRYPOINT ["init_ftp.sh"]
```

This Dockerfile does not fully configure FTP by itself. Its job is mainly to install the required software and copy the initialization script into the image. The real configuration happens when the container starts, inside ``init_ftp.sh``.

This follows the same logic used by the other containers:

```text
Dockerfile
    installs the service and copies the script

init_ftp.sh
    checks variables and secrets
    creates users and permissions
    generates the configuration file
    starts the service in the foreground
```

This separation is important because some values, such as the FTP username, FTP password, passive ports, and mounted volume, only exist at runtime when Docker Compose starts the container.

---

# FROM debian:bookworm

This instruction defines the base image used to build the FTP container.

Instead of starting from a prebuilt FTP image, the container starts from a clean Debian Bookworm system. Debian provides the basic Linux environment required to install and run the FTP server. This includes:

* the filesystem layout;
* the apt package manager;
* Linux users and groups;
* permissions;
* basic runtime libraries;
* networking support.

Every instruction after FROM is added on top of this Debian base. The final image becomes:

```text
Debian Bookworm
      │
      ├── vsftpd package
      ├── init_ftp.sh
      └── generated FTP configuration at runtime
```

Using Debian directly is important for Inception because the subject requires us to build our own images. If we used a ready-made FTP image, most of the service would already be configured for us. That would go against the spirit of the project.

By using ``FROM debian:bookworm`` we explicitly install and configure FTP ourselves.

---

# Installing vsftpd

```Dockerfile
RUN apt-get update && apt-get install -y vsftpd && rm -rf /var/lib/apt/lists/*
```

This instruction installs the FTP server package.

Before this line runs, the image is only a minimal Debian system. It does not contain an FTP server yet.

After this instruction, the container has the FTP server binary installed and can later start it with: ``vsftpd /etc/vsftpd.conf``.

---

# What Is vsftpd?

vsftpd means: ``Very Secure FTP Daemon``.

It is an FTP server implementation for Unix-like systems.

A daemon is a service that runs in the background and waits for requests. In this case, vsftpd waits for FTP clients to connect on port 21.

When a client such as FileZilla connects, vsftpd handles:

* accepting the connection;
* asking for username and password;
* authenticating the user;
* applying FTP configuration rules;
* listing directories;
* receiving uploaded files;
* sending downloaded files;
* closing the connection safely.

In Inception project, vsftpd is the program that makes the FTP container useful. The container itself is only an isolated environment. Debian provides the base system. Docker provides the isolation and networking. But vsftpd is the actual service that speaks the FTP protocol.

The flow is:

```text
FileZilla
    │
    │ FTP protocol
    ▼
  vsftpd
    │
    ▼
/var/www/html
```

So when we upload test.txt, FileZilla sends FTP commands to vsftpd, and vsftpd writes the file into the mounted WordPress volume.

--- 

# What Is An FTP User?

An FTP user is the account used to authenticate into the FTP server. When we connect with FileZilla, we provide:

```text
Host: rickymercury.42.fr
User: ftpuser
Password: ********
Port: 21
```

So when we create: ``useradd -m -d /var/www/html -s /bin/bash ftpuser``, we are creating a Linux user called: ``ftpuser``.

Then this line: ``echo "$FTP_USER:$FTP_PASSWORD" | chpasswd``, sets the password for that user.

When FileZilla sends the username and password, vsftpd checks whether that Linux user exists and whether the password is correct.

If authentication succeeds, the FTP session starts.

The FTP user also matters for permissions. When a file is uploaded, it is created by that user. Therefore, the user must have write permission in the target directory.

In project, the target directory is: ``/var/www/html``, which is the WordPress shared volume.

Creating a FTP user is better than using root or reusing an unrelated system account.

The FTP user should only have access to the files it needs to manage. In this project, that means the WordPress files inside: /var/www/html. It should not have unnecessary access to the whole container filesystem.

A dedicated user makes the system easier to understand:

```text
www-data
    used by WordPress/PHP-FPM to read and write website files

ftpuser
    used by FTP clients to upload and manage website files
```

This separation is cleaner than using one account for everything. However, because both users need access to the same files, permissions must be configured correctly. That is why the FTP user is added to the www-data group: ``usermod -aG www-data "$FTP_USER"`` and the WordPress directory is configured like this:

```text
chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html
```

This means:

```text
Owner: www-data
Group: www-data
Permissions: rwxrwxr-x

So:

www-data can write because it is the owner.
ftpuser can write because it belongs to the www-data group.
Others can read and enter directories, but cannot write.

```
This is the clean permission model for the FTP bonus:

* WordPress writes as www-data.
* FTP writes as ftpuser.
* Both share the www-data group.
* The shared volume remains usable by both services.

It avoids the earlier problem where ftpuser could log in but could not upload files because /var/www/html belonged to www-data with permissions 755. After adding ftpuser to the correct group and using 775, uploads work correctly.

---