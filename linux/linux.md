# Linux 

## Boot Process

Understand how Linux boots its foundational processes:

### 1. `BIOS/UEFI` → `Bootloader` (GRUB, systemd-boot)
- When the system powers on, **BIOS** (or **UEFI** in modern systems) performs hardware checks and initializes CPU, memory, and storage.
- It then locates the configured boot device and passes control to the **bootloader**.
- The bootloader loads from disk, presents a menu of operating systems or kernels, and loads the selected Linux kernel.

### 2. **Kernel Loading and `initramfs`**
- The **Linux kernel**, the core OS that acts as a bridge between hardware and software, is loaded into memory and begins execution.
- It uses a temporary filesystem called **`initramfs`** to load drivers and prepare for mounting the real root filesystem.

### 3. **`init` / `systemd` Startup**
- The kernel executes the first user-space process: traditionally `init`, but most modern systems use **`systemd`** (PID 1).
- `systemd` initializes services, mounts, networking, and manages dependencies.

### 4. **Runlevels / Targets**
- Older systems used **runlevels** (0–6) to define states like shutdown, multi-user, or reboot.
- `systemd` replaces these with **targets** like `multi-user.target` or `graphical.target`.

### 5. **Logs During Boot (`dmesg`, `journalctl -b`)**
- `dmesg` shows kernel messages and hardware initialization logs.
- `journalctl -b` displays logs from the current boot, including services managed by `systemd`.



## Filesystem Hierarchy (FHS)
Understand the purpose of key Linux directories:

- `/etc` – System configuration files.
- `/var` – Variable data: logs, spools, caches.
- `/usr` – User-installed software and libraries (read-only).
- `/home` – User personal directories and files.
- `/lib` – Shared libraries needed by core binaries.
- `/boot` – Bootloader files and kernel images.
- `/proc`, `/sys` – Virtual filesystems exposing kernel and hardware state.
- `/dev` – Device files for hardware and virtual devices.
- `/run` – Volatile runtime data (cleared on reboot).
- `/tmp` – Temporary files (cleared on reboot).
- `/srv` – Data for services like web or FTP.


## Permissions, Ownerships, and ACLs

Understand how Linux controls access to files and directories.

### Basic Permissions
- Files and directories have three permission sets: **owner**, **group**, and **others**.
- Each set has three flags: `r` (read), `w` (write), `x` (execute).
- View with `ls -l myscript.sh`
  - Output: `-rwxr-xr--`
  - `-` Regular file (not dir)
  - `rwx` Owner: read/write/exec
  - `r-x` Group: read/exec
  - `r--` Others: read only
- Directories need `x` in order to enter them.

### Key Commands
- `chmod` – Change file/directory permissions (e.g., `chmod 755 file.sh`).
- `chown` – Change file owner/group (e.g., `chown user:group file.txt`).
- `umask` – Default permission mask for newly created files. (read, 4 bits), (write, 2 bits),(execute, 1 bit) (e.g., `umask 022` removes write for group/others). 

### Special Permission Bits
- These change how users run programs or manage files, especially in *multi-user environments*.
- **setuid (`s`)** – Execute as file owner. User (e.g., `passwd` binary). i.e. `s` in `-rwsr-xr-x`
- **setgid (`s`)** – Execute as group; or for directories, new files inherit group.
- **sticky bit (`t`)** – On directories (like `/tmp`), only file owner can delete or rename.

### ACLs – Access Control Lists
- Provide fine-grained permissions beyond owner/group/others.
- `getfacl` – View current ACLs. (Get File Access Control List)
- `setfacl` – Add or modify ACLs (e.g., `setfacl -m u:alice:rw file.txt`).

### SELinux & AppArmor (Mandatory Access Control)
- **SELinux**: Enforces security policies using labels and contexts.
  - Commands: `sestatus`, `getenforce`, `setenforce`, `ls -Z`, `semanage`, `restorecon`
- **AppArmor**: Profile-based restrictions tied to executable paths.
  - Commands: `aa-status`, `aa-enforce`, `aa-complain`, `aa-logprof`

