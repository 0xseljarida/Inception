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
* [05 · Docker architecture (client ↔ daemon)](#05--docker-architecture)
    * [a · The CLI is just an HTTP client](#a--the-cli-is-just-an-http-client)
    * [b · dockerd, containerd, shim, runc](#b--dockerd-containerd-shim-runc)
    * [c · DEEPDIVE](#c--deepdive)
* [06 · Dockerfile](#06--dockerfile)
    * [a · Instructions and layers](#a--instructions-and-layers)
    * [b · FROM](#b--from)
    * [c · RUN](#c--run)
    * [d · COPY and the build context](#d--copy-and-the-build-context)
    * [e · CMD, ENTRYPOINT and PID 1](#e--cmd-entrypoint-and-pid-1)

---

<a id="01--why-containers-were-invented"></a>
<details>
<summary><h1>01 · Why containers were invented</h1></summary>


**One server. 200 customers. Each one wants their own isolated website.**

Three options existed:

| | Cost |
|:--|:--|
| **200 machines** | absurd |
| **200 processes on one machine** | no isolation. They read each other's files, one crash starves all |
| **200 VMs** | works, but 200 full operating systems: GBs of RAM, minutes to boot, all running the same Linux |

**The VM wastes everything.** The customer needs an isolated *website*, not an isolated *computer*.

> **Can one machine host many isolated tenants without pretending to be 200 machines?**

**Containers are the answer.** Keep one operating system, and make the kernel **restrict what each process can see of the machine**. A container is just a process. 

> **Note:** the "200 customers" framing above is a teaching device, not history.
> A 2005 host would have answered "shared hosting", and the real waste containers
> attacked was enterprise VM sprawl: thousands of VMs idling at 8% CPU.


<a id="a--container-vs-virtual-machine"></a>
<details>
<summary><h2>a · Container vs Virtual Machine</h2></summary>


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


</details>

</details>

<a id="02--what-is-a-container"></a>
<details>
<summary><h1>02 · What is a container?</h1></summary>


> **A container is a Linux process running in an isolated environment, where the kernel restricts and controls what the process can see and access.**

**No virtual machine boots. No OS is emulated.** Run `ps` on the host and you find an ordinary process among your others: same kernel, same scheduler.

**So what makes it a container?** Only **what that process is allowed to perceive and consume**. The kernel gives it a restricted view of the machine, and every system call it makes is answered from that view.

**Two kernel features enforce this:**

| | Controls | Purpose |
|:--|:--|:--|
| **Namespaces** | what a process can **see** | isolation |
| **cgroups** | what a process can **use** | limits |


<a id="a--containers-are-much-older-than-docker"></a>
<details>
<summary><h2>a · Containers are much older than Docker</h2></summary>


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


</details>

<a id="b--namespaces-what-it-sees"></a>
<details>
<summary><h2>b · Namespaces, what it sees</h2></summary>


> **A namespace gives a process its own private view of one part of the system.**

Instead of one global process list, one global network, one global hostname, the kernel keeps a second copy and hands it to the process. **The process has no way to detect the copy.** It queries the kernel and gets the private view back.

**Why use them?**

- **Isolation.** Each process gets its own view of the system and cannot access anyone else's.
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
&nbsp;&nbsp;&nbsp;&nbsp;A container reports a different boot time than the host.

<br>

One `sleep` command, seen from both sides at once:

```
inside container         on host
─────────────────        ─────────────────
PID 1  sleep 300    ═══  PID 50862  sleep 300
```

**Same process, two identities.** Inside it's process number 1, the first process in its pid namespace. Outside it's 50862, with a parent and hundreds of siblings it cannot see.

**The network namespace matters most here.** Each container gets its own interface, IP, routing table, and **its own set of ports**, which is why two containers can both listen on 9000 and never collide.


</details>

<a id="c--where-namespaces-actually-live"></a>
<details>
<summary><h2>c · Where namespaces actually live</h2></summary>


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


</details>

<a id="d--cgroups-what-it-uses"></a>
<details>
<summary><h2>d · cgroups, what it uses</h2></summary>


**Namespaces hide things but restrain nothing.** A process that only sees its own filesystem can still eat every byte of RAM on the machine, exactly the hosting problem from section 01.

**Control groups put a hard ceiling on consumption:** memory, CPU time, disk bandwidth, process count.

```bash
--memory=64m     may use 64 MB, no more
--cpus=0.5       gets half a core's worth of time
```

**Docker doesn't enforce this.** It writes a number to a file, and the **kernel** does the policing, including killing the process if it overruns.

> ⚠️ A container capped at 64 MB still reports the host's full 15 GB when asked how much memory the machine has. The reported value comes from the host, the enforced limit is the cgroup's.

> 💡 **Fun fact:** when Google started this work in 2006 it was called **"process containers"**. The name was changed to *control groups* in late 2007 to avoid confusion, because "container" already meant several different things around the kernel. It merged as **cgroups** in 2.6.24, January 2008.


</details>

<a id="e--conclusion"></a>
<details>
<summary><h2>e · Conclusion</h2></summary>


**Namespaces answer** *"what world does this process live in?"*
**cgroups answer** *"how much of the real machine may it consume?"*

**A container is a process given both:** a restricted view, and a resource limit.

**LXC put the two together first.** In 2008, five years before Docker, LXC combined namespaces and cgroups straight from the mainline kernel and called the result a container. The pieces themselves were never built for this: mount namespaces came from Plan 9, cgroups from Google's datacenters, union filesystems from live CDs.

**So containers already existed and already worked.** Docker arrived in 2013 to solve a different problem.


</details>

</details>

<a id="03--docker"></a>
<details>
<summary><h1>03 · Docker</h1></summary>


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


</details>

<a id="04--docker-image"></a>
<details>
<summary><h1>04 · Docker image</h1></summary>

<a id="a--definition"></a>
<details>
<summary><h2>a · Definition</h2></summary>


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


</details>

<a id="b--docker-images-vs-containers"></a>
<details>
<summary><h2>b · Docker images vs. containers</h2></summary>


> **An image is the package. A container is that package running.**

Docker defines a container as an **isolated process**: *"Containers are isolated processes for each of your app's components."* Self-contained, because it carries everything it needs, and isolated, because it barely touches the host or its neighbours.

| Image | Container |
|:--|:--|
| a package sitting on disk | a running process |
| does nothing on its own | has a lifecycle: start, stop, die |
| read-only | the image layers **plus its own writable directory** |
| built once | created and destroyed freely |

**Many containers, one image.** Each one gets its own writable directory, so each has its own data and state. Nothing a container writes ever reaches the image it came from.


</details>

<a id="c--image-layers"></a>
<details>
<summary><h2>c · Image layers</h2></summary>


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

**The merge is transparent to the process.** Opening `/etc/nginx.conf` looks like opening a file on a normal filesystem, not like reaching into layer 3.

**Why layers matter:**

- **Reuse.** You extend someone else's image by reusing their base layers and adding only your own data. Ten images built `FROM debian:bookworm` store that base **once**.
- **Cache.** On rebuild, unchanged layers are reused, which is why the order of your instructions changes build time.
- **Immutable.** Image layers are never touched. Every change a container makes lands in its own writable directory, and that directory dies with the container.


</details>

</details>

<a id="05--docker-architecture"></a>
<details>
<summary><h1>05 · Docker architecture (client ↔ daemon)</h1></summary>


> **Docker is client and server.** The `docker` command does almost nothing by itself.

**The daemon does the work.** In Docker's own words: *"The Docker client talks to the Docker daemon, which does the heavy lifting of building, running, and distributing your Docker containers."* `dockerd` listens for API requests and manages images, containers, networks and volumes.


<a id="a--the-cli-is-just-an-http-client"></a>
<details>
<summary><h2>a · The CLI is just an HTTP client</h2></summary>


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


</details>

<a id="b--dockerd-containerd-shim-runc"></a>
<details>
<summary><h2>b · dockerd, containerd, shim, runc</h2></summary>


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


</details>

<a id="c--deepdive"></a>
<details>
<summary><h2>c · DEEPDIVE</h2></summary>


- **`dockerd`**: the **Docker daemon** that manages Docker resources and translates Docker API requests into container operations.
- **`containerd`**: a **container runtime manager** that manages the lifecycle, images, and execution of containers, delegating the actual Linux isolation and process creation to a runtime such as `runc`.

**Stop thinking of them as two things that both "run containers".** They have different responsibilities.

```
docker CLI
    │
    │ HTTP API
    ▼
 dockerd
    │
    │ gRPC
    ▼
containerd
    │
    │ manages container runtime
    ▼
containerd-shim-runc-v2
    │
    ▼
   runc
    │
    │ creates Linux isolation
    ▼
your process
```

<br>

### 1. What `dockerd` actually does

Type this:

```bash
docker run -d --name web -p 8080:80 nginx
```

**The CLI does not create a process.** It sends a request to `dockerd`, conceptually:

```
POST /containers/create
{
    image: "nginx",
    name:  "web",
    ports: ...
}
```

**Then `dockerd` makes all the Docker-specific decisions:**

- what does `nginx` mean, and does that image exist locally?
- if not, pull it from a registry
- which network, which IP, which port mapping?
- which volumes and bind mounts?
- which environment variables, which restart policy?

**`dockerd` constructs the desired container configuration.** That is its whole job.

<br>

### 2. What `containerd` does

Once `dockerd` has decided *"I want a container with these properties"*, it asks `containerd` to manage the actual lifecycle.

**`containerd` knows nothing about the Docker CLI.** Its concern is narrower:

> *"I have an OCI image and an OCI runtime specification. I need to create and manage a container from them."*

It handles:

- image and layer management
- filesystem snapshots
- container lifecycle: start, stop, delete
- talking to the runtime, and managing the container's shim

<br>

### 3. Where the actual process comes from

**`containerd` does not perform the namespace setup either.** It goes through the shim to `runc`:

```
containerd
    ↓
containerd-shim-runc-v2
    ↓
runc
```

**`runc` is what performs the low-level creation**, using:

```
namespaces
cgroups
mounts
capabilities
seccomp
pivot_root
execve()
```

The result is an ordinary Linux process, placed inside the right namespaces and cgroups:

```
PID 12345  nginx
```

<br>

### 4. The separation, in one line each

**dockerd** = Docker's API and configuration layer *(the brain)*
**containerd** = container lifecycle manager
**runc** = low-level container creator
**Linux kernel** = what actually provides the isolation

<br>

### 5. Why not just dockerd → runc?

**Historically, it was.** Most of the container machinery lived inside Docker itself, and was split out later. The split is what makes `containerd` useful **without** Docker:

```
Docker ecosystem          Kubernetes
      │                        │
   dockerd                    CRI
      │                        │
  containerd               containerd
      │                        │
    runc                     runc
```

No `dockerd` required on the right-hand side.

<br>

### The distinction to keep in your head

`docker run nginx` asks **three different questions**:

| Question | Answered by |
|:--|:--|
| What should this container look like? | `dockerd` |
| How do I manage its lifecycle and filesystem? | `containerd` |
| How do I turn that into a Linux process with namespaces and cgroups? | `runc` |

And underneath all of them:

```
                 Linux kernel
                      ▲
                    runc
                      ▲
          containerd-shim-runc-v2
                      ▲
                 containerd
                      ▲
                   dockerd
                      ▲
                 docker CLI
```

</details>

</details>

<a id="06--dockerfile"></a>
<details>
<summary><h1>06 · Dockerfile</h1></summary>


> **A Dockerfile is a recipe for building an image.** A plain-text file of instructions that the builder executes in order. Docker uses **BuildKit** by default.

```dockerfile
FROM debian:bookworm
RUN apt-get update && apt-get install -y nginx
COPY nginx.conf /etc/nginx/conf.d/
CMD ["nginx", "-g", "daemon off;"]
```

```bash
docker build -t my-nginx .
```


<a id="a--instructions-and-layers"></a>
<details>
<summary><h2>a · Instructions and layers</h2></summary>


**Only instructions that change the filesystem create a layer:**

| Creates a layer | Metadata only |
|:--|:--|
| `FROM` `RUN` `COPY` `ADD` | `CMD` `ENTRYPOINT` `ENV` `WORKDIR` `EXPOSE` ... |

So the example above is **4 instructions but 3 layers**. This is where the layers in § 04 c come from: **the Dockerfile is what produces them.**


</details>

<a id="b--from"></a>
<details>
<summary><h2>b · FROM</h2></summary>


**`FROM` names the base image and comes first.** For Inception:

```dockerfile
FROM debian:bookworm
```

**Never `debian:latest`.** The subject forbids it and asks for the penultimate stable release:

```
Debian 13 · trixie     current stable
Debian 12 · bookworm   penultimate stable   ← this one
```

**`latest` is a moving tag.** The image behind it changes over time, so a build that worked yesterday can break tomorrow. Pinning `bookworm` makes the intended release explicit and the build reproducible.


</details>

<a id="c--run"></a>
<details>
<summary><h2>c · RUN</h2></summary>


**`RUN` executes a command in a temporary container and freezes the result as a layer.** It is where your image size is decided.

**Rule 1: `update` and `install` go in the same `RUN`.**

```dockerfile
# wrong
RUN apt-get update
RUN apt-get install -y nginx
```

The first line gets cached. Weeks later you add a package, the `update` layer is reused from cache with **stale package lists**, and the install asks for versions that no longer exist. The build breaks for no visible reason.

```dockerfile
# right
RUN apt-get update && apt-get install -y nginx
```

One layer, so the cache invalidates as a unit.

**Rule 2: clean up inside the same `RUN`, or it does nothing.**

```dockerfile
# useless
RUN apt-get update && apt-get install -y nginx
RUN rm -rf /var/lib/apt/lists/*
```

**Layers are immutable.** Deleting a file in layer 3 cannot remove it from layer 2. It only writes a **whiteout marker** that hides it. The bytes are still in the image and still shipped.

```dockerfile
# right
RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*
```

Now those files never exist in a committed layer at all.

**`--no-install-recommends`** skips the packages Debian merely suggests. On a minimal image that is often tens of megabytes.


</details>

<a id="d--copy-and-the-build-context"></a>
<details>
<summary><h2>d · COPY and the build context</h2></summary>


**The `.` at the end of the build command is not decoration.** It is the **build context**: the directory that gets packed up and sent to the daemon.

```bash
docker build -t my-nginx .
```

**Remember § 05: the CLI builds nothing.** It tars that directory, sends it over the socket, and BuildKit builds on the other side. That is why the output starts with a transfer, and it explains the rules below.

**`COPY` can only read from inside the context.**

```dockerfile
COPY nginx.conf /etc/nginx/conf.d/    # fine, it was sent
COPY ../secrets/db_password /run/     # impossible, never sent
```

**There is no way around it.** The daemon may sit on another machine entirely; it simply does not have your parent directory. Any path outside the context does not exist as far as the build is concerned.

**`.dockerignore` keeps junk out of the transfer.** Same syntax as `.gitignore`:

```
.git
*.md
secrets/
```

Without it you ship your whole `.git` history to the daemon on every build, which is slower and risks baking things into the image that should never be there.

**`COPY` vs `ADD`:** both copy files in, but `ADD` also unpacks local tar archives and can fetch URLs. That extra magic is surprising and hard to audit.

> **Use `COPY` unless you specifically need `ADD`.** This is Docker's own recommendation.

</details>

<a id="e--cmd-entrypoint-and-pid-1"></a>
<details>
<summary><h2>e · CMD, ENTRYPOINT and PID 1</h2></summary>


**They both say what to run.** `ENTRYPOINT` is the fixed command, `CMD` is the default argument. Used alone, either works.

**Write them in exec form, always:**

```dockerfile
CMD ["nginx", "-g", "daemon off;"]     # exec form: nginx is PID 1
CMD nginx -g "daemon off;"             # shell form: /bin/sh is PID 1
```

**Shell form silently wraps your command in `/bin/sh -c`.** The shell becomes PID 1 and your daemon becomes its child.

**Why that breaks things:** PID 1 is the reaper. It receives the signals and adopts orphans. `sh` does not forward `SIGTERM`, so `docker stop` is ignored, waits 10 seconds, then kills the container. Zombies pile up too.

**The daemon must stay in the foreground.** A service that daemonises exits immediately, and the container dies with it:

```
nginx     -g "daemon off;"
php-fpm   -F
mysqld    (already foreground)
```

> ⚠️ **The subject bans `tail -f`, `sleep infinity`, `while true` and bare `bash` as PID 1.** Each one is a fake process holding the container open while the real service runs behind it, or not at all. Instant fail at defense.

</details>

</details>