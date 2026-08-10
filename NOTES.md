<h1 align="center">Inception · Notes</h1>
<p align="center"><i>My understanding of the project. Written as I learn it.</i></p>

---

## Index

* [01 · Why containers were invented](#01--why-containers-were-invented)
    * [a · Container vs Virtual Machine](#a--container-vs-virtual-machine)
* [02 · What is a container?](#02--what-is-a-container)
    * [a · Containers are much older than Docker](#a--containers-are-much-older-than-docker)
    * [b · Namespaces, what it sees](#b--namespaces-what-it-sees)
    * [c · Where namespaces actually live](#c--where-namespaces-actually-live)
    * [d · cgroups, what it uses](#d--cgroups-what-it-uses)
* [03 · Docker](#03--docker)
* [04 · Docker image](#04--docker-image)
    * [a · Definition](#a--definition)
    * [b · Docker images vs. containers](#b--docker-images-vs-containers)
    * [c · Image layers](#c--image-layers)

---

# 01 · Why containers were invented

**One server. 200 customers. Each one wants their own isolated website.**

Three options existed:

| | Cost |
|:--|:--|
| **200 machines** | absurd |
| **200 processes on one machine** | no isolation. They read each other's files, one crash starves all |
| **200 VMs** | works, but 200 full operating systems: GBs of RAM, minutes to boot, all running the same Linux |

**The VM wastes everything.** The customer needs an isolated *website*, not an isolated *computer*.

> **Can one machine host many isolated tenants without pretending to be 200 machines?**

**Containers are the answer.** Keep one operating system, and make it **lie to each process about what machine it's on**. Yes a container is just a process. 

> **Note:** the "200 customers" framing above is a teaching device, not history.
> A 2005 host would have answered "shared hosting", and the real waste containers
> attacked was enterprise VM sprawl: thousands of VMs idling at 8% CPU.

---

## a · Container vs Virtual Machine

**Containers exist for density and isolation**, not to replace VMs.

| | Virtual Machine | Container |
|:--|:--|:--|
| **Memory** | a lot, a full OS each | far less, only the app |
| **Boot** | slow, a real boot sequence | instant, reuses the running kernel |
| **Scaling** | difficult | trivial |
| **Efficiency** | low | high |
| **Storage** | hard to share between VMs | shared freely between host and containers |
| **Isolation** | strong, hardware level | weaker, same kernel |

**The last row is the trade.** A VM's boundary is a hypervisor and hard to escape. A container's boundary is kernel bookkeeping, so a kernel bug crosses it.

---

# 02 · What is a container?

> **A container is just a normal Linux process on your kernel, with lies told to it. yep we just lie to the process !**

**No virtual machine boots. No OS is emulated.** Run `ps` on the host and you find an ordinary process among your others: same kernel, same scheduler.

**So what makes it a container?** Only **what that process is allowed to perceive and consume**. The kernel hands it a distorted view of the machine, and the process believes it.

**Two kernel features do the lying:**

| | Controls | Purpose |
|:--|:--|:--|
| **Namespaces** | what a process can **see** | isolation |
| **cgroups** | what a process can **use** | limits |

---

## a · Containers are much older than Docker

**None of this was invented in 2013.** The mechanism was already solved and in production:

```
1979  chroot              isolate a filesystem
2000  FreeBSD Jails       isolate filesystem + processes + users + one IP
2004  Solaris Containers  the word ships in a product
2006  cgroups             Google adds resource limits to Linux
2008  LXC                 first container manager using only mainline kernel features
2013  Docker              built on LXC at first
```

**Docker did not invent the container.** It arrived 34 years after `chroot` and 5 years after LXC.

---

## b · Namespaces, what it sees

> **A namespace gives a process its own private view of one part of the system.**

Instead of one global process list, one global network, one global hostname, the kernel keeps a second copy and hands it to the process. **The process never knows it got a copy.** It just looks around and reports what it finds.

**Why use them?**

- **Isolation.** Each process gets its own world and can't see anyone else's.
- **Security.** You can run something you don't trust. If a malicious process tries to destroy the filesystem, it destroys *its own view* of it. The host and every other process are untouched.
- **Containers.** Docker and LXC are built out of them.
- **Sharing, on purpose.** Namespaces can be handed out deliberately: two containers can share a network namespace, or a mount point, while staying separate everywhere else.

**There are 8 types:**

🖥️ **`pid`** → its own process IDs.
&nbsp;&nbsp;&nbsp;&nbsp;PID 1 inside a container is not PID 1 on the host.

🌐 **`net`** → its own interfaces, IPs, routing table, firewall rules, **ports**.
&nbsp;&nbsp;&nbsp;&nbsp;Two containers can both listen on 9000 without colliding.

📂 **`mnt`** → its own mount points and filesystem tree.
&nbsp;&nbsp;&nbsp;&nbsp;A container's `/etc` is a different `/etc` than the host's.

👤 **`user`** → its own UID / GID mapping.
&nbsp;&nbsp;&nbsp;&nbsp;A process can be root inside while being nobody outside.

🏷️ **`uts`** → its own hostname and domain name.
&nbsp;&nbsp;&nbsp;&nbsp;The container calls itself `mariadb`; the host never changed name.

🔗 **`ipc`** → its own shared memory, message queues, semaphores.
&nbsp;&nbsp;&nbsp;&nbsp;Nothing else can attach to its memory segments.

📦 **`cgroup`** → its own view of the cgroup tree.
&nbsp;&nbsp;&nbsp;&nbsp;It can't see where it sits in the host's hierarchy.

⏰ **`time`** → its own boot and monotonic clock. *(Linux 5.6+)*
&nbsp;&nbsp;&nbsp;&nbsp;A container can believe it booted at a different moment.

<br>

One `sleep` command, seen from both sides at once:

```
inside container         on host
─────────────────        ─────────────────
PID 1  sleep 300    ═══  PID 50862  sleep 300
```

**Same process, two identities.** Inside it's process number 1, the first thing that ever ran. Outside it's 50862, with a parent and hundreds of siblings it cannot see.

**The network namespace matters most here.** Each container gets its own interface, IP, routing table, and **its own set of ports**, which is why two containers can both listen on 9000 and never collide.

---

## c · Where namespaces actually live

**A namespace is not the process control block.** In Linux the PCB is `struct task_struct`: one per process, holding PID, state, memory map, open files.

**Each `task_struct` carries a pointer called `nsproxy`**, pointing to the set of namespaces that process belongs to:

```
task_struct  (one per process)
     └─ nsproxy ──> { pid_ns, net_ns, mnt_ns, uts_ns, ipc_ns, ... }
```

<p align="center"><img src="assets/task_struct-nsproxy.png" width="520"></p>
<p align="center"><i>include/linux/sched.h · a pointer, not the namespaces themselves</i></p>

**And what it points to is just a box of pointers**, one per namespace type:

<p align="center"><img src="assets/struct-nsproxy.png" width="560"></p>
<p align="center"><i>include/linux/nsproxy.h</i></p>

**`pid` is the odd one.** The field is `pid_ns_for_children`, not the process's own pid namespace. A process never changes pid namespace once it exists, so nsproxy carries the one its *children* will get. The kernel says this in the comment above the struct: the task's own is reached through `task_active_pid_ns()`.

**The key word is shared**, and the kernel says so itself in that comment:

> *"The nsproxy is shared by tasks which share all namespaces. As soon as a single namespace is cloned or unshared, the nsproxy is copied."*

**Every process in the same container points to the same namespace structs.** That's what makes them one container: not a flag in the PCB, but a shared set of objects.

**One exception: `user` is not in nsproxy.** Look at the screenshot, there's no `user_ns` field. It lives in `struct cred`, the process's credentials, because it's about *permissions*, not resources:

```
task_struct ──> nsproxy ──> uts, ipc, mnt, net, time, cgroup, pid_ns_for_children
            ──> cred    ──> user_ns
```

---

## d · cgroups, what it uses

**Namespaces hide things but restrain nothing.** A process that only sees its own filesystem can still eat every byte of RAM on the machine, exactly the hosting problem from section 01.

**Control groups put a hard ceiling on consumption:** memory, CPU time, disk bandwidth, process count.

```bash
--memory=64m     may use 64 MB, no more
--cpus=0.5       gets half a core's worth of time
```

**Docker doesn't enforce this.** It writes a number to a file, and the **kernel** does the policing, including killing the process if it overruns.

> ⚠️ A container capped at 64 MB still reports the host's full 15 GB when asked how much memory the machine has. It has no idea it's restricted. The limit is real anyway.

<br>

**Namespaces answer** *"what world does this process live in?"*
**cgroups answer** *"how much of the real machine may it consume?"*

**A container is a process given both:** a fabricated view, and a budget.

**None of it was built for Docker.** Mount namespaces came from Plan 9, cgroups from Google's datacenters, union filesystems from live CDs. In 2013 Solomon Hykes and his team at dotCloud combined these existing pieces into one tool and called it Docker.

---

# 03 · Docker

> **Docker is a tool that builds, ships and runs containers.**

Containers already worked, but building one meant assembling a filesystem by hand, choosing namespaces, wiring the network, then repeating all of it on every machine.

> **Isolation was solved. Distribution wasn't.**

**Docker's answer was the image:** build the environment once, ship it as one artifact.

| | |
|:--|:--|
| **Images** | a packaged filesystem you build once and ship anywhere |
| **A registry** | somewhere to publish and download them |
| **A daemon** | a background service managing images, containers, networks, and the API |
| **A CLI** | `docker run` instead of a page of manual setup |

> **In short:** containers are an operating-system feature. On Linux that's namespaces + cgroups, and Docker is a very good tool for using them.

---

# 04 · Docker image

## a · Definition

> **An image is your whole setup saved as one file you can copy to any machine: the OS files, your app, and everything it needs, packed together.**

**It's Docker's actual invention.** Isolation came from namespaces, limits from cgroups, layering from union filesystems. None of that is Docker's. The image is.

**It's not Docker-owned anymore.** The format was standardized as the **OCI Image Spec**, so Podman, containerd and Kubernetes all use the same images.

---

## b · Docker images vs. containers

**A Docker image is a blueprint** that is executed in a Docker container. You add layers of core functionality to an image, and that image is then used to create a running container.

**In other words, a container is a running instance of an image.** You can create many containers from the same image, each with its own unique data and state.

---

## c · Image layers

**An image is not one flat blob. It's a stack of layers, and a layer is a set of file changes.**

Each build instruction produces one:

```dockerfile
FROM debian:bookworm     → layer 1: the whole base filesystem
RUN apt install nginx    → layer 2: only the files apt added
COPY nginx.conf /etc/    → layer 3: one file
```

Stacked, they look like this:

```
layer 3   nginx.conf
layer 2   /usr/sbin/nginx, /etc/nginx/...
layer 1   /bin, /etc, /usr, /var ...
──────────────────────────────────────
the container sees:  all of it, merged into one /
```

**A union filesystem does the merging** (OverlayFS on this machine). The process opening `/etc/nginx.conf` has no idea it came from layer 3. It just sees a normal filesystem.

**Why layers matter:**

- **Shared.** Ten images built `FROM debian:bookworm` store that base layer **once**.
- **Cached.** On rebuild, unchanged layers are reused, which is why the order of your instructions changes build time.
- **Read-only.** Every layer is frozen. A running container adds one writable layer on top, and that one dies with the container.