> Use SELinux/AppArmor in hardened or multi-tenant environments to enforce security beyond file permissions.

## Processes and Scheduling

Understand how Linux handles multitasking and process control.

### Scheduling
- Linux uses the **Completely Fair Scheduler (CFS)** to distribute CPU time fairly among processes. 

  - The `scheduler` decides: (1) who runs next, (2) for how long, (3) who gets delayed.
  - `vruntime` is Virtual Runtime, number representing how much CPU time a process has received.
  - `Red-Black tree` is a self-balancing binary tree that CFS uses to keep track of `vruntime`
  - `weight` or `nice` value. Lower nice == higher priority.
    - Priorities and CPU time are managed dynamically based on load and `nice` values.

- You can influence Completely Fair Scheduler (CFS):
  - `nice` - change a process's priority.
  - `sched_setscheduler()` - Manually set scheduling policy via system call.
  - `/proc/sys/kernel/sched_*` - Kernel tuning programs (advanced)

### Foreground & Background Jobs
- **Foreground jobs** run in the terminal, you cannot type until finished.
- **Background jobs** let you use the terminal.
- Use `&` to run processes in the background (e.g., `./script.sh &`).
- `jobs` – List background jobs.
- `fg %1` – Bring job 1 to foreground. `%1` represents the job number of the current session.
- `bg %1` – Resume job 1 in background.

### Signals & `kill`
- Processes receive signals to control behavior:
  - `SIGTERM` (15): Ask a process to *terminate* gracefully. i.e. `killall -s SIGTERM python`
  - `SIGKILL` (9): Forcefully *kill* a process (cannot be trapped).
  - `SIGINT` (2): Sent by `Ctrl+C` to *interrupt* a process.
- Use `kill <pid>` or `killall <name>` or `pkill -SIGTERM java` to send signals.
- Trap a signal in a script: `trap "echo 'Caught SIGTERM'" SIGTERM`

### Priority & Affinity
- The user or admin can addect Priority and Affinity themselves to control performance tuning and resource control.
- To decrease you generally need `sudo`
- `nice` – Start process with given priority (lower nice = higher priority, i.e. `nice -n 10 ./heavy-script.sh`). Default is `0`
- `renice` – Change priority of a running process. i.e. `renice -n 5 -p 1234` Change PID 1234 to nice of 5
- `taskset` – Pin a process to specific CPU cores. i.e. `taskset -c 0,1 ./my_app` Make sure my_app runs only on core 0 and core 1. `taskset -cp 0,2 1234` Pin PID 1234 to core 0 and core 2

### Inspecting Processes
- `/proc/[pid]/` – Virtual filesystem with live process info and kernel state information. `/proc` is used heavily by tools like `lsof`, `htop`, `strace`, etc.
  - `/proc/[pid]/cmdline` – Exact Command line of process. i.e. `cat /proc/1234/cmdline`
  - `/proc/[pid]/status` – Process state, memory usage, threads. i.e. `grep VmRSS /proc/1234/status`
  - `/proc/[pid]/fd/` – File descriptors held or open by the process. i.e. To see the open files/sockets: `ls -l /proc/1234/fd`
  - `/proc/[pid]/environ` - Shows environment variables for the process.



## Storage and Filesystem

Understand how Linux handles disk layout, mounting, and performance.

### Disk Partitioning
- Disk partitioning is dividing a physical disk into separate sections (partitions) that the OS can manage. Each partition can have its own filesystem (i.e. `/`, `/home`, `swap`)
  - Make sure you copy important files or systems (cp, rsync, scp) to a backup location before modifying partitions.
- Tools like `fdisk`, `parted`, and `lsblk` are used to view and manage disk partitions.
- `fdisk` – Works with Master Boot Record (MBR) disks; interactive CLI. (i.e. `sudo fdisk /dev/sda`)
- `parted` – More powerful, Supports MBR and GUID Partition Table (GPT) and scripting. (i.e. `sudo parted /dev/sda`)
- `lsblk` – Lists block devices and their mount points. (i.e. `lsblk -f`)

