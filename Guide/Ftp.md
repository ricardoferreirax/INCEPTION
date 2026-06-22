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