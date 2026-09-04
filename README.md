<h1 align="center">Inception · Notes</h1>

## Index

<details>
<summary>01 · Why containers were invented</summary>

* a · Container vs Virtual Machine

</details>

<details>
<summary>02 · What is a container?</summary>

* a · Containers are much older than Docker
* b · Namespaces, what it sees
* c · Where namespaces actually live
* d · cgroups, what it uses
* e · Conclusion

</details>

<div>&emsp;03 · What Docker is</div>
<br>

<details>
<summary>04 · Docker image</summary>

* a · Definition
* b · Docker images vs. containers
* c · Image layers

</details>

<details>
<summary>05 · Docker architecture (client ↔ daemon)</summary>

* a · The CLI is a Docker API client
* b · dockerd, containerd, shim, runc

</details>

<details>
<summary>06 · Dockerfile</summary>

* a · Instructions and layers
* b · FROM
* c · RUN
* d · COPY and the build context
* e · CMD, ENTRYPOINT and PID 1
* f · Users and privileges inside a container

</details>

<div>&emsp;07 · Docker Compose</div>
<br>

<details>
<summary>08 · Volumes</summary>

* a · Why containers need them
* b · Named volumes and bind mounts
* c · Custom host paths with driver_opts

</details>

<div>&emsp;09 · Docker networking</div>
<br>

<details>
<summary>10 · MariaDB</summary>

* a · What MariaDB is
* b · MariaDB, the container

</details>

<details>
<summary>11 · WordPress</summary>

* a · What WordPress is
* b · The WordPress container

</details>

<details>
<summary>12 · nginx</summary>

* a · What nginx is
* b · The configuration files
* c · TLS and the certificate
* d · The nginx container

</details>

<div>&emsp;13 · The Makefile</div>
<br>

<details>
<summary>14 · Bonus</summary>

* a · A static website
* b · Adminer
* c · redis cache
* d · The service of my choice

</details>

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

> **Containerization is the answer.** Keep one operating system and use the kernel to **isolate and control what each process can see and use**. The result is what we call a **container**, which is essentially an isolated process.

> **Note:** the "200 customers" framing above is a teaching device, not history.
> A 2005 host would have answered "shared hosting".


<a id="a--container-vs-virtual-machine"></a>
<details>
<summary><h2>a · Container vs Virtual Machine</h2></summary>


**Containers exist for density and isolation**, not to replace VMs.

<p align="center"><img src="assets/Docke-vs-VM.png" width="800"></p>
<p align="center"><i>containers share one kernel · VMs each carry their own</i></p>

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


<p align="center"><img src="assets/image_linux_peng.jpeg" width="500"></p>
<p align="center"><i>the container is a Linux mechanism · Docker only makes it easy to use</i></p>

> **A container is a Linux process running in an isolated environment, where the kernel restricts and controls what the process can see and access.**

**No virtual machine boots. No OS is emulated.** Run `ps` on the host and you find an ordinary process among your others: same kernel, same scheduler.

<details>
<summary><b>VISUAL · Many containers, one kernel</b></summary>

<br>

<p align="center"><img src="assets/containers_kernel.webp" width="700"></p>
<p align="center"><i>many containers · one shared kernel</i></p>

</details>

**So what makes it a container?** Only **what that process is allowed to perceive and consume**. The kernel gives it a restricted view of the machine, and every system call it makes is answered from that view.

**Two kernel features enforce this:**

| Feature        | Controls                   | Purpose         |
| :------------- | :------------------------- | :-------------- |
| **Namespaces** | what a process can **see** | isolation       |
| **cgroups**    | what a process can **use** | resource limits |


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

**Docker did not invent the container.** It arrived 34 years after `chroot` and 5 years after LXC .

<details>
<summary><b>DEEPDIVE</b></summary>
	
### LXC

Linux Containers (LXC) is an operating system-level virtualization method for running multiple isolated Linux systems (containers) on a control host using a single Linux kernel.

The Linux kernel provides the cgroups functionality that allows limitation and prioritization of resources (CPU, memory, block I/O, network, etc.) without the need for starting any virtual machines, and also the namespace isolation functionality that allows complete isolation of an application's view of the operating environment, including process trees, networking, user IDs and mounted file systems.[3]

LXC combines the kernel's cgroups and support for isolated namespaces to provide an isolated environment for applications.[4]

Early versions of Docker used LXC as the container execution driver,[4] though LXC was replaced as the default in version 0.9.0[5][6] and was deprecated in 1.8.0,[7] before the driver was removed in 1.10.0.[8]