### Filesystems
- A filesystem defines how data is stored, organized and retrieved. Different filesystems have different features.
- Common Linux filesystems:
  - `ext4` – **Most widely used in Linux** "Fourth Extended Filesystem" Default, stable, widely used. Lacks modern features like built-in snapshots, deduplication.
  - `xfs` – "Extend File System" High-performance, scalable (default in RHEL/CentOS). Cannot shrink once created. Used for enterprise systems, large files, databases.
  - `btrfs` – "B-tree Filesystem" Advanced features (snapshots, compression).
  - `zfs` – "Zettabyte File System" Robust, scalable; includes RAID (Native RAID-Z), compression, deduplication, self-healing. Combines filesystem and volume manager. For storage servers.

### Mounting & Automount
- Storage devices (hard drives, USBs, partitions) must be **mounted** before you can access their contents. Mounting links to a specific directory (**mount point**) in the directory tree.
- `mount` – Attach filesystem (from a device or partition) to directory. (i.e. `sudo mount /dev/sdb1 /mnt/data`) access contents of `/dev/sdb1` via `/mnt/data`
- `umount` – Detach the mounted filesystem. `sudo umount /mnt/data` Make sure no processes are using the mount point using `lsof` `fuser`
- `/etc/fstab` – Configures automatic mounting at boot (filesystem table).

### RAID & LVM (Basics)
- **RAID and LVM** are two powerful technologies used in Linux to manage storage across multiple disks with improved performance, flexibility or redundancy.
- **Redundant Array of Independent Disks** – Redundant storage across multiple disks (via `mdadm` tool in Linux). Common RAID levels:
  - RAID 0 (striping): Data split across disks. Fast, no redundancy.
  - RAID 1 (mirroring): Identical data split across disks. Redundant
  - RAID 5/6/10 (parity): Distributes data + parity. Can tolerate 1/2/3 disk failures respectively.
  - `sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc`
- **LVM** – Logical Volume Manager, allows flexible management of disk space by abstracting into logical layers:
  - Flexible volume resizing, snapshots.
  - Tools: Physical Volume - `pvcreate`, Virtual Volume - `vgcreate`, Logical Volume - `lvcreate`.

### Swap Space
- Used when RAM is full; slower than RAM.
- `mkswap` – Formats a partition as swap.
- `swapon`, `swapoff` – Enable/disable swap space.
- Check usage with `free -h` or `swapon --show`.

### I/O Performance Monitoring
- `iostat` – CPU and disk I/O statistics over time.
- `iotop` – Real-time view of disk I/O by process.
- `fstrim` – Tells SSDs which blocks can be wiped (TRIM support).


## Networking in Linux
- Interface management: `ip`, `ifconfig`, `nmcli`
- Routing tables, NAT: `ip route`, `iptables`, `nftables`
- DNS, `/etc/hosts`, `/etc/resolv.conf`
- TCP stack tuning via `sysctl`
- Network troubleshooting: `netstat`, `ss`, `tcpdump`, `traceroute`

## Package Management
- Debian-based: `apt`, `dpkg`
- RedHat-based: `yum`, `dnf`, `rpm`
- Building from source (`./configure`, `make`, `make install`)
- Snap/Flatpak/AppImage formats

## Systemd and Service Management
- `systemctl`, `journalctl`, `systemd-analyze`
- Writing custom service files
- Managing service dependencies and targets

## Monitoring and Logging
- `top`, `htop`, `vmstat`, `iotop`, `sar`
- Log locations and rotation (`/var/log`, `logrotate`)
- Journald vs syslog
- Basic intro to tracing: `strace`, `lsof`, `perf`, `ftrace`, `bpftrace`

## Compiling and Kernel Modules
- `make menuconfig`, `make bzImage`, `make modules`
- Load/unload kernel modules: `modprobe`, `insmod`, `rmmod`, `lsmod`
- `dkms` for managing third-party kernel modules

