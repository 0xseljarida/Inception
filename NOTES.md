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
    * [e · Conclusion](#e--conclusion)
* [03 · Docker](#03--docker)
* [04 · Docker image](#04--docker-image)
    * [a · Definition](#a--definition)
    * [b · Docker images vs. containers](#b--docker-images-vs-containers)
    * [c · Image layers](#c--image-layers)
* [05 · Docker architecture](#05--docker-architecture)
    * [a · The CLI is just an HTTP client](#a--the-cli-is-just-an-http-client)
    * [b · dockerd, containerd, shim, runc](#b--dockerd-containerd-shim-runc)

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

> 💡 **Fun fact:** when Google started this work in 2006 it was called **"process containers"**. The name was changed to *control groups* in late 2007 to avoid confusion, because "container" already meant several different things around the kernel. It merged as **cgroups** in 2.6.24, January 2008.

---

## e · Conclusion

**Namespaces answer** *"what world does this process live in?"*
**cgroups answer** *"how much of the real machine may it consume?"*

**A container is a process given both:** a fabricated view, and a budget.

**LXC put the two together first.** In 2008, five years before Docker, LXC combined namespaces and cgroups straight from the mainline kernel and called the result a container. The pieces themselves were never built for this: mount namespaces came from Plan 9, cgroups from Google's datacenters, union filesystems from live CDs.

**So containers already existed and already worked.** Docker arrived in 2013 to solve a different problem.

---

# 03 · Docker

> **Docker is a tool that builds, ships and runs containers.**

LXC could already run a container, but you still had to assemble its filesystem by hand, choose the namespaces, wire the network, then repeat all of it on every machine. There was no way to hand someone a finished environment.

> **Isolation was solved. Distribution wasn't.**

**Solomon Hykes hit that wall at dotCloud**, a platform-as-a-service company already running customer applications in containers. Docker began as their internal tooling, and he open-sourced it in March 2013 at PyCon. dotCloud renamed itself Docker Inc. the same year.

**His answer was the image:** build the environment once, ship it as one artifact. Around it came three more pieces:

| | |
|:--|:--|
| **Images** | a packaged filesystem you build once and ship anywhere |
| **A registry** | somewhere to publish and download them |
| **A daemon** | a background service managing images, containers, networks, and the API |
| **A CLI** | `docker run` instead of a page of manual setup |

**Docker still wasn't touching the kernel yet.** It drove LXC until version 0.9 in 2014, when `libcontainer`, written in Go, replaced it. That component is what became `runc`.

> **In short:** containers are an operating-system feature. On Linux that's namespaces + cgroups, and Docker is a very good tool for using them.

<br>

**If a corrector asks "what is Docker?":**

> **Docker is a platform for building, shipping and running containers.**
>
> It provides no isolation of its own. It drives features that already exist in the Linux kernel: **namespaces** for isolation, **cgroups** for limits, and a **union filesystem** (OverlayFS) for layered images.
>
> It is **client and server**. The `docker` CLI is just an HTTP client; it sends every command to a daemon, `dockerd`, which builds images from Dockerfiles, pulls and pushes them to registries, and delegates the actual container creation down to `containerd` and `runc`.
>
> A container is **not a virtual machine**. No OS boots, no hardware is emulated. Every container is an ordinary process sharing the host's kernel, which is why it starts instantly and costs almost nothing in memory.

---

# 04 · Docker image

## a · Definition

> **A container image is a standardized package that includes all of the files, binaries, libraries and configurations to run a container.**
>
> <sub><i>Docker's own definition</i></sub>

**In plainer words:** your whole setup saved as one package you can copy to any machine. The OS files, your app, its dependencies and its config, together.

**What it does not contain is a kernel.** That is the entire difference from a VM image. A VM image carries an operating system that has to boot; a container image carries only userspace and borrows the kernel of whatever machine it lands on.

**Two rules define an image:**

- **It is immutable.** Once created it can never be modified. You can only build a new one, or add changes on top of it.
- **It is layered.** It is composed of layers, each one a set of filesystem changes that add, remove or modify files.

**It's Docker's actual invention.** Isolation came from namespaces, limits from cgroups, layering from union filesystems. None of that is Docker's. The image is.

**It's not Docker-owned anymore.** The format was standardized as the **OCI Image Spec**, so Podman, containerd and Kubernetes all use the same images.

---

## b · Docker images vs. containers

> **An image is the package. A container is that package running.**

Docker defines a container as an **isolated process**: *"Containers are isolated processes for each of your app's components."* Self-contained, because it carries everything it needs, and isolated, because it barely touches the host or its neighbours.

| Image | Container |
|:--|:--|
| a package sitting on disk | a running process |
| does nothing on its own | has a lifecycle: start, stop, die |
| read-only | the image layers **plus its own writable directory** |
| built once | created and destroyed freely |

**Many containers, one image.** Each one gets its own writable directory, so each has its own data and state. Nothing a container writes ever reaches the image it came from.

---

## c · Image layers

**An image is a stack of layers, and each layer is a set of filesystem changes:** additions, deletions, or modifications.

Each build instruction produces one:

```dockerfile
FROM debian:bookworm     → layer 1: the whole base filesystem
RUN apt install nginx    → layer 2: only the files apt added
COPY nginx.conf /etc/    → layer 3: one file
```

**On disk, every layer is extracted into its own directory.** They only become a filesystem when a container starts: a **union filesystem** stacks them into one unified view, and adds one more directory that belongs to the container itself.

```
writable layer   ← created at run time, for this container only
layer 3   nginx.conf
layer 2   /usr/sbin/nginx, /etc/nginx/...
layer 1   /bin, /etc, /usr, /var ...
──────────────────────────────────────
the process sees:  one merged /
```

**The process has no idea.** Opening `/etc/nginx.conf` looks like opening a file on a normal filesystem, not like reaching into layer 3.

**Why layers matter:**

- **Reuse.** You extend someone else's image by reusing their base layers and adding only your own data. Ten images built `FROM debian:bookworm` store that base **once**.
- **Cache.** On rebuild, unchanged layers are reused, which is why the order of your instructions changes build time.
- **Immutable.** Image layers are never touched. Every change a container makes lands in its own writable directory, and that directory dies with the container.

---

# 05 · Docker architecture

> **Docker is client and server.** The `docker` command does almost nothing by itself.

**The daemon does the work.** In Docker's own words: *"The Docker client talks to the Docker daemon, which does the heavy lifting of building, running, and distributing your Docker containers."* `dockerd` listens for API requests and manages images, containers, networks and volumes.

---

## a · The CLI is just an HTTP client

**They talk over a REST API**, on a UNIX socket or a network interface. Nothing more.

```
docker CLI  ──HTTP──>  /var/run/docker.sock  ──>  dockerd
```

**Proof, without using `docker` at all:**

```bash
curl -s --unix-socket /var/run/docker.sock http://localhost/version
```

```json
{"Version":"29.7.2","ApiVersion":"1.55","Os":"linux","Arch":"amd64", ...}
```

That's the same answer `docker version` prints, because that is all `docker version` does.

**One consequence worth knowing:**

```
srw-rw---- 1 root docker  /var/run/docker.sock
```

Anyone in the `docker` group can send commands to a daemon running as **root**. Being in the docker group is effectively being root on the machine.

**And they are separate services.** On this machine `dockerd` and `containerd` are both children of PID 1, started by systemd. Neither is the other's parent.

---

## b · dockerd, containerd, shim, runc

**`dockerd` does not start containers itself.** It hands the job down a chain:

```
docker CLI  ──>  dockerd  ──>  containerd  ──>  containerd-shim  ──>  runc  ──>  kernel
```

| | Does |
|:--|:--|
| **dockerd** | the Docker API, images, builds, networks, volumes, the CLI-facing features |
| **containerd** | container lifecycle: pull, unpack, start, stop, supervise |
| **containerd-shim** | one per container. Stays alive, holds its stdio, reports its exit code |
| **runc** | actually creates the container: `clone()` with the namespace flags, writes the cgroup files, `exec`s your process, then **exits immediately** |

**Only `runc` touches the kernel**, and it is gone a millisecond later. That is why you never see it in `ps`.

**A running container is a child of the shim, not of the daemon:**

```
sleep (24654)
  └─ containerd-shim (24630)
       └─ systemd (1)
```

**That is why `systemctl restart docker` doesn't kill your containers.** They were never the daemon's children. The daemon can die and come back, and the container never notices.

**And `containerd` is not Docker-only.** It is a separate CNCF project. Kubernetes talks to it directly, with no Docker involved.