[Wikipedia — LXC](https://en.wikipedia.org/wiki/LXC)
</details>

</details>

<a id="b--namespaces-what-it-sees"></a>
<details>
<summary><h2>b · Namespaces </h2></summary>


> **A namespace is a kernel mechanism that creates an isolated instance of a system resource.**

**The kernel normally maintains system resources globally:** a single process table, network stack, mount tree, hostname, etc. A namespace creates a separate instance of one of these resources and associates it with a group of processes.

**The result is isolation:** processes inside the namespace see and interact with their own instance rather than the host's global one.

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
&nbsp;&nbsp;&nbsp;&nbsp;The container calls itself `database`; the host never changed name.

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
<p align="center"><i><a href="https://github.com/torvalds/linux/blob/master/include/linux/sched.h"><code>include/linux/sched.h</code></a> · a pointer, not the namespaces themselves</i></p>

**And what it points to is just a box of pointers**, one per namespace type:

<p align="center"><img src="assets/struct-nsproxy.png" width="560"></p>
<p align="center"><i><a href="https://github.com/torvalds/linux/blob/master/include/linux/nsproxy.h"><code>include/linux/nsproxy.h</code></a></i></p>

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

<a id="03--what-docker-is"></a>
<details>
<summary><h1>03 · What Docker is</h1></summary>


At this point, **Linux** already gives us everything required to isolate a process. What is missing is a convenient, repeatable way to build, share, and run that isolated environment.

That is where Docker fits:

> **Docker is a platform that makes containers easy to build, share, and run in a repeatable way.**

**In other words,** Docker manages the images, networks, volumes, ports, and lifecycle needed to run containers. **Linux still creates the isolation** through namespaces and cgroups.

<p align="center"><img src="assets/What_does_docker_do.png" width="600"></p>
<p align="center"><i>Docker manages the objects needed to build and run containerized applications</i></p>

```text
                    Docker workflow

  Dockerfile ────> Image ────> Registry ────> Container
   describe         build        share            run
                                                   │
                                      isolated by Linux
                                         ┌─────────┴─────────┐
                                     namespaces           cgroups
                                    what it sees         what it uses
```

> **A Docker registry is a server that stores, versions, and distributes container images.** Think of it as GitHub for images: instead of hosting source code, it hosts packaged, ready-to-run application environments. **Docker Hub is the best-known public registry.**

It turns the low-level pieces of containerization into a workflow a developer can use:

1. **Describe** the application's environment in a `Dockerfile`.
2. **Build** that environment into an image.
3. **Share** the image through a registry such as Docker Hub.
4. **Run** it as a container on any compatible host.

> **Linux provides the container mechanism. Docker provides the tools and workflow around it.**


<a id="deepdive--where-docker-came-from"></a>
<details>
<summary><h2>DEEPDIVE · Where Docker came from</h2></summary>


**LXC could already run a container**, but you still had to assemble its filesystem by hand, choose the namespaces, wire the network, then repeat all of it on every machine. There was no way to hand someone a finished environment.

> **Isolation was solved. Distribution wasn't.**

**Solomon Hykes hit that wall at dotCloud**, a platform-as-a-service company already running customer applications in containers. Docker began as their internal tooling, and he open-sourced it in March 2013 at PyCon. dotCloud renamed itself Docker Inc. the same year.

**His answer was the image:** build the environment once, ship it as one artifact. Around it came three more pieces:

| | |
|:--|:--|
| **Images** | a packaged filesystem you build once and ship anywhere |
| **A registry** | somewhere to publish and download them |
| **A daemon** | a background service managing images, containers, networks, and the API |
| **A CLI** | `docker run` instead of a page of manual setup |

**Docker still wasn't touching the kernel yet.** It drove LXC until version 0.9 in March 2014, when `libcontainer`, written in Go, became the default execution driver and LXC dropped to an optional one. That component is what became `runc`.


</details>

</details>

<a id="04--docker-image"></a>
<details>
<summary><h1>04 · Docker image</h1></summary>

<a id="a--definition"></a>
<details>
<summary><h2>a · Definition</h2></summary>


> **A container image is a standardized package that includes all of the files, binaries, libraries and configurations to run a container.**
>
> <sub><i><a href="https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-an-image/">Docker's own definition</a></i></sub>

**In plainer words:** your whole setup saved as one package you can copy to any machine. The OS files, your app, its dependencies and its config, together.

**What it does not contain is a kernel.** That is the entire difference from a VM image. A VM image carries an operating system that has to boot; a container image carries only userspace and borrows the kernel of whatever machine it lands on.

**Two rules define an image:**

- **It is immutable.** Once created it can never be modified. You can only build a new one, or add changes on top of it.
- **It is layered.** It is composed of layers, each one a set of filesystem changes that add, remove or modify files.

**It's Docker's actual invention.** Isolation came from namespaces, limits from cgroups, layering from union filesystems. None of that is Docker's. The image is.


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

```text
layer 3   application configuration
layer 2   installed application and dependencies
layer 1   base userspace filesystem
────────────────────────────────────────
image     one combined filesystem
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
- **Immutable.** Image layers are never touched. Every change a container makes lands in its own writable directory, and that directory dies with the container.

**Docker records filesystem changes as layers while building an image.** § 06 a explains how Dockerfile instructions produce those changes and how the resulting layers are cached.


</details>

</details>

<a id="05--docker-architecture"></a>
<details>
<summary><h1>05 · Docker architecture (client ↔ daemon)</h1></summary>


> **Docker uses a client-server architecture.** The Docker client talks to the Docker daemon, which does the heavy lifting of building, running, and distributing your Docker containers. The Docker client and daemon can run on the same system, or you can connect a Docker client to a remote Docker daemon. The Docker client and daemon communicate using a REST API, over UNIX sockets or a network interface.
>
> <sub><i><a href="https://docs.docker.com/get-started/docker-overview/">Docker's own definition</a></i></sub>

`dockerd` listens for API requests and manages Docker objects such as images, containers, networks, and volumes.

<p align="center"><img src="assets/Docker-engine-components-flow.png" width="500"></p>
<p align="center"><i>the Docker client reaches the daemon through the REST API</i></p>

<details>
<summary><b>DEEPDIVE · Docker architecture diagram</b></summary>

<br>

<p align="center"><img src="assets/docker_archi.png" width="900"></p>
<p align="center"><i>the client sends commands to the daemon, which manages local objects and communicates with registries</i></p>

</details>


<a id="a--the-cli-is-a-docker-api-client"></a>
<details>
<summary><h2>a · The CLI is a Docker API client</h2></summary>


**The Docker CLI is the command-line client for Docker Engine.** When you run a command such as `docker ps`, the CLI translates it into an API request, sends it to the Docker daemon, and formats the daemon's response.

**The CLI does five client-side jobs:**

- Parses commands and options.
- Reads contexts and client configuration.
- Negotiates an API version with the daemon.
- Sends API requests.
- Formats daemon responses for humans.

```text
docker ps ──► Docker Engine API ──► dockerd
                                      │
               formatted table  ◄── response
```

**The daemon performs the actual Docker operations.** The CLI does not inspect containers or start their processes itself. For example, `docker ps` maps to the API endpoint `GET /containers/json`; `dockerd` obtains the container list and returns it for the CLI to display.

**On Linux, the CLI normally reaches the daemon through `/var/run/docker.sock`.** A Docker context can instead point the same CLI at a remote engine over SSH or TCP secured with TLS.

<br>

<details>
<summary><b>DEEPDIVE · Calling and securing the Docker API</b></summary>

<br>

**You can call the API without using the Docker CLI:**

```bash
curl -s --unix-socket /var/run/docker.sock http://localhost/version
```

```json
{"Version":"...","ApiVersion":"...","Os":"linux","Arch":"amd64", ...}
```

The daemon returns the same server information that appears in `docker version`; the CLI requests it and formats the response for humans. For normal commands, the client and daemon negotiate the highest API version they both support so different Engine releases can still communicate.

**The socket is therefore a security boundary, not an ordinary file:**

```
srw-rw---- 1 root docker  /var/run/docker.sock
```

With the usual rootful Docker daemon, anyone in the `docker` group can request privileged containers or mount the host filesystem. Access to that group therefore grants root-level privileges on the machine.

**Rootless Docker changes this model** by running both the daemon and containers without root privileges. A remote daemon requires the same caution: use SSH or TLS rather than exposing an unauthenticated TCP socket.

</details>


</details>

<a id="b--dockerd-containerd-shim-runc"></a>
<details>
<summary><h2>b · dockerd, containerd, shim, runc</h2></summary>


**`dockerd` does not create container processes directly.** It coordinates the operation and delegates the low-level work through this chain:

```
docker CLI  ──>  dockerd  ──>  containerd  ──>  containerd-shim  ──>  runc  ──>  kernel
```

1. **`dockerd` handles Docker-level features.** It receives API requests and decides which images, networks, volumes, ports, and container settings are required.

2. **`containerd` manages the container lifecycle.** It prepares images and filesystems, then coordinates creating, starting, stopping, and deleting containers.

3. **`containerd-shim` connects containerd to the runtime.** It invokes the runtime and remains available to supervise the container process, preserve its I/O, and report its exit status.

4. **`runc` creates the isolated process.** It applies the OCI configuration—namespaces, cgroups, mounts, and capabilities—starts the process, and then exits.


<p align="center"><img src="assets/docker_use_containerd.png" width="574"></p>
<p align="center"><i>a simplified container-creation path · each <code>runc</code> invocation exits after starting the container process · <a href="https://mlops-for-all.github.io/en/docs/prerequisites/docker/">source</a></i></p>

**`runc` performs the low-level container setup**: namespaces, cgroups, capabilities, mounts, and process creation. Once the container process is running, `runc` exits; the shim remains.

<br>

<details>
<summary><b>DEEPDIVE · How a container is actually started</b></summary>

<br>

### 1. The requests cross three different interfaces

```bash
docker run -d --name web -p 8080:80 nginx
```

That single command crosses several boundaries:

```
docker CLI  ──REST/HTTP──>  dockerd  ──gRPC──>  containerd  ──ttrpc──>  containerd-shim
```

The CLI first sends Docker API requests such as `POST /containers/create` and `POST /containers/{id}/start`. `dockerd` translates Docker concepts—image names, published ports, networks, mounts, environment variables, and restart policies—into the configuration needed by the lower layers.

On a typical Linux installation, `dockerd` reaches containerd's gRPC API through a Unix socket. containerd then communicates with the runtime shim over ttrpc. These are API relationships, not necessarily parent-child relationships between the processes.

<br>

### 2. Creation and execution are separate operations

containerd stores the container metadata and prepares a filesystem snapshot from the image. Starting the container is a separate step: containerd asks `containerd-shim-runc-v2` to create a task, and the shim invokes `runc` with an OCI bundle.

That bundle contains two important things:

- a root filesystem for the process
- an OCI configuration describing its command, namespaces, cgroups, mounts, capabilities, and other runtime settings

`runc` asks the Linux kernel to apply that configuration and starts the requested command. The result is an ordinary Linux process—not a daemon maintained by `runc`.

<br>

### 3. Why the shim remains after `runc` exits

Once the process is running, `runc` exits. The shim remains as the stable contact point for containerd: it keeps the container's standard input and output available, reports its exit status, and allows containerd to reconnect after a restart.

A common process tree therefore looks like this:

```text
systemd (PID 1)
  └─ containerd-shim-runc-v2
       └─ container process
```

Runtime v2 does not require exactly one shim per container; a shim implementation may manage one container or a related group.

The shim's independence does **not** mean that restarting Docker always preserves running containers. Docker normally stops them when the daemon shuts down cleanly. Keeping containers alive while the daemon is unavailable requires Docker's `live-restore` option.

<br>

### 4. Why containerd is a separate layer

containerd is an independent CNCF project, not a Docker-only component. Docker Engine uses it, while other systems can use it without `dockerd`; Kubernetes, for example, can communicate with containerd through the Container Runtime Interface.

This separation gives higher-level platforms their own user-facing features while sharing the same lower-level container lifecycle and OCI runtime machinery.

**Further reading:** [containerd Runtime v2](https://github.com/containerd/containerd/blob/main/docs/runtime-v2.md) · [OCI Runtime Specification](https://github.com/opencontainers/runtime-spec/blob/main/spec.md) · [Docker live restore](https://docs.docker.com/engine/daemon/live-restore/)

</details>

</details>

</details>

<a id="06--dockerfile"></a>
<details>
<summary><h1>06 · Dockerfile</h1></summary>


> **A Dockerfile is a recipe for building an image.** A plain-text file of instructions that the builder executes in order. Docker uses **BuildKit** by default.

<p align="center"><img src="assets/docker_file_to_image_to_container.png" width="700"></p>
<p align="center"><i>a Dockerfile is built into an image · an image is run as a container</i></p>

```dockerfile
FROM debian:bookworm
RUN apt-get update && apt-get install -y nginx
COPY nginx.conf /etc/nginx/conf.d/
CMD ["nginx", "-g", "daemon off;"]
```

```bash
docker build -t my-nginx .
```


**Common Dockerfile instructions:**

| Instruction | Role |
|:--|:--|
| `FROM` | names the base image to build on. Always the first instruction |
| `RUN` | executes a command at build time, inside a temporary container |
| `COPY` | copies files from the build context into the image |
| `ADD` | like `COPY`, but also unpacks local tar archives and fetches URLs |
| `WORKDIR` | sets the working directory for every instruction that follows, and for the running container. Creates it if missing |
| `ENV` | sets an environment variable that stays in the final image |
| `ARG` | build-time variable only. It does not exist in the running container |
| `USER` | sets the UID for the instructions that follow, and for PID 1 |
| `EXPOSE` | records a port as documentation |
| `VOLUME` | declares a path as a volume |
| `LABEL` | adds metadata: author, version, description |
| `ENTRYPOINT` | the fixed command the container runs |
| `CMD` | default arguments to `ENTRYPOINT`, or the whole command when there is no `ENTRYPOINT` |

**`EXPOSE` is the one that gets misread.** It publishes nothing and opens nothing. Only `docker run -p` or Compose's `ports:` map a port to the host, and containers on the same docker network reach each other whether or not `EXPOSE` is present.

**`ARG` is not a way to pass a secret.** Its value is baked into the layer and `docker history` prints it back.

<a id="a--instructions-and-layers"></a>
<details>
<summary><h2>a · Instructions and layers</h2></summary>


**Only instructions that change the filesystem create a layer:**

| Creates a layer | Metadata only |
|:--|:--|
| `FROM` `RUN` `COPY` `ADD` | `CMD` `ENTRYPOINT` `ENV` `WORKDIR` `EXPOSE` ... |

So the example above is **4 instructions but 3 layers**. This is where the layers in § 04 c come from: **the Dockerfile is what produces them.**

**Those layers also form the build cache.** When an instruction and its inputs have not changed, Docker can reuse the existing result instead of running that step again. Once a layer changes, the layers that depend on it must be rebuilt, so stable instructions generally belong before frequently edited files.


</details>

<a id="b--from"></a>
<details>
<summary><h2>b · FROM</h2></summary>


**`FROM` names the base image and comes first:**

```dockerfile
FROM debian:bookworm
```

**Avoid `debian:latest` when reproducibility matters.** `latest` is a moving tag: the image behind it changes over time, so a build that worked yesterday can behave differently tomorrow. Pinning a release such as `bookworm` makes the intended base explicit.


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

**`--no-install-recommends`** skips the packages apt would pull in under `Recommends`. That is a distinct relationship from `Suggests`, which apt never installs automatically regardless of this flag. Skipped correctly, the size difference is not a rounding error: Canonical measured a 60% smaller image and about 15% faster builds after adding the flag across their Python website Dockerfiles.

**It is a linter rule, not a personal habit.** hadolint's `DL3015` flags any `apt-get install` missing it, and a Depot.dev scan of real-world Dockerfiles found it triggered in 22% of them, meaning the other 78% already comply. `DL3009`, cleaning up `/var/lib/apt/lists/*` in the same layer, is the rule that pairs with it, covered above.

**Fewer packages also means a smaller attack surface.** Every installed package is more code that can carry a CVE, which is why dropping unused recommends shows up in most Docker security checklists.

**The flag can break things, deliberately.** Some packages genuinely need their recommends: fonts for a headless browser, locale or timezone data for some runtimes, or `ca-certificates` for software that connects over TLS. If a package that used to work fails after adding this flag, the missing recommend is the first suspect, and it gets added back explicitly, not fixed by dropping the flag.

**A global alternative exists** for turning this off on every future `apt-get install` instead of repeating the flag each time:

```dockerfile
RUN echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/99norecommends
```

Not needed here, since one `RUN` already installs every package this image needs. On a Debian desktop or dev machine, do not set this globally, recommends are usually what you actually want there.


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

**Do not keep a container alive with placeholders such as `tail -f`, `sleep infinity`, or `while true`.** Each one is a fake process holding the container open while the real service runs behind it, or not at all.

<br>

**Which leaves the question of what belongs in the script at all.** The rule is: anything that depends only on the image goes in the image, only what depends on runtime input goes in the entrypoint.

```text
Dockerfile        install dependencies           fixed, known at build time
entrypoint        render runtime configuration   needs environment variables or secrets
entrypoint        initialize persistent data     needs the volume mounted at run time
```

**Everything put in the image is done once and cached.** Everything put in the entrypoint is redone at every container start, which is why anything placed there needs a guard against running twice.

<br>

### Read about PID 1 and the best practices for writing Dockerfiles.

**PID 1 is the container's main process, so making it the actual service gives Docker direct control over that service's lifecycle and signals.**

</details>

<a id="f--users-and-privileges-inside-a-container"></a>
<details>
<summary><h2>f · Users and privileges inside a container</h2></summary>


> **Unless told otherwise, every process in a container runs as UID 0, root.**

**Nothing special makes this happen.** There is no login, no `su`, no privilege escalation. `runc` simply `exec`s the process with UID 0 because no other UID was requested. Three places can request one: the `USER` instruction in the Dockerfile, `--user` on `docker run`, or `user:` in Compose. If none of them appear, the answer stays 0.

**This is why `RUN` never needs `sudo`:**

```dockerfile
RUN apt-get update && apt-get install -y nginx
```

Each `RUN` executes in a temporary container whose process is already root, so `apt-get` has every permission it needs. Writing `sudo` there fails outright, because `debian:bookworm` does not even ship the `sudo` package.

<br>

### Container root is not quite host root

**With Docker's default configuration, UID 0 inside is the same UID 0 as the host.** User namespace remapping exists, but it is off by default, so the kernel sees one identical numeric identity on both sides.

**What separates them is not identity but capabilities.** Linux splits root's power into capability bits, and Docker grants a container only a subset of them:

| Granted by default | Not granted by default |
|:--|:--|
| `CHOWN` `SETUID` `SETGID` `KILL` `NET_BIND_SERVICE` `NET_RAW` `SYS_CHROOT` ... | `SYS_ADMIN` `SYS_MODULE` `SYS_TIME` `SYS_BOOT` ... |

**So container root can chown files and bind port 443, but cannot load a kernel module, change the system clock, or mount arbitrary filesystems.** Seccomp and AppArmor profiles narrow it further. It is root over the container's own namespaces, not over the machine.

> ⚠️ **The exception is the socket.** Anyone who can reach `/var/run/docker.sock` can ask the daemon for a container with every capability and the host filesystem mounted inside. That is why § 05 a calls the `docker` group equivalent to root.

<br>

### Dropping privileges on purpose

**A daemon that starts as root does not have to stay root.** The usual pattern is to acquire whatever needs privilege, then call `setuid()` and `setgid()` to a dedicated unprivileged system account. Files the daemon creates are then owned by that account rather than by root.

<br>

### The practical consequence for volumes

**UIDs are numbers, and they cross the boundary unchanged.** A file written by UID 999 inside the container appears on a mounted host directory as owned by whatever host account happens to be UID 999. Ownership is decided by the container process that writes the file, not by the user who ran Docker.

</details>

</details>

<a id="07--docker-compose"></a>
<details>
<summary><h1>07 · Docker Compose</h1></summary>


> **Docker Compose is a tool for defining and running multi-container applications.**
>
> <sub><i><a href="https://docs.docker.com/compose/">Docker's own definition</a></i></sub>

**A Dockerfile builds one image. Nothing in it describes a stack.** It cannot say which containers exist together, which network they share, which volumes persist, or what starts before what. Those are relationships *between* containers, and there is nowhere in a Dockerfile to write them down.

**That gap is what Compose fills:** *"it simplifies the control of your entire application stack, making it easy to manage services, networks, and volumes in a single YAML configuration file."* One file describes the whole system, and *"with a single command, you create and start all the services from your configuration file."*

```
Dockerfile    how ONE image is built
compose.yaml  how ALL the containers run together
```

<br>

<details>
<summary><b>What it replaces</b></summary>

<br>

**Without Compose, a multi-container application becomes a collection of long commands that must be repeated in the right order:**

```bash
docker network create app_net
docker volume create app_data
docker run -d --name database \
    --network app_net \
    --env-file .env \
    -v app_data:/var/lib/database \
    --restart unless-stopped \
    example/database
```

**Every flag is a fact that lives nowhere.** It exists in your shell history and has to be retyped identically on the next machine.

```yaml
services:
  database:
    image: example/database
    networks: [app_net]
    env_file: [.env]
    volumes:
      - app_data:/var/lib/database
    restart: unless-stopped
```

**The deeper change is declarative instead of imperative.** `docker run` is an instruction: *do this now*. A Compose file is a description: *this is what should exist*. Compose compares that description against what is actually running and makes up the difference, which is why `docker compose up` on an already-running stack does nothing instead of failing or duplicating.

</details>

<br>

<details>
<summary><b>Four core top-level elements</b></summary>

<br>

**A typical Compose file is organized around four core keys**, each mapping to Docker objects or data used by services:

```yaml
services:   the containers, one block each
networks:   the networks they are attached to
volumes:    the named volumes that outlive them
secrets:    files mounted read-only at /run/secrets/
```

**`services:` is the only mandatory one.** The other three declare named resources or data. A service attaches a named volume, network, or secret by listing it in its own configuration; in particular, a secret is not available to a service unless explicitly granted.

**Everything else nests inside a service:** `build`, `image`, `env_file`, `depends_on`, `restart`, `ports`. Those are per-container settings, so they have no meaning at the top level.

</details>

<br>

<details>
<summary><b>The keys, and what each one does</b></summary>

<br>

**A Dockerfile is a flat list of instructions. A Compose file is two levels**, and that split is the part worth getting straight first:

```text
compose.yaml
│
├── services:          what to run
│   ├── database:      service name, also its DNS hostname
│   │   └── build, volumes, networks, secrets, env_file, restart ...
│   └── web:
│
├── networks:          resources the services reference by name
├── volumes:
└── secrets:
```

**A top-level block declares a resource. A key inside a service attaches it.** `volumes:` at the top level creates a volume, `volumes:` inside a service mounts it. Same word, two different jobs.

| Top-level element | Role |
|:--|:--|
| `services` | the containers to run. Each key under it is a service name, and Compose's DNS resolves that name, not `container_name` |
| `networks` | *"lets you configure named networks that can be reused across multiple services"* |
| `volumes` | *"lets you configure named volumes that can be reused across multiple services"* |
| `secrets` | *"defines or references sensitive data that is granted to the services"* |

| Service-level key | Role |
|:--|:--|
| `build` | build configuration for creating an image from source. Points at the directory holding the Dockerfile |
| `image` | the image to start the container from. Together with `build`, it names the image Compose produces |
| `container_name` | a custom container name instead of the generated one. Not used for DNS |
| `depends_on` | controls startup and shutdown order. `service_started` only waits for the process to exist, `service_healthy` waits for a passing `healthcheck` |
| `environment` | environment variables set in the container, as an array or a map |
| `env_file` | one or more files containing environment variables to pass to the container |
| `networks` | the networks this container attaches to, referencing entries under the top-level `networks` |
| `volumes` | mounts host paths or named volumes into the container |
| `secrets` | grants access to secrets defined at top level. Each one lands at `/run/secrets/<name>` |
| `ports` | publishes a container port on the host |
| `expose` | records a port as reachable from other containers. Documentation only, like Dockerfile `EXPOSE` |
| `restart` | the policy applied on container termination: `no`, `always`, `on-failure`, `unless-stopped` |
| `command` | overrides the image's `CMD` |
| `entrypoint` | overrides the image's `ENTRYPOINT` |

**Under a top-level block, every key is a name.** This is the part that is easy to get wrong with `secrets:`, because the word appears twice and means something different each time:

```yaml
secrets:                               # declare, once
  api_key:                             # ← the NAME of a secret
    file: ./secrets/api_key.txt        # ← where its content comes from

services:
  web:
    secrets: [api_key]                 # attach, by name
```

**The name decides the path, the filename does not.** `file:` is only a host path that Compose reads. What the container sees is `/run/secrets/<name>`, and the `.txt` never appears:

```text
name in compose     file on host                 path in container
api_key       ←──   ./secrets/api_key.txt   ──→  /run/secrets/api_key
```

**The name is part of the container interface.** Renaming the host file changes nothing, but renaming the Compose key changes the path inside the container. Use environment variables or `env_file` for ordinary configuration and secrets for confidential values.

**A user-defined network also provides DNS between its services:**

> Containers on the default bridge network can only access each other by IP addresses, unless you use the `--link` option, which is considered legacy.
>
> User-defined bridges provide automatic DNS resolution between containers.
>
> <sub><i>Docker, bridge network driver</i></sub>

**That is why a service can connect to `database` by name instead of tracking a changing container IP address.** A restart policy separately controls whether Docker starts a container again after it exits.

</details>

<br>

<details>
<summary><b>Ignore the <code>version:</code> line in old examples</b></summary>

<br>

**Almost every Compose tutorial online opens with a line that is now obsolete:**

```yaml
version: "3.8"     # delete this
```

**It described which schema version the file targeted**, back when the format was versioned 2.0 through 3.8. The Compose Specification replaced that scheme, and Compose *"always uses the most recent schema to validate the Compose file, regardless of the `version` field."*

**Leaving it in is not an error, but it is noise.** Current Compose releases warn:

```
WARN: the attribute `version` is obsolete, it will be ignored,
      please remove it to avoid potential confusion
```

**The preferred filename is `compose.yaml`.** `compose.yml`, `docker-compose.yaml`, and `docker-compose.yml` are also supported for compatibility. If both a preferred and legacy filename exist, Compose selects the preferred one and warns about the ambiguity.

</details>

<br>

<details>
<summary><b>Compose is a client, not a second engine</b></summary>

<br>

**Compose creates nothing itself.** It parses the YAML, works out which containers, networks and volumes should exist, and then sends ordinary requests to the same API from § 05:

```
docker compose up
      │  reads compose.yaml
      │  decides what should exist
      ▼
  dockerd            same REST API, same socket
      ▼
 containerd
      ▼
   runc
      ▼
Linux kernel
```

**So nothing new happens at the bottom.** A container started by Compose is indistinguishable from one started by `docker run`, and `docker ps` lists them side by side. Compose only removes the typing, it does not add a layer of isolation or a new kind of object.

</details>

<br>

<details>
<summary><b><code>docker compose</code>, not <code>docker-compose</code></b></summary>

<br>

**The hyphen marks the old implementation.** Compose V1 was a separate Python program invoked as `docker-compose`. V2 rewrote it in Go as a plugin to the `docker` CLI, invoked as a subcommand:

```
docker-compose    V1, Python, separate binary, no longer maintained
docker compose    V2 onward, Go, a plugin of the docker CLI
```

**Use the space form in current documentation.** The hyphenated command may not exist on a modern installation, and tutorials that still use it often also carry the obsolete `version:` line.

</details>

</details>

<a id="08--volumes"></a>
<details>
<summary><h1>08 · Volumes</h1></summary>


<a id="a--why-containers-need-them"></a>
<details>
<summary><h2>a · Why containers need them</h2></summary>


> **A volume is a directory on the host that Docker mounts into a container, so the data written there survives the container.**

**A container's filesystem dies with the container.** Remove a database container and every table stored in its writable layer goes with it. That is normally correct behaviour, not a flaw: the whole point of an image is that a container is disposable, and § 04 c explains why.

**Databases and uploaded media are the exception.** They are the one thing that must outlive the process that wrote them.

**A volume solves that by pointing part of the container's filesystem somewhere else.** Writes to that path go through to the host disk instead of into the writable layer:

```
container                        host
/var/lib/data    ───────────────► a real directory on the disk
                                  survives docker rm, survives a rebuild
```

**Nothing inside the container can tell the difference.** The application opens `/var/lib/data` exactly as it would on a normal machine. The redirection happens in the mount namespace, § 02 b, before the process ever sees the path.

</details>

<a id="b--named-volumes-and-bind-mounts"></a>
<details>
<summary><h2>b · Named volumes and bind mounts</h2></summary>


**There are two ways to say "mount something from the host", and Docker treats them differently:**

```yaml
volumes:
  - /srv/app-data:/var/lib/data   ← bind mount
  - app_data:/var/lib/data        ← named volume
```

| | Named volume | Bind mount |
|:--|:--|:--|
| **who chooses the host path** | Docker | you |
| **default location** | `/var/lib/docker/volumes/<name>/_data` | wherever you point it |
| **listed by `docker volume ls`** | yes | no |
| **exists as an object** | yes, with a name and a driver | no, it is only a path |
| **copy-up on first mount** | yes | no |

**A named volume can be inspected to find its Docker-managed location:**

```
$ docker volume create probe_tmp && docker volume inspect probe_tmp
/var/lib/docker/volumes/probe_tmp/_data | driver=local
```

**Copy-up is a key behavioural difference.** Mounting an *empty* named volume over a directory that already contains files in the image copies those files into the volume. A bind mount never does this; it simply hides whatever was underneath.

</details>

<a id="c--custom-host-paths-with-driver_opts"></a>
<details>
<summary><h2>c · Custom host paths with <code>driver_opts</code></h2></summary>


**A named volume normally uses a path chosen by Docker.** When a specific host directory is required, `driver_opts` can pass bind-mount options to the `local` volume driver:

```yaml
volumes:
  app_data:
    driver_opts:
      type: none                  # no filesystem to create; pass through
      o: bind                     # mount it as a bind
      device: /srv/app-data       # host directory to use
```

**It is still a named volume.** `docker volume ls` lists it, `docker volume rm` removes it, and copy-up still applies. Only the location changed.

**The directory must already exist.** `type: none` creates nothing. Otherwise the mount fails:

```
failed to mount local volume:
  mount /srv/does-not-exist:/var/lib/docker/volumes/..._data
  no such file or directory
```

The container never starts, and the directory is still missing afterwards. Create the host directory before running `docker compose up`.

**Use one device per volume.** Two volumes pointing at the same `device` are two Docker names for one host directory, so unrelated application data becomes mixed together.

</details>

</details>

<a id="09--docker-networking"></a>
<details>
<summary><h1>09 · Docker networking</h1></summary>

> **Docker networking determines how containers communicate. Docker can create virtual networks that act like virtual switches. Containers attached to the same network can communicate with each other.**

<br>

```text
             Docker bridge network
              ┌───────────────┐
              │ Virtual switch│
              └───┬────┬────┬─┘
                  │    │    │
                web  API  database
```

<br>

**The three modes:**

```text
BRIDGE
Container ── Docker virtual network ── Other containers
                         │
                         └── Host/NAT ── Internet


HOST
Container ───────────── Host network
        (no separate network isolation)


NONE
Container
   │
   └── No network
```

**A user-defined bridge network also provides DNS.** Containers can reach one another using their service or container names instead of tracking changing IP addresses.

</details>

---

<a id="10--mariadb"></a>
<details>
<summary><h1>10 · MariaDB</h1></summary>


<p align="center"><img src="assets/mariadb_image.png" width="400"></p>
<p align="center"><i>the seal came with the fork · MySQL's dolphin stayed with Oracle</i></p>

<a id="a--what-mariadb-is"></a>
<details>
<summary><h2>a · What MariaDB is</h2></summary>


> **MariaDB is an open-source relational database management system (RDBMS) that stores and manages structured data in tables and provides an SQL interface for accessing and manipulating that data.**

**It does four things:**

- **Stores data in tables**, rows and columns with declared types.
- **Lets applications read and modify that data using SQL**, the query language.
- **Manages accounts, privileges, transactions, indexes and storage.**
- **Runs as a database server** that clients connect to, over a socket or over the network.

```
MariaDB client                    MariaDB server
(mariadb, the CLI)                (mariadbd, the daemon)
     │                                  │
     │────── network / socket ─────────►│
     │                                  │
  sends SQL                         stores data
  receives results                  executes SQL
```

**The last point is the one that matters for Inception.** MariaDB is not a library linked into WordPress. It is a separate long-running process, which is exactly why it gets its own container.

```
wordpress container
  php-fpm + PHP's client library
    │
    │ SQL over TCP, port 3306
    ▼
mariadb container
  mariadbd, the daemon
    │
    ▼
/var/lib/mysql   (files on disk)
```

<br>

<details>
<summary><b>DEEPDIVE</b></summary>

<br>

**The split is blunt: the client transports, the server thinks.**

**A client is any program that speaks MariaDB's client/server protocol.** It is not necessarily the `mariadb` binary:

```
mariadb          the interactive CLI
mariadb-admin    ping, shutdown, status
mariadb-dump     backups
libmariadb       the C library other programs link against
PHP's driver     what WordPress actually uses
```

**MariaDB uses a MySQL-compatible client/server protocol**, which is one reason MySQL clients and MariaDB clients are often interchangeable.

**The client never parses SQL.** It opens the connection, authenticates, wraps the query text in a packet, and reads back whatever the server returns.

```
client                                   server (mariadbd)
  │   open TCP 3306 or unix socket ────► │
  │   ◄──────────── handshake packet     │
  │   authentication packet ───────────► │
  │   ◄──────────── OK                   │
  │                                      │
  │   COM_QUERY "SELECT ..." ──────────► │  parse the SQL
  │                                      │  check privileges
  │                                      │  plan and execute
  │                                      │  read /var/lib/mysql
  │   ◄──────────── result set packets   │
```

**Every packet is binary framed, but the query inside it is plain text:**

```
┌────────────────┬─────────┬──────────────────────────────┐
│ length 3 bytes │ seq 1 B │ payload                      │
└────────────────┴─────────┴──────────────────────────────┘
                             │
                             ├─ 0x03  COM_QUERY
                             └─ "SELECT * FROM wp_posts"
```

| Client | Server |
|:--|:--|
| opens the connection | listens on the socket |
| authenticates | verifies the account and password |
| wraps SQL text in a packet | parses and plans the SQL |
| sends it | checks privileges |
| decodes result packets | reads and writes the files in `/var/lib/mysql` |

**This is why WordPress never runs the `mariadb` binary.** PHP links a connector library that produces the same packets, so `mariadbd` cannot tell whether a query came from the CLI or from a web request.

</details>

<br>

<details>
<summary><b>History: why a fork of MySQL exists</b></summary>

<br>

**MariaDB was created in 2009 as a fork of MySQL by its original developers**, after Oracle acquired MySQL through its purchase of Sun Microsystems.

**The goal was an independent, community-driven alternative** to an Oracle-controlled MySQL, while keeping strong MySQL compatibility.

**That compatibility explains the naming you meet everywhere in this project.** MariaDB kept the wire protocol on port 3306, the SQL syntax, the system table names, and the on-disk paths:

```
/var/lib/mysql          the data directory
/run/mysqld/mysqld.sock the Unix socket
mysql                   the system database
mysql                   the Linux system account
```

**The binaries were renamed in MariaDB 10.5, and the old names survive as symlinks:**

```
/usr/bin/mysql    ──symlink──►  /usr/bin/mariadb      the client
/usr/sbin/mysqld  ──symlink──►  /usr/sbin/mariadbd    the daemon
```

**Prefer the `mariadb` names.** The `mysql` symlinks exist only so that existing scripts keep working.

</details>

</details>

<a id="b--mariadb-the-container"></a>
<details>
<summary><h2>b · MariaDB, the container</h2></summary>


**Three files build this service**, and each answers a different question:

```
Dockerfile              how the image is built
conf/99-inception.cnf   what settings the daemon runs with
tools/entrypoint.sh     what happens on every container start
```

<br>

### The Dockerfile

```dockerfile
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql/*

COPY conf/99-inception.cnf /etc/mysql/mariadb.conf.d/99-inception.cnf
COPY --chmod=755 tools/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

**Everything lives in one `RUN`** for the reason in § 06 c: a deletion in a later layer only hides files, it does not remove their bytes from the image.

**`rm -rf /var/lib/mysql/*` is the line that is easy to miss.** Debian's `mariadb-server` package runs `mariadb-install-db` in its post-install script, so the image ships with an already-initialised data directory. That silently breaks the entrypoint, as explained below.

**`COPY --chmod=755`** sets the executable bit during the copy, replacing a separate `RUN chmod +x` and the extra layer it would create.

<br>

### The configuration file

```ini
[mysqld]
bind-address     = 0.0.0.0
port             = 3306
skip-name-resolve
```

**Only settings whose default is wrong belong here.** Debian ships `bind-address = 127.0.0.1`, meaning the daemon listens only on the loopback interface of its own network namespace, so the wordpress container could never reach it.

**The file is not replacing Debian's, it is overriding it.** `/etc/mysql/mariadb.conf.d/` is read in alphabetical order and, in MariaDB's own words, *"if an option is set multiple times, the later setting will override the earlier setting."*

```
50-server.cnf     bind-address = 127.0.0.1
99-inception.cnf  bind-address = 0.0.0.0     ← read later, wins
```

**Both files are read.** Nothing is skipped. `my_print_defaults mysqld` prints the resulting list in order, showing both values, and the daemon applies the last one.

<br>

### The entrypoint script

```bash
#!/bin/bash

set -e

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

if [ ! -d "/var/lib/mysql/mysql" ]; then
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql

	cat > /tmp/init.sql <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
EOF

	exec mariadbd --user=mysql --init-file=/tmp/init.sql
fi

exec mariadbd --user=mysql
```

**Why a script exists at all.** Pulling `mariadb` from Docker Hub would do all of this for you, and that is exactly what is forbidden:

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> This means you have to build the Docker images of your project yourself. It is then forbidden to pull ready-made Docker images, as well as using services such as DockerHub (Alpine/Debian being excluded from this rule).
>
> <sub><i>the subject</i></sub>

</details>

**So the initialisation has to be written by hand, and it has to happen at run time.** A `RUN` finishes at build time, long before any daemon exists, and the volume mounts over `/var/lib/mysql` only when the container starts. The database, the account and the passwords can only be created then.

**`mkdir -p /run/mysqld`, because there is no init system.** On a real Debian machine `systemd-tmpfiles` recreates that directory at every boot, since `/run` is a tmpfs and no package may ship files there. A container has no systemd, so nothing does it, and `mariadbd` aborts with *"Can't start server : Bind on unix socket"*.

**Two values come from files, two from the environment.** Passwords arrive as Docker secrets mounted at `/run/secrets/`, so they never appear in `docker inspect` or in the image. The database and account names are non-secret and arrive as environment variables from `.env`.

**The guard makes initialisation happen exactly once.** `/var/lib/mysql/mysql` is the system database directory, created by `mariadb-install-db`. Its presence means the volume already holds a working installation, so a restart must not touch it.

<br>

<details>
<summary><b>Two failures that shaped this script</b></summary>

<br>

**1. The guard never fired, and nothing was created.**

The container started, reported `ready for connections`, and looked healthy. But `SHOW DATABASES` had no `wordpress` and there was no `wp_user`.

The Debian package had already run `mariadb-install-db` during `apt-get install`, so `/var/lib/mysql/mysql` existed **inside the image**. The guard was false on the very first boot and skipped everything.

```
apt-get install mariadb-server
      ↓ postinst runs mariadb-install-db at BUILD time
/var/lib/mysql/mysql exists in the image
      ↓
if [ ! -d /var/lib/mysql/mysql ]  → false
      ↓
no database, no account, no root password
```

The fix is `rm -rf /var/lib/mysql/*` in the Dockerfile. It also removes about 113 MB of dead weight, since `ib_logfile0` alone is 100 MB.

<br>

**2. `--bootstrap` cannot create accounts.**

The obvious way to run SQL before the server is listening is bootstrap mode, which reads statements from standard input with no socket and no authentication. `CREATE DATABASE` works there. The other three do not:

```
CREATE DATABASE d1;                             OK
CREATE USER 'u1'@'%' IDENTIFIED BY 'p';         ERROR 1290
GRANT ALL PRIVILEGES ON d1.* TO 'u1'@'%';       ERROR 1290
ALTER USER 'root'@'localhost' IDENTIFIED BY ''; ERROR 1290
```

> ERROR 1290: The MariaDB server is running with the --skip-grant-tables option so it cannot execute this statement

**Bootstrap is not "no privilege checks", it is "no grant tables".** The privilege tables are never loaded, so every account-management statement is refused. That is the opposite of the intuitive reading.

**`--init-file` is the correct tool.** The real daemon starts normally, with grant tables loaded, and executes the file before accepting any connection. MariaDB documents it as *"Name of a file containing SQL statements that will be executed by the server on startup"*, with *"each statement should be on a new line, and end with a semicolon."*

```
mariadbd --init-file=... starts
   ↓ grant tables loaded
   ↓ executes the file
   ↓ opens socket and port
ready for connections
```

</details>

<br>

**The last line is `exec`, and that is not cosmetic.** The script is PID 1. `exec` replaces its process image with `mariadbd` while keeping the same PID, so the daemon becomes PID 1 and receives `SIGTERM` from `docker stop` directly. Without it the script would exit and the container would stop, or bash would linger as PID 1 and swallow the signal.

**There are two `exec` lines and only one ever runs:**

```
first boot                          later boots
datadir empty                       datadir already initialised
   ↓ guard true                        ↓ guard false
mariadb-install-db                  (block skipped)
write init.sql
   ↓
exec mariadbd --init-file=...       exec mariadbd
   ↓                                   ↓
PID 1, runs the SQL, then serves    PID 1, serves
```

</details>

</details>

<a id="11--wordpress"></a>
<details>
<summary><h1>11 · WordPress</h1></summary>


<p align="center"><img src="assets/wordpress_images.png" width="300"></p>
<p align="center"><i>PHP source code, not a server</i></p>

<a id="a--what-wordpress-is"></a>
<details>
<summary><h2>a · What WordPress is</h2></summary>


> **WordPress is open-source content management system (CMS) software, written in PHP, that stores its content in a MySQL or MariaDB database and generates web pages from it on request.**

**WordPress describes itself in one line:** *"built on PHP and MariaDB, and licensed under the GPLv2."* Those two names are not a coincidence for this project. They are the two other containers.

**It does four things:**

- **Stores content in a database**, posts, pages, comments, users, settings.
- **Generates pages on request** by executing PHP that queries that database and returns HTML.
- **Provides an administration interface** at `/wp-admin` for writing and configuring, with no file editing required.
- **Extends itself** through themes, which decide appearance, and plugins, which add behaviour.

<br>

<details>
<summary><b>WordPress is not a server</b></summary>

<br>

**This is the part that trips people up.** MariaDB is a daemon: install it, start it, and something is listening. WordPress is not. It is a directory of PHP source files:

```
wordpress/
├── index.php
├── wp-admin/          the admin interface
├── wp-includes/       the core library
├── wp-content/        themes, plugins, uploads
├── wp-config.php      credentials and settings
└── ... ~2500 files
```

**Files do not execute themselves, and they do not speak HTTP.** Nothing in that directory listens on a port. Everything WordPress cannot do for itself is one of the other two containers, which is the whole architecture:

```
browser
  │  HTTPS 443
  ▼
nginx              terminates TLS, serves .css .js .jpg itself
  │  FastCGI 9000  forwards anything .php
  ▼
php-fpm            executes the WordPress PHP code
  │  SQL 3306
  ▼
mariadb            stores the content
```

**The container named `wordpress` is really php-fpm plus the WordPress files.** The subject spells out the separation, service by service:

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> • A Docker container that contains NGINX with TLSv1.2 or TLSv1.3 only.
>
> • A Docker container that contains WordPress + php-fpm (it must be installed and configured) only, without nginx.
>
> • A Docker container that contains MariaDB only, without nginx.
>
> <sub><i>the subject</i></sub>

</details>

**"Without nginx" appears twice on purpose.** The executor and the web server are two different jobs, so they are two different containers. The same list also fixes nginx as the only way in:

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> Your NGINX container must be the only entrypoint into your infrastructure via the port 443 only, using the TLSv1.2 or TLSv1.3 protocol.
>
> <sub><i>the subject</i></sub>

</details>

</details>

<br>

<details>
<summary><b>Where the state actually lives</b></summary>

<br>

**WordPress state is split across two places, and both must survive a rebuild.**

```
database (12 tables)              filesystem (wp-content/)
├── wp_posts       content        ├── uploads/   media files
├── wp_options     settings       ├── themes/
├── wp_users       accounts       └── plugins/
├── wp_comments
├── wp_terms, wp_postmeta, ...
```

**A default single-site install creates exactly 12 tables**, all prefixed `wp_` by default. Verified by reading `wp-admin/includes/schema.php` in the 7.0.4 tarball:

```
posts  postmeta  comments  commentmeta  users  usermeta
options  terms  termmeta  term_taxonomy  term_relationships  links
```

**Uploaded media is the exception that is easy to forget.** An image you upload is a real file under `wp-content/uploads/`, and only its metadata goes in the database. Restore the database alone and every image is a broken link, which is why the WordPress volume covers the files and the MariaDB volume covers the tables.

</details>

<br>

<details>
<summary><b><code>wp-config.php</code> is where the two halves meet</b></summary>

<br>

**WordPress finds its database through one file.** From the official sample, `wp-config-sample.php`:

```php
define( 'DB_NAME', 'database_name_here' );
define( 'DB_USER', 'username_here' );
define( 'DB_PASSWORD', 'password_here' );
define( 'DB_HOST', 'localhost' );
$table_prefix = 'wp_';
```

**`DB_HOST` is the line that changes for Docker.** On a normal server WordPress and the database share a machine, so `localhost` works. Here they are separate containers, so it becomes the service name `mariadb`, resolved by Docker's internal DNS on the custom network.

**This file is also why the entrypoint cannot be skipped.** It contains a password, so it cannot be baked into the image or committed, and it must be generated at container start from the secrets in `/run/secrets/`.

</details>

<br>

<details>
<summary><b>Versions</b></summary>

<br>

| | Required by WordPress 7.0.4 | What this project has |
|:--|:--|:--|
| **PHP** | 8.3+ recommended, still runs on 7.4+ | 8.2.33, from Debian 12 |
| **Database** | MariaDB 10.11+ or MySQL 8.0+ | MariaDB 10.11.18 |
| **HTTPS** | *"Required for every install."* | nginx, TLSv1.2 and TLSv1.3 |

**Debian 12 ships PHP 8.2, below the recommended 8.3.** That is fine here, WordPress still runs on anything from 7.4 up, and the base image is fixed by the subject anyway. Note that WordPress does not call 7.4 supported: it flags it as end of life and warns it *"may expose your site to security vulnerabilities"*. 8.2 is past that line and still receiving security fixes.

</details>

<br>

<details>
<summary><b>DEEPDIVE: php-fpm and FastCGI</b></summary>

<br>

> **FPM (FastCGI Process Manager) is a primary PHP FastCGI implementation containing some features (mostly) useful for heavy-loaded sites.**
>
> <sub><i>the PHP manual's own definition</i></sub>

**Two separate ideas are bundled in that name.** FastCGI is a protocol. Process manager is what php-fpm adds on top of it.

<br>

**The problem FastCGI solves.** The original mechanism was CGI, and it created one process per request:

```
CGI                                FastCGI
──────────────────────────────     ──────────────────────────────
request arrives                    request arrives
  ↓ fork()                           ↓ (php-fpm already running)
  ↓ exec php                         ↓ send over an open socket
  ↓ start the interpreter            ↓ an idle worker picks it up
  ↓ compile the script               ↓ compile (or hit opcache)
  ↓ run it                           ↓ run it
  ↓ write stdout, exit               ↓ write the response back
process destroyed                  worker stays alive for the next one
```

**The cost being avoided is interpreter startup.** WordPress loads hundreds of PHP files per request. Paying process creation plus interpreter initialisation each time is the difference between a usable site and an unusable one.

**FastCGI is a binary protocol, not HTTP.** nginx does not proxy the HTTP request onward. It translates it into FastCGI records: the request parameters become key/value pairs, and the body and response are streamed as typed records over one connection.

```
nginx                                      php-fpm
  │  FCGI_BEGIN_REQUEST                ──►  │
  │  FCGI_PARAMS  SCRIPT_FILENAME=...  ──►  │  which file to run
  │               REQUEST_METHOD=GET   ──►  │
  │               QUERY_STRING=...     ──►  │
  │  FCGI_STDIN   (POST body)          ──►  │
  │                                         │  executes the PHP
  │  ◄── FCGI_STDOUT  headers + HTML        │
  │  ◄── FCGI_END_REQUEST                   │
```

**`SCRIPT_FILENAME` is the important one.** php-fpm does not receive the PHP code, it receives a **path**. It opens that path on its own filesystem and executes it. So both containers must see the same WordPress files, which is why they share the volume.

<br>

**The process manager half.** php-fpm runs a master process and a pool of workers:

```
php-fpm master        reads config, spawns and reaps workers, holds the socket
├── worker            one request at a time
├── worker
└── worker            pm = dynamic, count adjusts with load
```

**The master never executes PHP.** It supervises. That division is what lets a worker crash on a fatal error without taking the service down, and it is why php-fpm is the process that belongs at PID 1.

**Debian's defaults for both of those do not suit a container.** § 09 b covers what has to change and why.

</details>

<br>

<details>
<summary><b>History: a fork of an abandoned blog script</b></summary>

<br>

**WordPress began in 2003 as a fork of b2/cafelog**, a PHP blogging script whose original developer had stopped maintaining it. Matt Mullenweg and Mike Little forked it and kept it going under the GPL.

**It was a blogging tool for years before it was a CMS.** The vocabulary still shows it: the main content table is `wp_posts`, and pages are stored there too, as posts with a different `post_type`.

**The comparison with MariaDB is worth noticing.** Both projects in this stack exist because of a fork:

```
b2/cafelog  ──abandoned──►  WordPress   (2003)
MySQL       ──acquired──►   MariaDB     (2009)
```

</details>

</details>

<a id="b--the-wordpress-container"></a>
<details>
<summary><h2>b · The WordPress container</h2></summary>


**Three files build this service**, the same split as § 08 b:

```
Dockerfile              how the image is built
conf/www.conf           what settings php-fpm runs with
tools/entrypoint.sh     what happens on every container start
```

<br>

<details>
<summary><b>(overview) The volume nginx and wordpress share</b></summary>

<br>

**§ 09 a has the request path, browser to nginx to php-fpm to mariadb.** The dependency runs one way only: php-fpm binds 9000 and waits whether or not nginx exists, mariadb binds 3306 and waits whether or not wordpress exists. Nothing calls back upward.

**What that diagram leaves out is a filesystem shared between two containers:**

```
              named volume: the WordPress files
              /home/login/data/wordpress
                          │
        ┌─────────────────┴─────────────────┐
        ▼                                   ▼
nginx                              wordpress
/var/www/html                      /var/www/html
reads .css .js .jpg                executes .php
```

**FastCGI does not send code, it sends a path.** nginx forwards the request with `SCRIPT_FILENAME=/var/www/html/index.php`, and php-fpm opens that path on its own filesystem. If the two containers did not mount the same volume, php-fpm would be told to run a file that does not exist on its side. That is why one volume is mounted twice.

</details>

<br>

<details>
<summary><b>(Dockerfile) What the image needs</b></summary>

<br>

**WordPress requires exactly two PHP extensions.** Its own hosting handbook lists `json` and `mysqli` as required, and everything else as highly recommended.

| package | why |
|:--|:--|
| `php8.2-fpm` | the daemon itself, and PID 1 |
| `php8.2-mysql` | provides `mysqli`, there is no database access without it |
| `ca-certificates` | wp-cli downloads over HTTPS and PHP validates against the system CA store |

**`json` is not a package.** It has been compiled into PHP since 8.0, so it is already present.

**`ca-certificates` is the one that gets forgotten**, and without it the build dies on `certificate verify failed` when wp-cli reaches `api.wordpress.org`. Many published Dockerfiles never list it and still work, because they omit `--no-install-recommends` and `libcurl4` carries `Recommends: ca-certificates`. See § 06 c.

</details>

<br>

<details>
<summary><b>(www.conf, Dockerfile) The two Debian defaults that are wrong</b></summary>

<br>

**Debian configures php-fpm for a web server sitting on the same machine.** Both of those assumptions break inside a container.

**1. It listens on a Unix socket.**

```
/etc/php/8.2/fpm/pool.d/www.conf:41
listen = /run/php/php8.2-fpm.sock
```

A Unix socket is a filesystem object. nginx lives in a different mount namespace, so that path simply does not exist for it. `listen = 9000` binds a TCP port instead, which the docker network can route.

> Measured: `listen = 9000` binds `[::]:9000`, not `0.0.0.0:9000`. `/proc/net/tcp` stays empty and the socket shows up in `/proc/net/tcp6`. IPv4 clients still reach it through dual-stack. Write `listen = 0.0.0.0:9000` to make it explicit.

**2. It daemonises.**

```
/etc/php/8.2/fpm/php-fpm.conf:101
;daemonize = yes
```

The line is commented out and the built-in default is `yes`, so php-fpm would fork, the parent would exit, and PID 1 would be gone. `php-fpm8.2 -F` keeps it in the foreground. § 06 e covers why that matters.

**The port is never published to the host.** Only the docker network reaches 9000, which is what keeps nginx the sole entrypoint.

</details>

<br>

<details>
<summary><b>(www.conf) Overriding one line, mariadb-style</b></summary>

<br>

**`pool.d/` behaves like `mariadb.conf.d/` from § 08 b.** Every `*.conf` file in it is included, and two files can declare the same pool name. So instead of replacing the whole shipped `www.conf`, a second file can carry just the one directive that is wrong:

```
www.conf     [www]  user=www-data  group=www-data  pm=dynamic ...  listen=/run/php/...sock
www2.conf    [www]  listen=9000
```

**Measured: declaring `[www]` twice is not an error.** Whichever file loads *last* wins for any directive it repeats, and everything it does not repeat survives from the other file. Same rule as MariaDB's *"if an option is set multiple times, the later setting will override the earlier setting."*

**The `[www]` header is not optional**, even for a one-line file. Without it `listen` belongs to no pool, and php-fpm refuses to start with `unknown entry 'listen'`.

<br>

**"Later" means alphabetically later, and that is easy to get backwards.** The first attempt named the file `www-listen.conf`, expecting it to load after `www.conf`. It loads before it: in ASCII `-` is 0x2D and `.` is 0x2E. The shipped file was then read last, its Unix-socket `listen` won, and the override was silently discarded:

```
$ php-fpm8.2 -tt | grep listen
listen = /run/php/php8.2-fpm.sock     ← the override never took effect
```

**No error anywhere.** `php-fpm -t` reports success and the master starts normally, because nothing is invalid, it just resolves to the wrong value.

**The fix is the filename, not the content.** `www2.conf` sorts after `www.conf` (`2` is 0x32), so it loads second and its `listen = 0.0.0.0:9000` is the one that survives.

</details>

<br>

<details>
<summary><b>(Dockerfile) WordPress core does not come from apt</b></summary>

<br>

**`apt-get install wordpress` is the wrong instinct**, for two reasons. The version is frozen at whatever the release shipped with (`6.1.9+dfsg1-0+deb12u1`), and it drags `apache2` plus `libapache2-mod-php8.2` into a container that already has nginx in front of it.

**Core is source code, not a package.** It comes from `wordpress.org`, or from `wp core download`, which verifies the md5 of the tarball itself.

</details>

<br>

<details>
<summary><b>(Dockerfile, entrypoint.sh) wp-cli</b></summary>

<br>

**wp-cli is a PHP program that loads WordPress core and calls its functions directly.** It ships as a `.phar`, a PHP Archive, which is an entire application packed into one executable file.

**It needs no web server, and that is the property the container depends on.** Nothing is listening while the entrypoint runs, yet `wp core install` can still create the tables and the accounts, because it is executing the same WordPress code a request would have executed.

```
a normal request    browser → nginx → php-fpm → WordPress code → mariadb
wp-cli                                php CLI → WordPress code → mariadb
```

**`--allow-root` is not optional here.** wp-cli refuses UID 0 by default, and the reason is code execution, not file ownership: commands like `wp plugin install --activate` run third-party PHP that inherits wp-cli's privileges. The entrypoint has no other user to run as, so the flag has to be there.

</details>

<br>

<details>
<summary><b>(Dockerfile, entrypoint.sh) Build time and run time</b></summary>

<br>

**"Installing WordPress" is three separate operations, and they do not belong in the same place:**

| operation | needs | when |
|:--|:--|:--|
| `wp core download` | network | build time |
| `wp config create` | the database password | run time |
| `wp core install` | a reachable mariadb | run time |

**The last two are impossible during a build.** Secrets are mounted at `/run/secrets/` only when the container starts, and no database exists while the image is being built.

**Downloading core at build time still reaches the volume**, because of copy-up:

> "If you mount an *empty volume* into a directory in the container in which files or directories exist, these files or directories are propagated (copied) into the volume by default."

**It happens exactly once.** The same page continues: *"If you mount a non-empty volume [...] the pre-existing files are obscured by the mount."* Once `/home/login/data/wordpress` holds anything, rebuilding the image will never refresh it. That is correct behaviour for a CMS, since the volume owns the content, but it is also why the entrypoint still needs a guard of its own.

</details>

<br>

<details>
<summary><b>(entrypoint.sh) What the entrypoint must do</b></summary>

<br>

**Same reasoning as § 08 b.** A `RUN` finishes at build time, while the secrets and the database only exist at run time, so configuration can only happen when the container starts.

1. **Read the passwords from `/run/secrets/`.** They are files, not environment variables, so nothing in `docker inspect` or `/proc/1/environ` reveals them.

**Three secret files, read in two different ways.** The wordpress container needs the database password *and* the two WordPress account passwords, and they are not shaped the same:

| File | Contains | Read with |
|:--|:--|:--|
| `db_password` | one opaque value, no key, no newline meaning | `DB_PASSWORD=$(cat /run/secrets/db_password)` |
| `credentials` | `KEY=value` lines: `ADMIN_PASSWORD`, `USER_PASSWORD` | `source /run/secrets/credentials` |

**`cat` gives a string, `source` defines variables.** `credentials` is not a value, it is a fragment of shell script, so `source` runs it and both variables exist afterwards. That is also why it must contain nothing but assignments: anything else in it executes as root.

**`db_root_password` is not mounted here.** A service sees a secret only if it lists it, so wordpress never receives the root password at all.

2. **Wait for mariadb.** `depends_on` only waits for the mariadb *container* to start, not for `mariadbd` to finish its first-boot setup (`mariadb-install-db`, then the init SQL). Connecting too early fails. A bounded retry that gives up after a set number of attempts is not an infinite loop.

```bash
(exec 3<>/dev/tcp/$DB_HOST/3306) 2>/dev/null
```

**No extra package needed to check it.** Neither `mysql-client` nor `netcat` is installed, and neither has to be. `/dev/tcp/host/port` is a bash built-in redirection target: it opens a real TCP connection, exit code 0 if something is listening. `2>/dev/null` silences the "Connection refused" message without affecting the exit code.

3. **Guard on `wp-config.php`.** Same shape as `[ ! -d /var/lib/mysql/mysql ]`: first boot configures, every later boot must leave existing content alone.

4. **First boot only:** `wp config create`, then `wp core install`, then `wp user create` for the second account.

**Two accounts, and one of them has a naming rule:**

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> In your WordPress database, there must be two users, one of them being the administrator. The administrator's username can't contain admin/Admin or administrator/Administrator (e.g., admin, administrator, Administrator, admin-123, and so forth).
>
> <sub><i>the subject</i></sub>

</details>

**"Contain" is the operative word**, so `admin-123` and `wpadmin` both fail, not only the exact word. `wp core install --admin_user=` creates the first account, `wp user create` the second.

5. **End with `exec "$@"`**, so php-fpm replaces the script and becomes PID 1.

</details>

<br>

<details>
<summary><b>(Dockerfile) Ownership</b></summary>

<br>

**The php-fpm master starts as root and drops its workers to `www-data`:**

```
/etc/php/8.2/fpm/pool.d/www.conf:28
user  = www-data
group = www-data
```

**Those workers are what executes WordPress**, and WordPress writes into `wp-content/uploads`. Anything a `RUN` downloaded is owned by root, so the tree has to be handed over:

```
chown -R www-data:www-data /var/www/html
```

**Skipping it fails silently.** The site loads, because reading is allowed. Uploads, plugin installs and updates are the things that break.

**UID 33 then appears on the host.** As § 06 f says, UIDs cross the boundary unchanged, and copy-up preserves them, so `ls -l /home/login/data/wordpress` shows UID 33 rather than `login`. That is correct, not a bug.

</details>

</details>

</details>

<a id="12--nginx"></a>
<details>
<summary><h1>12 · nginx</h1></summary>


<a id="a--what-nginx-is"></a>
<details>
<summary><h2>a · What nginx is</h2></summary>


> **nginx is a web server: a daemon that listens on a TCP port, speaks HTTP, and answers each request either with a file from disk or with a response produced by another program.**

**A web server exists because a browser cannot read a disk.** The browser only knows how to open a TCP connection and send an HTTP request. Something on the other side has to accept that connection, parse the request, decide what the requested path means, and write an HTTP response back. That is the whole job.

**nginx answers a request in one of two ways.** Either the path maps to a file it can read and send as is, or the path maps to something it cannot produce itself, in which case it forwards the request to a process that can, and relays the answer:

```
GET /style.css   ──►  nginx reads the file           ──►  200 + bytes
GET /index.php   ──►  nginx cannot execute PHP
                      forwards to php-fpm            ──►  200 + generated HTML
```

**The second case is why the WordPress container exists.** As § 09 says, php-fpm executes PHP but does not speak HTTP, and nginx speaks HTTP but cannot execute PHP. Neither is a complete website on its own.

<br>

**In this project nginx has one more job: it is the only door.**

```
browser ──HTTPS 443──► nginx ──┬── static files from the volume
                               │
                               └── FastCGI 9000 ──► wordpress ──► mariadb
```

**Only nginx has a published port.** Everything else is reachable by container name inside the Docker network and by nothing on the host, which is what the subject means by a single entrypoint.

**nginx also terminates TLS.** The encrypted connection ends at nginx: it holds the certificate and the private key, decrypts the request, and everything it forwards afterwards travels as plain traffic inside the private network. WordPress and MariaDB never handle a certificate.

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> A Docker container that contains NGINX with TLSv1.2 or TLSv1.3 only.
>
> Your NGINX container must be the only entrypoint into your infrastructure via the port 443 only, using the TLSv1.2 or TLSv1.3 protocol.
>
> <sub><i>the subject</i></sub>

</details>

</details>

<a id="b--the-configuration-files"></a>
<details>
<summary><h2>b · The configuration files</h2></summary>


**nginx reads exactly one file: `/etc/nginx/nginx.conf`.** Every other file it uses is pulled in because that one names it. There is no directory the daemon scans on its own.

**The file is a tree of contexts.** A context is a block that scopes directives, and a directive is only legal inside certain contexts:

```text
main            user, worker_processes, pid        ← no braces, the file itself
├── events {}   how workers accept connections
└── http {}     everything HTTP
    └── server {}      one virtual host
        └── location {}    one URL path
```

**Settings inherit downward** unless the inner context redefines them. That is why an `ssl_protocols` written once in `http` applies to every `server` block underneath it.

**`include` is textual insertion at the point where it appears**, and the nginx documentation gives its context as `any`. Debian's `nginx.conf` uses it twice, both times *inside* `http`:

```nginx
include /etc/nginx/conf.d/*.conf;
include /etc/nginx/sites-enabled/*;
```

**So an included file may only contain http-level directives**, which in practice means `server` blocks. That is why a site file starts directly with `server {` and never repeats `http {`.

<br>

**`conf.d` and `sites-enabled` are the same thing to nginx.** The split is a Debian packaging convention, not an nginx feature:

```text
sites-available/   every site you have written
sites-enabled/     symlinks to the ones currently active   ← enable = ln -s, disable = rm
conf.d/            fragments that are always on
```

**nginx reads both, in that order, and merges the `server` blocks into one list.** Selection then happens per request: `listen` first, then the `Host` header against `server_name`, with unmatched requests going to that port's default server.

**Two things in the packaged file matter directly here:**

- `ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;` the default permits two protocols the subject forbids. The `server` block must redefine it.
- `include /etc/nginx/sites-enabled/*;` picks up `default`, which owns port 80. Deleting that symlink is what removes it.

**Duplicating a directive in one context is fatal, not a silent override.** Measured on the `nginx` 1.22.1-9+deb12u9 package:

```
"root" directive is duplicate in /etc/nginx/conf.d/a.conf:1
nginx: configuration file /etc/nginx/nginx.conf test failed
```

**That is the opposite of `mariadb.conf.d/` and php-fpm's `pool.d/`**, § 08 b and § 09 b, where the later file quietly wins. Here two `server` blocks coexist and are chosen by address, while two identical directives in one block refuse to start.

</details>


<a id="c--tls-and-the-certificate"></a>
<details>
<summary><h2>c · TLS and the certificate</h2></summary>


**nginx cannot serve HTTPS without two files**, and the image has to produce them itself:

```dockerfile
RUN mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/login.key \
        -out    /etc/nginx/ssl/login.crt \
        -subj "/C=MA/ST=BENGUERIR/L=BENGUERIR/O=4242/OU=42/CN=login.42.fr"
```

<details>
<summary><b>The command, flag by flag</b></summary>

<br>

```text
openssl req
    │
    ├── -x509       → create a self-signed certificate
    ├── -nodes      → don't encrypt the private key
    ├── -newkey     → generate a new private key
    │      └── rsa:2048 → RSA key, 2048 bits
    ├── -days       → certificate validity period
    │      └── 365
    ├── -keyout     → where to save the private key
    ├── -out        → where to save the certificate
    └── -subj       → certificate identity information
```

</details>

> **A certificate is a public key bound to an identity, plus a signature over that binding.**

**The two files are the two halves of one key pair.** `openssl` generates both in a single command:

```text
login.key   the private key    stays in the container, never sent to anyone
login.crt   the certificate    the public key + the identity + a signature, sent to every browser
```

**Normally the signature comes from a certificate authority**, which verifies you control the domain before signing. No authority will ever sign `login.42.fr`, so the key signs its own certificate. RFC 5280 defines that case directly:

> Self-signed certificates are self-issued certificates where the digital signature may be verified by the public key bound into the certificate.

**Which is exactly what the output shows:**

```text
subject = ... CN = login.42.fr
issuer  = ... CN = login.42.fr      ← the same name, nothing above it
```

**The browser warning follows from that, and is expected.** A browser trusts a certificate by walking up the chain to a root it already holds. Here there is no chain, so verification stops immediately with a self-signed error. Clicking through it is the normal demonstration for this project.

<br>

**What each option does:**

| Option | Role |
|:--|:--|
| `req` | the certificate-request subcommand |
| `-x509` | *"outputs a certificate instead of a certificate request"*, so no authority is involved |
| `-nodes` | do not encrypt the private key on disk |
| `-newkey rsa:2048` | generate a fresh 2048-bit RSA key pair in the same command |
| `-days 365` | how long the certificate stays valid. Without it the default is 30 |
| `-keyout` | where the private key is written |
| `-out` | where the certificate is written |
| `-subj` | the identity, supplied inline so the build never stops to prompt |

**`-nodes` is the one that breaks the container if forgotten.** It means *no DES*, do not encrypt the key. An encrypted key makes nginx block at startup waiting for a passphrase that nobody can type into a container. OpenSSL 3.0 renamed it `-noenc` and kept `-nodes` working as a deprecated alias.

**`CN` must be the domain.** It is the only field of `-subj` with a technical role. `C` must be a two-letter country code, and `ST`, `L`, `O`, `OU` are free text that nothing verifies.

**Modern browsers no longer read `CN` for that, though.** They match the URL against the `subjectAltName` extension, and the command above produces a certificate with no `subjectAltName` at all, measured with `openssl x509 -noout -text`. Chrome removed the `CN` fallback in version 58, calling it deprecated by RFC 2818 *"for nearly two decades"*. Adding the extension is one more option:

```
-addext "subjectAltName=DNS:login.42.fr"
```

**It changes nothing about the warning.** The certificate is still self-signed, so the browser still refuses to trust it. The extension only makes the *name* correct, turning two complaints back into one.

**Only the certificate is public.** The private key must stay unreadable to anyone else, which is why `openssl` creates it `0600` by default.

<br>

<details>
<summary><b>DEEPDIVE: what the key pair is actually doing</b></summary>

<br>

**Symmetric encryption needs a shared secret, and that is the problem.** One key encrypts and decrypts, so both sides must already have it. Two machines that have never met cannot agree on one over a wire that an attacker is reading.

**Asymmetric cryptography breaks that deadlock with two mathematically linked keys:**

```text
public key    can be handed to anyone      verifies signatures, encrypts to the owner
private key   never leaves the machine     creates signatures, decrypts
```

**RSA is one such algorithm**, built on the difficulty of factoring the product of two large primes. `rsa:2048` is the size of that product in bits. The public and private key are two different views of the same numbers, and deriving one from the other means factoring a 2048-bit integer.

<br>

**A signature is not encryption.** These are different operations and confusing them is the usual mistake:

```text
encrypt   with the PUBLIC key   →  only the private key can read it       confidentiality
sign      with the PRIVATE key  →  anyone with the public key can check   authenticity
```

**Signing a certificate means:** hash the certificate body, then transform that hash with the private key. Anyone holding the public key can reverse the transform and compare hashes. A match proves the holder of the private key produced it, and that nothing was altered afterwards.

<br>

**The certificate is a structured document, not a blob.** RFC 5280 splits it into three fields:

```text
tbsCertificate      "to be signed": version, serial, issuer, subject,
                     validity (notBefore/notAfter), subjectPublicKeyInfo, extensions
signatureAlgorithm   which algorithm signed it
signatureValue       the signature over the DER encoding of tbsCertificate
```

**`openssl x509 -noout -text` prints exactly those fields**, and every one of them came from either `-subj`, `-days`, or the generated key.

**`.crt` and `.key` are both PEM**, base64 wrapped in header lines, which is why they are readable text:

```text
-----BEGIN CERTIFICATE-----
-----BEGIN PRIVATE KEY-----
```

The extension is convention only. nginx decides what a file is by which directive points at it, `ssl_certificate` or `ssl_certificate_key`.

<br>

**Where the key is used during a connection, and it is not where most explanations put it.** In TLS 1.3 the certificate plays no part in establishing the session key:

> Static RSA and Diffie-Hellman cipher suites have been removed; all public-key based key exchange mechanisms now provide forward secrecy.
>
> <sub><i>RFC 8446, TLS 1.3</i></sub>

**The session key comes from an ephemeral Diffie-Hellman exchange instead**, and the certificate is used only to prove who is on the other end:

```text
1  client and server exchange (EC)DHE key shares
2  both derive the same session key, which never travels the wire
3  server sends its certificate
4  server signs the handshake with its private key   ← CertificateVerify
5  client checks that signature against the public key in the certificate
6  everything after this point is symmetric encryption with the session key
```

**Step 4 is the only place the private key is used.** So the key pair authenticates, and forward secrecy follows: recovering the private key later does not decrypt a recorded session, because the session key was never derived from it.

**In TLS 1.2 that was not true.** The old RSA key-exchange suites had the client encrypt the premaster secret to the certificate's public key, so stealing that key decrypted every past session captured with it. Removing that is one of the main reasons TLS 1.3 exists, and one reason the subject allows only these two versions.

<br>

**Why 2048 and not 4096.** 2048-bit RSA is the current baseline, roughly 112 bits of security, and is what public authorities issue by default. 4096 is slower to generate and slower per handshake for a margin nothing in this project needs. Modern deployments increasingly prefer ECDSA keys, which reach the same strength with far smaller numbers, but RSA is the universally supported choice and the one every reference for this project uses.

</details>

</details>

<a id="d--the-nginx-container"></a>
<details>
<summary><h2>d · The nginx container</h2></summary>


**Two files build this service**, one fewer than the other two, because nothing here needs to happen at run time:

```
Dockerfile           how the image is built, certificate included
conf/default.conf    the one server block
```

**There is no entrypoint script, no secret, and no `.env`.** nginx holds no state, has no first boot to guard, and needs no password. Everything it requires is decided at build time, which is why `ENTRYPOINT` can be the daemon itself.

<br>

<details>
<summary><b>(Dockerfile) Three things, in cache order</b></summary>

<br>

```dockerfile
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx openssl \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/nginx/sites-enabled/default

RUN mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/login.key \
        -out    /etc/nginx/ssl/login.crt \
        -subj "/C=MA/ST=BENGUERIR/L=BENGUERIR/O=4242/OU=42/CN=login.42.fr"

COPY conf/default.conf /etc/nginx/conf.d/

ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

**`openssl` is not in the base image.** Measured on `debian:bookworm`: no `openssl` binary and no such package installed, only the `libssl3` library. It has to be installed alongside nginx.

**`rm /etc/nginx/sites-enabled/default` removes the packaged site**, which owns port 80 as its default server, as § 10 b explains. Deleting one symlink is preferable to editing the packaged `nginx.conf`, and it belongs in the same `RUN` for the whiteout reason in § 06 c.

**The `COPY` comes last on purpose.** `default.conf` is the file that gets edited over and over, and every edit invalidates the cache for everything below it. Placed above the certificate `RUN`, each edit would regenerate a fresh key pair. Whatever changes most often goes last.

**`daemon off;` is what keeps nginx in the foreground**, the same requirement as `php-fpm -F` and a foreground `mariadbd`. § 06 e covers why.

</details>

<br>

<details>
<summary><b>(default.conf) The server block, line by line</b></summary>

<br>

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name login.42.fr;

    ssl_certificate     /etc/nginx/ssl/login.crt;
    ssl_certificate_key /etc/nginx/ssl/login.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /var/www/html/;
    index index.php;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass wordpress:9000;
    }
}
```

**There is no port 80 block at all**, not even a redirect to HTTPS. A redirect would require listening on 80, and the subject allows one open port. What actually closes port 80 is the absence of a `ports:` mapping for it in Compose, not anything written here.

| Directive | Role |
|:--|:--|
| `listen 443 ssl` | accept TLS connections on 443. The second line adds the IPv6 socket |
| `server_name` | the name matched against the request's `Host` header |
| `ssl_certificate` | the `.crt`, the public half sent to the browser |
| `ssl_certificate_key` | the `.key`, which never leaves the container |
| `ssl_protocols` | overrides Debian's `TLSv1 TLSv1.1 TLSv1.2 TLSv1.3` inherited from `http` |
| `root` | the directory paths are resolved against, the shared volume |
| `index` | what to serve when the path is a directory |
| `location ~ \.php$` | a regex location: everything ending in `.php` goes to php-fpm |

**Swapping the two certificate lines is a startup failure, not a warning.** Measured:

```
[emerg] cannot load certificate "/etc/nginx/ssl/s.key":
        PEM_read_bio_X509_AUX() failed ... Expecting: TRUSTED CERTIFICATE
```

**`include snippets/fastcgi-php.conf;` ships with the Debian package**, and it is what supplies the FastCGI parameters § 09 a describes:

```
fastcgi_split_path_info ^(.+?\.php)(/.*)$;
try_files $fastcgi_script_name =404;
fastcgi_param PATH_INFO $path_info;
fastcgi_index index.php;
include fastcgi.conf;
```

**That last line is the important one.** `fastcgi.conf` sets `SCRIPT_FILENAME` to `$document_root$fastcgi_script_name`, the path php-fpm opens on its own filesystem. Without it php-fpm receives no filename and returns a blank page. `try_files ... =404` is a small security measure: a request for a `.php` file that does not exist is refused here rather than passed to php-fpm.

</details>

<br>

<details>
<summary><b>(docker-compose.yml) The service, and the two keys only nginx has</b></summary>

<br>

```yaml
nginx:
  image: nginx:1.0
  build: ./requirements/nginx
  networks: [inception]
  restart: unless-stopped
  ports: ["443:443"]
  depends_on: [wordpress]
  volumes:
    - wordpress_volume:/var/www/html
```

**`ports:` appears exactly once in the whole file.** That single mapping is what makes nginx the only entrypoint. mariadb's 3306 and php-fpm's 9000 are bound inside their own network namespaces and reachable only from the `inception` network.

**The volume is mounted a second time here**, the same named volume wordpress uses. § 09 b explains why: FastCGI sends a path, not code, so both containers must see the same files at the same path.

**`depends_on` is not optional for nginx**, and the reason is different from wordpress's. nginx resolves `fastcgi_pass wordpress:9000` while parsing its configuration, at startup, not per request. If the wordpress container does not exist yet, the name does not resolve and nginx refuses to start:

```
[emerg] host not found in upstream "wordpress" in /etc/nginx/conf.d/default.conf:25
nginx: configuration file /etc/nginx/nginx.conf test failed
```

**So the chain is mariadb, then wordpress, then nginx.** For wordpress `depends_on` is only ordering, since the entrypoint still has to wait for `mariadbd` to finish initialising. For nginx it is the difference between starting and crash-looping on a cold `up`.

</details>

<br>

<details>
<summary><b>The domain name, and why /etc/hosts is involved</b></summary>

<br>

**The subject fixes the name the site answers to:**

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> To make things simpler, you have to configure your domain name so it points to your local IP address. This domain name must be login.42.fr.
>
> <sub><i>the subject</i></sub>

</details>

**No DNS server anywhere knows `login.42.fr`.** `/etc/hosts` is a plain name-to-address table the resolver consults before asking DNS, so one line is enough:

```
127.0.0.1   login.42.fr
```

**`127.0.0.1` is loopback, meaning this machine.** The request therefore never leaves the host:

```
browser asks for login.42.fr
   │ /etc/hosts answers 127.0.0.1
   ▼
this machine, port 443        ← published by ports: ["443:443"]
   ▼
nginx container
```

**The name has to match the certificate's `CN`.** Reaching the same server through `https://localhost` connects fine but adds a second browser warning, because the certificate says `login.42.fr` and the URL does not.

</details>

</details>


</details>

<a id="13--the-makefile"></a>
<details>
<summary><h1>13 · The Makefile</h1></summary>


> **The Makefile is the only thing you need to Run. Everything else is reached through it.**

**The subject fixes the chain in one direction:**

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> A Makefile is also required and must be located at the root of your directory. It must set up your entire application (i.e., it has to build the Docker images using docker-compose.yml).
>
> You also have to write your own Dockerfiles, one per service. The Dockerfiles must be called in your docker-compose.yml by your Makefile.
>
> <sub><i>the subject</i></sub>

</details>

**So `make` calls Compose, and Compose calls the Dockerfiles.** Nothing is built by hand, and no `docker build` is ever typed.

<br>

**There is one thing Compose cannot do for itself, and it is the reason `up` has a prerequisite.** As § 11 c shows, `type: none` creates no directory: if `/home/login/data/mariadb` is missing, the volume fails to mount and the container never starts. The Makefile has to create both directories first.

```make
COMPOSE		= docker compose -f srcs/docker-compose.yml
DATA_DIR	= /home/login/data
VOLUMES		= $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

all: up

$(VOLUMES):
	mkdir -p $@

up: $(VOLUMES)
	$(COMPOSE) up -d --build
```

**`$(VOLUMES)` is a real target, not a phony one.** Each name is a directory on disk, so `make` runs `mkdir -p` only when the directory is missing and skips it otherwise. `$@` expands to whichever one is being built.

<br>

**`clean` and `fclean` must be different, and mixing them destroys the database:**

```
down     stop and remove the containers and the network
clean    the above, plus the images this project built  (--rmi local)
fclean   the above, plus the volumes and the host data  (down -v)
```

**`docker compose down` keeps volumes. `down -v` deletes them.** So `clean` can be run freely, while `fclean` is the one that wipes WordPress and starts the stack from nothing.

**`fclean` is also the only place `sudo` is justified.** The files under `data/` were written by the container processes after they dropped privileges, so they are owned by UID 999 (`mysql`) and UID 33 (`www-data`), as § 06 f explains. Your own account cannot delete them.

**No `sudo` anywhere else.** Being in the `docker` group is already enough to reach the socket, and `sudo mkdir` would create the data directories owned by root.

</details>

<a id="14--bonus"></a>
<details>
<summary><h1>14 · Bonus</h1></summary>


> **The bonus part is five extra services, each one an additional container built from its own Dockerfile.**

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> The bonus part will only be assessed if the mandatory part is completed perfectly. Perfect means the mandatory part has been fully completed and functions without any malfunctions.
>
> <sub><i>the subject</i></sub>

</details>

**Each bonus service is worth one point, and each one follows the same pattern already used three times:** a directory under `srcs/requirements/`, one Dockerfile on the same Debian base, a real foreground daemon as PID 1, a service in `docker-compose.yml` on the `inception` network, and a named volume only if it has state to keep.

```text
srcs/requirements/
├── mariadb/        mandatory
├── wordpress/      mandatory
├── nginx/          mandatory
└── bonus/
    ├── static/
    ├── adminer/
    └── redis/
```

**The order below is my build order, easiest first, not the order the subject lists them in.**

| Container | Time | What makes it that |
|:--|:--|:--|
| **static site** | 30 to 60 min | one nginx, or any non-PHP server, on its own port. A few HTML and CSS files, no state, no secrets |
| **adminer** | 1 to 2 h | one PHP file to download, and the php-fpm knowledge from § 09 reused as is. The only new decision is whether it gets its own nginx or a `location` in the existing one |
| **redis** | 2 to 3 h | `redis-server` in the foreground is trivial. The work is on the WordPress side, installing and configuring the object cache plugin so it actually connects |
| **free choice** | varies | cheapest is a small monitoring or exporter service. Whatever it is, it has to be justified in one sentence at the defense |

<br>


<a id="a--a-static-website"></a>
<details>
<summary><h2>a · A static website</h2></summary>


> **A static website is a site whose files are sent to the browser exactly as they are stored on disk, with no code executed on the server.**

**The server does one thing: map a URL to a file and send it.** No interpreter runs, no database is queried, nothing is generated per request. This is the opposite of WordPress, where every `.php` request is handed to php-fpm, which executes code and builds the page.

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> Create a simple static website in the language of your choice except PHP (yes, PHP is excluded). For example, a showcase site or a site for presenting your resume.
>
> <sub><i>the subject</i></sub>

</details>

**The exclusion of PHP is the whole constraint.** HTML and CSS satisfy it, and JavaScript does too, because JavaScript runs in the visitor's browser and not in the container. Nothing in this container executes anything.

<br>

**So the container is the smallest one in the project:** nginx, a configuration file, and the files themselves.

```text
srcs/requirements/bonus/resume/
├── Dockerfile
├── conf/
│   └── default.conf
└── srcs/
    ├── index.html
    └── style.css
```

**No volume, no secret, no environment variable, no `depends_on`.** The site has no state to keep and talks to nothing, so the files are baked into the image with `COPY` rather than mounted. Rebuilding the image is how the site is updated.

<br>


<details>
<summary><b>The Dockerfile</b></summary>

<br>

```dockerfile
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/nginx/sites-enabled/default

COPY conf/default.conf /etc/nginx/conf.d/

COPY ./srcs/ /var/www/static

ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
```

**`rm /etc/nginx/sites-enabled/default` is not optional here either.** The Debian package ships a `server` block that claims port 80 as `default_server` with `root /var/www/html`, and `nginx.conf` includes it alongside `conf.d/`. Left in place, it either collides with my own block, or wins and serves the welcome page:

```text
nginx: [emerg] a duplicate default server for 0.0.0.0:80
```

**Every line of a multi-line `RUN` ends with `\` except the last one.** Getting this wrong is silent in one direction and fatal in the other:

| Mistake | What actually happens |
|:--|:--|
| `\` left on the last line | the next instruction is swallowed into the `RUN`, so `rm -rf /var/lib/apt/lists/* COPY conf/default.conf /etc/nginx/conf.d/` runs and deletes `conf.d/`. BuildKit only warns: `NoEmptyContinuation` |
| `\` missing on a middle line | the next line starts with `&&`, which is not an instruction: `unknown instruction: &&` |

**`COPY ./srcs/ /var/www/static` copies the directory, not a glob.** Writing `COPY ./srcs/* /var/www/static` looks equivalent and is not: the shell-style glob expands to each entry, and the contents of each subdirectory are copied into the destination, flattening the tree. Measured:

```text
srcs/index.html        ->  /var/www/static/index.html
srcs/css/style.css     ->  /var/www/static/style.css     the css/ directory is gone
```

Every `<link href="css/style.css">` would then return 404.

</details>


<details>
<summary><b>The server block</b></summary>

<br>

```nginx
server {
	listen 4242;
	listen [::]:4242;

	server_name login.resume.42.fr;

	root /var/www/static/;

	index index.html;
}
```

**`root` is the mapping, and it is the only thing nginx needs to serve a file.** The path opened for a request is `root` plus the request URI, so `GET /style.css` reads `/var/www/static/style.css`. nginx has a compiled-in default of `root html;`, relative to the prefix, which is why an untouched nginx serves a welcome page at all.

**`index` is separate from `root`.** It only decides which file answers a URI ending in `/`, so `GET /` becomes `/var/www/static/index.html`.

**`server_name` is decorative in this container.** It selects between competing `server` blocks listening on the same address and port, and this container has exactly one block, so every request lands here whatever the `Host` header says. For the name to work in a browser it also has to resolve, which means a line on the host:

```text
127.0.0.1       login.42.fr login.resume.42.fr
```

**No `try_files` is needed.** The static file module already returns 404 when the file is missing. `try_files $uri $uri/ =404;` makes that explicit and matters once there are rewrites, which there are none of here.

</details>


<details>
<summary><b>The Compose service</b></summary>

<br>

```yaml
  resume:
    image: resume:1.0
    build: ./requirements/bonus/resume
    networks: [inception]
    restart: unless-stopped
    ports: ["4242:4242"]
```

**Port 80 inside the container would have been fine too.** Each container has its own network namespace, so it has its own set of port numbers: the resume container's port 80 and the mandatory nginx's port 80 are two different things and cannot collide.

**What must not be taken is host port 80.** The subject makes nginx the only entrypoint on 443, so an open port 80 on the host reads as a second, plain HTTP entrypoint into the infrastructure. Publishing `4242:4242` keeps the mandatory rule intact and still reaches the site.

</details>

</details>

---


<a id="b--adminer"></a>
<details>
<summary><h2>b · Adminer</h2></summary>


> **Adminer is a database administration tool that ships as a single PHP file: it connects to a database server and exposes it as a web interface.**

**It exists to replace a terminal client.** Instead of `mariadb -u wp_user -p` and typing SQL, the browser shows the databases, the tables, the rows, and lets them be edited. For this project it is a way to inspect the WordPress database.

**Adminer is PHP, and that decides the architecture of the container.** PHP is not a server: something has to receive the HTTP request, and something has to execute the code. Those are two different programs, exactly as in § 09:

```text
browser --HTTP--> web server --FastCGI--> php-fpm --> adminer.php --> mariadb
```

**One container cannot run both**, because a container runs a single foreground daemon as PID 1. So the Adminer container runs php-fpm only, and the web server in front of it is the mandatory nginx, which gains one `location`:

```nginx
location /adminer/ {
    fastcgi_pass adminer:9000;
}
```

**The consequence to think about is `SCRIPT_FILENAME`.** nginx does not open the PHP file, it sends a path to php-fpm, and php-fpm opens that path inside *its own* filesystem. So the path has to be correct in the Adminer container, not in nginx.

**Implementation to be written.**

</details>

---


<a id="c--redis-cache"></a>
<details>
<summary><h2>c · redis cache</h2></summary>


> **Redis is an in-memory key value data store: a server process that keeps data in RAM, addresses it by string keys, and answers over TCP on port 6379.**

**It exists because RAM is orders of magnitude faster than a database query.** A SQL query has to be parsed, planned, executed against indexes, and read from disk or from the database's own buffer pool. A Redis lookup is a hash table read in a process that never touches the disk. Anything expensive to compute and cheap to lose belongs in front of the database, not in it.

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> Set up redis cache for your WordPress website in order to properly manage the cache.
>
> <sub><i>the subject</i></sub>

</details>

**WordPress is exactly the workload this helps.** A single page load issues dozens of queries for the same rows: the site options, the active theme, the post objects, the user meta. With Redis in front, WordPress asks Redis first and only falls back to MariaDB on a miss, storing the answer for the next request.

```text
without redis                     with redis
wordpress                         wordpress
   │ SQL, every request              │ GET key
   ▼                                 ▼            miss only
mariadb                            redis ──────────────> mariadb
```

<br>

**Two distinctions matter more than the commands.**

**Redis is not a manager of the cache, it is the cache.** The server holds the values and executes `GET`, `SET`, and expiry. What to store, under which key, for how long, and when to fall back to MariaDB is decided by the WordPress side, not by Redis.

**MariaDB is the source of truth, Redis is a copy.** Losing the entire Redis dataset costs a slower next page load and nothing else. That is why this container gets no volume, while mariadb cannot work without one.

**Redis and MariaDB never talk to each other.** There is no replication and no connection between the two containers. WordPress is the only link, and consistency exists only because WordPress overwrites or deletes the cached key when it updates the row.

```text
wordpress ──> redis      (fast copy)
    └───────> mariadb    (source of truth)
```

<br>


<details>
<summary><b>DEEPDIVE · the concepts behind the cache</b></summary>

<br>

**A key value store is the simplest database model there is.** There are no tables, no columns, no schema, and no joins. There is one flat namespace of keys, each holding one value, and the only questions the server can answer are "what is at this key" and "put this at this key".

```text
relational                        key value
┌───────────────────────┐         ┌──────────────────────────────────┐
│ wp_options            │         │ wordpress:options:alloptions  -> │
│  option_id  name  val │         │ wordpress:posts:42            -> │
│  1  siteurl  ...      │         │ wordpress:users:1             -> │
└───────────────────────┘         └──────────────────────────────────┘
 query planner, indexes,           hash table lookup
 joins, disk pages
```

**The value is a byte string as far as the cache is concerned.** WordPress serialises a PHP array or object into a string, stores it, and unserialises it on the way back. Redis itself also has richer types, lists, hashes, sets, sorted sets, but the object cache only needs strings.

<br>

**In memory is the whole point, and the whole risk.** The dataset lives in the process address space, so a restart of the container loses it. Redis can persist to disk, and understanding the two mechanisms is worth it even though this project uses neither:

| Mechanism | What it does |
|:--|:--|
| **RDB** | writes a point in time snapshot of the whole dataset to a file, every N seconds or on demand |
| **AOF** | appends every write command to a log file, replayed at startup to rebuild the dataset |

**Neither is wanted here.** Persistence would mean a volume, disk writes on every cached value, and a cache that outlives the database it mirrors. A cold cache after a restart is the correct behaviour: WordPress simply queries MariaDB and refills it.

<br>

**Keys can expire, and expiry is what keeps a cache from becoming stale.** A key set with a TTL is deleted automatically once the time is up, so cached data has a lifetime instead of living forever.

```text
SET key value EX 300      the key disappears 300 seconds later
TTL key                   how many seconds remain
```

**Redis does not scan the whole keyspace looking for expired keys.** It removes them lazily, when a key is accessed and found to be expired, and also samples random keys periodically in the background. The effect is that expired keys stop being visible immediately, while the memory they used is reclaimed slightly later.

<br>

**Eviction is different from expiry, and this is the distinction people get wrong.** Expiry is a deadline the writer chose. Eviction is what the server does when it runs out of the memory it was allowed, regardless of any deadline.

```text
maxmemory           the limit. Default 0, meaning no limit on 64 bit systems
maxmemory-policy    what to delete when the limit is reached
```

**With the default policy, `noeviction`, nothing is deleted and writes start failing with an error while reads keep working.** That is the right default for a data store and the wrong one for a cache, where the usual choice is:

```text
maxmemory 256mb
maxmemory-policy allkeys-lru
```

**`allkeys-lru` evicts the least recently used key**, which is the sensible default when a small subset of the data is read far more often than the rest. The `volatile-*` policies only consider keys that carry a TTL, and behave like `noeviction` when no key has one. Redis approximates LRU by sampling a handful of random keys rather than maintaining an exact ordering, because exact LRU costs more memory than it saves.

<br>

**On the WordPress side, the object cache is the mechanism being replaced.** WordPress already has one, `WP_Object_Cache`, and it is non persistent: it holds values in PHP memory for the duration of a single request and throws them away when the request ends. Two requests for the same page each query MariaDB from scratch.

**A drop-in replaces it.** A file named `object-cache.php` placed in `wp-content/` is loaded by WordPress instead of the built in class, and every `wp_cache_get()` and `wp_cache_set()` call then goes to Redis. Plugin code does not change, because plugins call those functions rather than the class.

```text
wp_cache_get( 'alloptions', 'options' )
        │
        ▼
wp-content/object-cache.php        the drop in
        │
        ▼
redis:6379
```

**Transients follow automatically.** Without a persistent object cache, `set_transient()` writes to the `wp_options` table, which means the "cache" is another row in the database. With one installed, transients use the `wp_cache_*` functions instead, so they land in Redis.

<br>

**Version note.** Debian 12 Bookworm packages `redis-server` 5:7.0.15-1~deb12u9, measured with `apt-cache policy` in a throwaway `debian:bookworm` container. The eviction policies above are documented for Redis 7 and later.

<br>

Sources:
* https://redis.io/docs/latest/develop/reference/eviction/
* https://developer.wordpress.org/reference/classes/wp_object_cache/
* https://developer.wordpress.org/apis/transients/

</details>


<details>
<summary><b>The redis container</b></summary>

<br>

```dockerfile
FROM debian:bookworm

RUN apt-get update \
    && apt-get install --no-install-recommends -y redis-server redis-tools \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "redis-server", "--protected-mode", "no", \
             "--maxmemory", "256mb", "--maxmemory-policy", "allkeys-lru" ]
```

**This is the smallest container in the project and it has no configuration file at all.** That is deliberate, and it works because of one detail: `redis-server` reads `/etc/redis/redis.conf` **only when the path is given as its first argument**. No argument is given, so the packaged file is ignored and the server starts from its built-in defaults, which every command line flag then overrides.

**That matters, because Debian's packaged file is hostile to containers.** Measured inside a throwaway `debian:bookworm` with `redis-server` installed:

| Packaged setting | What it would do here |
|:--|:--|
| `daemonize yes` | PID 1 would fork and the parent exit, so the container stops immediately |
| `bind 127.0.0.1 -::1` | only loopback inside its own network namespace, so wordpress could never connect |
| `protected-mode yes` | refuses connections from outside loopback when no password is set |

**`--protected-mode no` is safe here only because of the network.** Redis has no password and would be wide open, but the service publishes no port, so it exists only on the `inception` network and nothing outside Docker can reach it. Publishing `6379` would put an unauthenticated database on the host.

**The two memory flags are the answer to "how do you manage the cache".** Built-in defaults are `maxmemory 0`, no limit, and `noeviction`, which means writes start failing once RAM fills instead of old keys being dropped. A ceiling plus `allkeys-lru` is the behaviour a cache is supposed to have.

**`redis-tools` is not needed to run the server.** It provides `redis-cli`, which is how the cache is inspected during a defense:

```text
redis-cli DBSIZE            how many keys are cached
redis-cli INFO stats        keyspace_hits and keyspace_misses
redis-cli CONFIG GET maxmemory-policy
```

</details>


<details>
<summary><b>The WordPress side</b></summary>

<br>

**Redis alone changes nothing.** WordPress has to be told to use it, and that takes one package in the image and three commands at first boot.

**The package is the PHP extension**, `php8.2-redis`, version 5.3.7+4.3.0-3 in Debian 12. It is the C extension that lets PHP speak RESP. Without it the drop-in loads and immediately fails, because PHP has no `Redis` class.

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
	php8.2-fpm \
	php8.2-mysql \
	php8.2-redis \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*
```

**The three commands live in the entrypoint, inside the first boot guard:**

```bash
	wp plugin install redis-cache --activate --allow-root
	wp config set WP_REDIS_HOST redis --allow-root
	wp redis enable --allow-root
```

**Their position in the script is not a detail, it is the whole thing.** Three rules, each learned by breaking it:

| Rule | What happens otherwise |
|:--|:--|
| after `wp core install` | the database has no tables yet, so every command that loads WordPress fails with `Error: The site you have requested is not installed.` |
| inside the `if [ ! -f wp-config.php ]` guard | the plugin is reinstalled over the network on every restart, and one failure turns into a crash loop through `restart: unless-stopped` |
| `--allow-root` on each | wp-cli refuses: `YIKES! It looks like you're running this as root.` |

**`wp redis enable` is the command that actually does the work.** It writes `wp-content/object-cache.php`, the drop-in. Installing and activating the plugin without it leaves WordPress querying MariaDB for everything.

**`WP_REDIS_PORT` is not set** because the plugin defaults to 6379.

**Verified on a cold boot**, from an empty `/home/login/data`:

```text
Status: Connected
Client: PhpRedis (v5.3.7)
Drop-in: Valid
DBSIZE 49                        keys present after two page loads
keyspace_hits 96 / misses 90
```

</details>


<details>
<summary><b>The Compose service</b></summary>

<br>

```yaml
  redis:
    image: redis:1.0
    build: ./requirements/bonus/redis
    networks: [inception]
    restart: unless-stopped
```

**Four lines, and the absences are the interesting part.** No `ports`, because only nginx is an entrypoint and WordPress reaches Redis by service name on the internal network. No `volumes`, because the dataset is a losable copy. No `env_file` and no `secrets`, because there is nothing to configure and no password.

**`wordpress` gains the dependency**, since its first boot now calls `wp redis enable`, which fails if Redis is unreachable:

```yaml
    depends_on: [mariadb, redis]
```

**`depends_on` waits for the container to start, not for the server to be ready.** Redis is listening in well under the time WordPress spends waiting for MariaDB, so no extra wait loop is needed for it.

</details>


<details>
<summary><b>DEEPDIVE · how Redis actually works, and where it came from</b></summary>

<br>

**Redis was written to solve a write rate problem, not a read cache problem.** In 2008 and 2009 Salvatore Sanfilippo, antirez, was running LLOOGG, a real time web analytics service, and MySQL could not keep up with the rate at which page views had to be recorded and re-read. His conclusion was that the working set belonged in memory, and that the database should expose data structures rather than tables.

**Version 0.1 was sent on 10 February 2009 and understood three commands: `set`, `get`, `del`.** The second tarball, around 25 February, coincided with the first public post on Hacker News, with the whole codebase still under 3700 lines of C including comments. The event loop was borrowed from Jim Tcl and reimagined as a command interpreter, which is why the architecture below has been stable for fifteen years: it was there in the first month.

**What it solved, stated plainly:** a data store where an operation costs a hash lookup and a memory write instead of a query plan and a disk seek, and where the client can ask for a list, a set, or a counter instead of assembling one out of rows.

<br>

**The server is a single threaded event loop, and that is a design decision rather than a limitation.**

```text
        ┌──────────────────────────────────────────────┐
        │              one thread, one loop            │
        │                                              │
   epoll_wait ──> which sockets are readable?          │
        │                                              │
        ├──> read bytes from a client socket           │
        ├──> parse RESP into a command + arguments     │
        ├──> execute it: hash table lookup, write      │
        ├──> append the reply to the client's buffer   │
        └──> write buffers back to sockets, repeat     │
        └──────────────────────────────────────────────┘
```

**Measured in the project's own container:**

```text
redis_version:7.0.15
multiplexing_api:epoll
io_threads_active:0
process_id:1
```

**`epoll` is the kernel mechanism that makes one thread enough.** Instead of one thread blocking per connection, the process registers thousands of sockets with the kernel and asks a single question: which of these are ready now. The loop then does a tiny amount of work per ready socket.

**Why not threads?** Because the work per command is measured in microseconds and is dominated by memory access, so locking would cost more than it saves. One thread also means commands are executed one at a time, in arrival order, which is why Redis needs no concurrency control: atomicity is a property of the architecture, not a feature bolted on. Redis 6 added `io-threads` for reading and writing sockets only, never for executing commands, and it is off by default, which the measurement above confirms.

<br>

**RESP, the Redis Serialization Protocol, is what travels on TCP port 6379.** It is deliberately human readable, and every part is terminated by `\r\n`.

**A client always sends an array of bulk strings**, the command name first, then its arguments:

```text
C: *2\r\n$4\r\nLLEN\r\n$6\r\nmylist\r\n
S: :48293\r\n
```

**The first byte of a reply identifies its type**, which is what makes the parser trivial:

| Byte | Type | Example |
|:--|:--|:--|
| `+` | simple string | `+OK\r\n` |
| `-` | error | `-ERR unknown command 'asdf'\r\n` |
| `:` | integer | `:1000\r\n` |
| `$` | bulk string, length prefixed | `$5\r\nhello\r\n`, and `$-1\r\n` for a missing key |
| `*` | array | `*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n` |

**Length prefixes are the reason it parses as fast as a binary protocol.** Nothing has to be scanned for delimiters or unescaped: read the number, then read exactly that many bytes.

**Redis also accepts inline commands**, space separated and newline terminated, precisely so that a bare `telnet` or a bash `/dev/tcp` redirection can talk to it. No command starts with `*`, so the server can tell the two forms apart.

<br>

**Inside, the keyspace is a hash table.** Every key of a database lives in one dictionary mapping the key string to a value object, and a second dictionary holds the expiration timestamps of the keys that have one.

```text
db->dict      "wp:options:alloptions" -> value object
db->expires   "wp:options:alloptions" -> unix time in ms
```

**Growing that hash table cannot be allowed to block the loop**, so rehashing is incremental: a new larger table is allocated and buckets are migrated a few at a time, on every subsequent operation, while lookups check both tables. A resize of a dataset with millions of keys therefore never produces a pause.

**Expiration is not a timer per key either.** A key is removed lazily, when something touches it and finds it expired, and a background cycle also samples random keys from `db->expires` and deletes the expired ones. The visible behaviour is exact, an expired key is never returned, while the memory is reclaimed slightly later.

<br>

**Everything above explains the one number that matters for this project:** a `GET` from WordPress costs a socket read, a RESP parse, one hash lookup, and a socket write, with no disk in the path at all. The equivalent `SELECT` against MariaDB costs parsing, planning, index traversal, and potentially a page read. That gap is what the cache buys, and it is also why losing the cache costs nothing but time.

<br>

Sources:
* https://redis.io/docs/latest/develop/reference/protocol-spec/
* https://github.com/antirez/historical-redis-versions
* https://redis.io/docs/latest/operate/oss_and_stack/management/optimization/latency/
* https://redis.io/docs/latest/commands/info/

</details>

</details>

---


<a id="d--the-service-of-my-choice"></a>
<details>
<summary><h2>d · The service of my choice</h2></summary>


> **netdata is a monitoring agent: it reads system metrics straight out of the kernel and serves them as a live dashboard, with no configuration, no agent to install elsewhere, and no external database.**

<details>
<summary><b>Proof from the subject</b></summary>

<br>

> Set up a service of your choice that you think is useful. During the defense, you will have to justify your choice.
>
> <sub><i>the subject</i></sub>

</details>

**Justification for the defense, in one sentence:** the whole stack is invisible once it is running, because `docker ps` says `Up` and nothing else, so netdata answers the question that actually matters when something is slow, which is what the machine is doing with its CPU, memory, disk, and network right now.

<br>

**Metrics do not live in any container's filesystem, they live in the kernel**, exposed through `/proc` and `/sys`. The surprise, covered below, is that a container can already read them without being given anything special, which is why this ends up being the simplest service in the project.

```dockerfile
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends netdata \
    && rm -rf /var/lib/apt/lists/*

COPY conf/netdata.conf /etc/netdata/netdata.conf

ENTRYPOINT [ "netdata", "-D" ]
```

```yaml
  netdata:
    image: netdata:1.0
    build: ./requirements/bonus/netdata
    networks: [inception]
    ports: ["19999:19999"]
    restart: unless-stopped
```

**`-D` keeps it in the foreground**, for the same reason every other daemon in this project needs a flag like it: without it netdata forks, the parent exits, and PID 1 is gone.

<br>

**Five lines, and no mounts at all.** netdata's own documentation asks for the host's `/proc` and `/sys` to be bind mounted in, plus `NETDATA_HOST_PREFIX=/host` to redirect its reads there. This container does neither, because measuring showed that on a normal Docker host it changes nothing.

<br>


<details>
<summary><b>Measured: why this container needs no mounts</b></summary>

<br>

**This started as an assumption, that the mounts plus the prefix are what make host wide metrics possible.** Testing it showed otherwise. Three variants of the same image, each given twelve seconds to settle, then asked for its chart list:

```text
no mounts, no prefix     charts=257   battery=7   sda=5
mounts, NO prefix        charts=257   battery=7   sda=5
mounts + prefix          charts=257   battery=7   sda=5
```

**Identical.** The container charts the host's disk `sda` and the laptop battery `BAT0` even with no mounts and no environment variable at all.

**The reason is that a container is far less isolated from the kernel's reporting interfaces than the word "namespace" suggests.** Docker gives every container a read only bind of the host's `sysfs`, so `/sys/class/power_supply` is already there. And most of `/proc` is not namespaced at all: the PID namespace changes which `/proc/<pid>` directories are listed, but `/proc/stat`, `/proc/meminfo`, and `/proc/uptime` still report the whole machine, because those files describe the kernel and there is only one kernel.

```text
namespaced          /proc/<pid>, /proc/net, the process list
NOT namespaced      /proc/stat, /proc/meminfo, /proc/uptime, /proc/cpuinfo
```

**The wider lesson is worth more than the setting.** A container is isolated in what it can *change*, far more than in what it can *see*.

</details>


<details>
<summary><b>Bug · overriding one setting silently dropped another</b></summary>

<br>

**netdata's default web port, 19999, is unreachable from outside the container by design.** The Debian package ships this, with the reasoning written next to it:

```ini
[global]
	bind socket to IP = 127.0.0.1
	# Netdata is not designed to be exposed to potentially hostile
	# networks. See https://github.com/netdata/netdata/issues/164
```

**Binding to `127.0.0.1` means the kernel only delivers packets that arrived on loopback**, the interface reachable only from inside that same network namespace. A published port maps to the container's real interface, `eth0`, never to its loopback, so a process bound to `127.0.0.1` cannot be reached through `ports:` no matter what is published. `0.0.0.0` is the wildcard meaning every interface, which is what makes a published port actually answer.

**So the fix was one line:**

```ini
[web]
    bind to = 0.0.0.0
```

**Writing only that line broke the container completely**, because `COPY` replaces the whole file rather than merging into it. `run as user = netdata`, which lived under `[global]` in the packaged file, disappeared with it. `strace` on the process showed the consequence exactly:

```text
setgid(65534)                               nogroup
setuid(65534)                               nobody, not netdata (999)
mkdir("/var/lib/netdata/registry", 0770) = -1 EACCES
```

**With no explicit `run as user`, netdata's internal fallback is `nobody`**, uid 65534, which owns nothing under `/var/lib/netdata`. The daemon wrote a clean `FATAL` line and exited.

**Two things made that failure hard to see.** netdata writes that line to `/var/log/netdata/error.log` and not to stdout, so `docker logs` showed only cheerful startup messages, and `restart: unless-stopped` kept recreating the container underneath every attempt to look inside it.

**The working config restores both settings**, which is the general lesson: a file that replaces a packaged file has to carry every value it does not intend to change, not only the one it does.

```ini
[global]
    run as user = netdata

[web]
    bind to = 0.0.0.0
```

</details>


<details>
<summary><b>Scope decision · per container graphs were attempted and dropped</b></summary>

<br>

**netdata can also break metrics down per container**, one CPU chart for wordpress, another for mariadb, by reading cgroups and asking the Docker daemon for the names behind them. Getting that working needed considerably more than the dashboard itself:

```yaml
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    pid: host
```

**Plus an entrypoint script**, because the socket is owned by `root` and a group that the `netdata` user does not belong to, so the container had to look up that group at runtime and join it. Plus `curl` in the image, because netdata's container naming script shells out to it. Even with all of that in place, the per container charts never appeared.

**It was removed rather than pursued**, for three reasons worth being able to say out loud:

| Reason | |
|:--|:--|
| the subject does not ask for it | it asks for a useful service, justified at the defense, and host wide monitoring is already that |
| the cost is real isolation | `pid: host` and the Docker socket would have been the two heaviest privileges in the whole Compose file, for a cosmetic gain |
| every extra moving part is a thing that can break during a defense | an entrypoint, a runtime group lookup, and an extra package, all to add graphs nobody asked for |

**One false alarm from that attempt is worth keeping**, because it will happen again to anyone who adds `pid: host` to a container:

```bash
docker exec srcs-netdata-1 cat /proc/1/comm
# systemd
```

**That looked like the entrypoint had failed. It had not.** `pid: host` shares the host's entire PID namespace, so `/proc/1` inside the container becomes the host's real init process. The PID 1 check that is correct for every other container in this project silently stops meaning anything the moment that setting is added, and the check that still works is to ask Docker what it considers the main process:

```bash
docker inspect srcs-netdata-1 --format '{{.Path}} {{.Args}}'
# netdata [-D]
```

**With `pid: host` gone, `/proc/1/comm` reports `netdata` again**, and the same check now works uniformly across all seven containers.

</details>

<br>

**Verified on a cold boot**, from an empty `/home/login/data` with every image rebuilt:

```text
resume 200   wordpress 200   wp-admin 302   adminer 200   netdata 200
restarts: 0 on all seven containers

PID 1:  mariadbd, php-fpm8.2, nginx, nginx, php-fpm8.2, redis-server, netdata
```

<br>


<details>
<summary><b>DEEPDIVE · how netdata sees what it sees</b></summary>

<br>

**A process only knows what its own namespaces show it.** A container's `/proc` is not a copy of the host's, it is a view the kernel generates that lists only the processes inside that container's PID namespace, and the interfaces it shows are the ones in its own network namespace. That isolation is the entire point of a container, as § 02 covers, and it is precisely what a monitoring agent has to be given a way around, because a monitor that can only see itself is useless.

<br>

**`/proc` and `/sys` are not files on disk, they are interfaces the kernel exposes at runtime.** Reading `/proc/stat` does not read bytes that someone wrote earlier, it asks the scheduler for the counters it is maintaining right now and gets them formatted as text on the spot. `/sys` does the same for devices: every block device, network interface, thermal sensor, and battery has a directory there, generated live.

```text
cat /proc/meminfo                              kernel formats memory accounting on every read
cat /sys/class/net/eth0/statistics/rx_bytes    counter maintained by the network driver
cat /sys/class/power_supply/BAT0/capacity      value read from the battery controller
```

**Reading them from inside a container is therefore not reading a copy.** Every read still reaches the kernel and returns what is true at that instant, which is why no data is ever duplicated or stale, and why a container that can open these paths at all sees the real machine behind them.

<br>

**The two privileges that were tried and removed are worth understanding anyway**, because they come up constantly in real infrastructure and both are commonly pasted into Compose files without a second thought.

**`/var/run/docker.sock` is not a filesystem, it is the Docker daemon's API.** Anything that can write to that socket can send the daemon the same HTTP requests the `docker` command sends: list containers, read their stats, and also create containers, mount any host path into them, and run them as root. Mounting it `:ro` does not make the API read only, it only makes the socket file itself read only inside the container, and a socket is written by sending on it, not by writing the file. So `:ro` on a Docker socket buys close to nothing. This is why removing it mattered more than the graphs it would have enabled: it is effectively root on the host, handed to one container.

**`pid: host` shares exactly one namespace, and only one.** Namespaces are independent of each other, so sharing the PID namespace does not share the network namespace, which is why netdata still needed `bind to = 0.0.0.0` even while `pid: host` was set. What it changes is that `/proc/<pid>` inside the container enumerates the host's real processes under the host's real PIDs, which is what would let a monitor attribute CPU to the right process instead of seeing only its own.

<br>

**Once collected, metrics never reach a database.** netdata's per second samples live in a fixed size ring buffer in RAM, `dbengine`, which is why the first thing it logs on every start is how much space that buffer may use:

```text
MAIN : Found 0 legacy dbengines, setting multidb diskspace to 256MB
```

**No volume is declared for this container, and that follows from the ring buffer rather than being an oversight.** Old samples are overwritten as new ones arrive, so losing the writable layer on a restart costs a few hours of history and nothing structural. It is the same reasoning as the redis container in § c: both hold data that is a disposable copy, neither is a source of truth, so neither gets a volume.

<br>

**What this container costs the infrastructure, stated plainly for the defense:** one published port, and nothing else. No mount, no shared namespace, no capability beyond the default set, no access to the Docker daemon. What it sees, it sees because Docker gives every container that much already. It can see the machine. It cannot touch it.

</details>

</details>

</details>

</details>

https://mlops-for-all.github.io/en/docs/prerequisites/docker/