## Security Concepts
- Firewall: `ufw`, `firewalld`, `iptables`
- Auditing: `auditd`, `ausearch`
- Encryption: `GPG`, `dm-crypt`, `LUKS`
- Rootkit detection, hardening tips

## Automation and Scripting
- Bash scripting (with traps, subshells, conditionals)
- Cron, systemd timers
- Configuration management tools: Ansible, Puppet, Chef
- Git hooks and shell customizations

## Containerization and Namespaces
What makes containers work under the hood:
- Namespaces (PID, mount, net)
- Cgroups
- Union filesystems (overlayfs)
- Tools: `chroot`, `unshare`, `lxc`, `docker`

## Top-Level Structure of Linux Kernel Source Tree
The Linux kernel source tree is typically located at `/usr/src/linux`. It contains all the source code necessary to build and maintain the Linux kernel. Each top-level directory in this tree has a specific purpose, from device drivers to memory management and networking.

- **Top-level source tree:** `/usr/src/linux`

---

###  `arch/`
Contains **architecture-specific kernel code** for supported hardware platforms.

- Each subdirectory represents a CPU architecture (e.g., `x86/`, `arm/`, `riscv/`)
- Includes low-level boot code, memory layout, and platform initialization
- Works closely with `include/asm-<arch>` headers

---

###  `include/`
Holds **header files** necessary for building kernel code.

- `include/linux/`: Core kernel headers
- `include/uapi/`: User-space API headers
- `include/asm/`: Architecture-specific headers
- Used across all kernel subsystems

---

###  `init/`
Handles **kernel initialization** after the bootloader hands off execution.

- Defines the `start_kernel()` function
- Sets up memory zones, schedulers, interrupts, and initial kernel threads

---

###  `mm/`
Implements **memory management** logic.

- Virtual memory and paging
- Page allocation and deallocation
- Slab/slub allocators
- Support for NUMA architectures
- Handles memory pressure and OOM (Out Of Memory) situations

---

###  `drivers/`
Contains **all device drivers**, categorized by type.

- `char/`, `block/`, `net/`, `usb/`, `gpu/`, `sound/`, etc.
- Supports kernel modules and loadable drivers
- Interface between hardware and kernel subsystems

---

###  `ipc/`
Provides **Interprocess Communication (IPC)** support.

- System V IPC (semaphores, shared memory, message queues)
- POSIX-style IPC mechanisms
- Synchronization primitives and internal message passing logic

---

###  `fs/`
Contains **file system code and I/O management**.

- Implements supported file systems (`ext4/`, `xfs/`, `nfs/`, etc.)
- Virtual File System (VFS) layer for abstraction
- Manages file descriptors, mounting, caching, and file operations

---

###  `kernel/`
Houses **core kernel functionality**.

- Process scheduling and context switching
- Signal handling
- System call dispatch
- Kernel threads (`kthreads`)
- Panic, reboot, and system control mechanisms

---

###  `net/`
Implements the **networking stack**.

- Core socket layer (AF_INET, AF_UNIX, etc.)
- Protocols: IPv4, IPv6, TCP, UDP, SCTP, Netlink
- Wireless support, Bluetooth, and packet filtering (Netfilter/iptables)

---

###  `lib/`
Provides **utility functions and helper libraries** used across the kernel.

- String/memory operations (`memcpy`, `strcmp`, etc.)
- Sorting algorithms
- Checksums and cryptographic utilities
- Bit manipulation and encoding helpers

---

###  `scripts/`
Contains **build scripts and helper tools** for the kernel build system.

- `Makefile` support scripts
- Linker scripts
- Kconfig processing tools
- Header file generators and kernel symbol tools

---

###  `tools/`
Provides **user-space utilities** and **testing frameworks**.

- `perf/`: Performance analysis tool
- `bpf/`: BPF development tools
- `selftests/`: Regression and runtime testing tools
- Miscellaneous scripts and helpers for developers

---
