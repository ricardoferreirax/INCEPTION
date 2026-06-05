# Debian Setup

## 1) Install sudo

# 1) Install sudo

## What is Root?

When a Linux system is installed, a special account called **root** is created automatically. The root account is known as the **superuser** because it has unrestricted access to the entire operating system.

Unlike normal users, root can:

- Modify or delete any file
- Install or remove software
- Create or delete users
- Change ownership and permissions of any file
- Control every running process

In Linux, almost every critical administrative task requires root privileges.

### a) Switch to the root user

```bash
su -
```

The root account is the administrator account of Linux. It has unrestricted access to every file, directory, process, and system configuration.

The `su` command stands for **substitute user**. Using: ``su -``, switches to the root account and loads the root user's environment.

It allows a user to temporarily become another user.

The `-` creates and loads a complete login shell session for root.
It loads:

```text
Root environment variables
Root PATH
Root shell configuration
Root HOME directory
Root profile files
```

This behaves exactly as if root had logged in directly.

Otherwise, ``without '-'``, Linux changes the user but keeps much of the current environment. Variables such as:

```text
PATH
HOME
SHELL
```

may still belong to the original user.

---

### b) Update and upgrade installed packages

```bash
apt-get update && apt-get upgrade -y
```

#### apt-get update

Downloads the latest package information from Debian repositories.
It does **not** install updates.

It only refreshes the package database so Debian knows:

* which packages exist
* which versions are available
* where they can be downloaded

#### apt-get upgrade -y

Installs the newest available versions of all currently installed packages.

Running update before upgrade is considered good practice because Debian first needs to know what updates are available.

---

### c) Install sudo

```bash
apt-get install sudo -y
```

Installs the `sudo` package.

The sudo command allows a normal user to execute specific commands with elevated privileges. Allows authorized users to execute commands with administrative privileges without logging directly into the root account.

Instead of ``su -`` we can use ``sudo command``.

Internally:

```text
1. sudo checks who executed the command.
2. sudo verifies permissions.
3. sudo requests authentication.
4. sudo validates the password.
5. sudo executes the command as root.
```

After the command finishes, the user returns to normal privileges.
This is safer than working permanently as root.

---

# 2) Add User to the Sudo Group

### a) Add user to sudo group

```bash
adduser rmedeiro sudo
```

Adds the user `rmedeiro` to Debian's `sudo` group.

Members of this group are allowed to execute commands using sudo.

This grants administrative privileges without giving direct root access.

---

### b) Verify group membership

```bash
getent group sudo
```

Displays information about the sudo group.

Expected output: ``sudo:x:27:rmedeiro``

This confirms that the user belongs to the group.

---

### c) Reboot the system

```bash
reboot
```

or

```bash
sudo reboot
```

A reboot ensures the new group membership is applied to all sessions.

---

# 3) Update the System

```bash
sudo apt update && sudo apt upgrade -y
```

Performs the same update and upgrade process but now using sudo instead of logging in as root.

---

# 4) Install Vim

```bash
sudo apt install -y vim
```

Vim is one of the most popular text editors in Linux.
It is commonly used to edit:

* configuration files
* scripts
* Dockerfiles
* system settings

---

# 5) Configure sudoers

## What is the sudoers File?

When a user executes ``sudo command``, Linux does not automatically trust that user.

Instead, sudo checks a special configuration file called: ``/etc/sudoers``.

This file defines:

- Who can use sudo
- Which commands they can execute
- On which machines they can execute them
- As which user they can execute them

Think of it as the access control list for administrative privileges.

## Editing sudoers Safely

Open the sudoers file:

```bash
sudo visudo
```

Find:

```text
root ALL=(ALL:ALL) ALL
```

Add:

```text
rmedeiro ALL=(ALL:ALL) ALL
```

### Meaning

```text
rmedeiro      -> username
ALL           -> any host
(ALL:ALL)     -> any user and group
ALL           -> any command
```

This grants full administrative privileges.

### Why use visudo?

Never edit `/etc/sudoers` directly.

`visudo`:

* checks syntax
* prevents corruption
* prevents locking yourself out of sudo

---

# 6) Install OpenSSH Server

## What is SSH?

SSH stands for ``Secure Shell``.
It is a network protocol used to remotely access another machine through an encrypted connection.


### a) Install OpenSSH

```bash
sudo apt install -y openssh-server
```

Installs the SSH server.
SSH allows secure remote access to the virtual machine.

---

### b) Enable SSH at boot

```bash
sudo systemctl enable ssh
```

Ensures SSH automatically starts whenever the VM boots.

---

### c) Start SSH

```bash
sudo systemctl start ssh
```

Starts the SSH service immediately.

---

### d) Verify SSH status

```bash
sudo systemctl status ssh
```

Expected:

```text
active (running)
```

This confirms that the SSH server is accepting connections.

---

# 7) Change SSH Port from 22 to 4242

### a) Open SSH configuration

```bash
sudo vim /etc/ssh/sshd_config
```

---

### b) Change the port

Find:

```text
#Port 22
```

Replace with:

```text
Port 4242
```

---

### c) Restart SSH

```bash
sudo systemctl restart ssh
```

Reloads the configuration.

---

### d) Verify

```bash
sudo systemctl status ssh
```

---

# 8) Configure VS Code Remote SSH

## a) Install Extension

Install:

```text
Remote - SSH
```

from the VS Code Extensions.

---

## b) Open Command Palette

```text
Ctrl + Shift + P
```

---

## c) Connect to Host

Select:

```text
Remote-SSH: Connect to Host...
```

Then:

```text
Add New SSH Host...
```

---

## d) Add VM

```bash
ssh -p 4242 rmedeiro@<VM_IP>
```

Example:

```bash
ssh -p 4242 rmedeiro@192.168.1.120
```

Find VM IP:

```bash
hostname -I
```

---

## e) Connect

Choose:

```text
~/.ssh/config
```

Connect and enter the password.
VS Code will automatically install the remote server components.

We can then edit files directly inside the VM.

---

# 9) Install VS Code Inside the VM

VS Code can run directly inside the virtual machine.

---

## a) Update System

```bash
sudo apt update
sudo apt upgrade -y
```

---

## b) Install Dependencies

```bash
sudo apt install -y wget gpg apt-transport-https
```

Required to add external repositories securely.

---

## c) Add Microsoft GPG Key

```bash
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | \
sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null
```

This key allows Debian to verify packages downloaded from Microsoft's repository.

---

## d) Add VS Code Repository

```bash
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
```

Adds Microsoft's package repository.

---

## e) Install VS Code

```bash
sudo apt update
sudo apt install -y code
```

Installs Visual Studio Code.

---

## f) Launch VS Code

```bash
code .
```

---

# 10) Install Common Development Tools

```bash
sudo apt install -y git curl wget tree zsh make build-essential ca-certificates gnupg lsb-release apt-transport-https
```

---

# 11) Install Oh My Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

---
