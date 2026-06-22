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