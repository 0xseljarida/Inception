<h1 align="center">Inception · Notes</h1>

<p align="center"><img src="assets/containers_kernel.png" alt="Container ship labeled Linux kernel" width="600"></p>

Since “you have to know the past to understand the present”, I included the history behind these technologies (containers, Docker, MariaDB...). Reading it is optional, but it will help you make sense of things and make them suckless.

## Index

<details>
<summary><a href="#01--why-containers">01 · Why Containers?</a></summary>

* a · Container vs Virtual Machine

</details>

<details>
<summary><a href="#02--what-is-a-container">02 · What is a container?</a></summary>

* a · History
* b · Namespaces, what it sees
* c · Where namespaces actually live
* d · cgroups, what it uses
* e · Conclusion

</details>

<div>&emsp;<a href="#03--what-docker-is">03 · What is Docker?</a></div>
<br>

<details>
<summary><a href="#04--docker-image">04 · Docker image</a></summary>

* a · Docker images vs. containers
* b · Image layers

</details>

<details>
<summary><a href="#05--docker-architecture">05 · Docker architecture (client ↔ daemon)</a></summary>

* a · The client side
* b · The server side

</details>

<details>
<summary><a href="#06--dockerfile">06 · Dockerfile</a></summary>

* a · Instructions and layers
* b · FROM
* c · RUN
* d · COPY and the build context
* e · CMD, ENTRYPOINT and PID 1
* f · Users and privileges inside a container

</details>

<details>
<summary><a href="#07--volumes">07 · Volumes</a></summary>

* a · Why containers need them
* b · Named volumes and bind mounts
* c · Custom host paths with driver_opts

</details>

<div>&emsp;<a href="#08--docker-networking">08 · Docker networking</a></div>
<br>

<details>
<summary><a href="#09--docker-compose">09 · Docker Compose</a></summary>

* a · Why Compose?
* b · YAML
* c · How to write a Compose file
* d · Important keys
* e · Essential commands

</details>

<details>
<summary><a href="#10--mariadb">10 · MariaDB</a></summary>

* a · History
* b · MariaDB deep dive
* c · MariaDB, the container

</details>

<details>
<summary><a href="#11--wordpress">11 · WordPress</a></summary>

* a · History
* b · WordPress deep dive
* c · The WordPress container

</details>

<details>
<summary><a href="#12--nginx">12 · nginx</a></summary>

* a · TLS and the certificate
* b · The nginx container

</details>

---

<a id="01--why-containers"></a>
<details>
<summary><h1>01 · Why Containers?</h1></summary>

**Imagine one server hosting websites for 200 customers. Each customer needs their website isolated from everyone else's.**

<p align="center"><img src="assets/hosting-isolation-comparison.png" alt="200 machines, 200 processes, 200 VMs, and containers compared" width="900"></p>

Three options existed:

| | Cost |
|:--|:--|
| **200 machines** | absurd |
| **200 processes on one machine** | no isolation. They read each other's files, one crash starves all |
| **200 VMs** | works, but 200 full operating systems: GBs of RAM, minutes to boot, all running the same Linux |

**The VM wastes everything.** The customer needs an isolated *website*, not an isolated *computer*.

> **Can one machine host many isolated tenants without pretending to be 200 machines?**

> **Containerization makes this possible.** Keep one operating system and use some kernel features to **isolate and control what each process can see and use**. The result is what we call a **container**, which is essentially an isolated process.

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

**Isolation is the tradeoff:** containers share a kernel, so a kernel vulnerability can break their isolation.


</details>

</details>

<a id="02--what-is-a-container"></a>
<details>
<summary><h1>02 · What is a container?</h1></summary>


<p align="center"><img src="assets/image_linux_peng.jpeg" width="500"></p>
<p align="center"><i>the container is a Linux mechanism · Docker only makes it easy to use</i></p>

> **A container is a Linux process running in an isolated environment, where the kernel restricts and controls what the process can see and access.**

Containerization is an operating-system-level virtualization technique that isolates processes and their view of system resources while allowing them to share the host's kernel.

**No virtual machine boots. No OS is emulated.** Run `ps` on the host and you find an ordinary process among your others: same kernel, same scheduler.

<details>
<summary><b>VISUAL · Many containers, one kernel</b></summary>

<br>

<p align="center"><img src="assets/containers_kernel.png" width="700"></p>
<p align="center"><i>many containers · one shared kernel</i></p>

</details>

**So what makes it a container?** Only **what that process is allowed to perceive and consume**. The kernel gives it a restricted view of the machine, and every system call it makes is answered from that view.

**Two kernel features enforce this:**

| Feature        | Controls                   | Purpose         |
| :------------- | :------------------------- | :-------------- |
| **Namespaces** | what a process can **see** | isolation       |
| **cgroups**    | what a process can **use** | resource limits |


<a id="a--history"></a>
<details>
<summary><h2>a · History</h2></summary>


People started talking about Linux containers in the mid-2000s, when Google created process containers in 2006 (later renamed cgroups and merged into the Linux kernel), followed by the release of LXC (Linux Containers) in 2008.

**None of this was invented in 2013.** The mechanism was already solved and in production:

```
1979  chroot              isolate a filesystem
2000  FreeBSD Jails       isolate filesystem + processes + users + one IP
2004  Solaris Containers  the word ships in a product
2006  cgroups             Google adds resource limits to Linux
2008  LXC                 first container manager using only mainline kernel features
2013  Docker              initially used LXC; introduced its own libcontainer on 10 March 2014 (v0.9)
```

<details>
<summary><b>LXC DEEPDIVE</b></summary>

	
### LXC

Linux Containers (LXC) is an operating system-level virtualization method for running multiple isolated Linux systems (containers) on a control host using a single Linux kernel.

From [linuxcontainers.org](https://linuxcontainers.org/):

> Our focus is providing containers and virtual machines that run full Linux systems. While VMs supply a complete environment, system containers offer an environment as close as possible to the one you'd get from a VM, but without the overhead that comes with running a separate kernel and simulating all the hardware.

The Linux kernel provides the cgroups functionality that allows limitation and prioritization of resources (CPU, memory, block I/O, network, etc.) without the need for starting any virtual machines, and also the namespace isolation functionality that allows complete isolation of an application's view of the operating environment, including process trees, networking, user IDs and mounted file systems.[3]

LXC combines the kernel's cgroups and support for isolated namespaces to provide an isolated environment for applications.[4]

Early versions of Docker used LXC as the container execution driver,[4] though LXC was replaced as the default in version 0.9.0[5][6] and was deprecated in 1.8.0,[7] before the driver was removed in 1.10.0.[8]

[Wikipedia: LXC](https://en.wikipedia.org/wiki/LXC)

[Docker: LXC vs. Docker](https://www.docker.com/blog/lxc-vs-docker/)

[good docker vid](https://www.youtube.com/watch?v=Uur3gqmAE6g&list=PLIbkvnlX0hoQ)
</details>

</details>

<a id="b--namespaces-what-it-sees"></a>
<details>
<summary><h2>b · Namespaces, what it sees</h2></summary>

> **A namespace is a Linux kernel mechanism that gives a group of processes an isolated view of a system resource, such as process IDs or network interfaces.**

Processes in the same namespace share that view. Separate namespaces let containers have different process IDs, mounts, and networks while sharing the same kernel.

| Namespace | What it isolates |
|:--|:--|
| `pid` | Process IDs and which processes are visible |
| `net` | Network interfaces, IPs, routes, firewall rules, and ports |
| `mnt` | Mount points |
| `user` | User and group IDs |
| `uts` | Hostname and NIS domain name |
| `ipc` | Shared memory, message queues, and semaphores |
| `cgroup` | View of the cgroup hierarchy |
| `time` | Offsets for monotonic and boot-time clocks |

For example, one process can have two PIDs:

```text
Inside container          On host
PID 1: sleep 300     =     PID 50862: sleep 300
```

**Same process, different views.** The host can see it; the container's PID namespace hides host processes from it.

Two containers with separate **network namespaces** can also listen on port `9000` without colliding.

</details>

<a id="c--where-namespaces-actually-live"></a>
<details>
<summary><h2>c · Where namespaces actually live</h2></summary>


The kernel tracks each task (a process or thread) in a `task_struct`. Its **`nsproxy` pointer** leads to most of its namespace references.

<p align="center"><img src="assets/task_struct-nsproxy.png" width="520"></p>
<p align="center"><i>Linux kernel source · <a href="https://github.com/torvalds/linux/blob/master/include/linux/sched.h"><code>include/linux/sched.h</code></a></i></p>

**Notice the comment above `nsproxy`: `/* Namespaces: */`.** This is the Linux kernel's own code, check the link above.

The `nsproxy` structure holds pointers to namespace objects:

<p align="center"><img src="assets/struct-nsproxy.png" width="560"></p>
<p align="center"><i>Linux kernel source · <a href="https://github.com/torvalds/linux/blob/master/include/linux/nsproxy.h"><code>include/linux/nsproxy.h</code></a></i></p>

**Processes in the same namespace share the same kernel namespace object.**

The **user namespace** is referenced through `cred` (the task's credentials), rather than `nsproxy`:

```text
task_struct ──> nsproxy ──> uts, ipc, mnt, net, time, cgroup, ...
            ──> cred    ──> user_ns
```

<details>
<summary><b>DEEPDIVE</b></summary>

**PID namespaces.** The field is `pid_ns_for_children`, not the process's own PID namespace. A process's own PID namespace stays fixed throughout its lifetime, so `nsproxy` holds the one future children will use. The comment above the struct explains that the task's own is accessed through `task_active_pid_ns()`.

**Sharing.** The comment also explains how tasks share `nsproxy`:

> "The nsproxy is shared by tasks which share all namespaces. As soon as a single namespace is cloned or unshared, the nsproxy is copied."

Copying `nsproxy` does not copy every namespace object. Its pointers can still refer to namespaces shared with other tasks.

**User namespaces.** There is no `user_ns` field in `nsproxy`. It lives in `struct cred`, alongside the task's user IDs, group IDs, and capabilities.

</details>

</details>

<a id="d--cgroups-what-it-uses"></a>
<details>
<summary><h2>d · cgroups, what it uses</h2></summary>

If you've used a VM, you probably remember choosing its CPU count and RAM. **cgroups give containers similar resource controls, enforced by the host kernel.**

<p align="center"><img src="assets/vm-cpu-settings.png" alt="Virtual machine settings showing the number of virtual CPUs" width="628"></p>

The VM setting chooses a virtual CPU count; a cgroup CPU quota limits how much CPU time processes can use.

**Namespaces hide things but restrain nothing.** A process that only sees its own filesystem can still eat every byte of RAM on the machine, exactly the hosting problem from section 01.

**Control groups put a hard ceiling on consumption:** memory, CPU time, disk bandwidth, process count.

```bash
--memory=64m     may use 64 MB, no more
--cpus=0.5       gets half a core's worth of time
```

**Docker doesn't enforce this.** It writes a number to a file, and the **kernel** does the policing, including killing the process if it overruns.

> ⚠️ A container capped at 64 MB still reports the host's full 15 GB when asked how much memory the machine has. The reported value comes from the host, the enforced limit is the cgroup's.

> 💡 **Fun fact:** Google added cgroups to the Linux kernel. Check [history](#a--history).


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
<summary><h1>03 · What is Docker?</h1></summary>


At this point, **Linux** already gives us everything required to isolate a process. What is missing is a convenient, repeatable way to build, share, and run that isolated environment.

That is where Docker fits:

> **Docker is a platform that makes containers easy to build, share, and run in a repeatable way.** That's it, it's just a tool!

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


<a id="docker-history"></a>
<details>
<summary><h2>History</h2></summary>

**Docker did not invent the container.** It arrived 34 years after `chroot` and 5 years after LXC (Linux Containers).

**LXC could already run a container**, but you still had to assemble its filesystem by hand, choose the namespaces, wire the network, then repeat all of it on every machine. There was no way to hand someone a finished environment.

Docker's founder, **Solomon Hykes**, first demonstrated it at PyCon on 15 March 2013, in a short talk titled [“The future of Linux Containers”](https://www.youtube.com/watch?v=362sHaO5eGU). His team at dotCloud (a platform-as-a-service company) already used Linux containers, but the tools were complicated and difficult for other developers to adopt. As Docker gained popularity, it became the company's main focus, and dotCloud renamed itself Docker Inc. in October 2013.

Check out [this one-minute bit about Docker's history](https://www.youtube.com/watch?v=GVVtR_hrdKI&t=966s). Just one minute, you TikTok-brained scroller. You can do this.

</details>

</details>

<a id="04--docker-image"></a>
<details>
<summary><h1>04 · Docker image</h1></summary>

> **A container image is a standardized package that includes all of the files, binaries, libraries and configurations to run a container.**
>
> <sub><i><a href="https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-an-image/">Docker's own definition</a></i></sub>

For example, an **nginx image** packages the nginx executable, its libraries, configuration files, and default startup command. Docker uses that package to create containers, so nginx does not need to be installed on the host.

- **Immutable:** its contents stay fixed. Updating the packaged software means building a new image.
- **Layered:** you can start from an existing image and add your application's files and dependencies.

The image provides userspace files; the container uses the **host kernel**.

<p align="center"><img src="assets/docker-image-versions.png" alt="A Dockerfile used to build separate image versions: v1, v2, and v3" width="700"></p>
<p align="center"><i>each version is a separate image</i></p>

<a id="a--docker-images-vs-containers"></a>
<details>
<summary><h2>a · Docker images vs. containers</h2></summary>


> **An image is a package. A container is an instance created from it.**

If you know classes and objects, think of the **image as a class** and each **container as an object created from it**. One image can create many containers, each with its own writable layer and state.

<p align="center"><img src="assets/docker-image-vs-container.webp" alt="Dockerfile built into an image, then used to run a container" width="700"></p>

| Image | Container |
|:--|:--|
| Read-only | Adds its own writable layer |
| Reusable across containers | Has its own data and state |
| No running processes | Can be running or stopped |

**`docker run` creates a container from an image and starts its process.** You can create several containers from the same image; changes in one container's writable layer leave the image and the other containers' writable layers unchanged.

</details>

<a id="b--image-layers"></a>
<details>
<summary><h2>b · Image layers</h2></summary>


An image is a stack of **read-only layers**. Each layer records files added, changed, or deleted during a build.

<p align="center"><img src="assets/docker-image-layers.png" alt="Read-only image layers beneath a container's writable layer, combined into one filesystem" width="800"></p>

Each container adds its own **writable layer**. A **union filesystem**, such as OverlayFS, combines the layers into the single `/` its processes see.

Containers can share image layers. Removing a container deletes its writable layer; use [volumes](#07--volumes) to keep data.

See § 06 a for how Dockerfile instructions create layers and how the build cache reuses them.

<details>
<summary><b>DEEPDIVE</b></summary>

With **OverlayFS**:

- **Read:** use the topmost visible version of a file.
- **Change:** on the first write to an image file, copy it into the writable layer, then modify the copy. This is **copy-on-write**.
- **Delete:** hide an image file from that container. It remains in the read-only image layer.

[Docker: OverlayFS](https://docs.docker.com/engine/storage/drivers/overlayfs-driver/)

</details>

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

<p align="center"><img src="assets/docker_archi.png" width="900"></p>
<p align="center"><i>the client sends commands to the daemon, which manages local objects and communicates with registries</i></p>

**Docker Engine is the complete client-server system:**

- **`docker`**: the CLI client.
- **Engine API**: the interface used to communicate with the daemon.
- **`dockerd`**: the daemon that manages containers, images, networks, and volumes.

Part **a** explains the client and API. Part **b** explains the server side: `dockerd`, `containerd`, the shim, and `runc`.

<a id="a--the-client-side"></a>
<details>
<summary><h2>a · The client side</h2></summary>


**The Docker CLI is the command-line client for Docker Engine.** It translates commands into HTTP requests, sends them to `dockerd`, and formats the response.

For example, `docker ps` sends `GET /containers/json`. The daemon returns the container list, which the CLI displays as a table.

```text
docker ps ──► Docker Engine API ──► dockerd ──► response ──► CLI formats table
```

On Linux, requests normally travel through `/var/run/docker.sock`. **HTTP describes the messages; the Unix socket carries them locally.**

[Docker: Engine API](https://docs.docker.com/reference/api/engine/)

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

The daemon returns the same server information that appears in `docker version`.

**Contexts** select which daemon the CLI connects to. The CLI reads the selected context and client configuration to find its connection settings.

**API-version negotiation** selects a version supported by both client and daemon, allowing different Engine releases to communicate.

**The socket is therefore a security boundary, not an ordinary file:**

```
srw-rw---- 1 root docker  /var/run/docker.sock
```

With the usual rootful Docker daemon, anyone in the `docker` group can request privileged containers or mount the host filesystem. Access to that group therefore grants root-level privileges on the machine.

**Rootless Docker changes this model** by running both the daemon and containers without root privileges. A remote daemon requires the same caution: use SSH or TLS rather than exposing an unauthenticated TCP socket.

</details>


</details>

<a id="b--the-server-side"></a>
<details>
<summary><h2>b · The server side</h2></summary>

**`dockerd` does not create container processes directly.** It coordinates the operation and delegates the low-level work.

1. **`dockerd` handles Docker-level features.** It receives API requests and decides which images, networks, volumes, ports, and container settings are required.

2. **`containerd` manages the container lifecycle.** It prepares images and filesystems, then coordinates creating, starting, stopping, and deleting containers.

3. **`containerd-shim` connects containerd to the runtime.** It invokes the runtime and remains available to supervise the container process, preserve its I/O, and report its exit status.

4. **`runc` creates the isolated process.** It applies the OCI configuration (namespaces, cgroups, mounts, and capabilities), starts the process, and then exits.

<p align="center"><img src="assets/docker_use_containerd.png" width="574"></p>
<p align="center"><i>a simplified container-creation path</i></p>

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

The CLI first sends Docker API requests such as `POST /containers/create` and `POST /containers/{id}/start`. `dockerd` translates Docker concepts (image names, published ports, networks, mounts, environment variables, and restart policies) into the configuration needed by the lower layers.

On a typical Linux installation, `dockerd` reaches containerd's gRPC API through a Unix socket. containerd then communicates with the runtime shim over ttrpc. These are API relationships, not necessarily parent-child relationships between the processes.

<br>

### 2. Creation and execution are separate operations

containerd stores the container metadata and prepares a filesystem snapshot from the image. Starting the container is a separate step: containerd asks `containerd-shim-runc-v2` to create a task, and the shim invokes `runc` with an OCI bundle.

That bundle contains two important things:

- a root filesystem for the process
- an OCI configuration describing its command, namespaces, cgroups, mounts, capabilities, and other runtime settings

`runc` asks the Linux kernel to apply that configuration and starts the requested command. The result is an ordinary Linux process, not a daemon maintained by `runc`.

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

> **A Dockerfile is a plain-text recipe for building an image.** It describes the base image, software, files, and default startup command. Docker uses **BuildKit** as its builder.

<p align="center"><img src="assets/docker_file_to_image_to_container.png" width="700"></p>
<p align="center"><i>a Dockerfile is built into an image · an image is run as a container</i></p>

```dockerfile
FROM debian:bookworm
RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*
COPY nginx.conf /etc/nginx/conf.d/
CMD ["nginx", "-g", "daemon off;"]
```

With `nginx.conf` beside the Dockerfile, build the image with:

```bash
docker build -t my-nginx .
```

**Common Dockerfile instructions:**

| Instruction | Role |
|:--|:--|
| `FROM` | Starts a build stage from a base image |
| `RUN` | Runs a command during the build |
| `COPY` | Copies files into the image |
| `ADD` | Copies files, with archive extraction and remote-source support |
| `WORKDIR` | Sets the working directory; creates it if missing |
| `ENV` | Sets default environment variables for the image |
| `ARG` | Defines a build-time variable |
| `USER` | Selects the user for later build commands and container startup |
| `EXPOSE` | Documents a port the application uses |
| `VOLUME` | Declares a volume mount point |
| `LABEL` | Adds image metadata |
| `ENTRYPOINT` | Sets the startup executable |
| `CMD` | Sets the default command or arguments |

**`EXPOSE` does not publish a port.** Use `docker run -p` or Compose's `ports:` to map it to the host.

**Build arguments are unsuitable for secrets:** their values can appear in image history or metadata. Use [build secret mounts](https://docs.docker.com/build/building/secrets/) instead.

[Docker — Dockerfile reference](https://docs.docker.com/reference/dockerfile/)

<a id="a--instructions-and-layers"></a>
<details>
<summary><h2>a · Instructions and layers</h2></summary>

**`FROM` reuses the base image's existing layers.** Build steps such as `RUN`, `COPY`, and `ADD` record filesystem changes in new layers. `CMD`, `ENTRYPOINT`, and `ENV` set image configuration.

The example above adds nginx and its configuration on top of Debian's layers. `CMD` records what to run when a container starts. The total layer count depends on the base image and filesystem changes; it is not the number of instructions. See § 04 b.

**The build cache reuses unchanged steps.** When an instruction or its inputs change, steps that depend on it need rebuilding. Put stable dependency installation before frequently edited application files.

</details>

<a id="b--from"></a>
<details>
<summary><h2>b · FROM</h2></summary>

**`FROM` selects the base image and starts a build stage:**

```dockerfile
FROM debian:bookworm
```

`ARG` declarations can appear before the first `FROM` to parameterize it.

A release tag such as `bookworm` makes the intended base explicit. Tags can still change; pin an image digest when you need the exact same base contents.

</details>

<a id="c--run"></a>
<details>
<summary><h2>c · RUN</h2></summary>

**`RUN` executes a command while building the image.** For Debian packages, update, install, and clean up in the same instruction:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*
```

Keeping `update` and `install` together avoids reusing stale package lists when the install command changes. Cleaning up in the same `RUN` keeps those lists out of the resulting layer.

**Deleting files in a later layer only hides them.** The earlier layer still contains their bytes.

<details>
<summary><b>DEEPDIVE · apt options</b></summary>

**`--no-install-recommends` skips recommended packages.** Install any your application needs explicitly. For example, this project's WordPress image installs `ca-certificates` for HTTPS connections.

APT normally leaves `Suggests` packages uninstalled; this flag changes how it treats `Recommends`.

To disable recommended packages for later apt installs throughout an image:

```dockerfile
RUN echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/99norecommends
```

Related Hadolint checks: [DL3015 — skip extra packages](https://github.com/hadolint/hadolint/wiki/DL3015) and [DL3009 — remove package lists](https://github.com/hadolint/hadolint/wiki/DL3009).

[Docker — RUN best practices](https://docs.docker.com/build/building/best-practices/#run)

</details>

</details>

<a id="d--copy-and-the-build-context"></a>
<details>
<summary><h2>d · COPY and the build context</h2></summary>

**The build context is the set of files available to the builder.** Here, `.` selects the current directory:

```bash
docker build -t my-nginx .
```

Plain `COPY` reads from that context. It cannot reach files outside it using `../`:

```dockerfile
COPY nginx.conf /etc/nginx/conf.d/
```

**`.dockerignore` excludes files from the context:**

```text
.git
*.md
secrets/
```

BuildKit loads files as needed and can skip unused files. Excluding private or irrelevant files keeps them out of reach of build instructions such as `COPY .`.

Use **`COPY`** for ordinary file copying. **`ADD`** also supports extracting local tar archives and fetching remote sources.

[Docker — Build context](https://docs.docker.com/build/concepts/context/)

</details>

<a id="e--cmd-entrypoint-and-pid-1"></a>
<details>
<summary><h2>e · CMD, ENTRYPOINT and PID 1</h2></summary>

**`ENTRYPOINT` selects the startup executable. `CMD` supplies default arguments**, or the default command when no `ENTRYPOINT` is set.

```dockerfile
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
```

Together, these run `nginx -g "daemon off;"` when the container starts.

**Prefer exec form**, as above, so the service starts directly without an extra shell. Docker sends stop signals to **PID 1**; a shell wrapper may not forward them to the service. If an entrypoint script launches the service, finish it with `exec "$@"` to replace the shell.

**Keep the service in the foreground.** The container stops when its main process exits. A placeholder such as `sleep infinity` hides whether the actual service is still running.

Install dependencies in the **Dockerfile**. Use an **entrypoint script** for configuration that needs runtime variables or secrets, and for initializing mounted data. Guard initialization so a restart preserves existing data.

</details>

<a id="f--users-and-privileges-inside-a-container"></a>
<details>
<summary><h2>f · Users and privileges inside a container</h2></summary>

**`USER` selects the account for later `RUN` steps and the container's startup command.** The base image may already set it; otherwise the default is UID 0, root.

```dockerfile
USER www-data
```

Choose an existing account with the permissions the application needs. `docker run --user` or Compose's `user:` can override the image's default.

Install packages as root before switching users. Build steps already running as root do not need `sudo`.

**File ownership follows numeric UIDs and GIDs.** With rootful Docker and no user-namespace remapping, a file written as UID 999 also appears as UID 999 on a mounted host directory. Match directory permissions to the service's actual IDs.

<details>
<summary><b>DEEPDIVE · Container privileges</b></summary>

With rootful Docker and no user-namespace remapping, UID 0 inside maps to UID 0 on the host. Namespaces, reduced capabilities, seccomp, and security profiles restrict what the process can do. Rootless Docker and user-namespace remapping change the UID mapping.

Linux divides root's privileges into **capabilities**. Examples from Docker's default sets:

| Granted by default | Not granted by default |
|:--|:--|
| `CHOWN` `SETUID` `SETGID` `KILL` `NET_BIND_SERVICE` `NET_RAW` `SYS_CHROOT` | `SYS_ADMIN` `SYS_MODULE` `SYS_TIME` `SYS_BOOT` |

A service can also start as root, prepare files, then drop privileges using `setuid()` and `setgid()`. Files it writes afterward belong to that service account.

Access to a rootful Docker daemon's API can grant host-level privileges; see § 05 a.

[Docker — Runtime privileges and capabilities](https://docs.docker.com/engine/containers/run/#runtime-privilege-and-linux-capabilities)

</details>

</details>

</details>

<a id="07--volumes"></a>
<details>
<summary><h1>07 · Volumes</h1></summary>

> **A volume is persistent storage managed by Docker. Mount it into a container to keep data after the container is removed.**

<p align="center"><img src="assets/docker-volumes.png" alt="A container mounts a Docker volume stored on the host; the data remains after the container is removed" width="800"></p>

[Docker: Volumes](https://docs.docker.com/engine/storage/volumes/)

<a id="a--why-containers-need-them"></a>
<details>
<summary><h2>a · Why containers need them</h2></summary>

**Stopping or restarting a container keeps its writable layer. Removing the container deletes it.** A database stored only in that layer disappears with it; see [image layers](#b--image-layers).

**Mount a volume at `/var/lib/data`**, and files written there go to the volume instead. A replacement container can mount the same volume and use the same files.

The application uses the mounted path like an ordinary directory. Use volumes for data such as databases and uploaded media.

[Docker: Storage](https://docs.docker.com/engine/storage/)

</details>

<a id="b--named-volumes-and-bind-mounts"></a>
<details>
<summary><h2>b · Named volumes and bind mounts</h2></summary>

**Choose one mount inside a Compose service:**

```yaml
# Named volume: Docker manages the storage
volumes:
  - app_data:/var/lib/data
```

Declare `app_data` under the top-level `volumes:` as well.

Or use a host path directly:

```yaml
# Bind mount: you choose the host path
volumes:
  - /srv/app-data:/var/lib/data
```

| | Named volume | Bind mount |
|:--|:--|:--|
| **who chooses the host path by default** | Docker | you |
| **typical location on Linux** | `/var/lib/docker/volumes/<name>/_data` | wherever you point it |
| **listed by `docker volume ls`** | yes | no |
| **copies existing container files** | into an empty volume, by default | no |

**When an empty volume is mounted over existing container files, Docker copies them into the volume by default.** Copying can be disabled. A bind mount hides existing files without copying them.

[Docker: Mounting a volume over existing data](https://docs.docker.com/engine/storage/volumes/#mounting-a-volume-over-existing-data)

<details>
<summary><b>DEEPDIVE · Inspecting a volume</b></summary>

`docker volume inspect` returns JSON. Use `--format` to show only its mount point and driver:

```console
$ docker volume create probe_tmp
probe_tmp
$ docker volume inspect --format '{{ .Mountpoint }} | driver={{ .Driver }}' probe_tmp
/var/lib/docker/volumes/probe_tmp/_data | driver=local
```

The path is on the Docker host and may differ from this Linux example.

</details>

</details>

<a id="c--custom-host-paths-with-driver_opts"></a>
<details>
<summary><h2>c · Custom host paths with <code>driver_opts</code></h2></summary>

**Use the `local` driver's bind options to give a named volume a specific host directory:**

```yaml
volumes:
  app_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/app-data       # existing host directory
```

**It is still a named volume**, backed by `/srv/app-data`. Docker lists and manages it as a volume, and empty-volume copying still applies.

**Create the host directory before running `docker compose up`.** Use a separate directory for each application's data: two volumes with the same `device` share the same files.

[Docker: Volume driver options](https://docs.docker.com/reference/compose-file/volumes/#driver_opts)

<details>
<summary><b>DEEPDIVE · Missing host directories</b></summary>

If the source directory does not exist, the mount fails:

```text
failed to mount local volume:
  mount /srv/does-not-exist:/var/lib/docker/volumes/..._data
  no such file or directory
```

The container does not start. Docker does not create the source directory for this kind of mount.

</details>

</details>

</details>

<a id="08--docker-networking"></a>
<details>
<summary><h1>08 · Docker networking</h1></summary>

> **Docker networking determines how containers communicate. Docker can create virtual networks that act like virtual switches. Containers attached to the same network can communicate with each other.**

<br>

```text
       Docker bridge network
    ┌─────────────────────────┐
    │      Virtual switch     │
    └────┬───────┬───────┬────┘
         │       │       │
        web     API   database
```

<br>

**Three common modes:**

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
   └── Loopback only
```

**A user-defined bridge network also provides DNS.** Containers can reach one another using their service or container names instead of tracking changing IP addresses.

<details>
<summary><b>DEEPDIVE · The Linux bridge</b></summary>

<p align="center"><img src="assets/bridge.png" alt="Container interfaces connected through veth pairs to the host's docker0 bridge, with traffic routed toward the internet" width="900"></p>

This diagram shows Docker's **default bridge**, `docker0`. Each container has one end of a `veth` pair; the other end connects to the bridge on the host. Think of the pair as a virtual Ethernet cable.

For external traffic, the host routes packets and normally applies NAT. User-defined bridge networks use their own bridges instead of `docker0`. The addresses shown are examples.

[Docker: Bridge networks](https://docs.docker.com/engine/network/drivers/bridge/) · [Linux: veth](https://man7.org/linux/man-pages/man4/veth.4.html)

</details>

</details>

<a id="09--docker-compose"></a>
<details>
<summary><h1>09 · Docker Compose</h1></summary>

> **Docker Compose is a tool for defining and running multi-container applications.**

<p align="center"><img src="assets/docker-compose.png" alt="Compose reads a YAML file and uses Docker Engine to run services with shared networks and persistent volumes" width="900"></p>

**A Dockerfile builds an image. A Compose file describes how services run together**, including their networks, storage, and configuration. A service defines how to run one or more containers from an image.

[Docker: Compose](https://docs.docker.com/compose/)

<a id="a--why-compose"></a>
<details>
<summary><h2>a · Why Compose?</h2></summary>

Starting one container might look like this:

```bash
docker run -d --name database -p 1337:3306 --env-file .env my-database:1.0
```

Now add a web server and an application. Each needs its own settings, the right volumes, a shared network, and a startup order. With the images already built, it starts looking like this: **don't read it juts look at it, i know it's too much**

```bash
docker network create app_net
docker volume create app_data

docker run -d --name database --network app_net --env-file .env \
  -v app_data:/var/lib/database --restart unless-stopped my-database:1.0

docker run -d --name app --network app_net --env-file .env \
  --restart unless-stopped my-app:1.0

docker run -d --name web --network app_net -p 8080:80 \
  --restart unless-stopped my-web:1.0
```

**That's too much to keep retyping.** As we said, Docker is trying to make things simple.

**Compose puts that setup in one YAML file.** Then:

```bash
docker compose up
```

Compose reads the file and sends requests to the Docker Engine API to create networks and volumes, mount data, and start the containers. The Engine performs those operations.

[Docker: How Compose works](https://docs.docker.com/compose/intro/compose-application-model/)

</details>

<a id="b--yaml"></a>
<details>
<summary><h2>b · YAML</h2></summary>

**YAML is a human-readable data serialization language**, often used for configuration files. It represents data as values, lists, and mappings (dictionaries).

The name originally meant [“Yet Another Markup Language”](https://yaml.org/spec/history/2001-06-16.html). Today it means **“YAML Ain't Markup Language”**. The “Y” stands for YAML. Yes, it's a recursive joke, (GNU aah name).

**Rule #1: NEVER use tabs for indentation.** Use spaces, consistently. Two spaces per level works well.

**Key-value pairs:** write `key: value`, with a space after the colon.

```yaml
image: nginx
container_name: web_server
restart: unless-stopped
```

**Lists:** each `- ` introduces an item. Quote port mappings so they stay strings.

```yaml
ports:
  - "80:80"
  - "443:443"
```

**Nested mappings:** indentation groups properties under a key.

```yaml
nginx:
  build: ./nginx
  container_name: web_server
  expose:
    - "443"
```

Here, `build`, `container_name`, and `expose` belong to `nginx`. Entries at the same indentation level are siblings. `#` starts a comment.

YAML also supports inline lists, such as `networks: [app_net]`, and empty mappings, `{}`. **YAML supplies the structure; Compose gives keys such as `image` and `ports` their meaning.**

[YAML: Specification](https://yaml.org/spec/1.2.2/)

</details>

<a id="c--how-to-write-a-compose-file"></a>
<details>
<summary><h2>c · How to write a Compose file</h2></summary>

Create a file named `compose.yaml`. **Start with `services:`**, then give each service a name and its settings:

```yaml
services:
  web:
    image: nginx
    ports:
      - "8080:80"
```

Read it from the outside in:

- **`services:`** groups the services to run.
- **`web:`** is a service name you choose.
- **`image: nginx`** selects the image to run.
- **`"8080:80"`** maps port 8080 on your host to port 80 inside the container.

That's enough for a web server. Run `docker compose up`, then open `http://localhost:8080`.

**Using your own Dockerfile?** Replace `image: nginx` with `build: ./web`, where `web/Dockerfile` contains the build instructions. Keep the port mapping if your application listens on port 80.

**Adding another service?** Put it under `services:`, at the same indentation level as `web:`. Compose creates a shared network automatically, so services can reach one another by name. Add volumes, secrets, and other settings when you need them.

<details>
<summary><b>DEEPDIVE · Multiple services and shared resources</b></summary>

This example assumes a `Dockerfile` in each of `web/` and `database/`, a `.env` file for database settings, and `secrets/db_password.txt` for its password. Save the YAML as `compose.yaml` beside those paths:

```yaml
services:
  web:
    build: ./web
    image: my-web:1.0
    ports:
      - "8080:80"
    networks: [app_net]
    depends_on: [database]
    restart: unless-stopped

  database:
    build: ./database
    image: my-database:1.0
    env_file: [.env]
    networks: [app_net]
    volumes:
      - app_data:/var/lib/database
    secrets: [db_password]
    restart: unless-stopped

networks:
  app_net: {}

volumes:
  app_data: {}

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

**Top-level blocks declare resources; service entries attach them.** `app_data` is declared once and mounted into `database`. The password file is available only to `database`, at `/run/secrets/db_password` by default; its application must read that file.

`app_net: {}` and `app_data: {}` use the default settings. Both services join `app_net`, so `web` can reach the database by its service name, `database`. `"8080:80"` publishes the web container's port 80 on the host's port 8080.

**The short form of `depends_on` controls startup order, not readiness.** Here, `database` starts before `web`, but it may not yet accept connections. Use a `healthcheck` with `condition: service_healthy`, or application retries, when readiness matters.

If `database` defines a healthcheck, the dependency can be written as:

```yaml
depends_on:
  database:
    condition: service_healthy
```

[Docker: Startup order](https://docs.docker.com/compose/how-tos/startup-order/)

</details>

</details>

<a id="d--important-compose-keys"></a>
<details>
<summary><h2>d · Important keys</h2></summary>

At the top level, **`services`** defines the application's services. **`networks`**, **`volumes`**, and **`secrets`** declare resources those services can use.

Inside a service:

| Key | Purpose |
|:--|:--|
| `build` | configures how to build the image; a short path selects the build context |
| `image` | selects the image to run; also names the image when built with `build` |
| `container_name` | sets a custom container name instead of the generated one |
| `environment` | sets environment variables in the container |
| `env_file` | reads container environment variables from a file |
| `networks` | attaches the service to networks |
| `volumes` | mounts named volumes or host paths |
| `secrets` | grants access to declared secrets as files |
| `ports` | publishes ports as `host:container` |
| `expose` | documents container ports as a list; does not publish them on the host |
| `depends_on` | sets dependency order; readiness requires an explicit condition |
| `restart` | sets when Docker restarts an exited container, such as `unless-stopped` |
| `command` | overrides the image's `CMD` |
| `entrypoint` | overrides the image's `ENTRYPOINT` |

Use service names such as `database` to reach other services on a shared network; see [Docker networking](#08--docker-networking). A custom `container_name` is also resolvable there, but is optional and prevents scaling that service beyond one container.

[Docker: Service reference](https://docs.docker.com/reference/compose-file/services/)

</details>

<a id="e--essential-compose-commands"></a>
<details>
<summary><h2>e · Essential commands</h2></summary>

Run these from the directory containing your Compose file. First, check the file with `docker compose config --quiet`; it validates the configuration without starting containers.

| Command | Purpose |
|:--|:--|
| `docker compose up -d --build` | builds images and creates or updates containers in the background |
| `docker compose ps` | shows containers and their status |
| `docker compose logs -f` | follows service logs |
| `docker compose down` | stops and removes the project's containers and networks; keeps named volumes |

**Running `up` again reuses unchanged containers.** If a service's configuration or image has changed, Compose recreates the affected containers while preserving mounted volumes.

[Docker: `up`](https://docs.docker.com/reference/cli/docker/compose/up/) · [Docker: `down`](https://docs.docker.com/reference/cli/docker/compose/down/)

</details>

<a id="compose-history"></a>
<details>
<summary><h2>History</h2></summary>

<p align="center"><img src="assets/docker-compose-history.png" alt="Compose V1 used Python and legacy file formats; V2 and V5 use Go and the Compose Specification, with a Go SDK added in V5" width="900"></p>

If an old tutorial's file looks different, this is why:

| File format | What changed |
|:--|:--|
| **1 (2014)** | service names were written at the root, without `services:` |
| **2.x (2016)** | added `services:` and a `version: "2.x"` declaration |
| **3.x (2017)** | used `version: "3.x"` and added options aimed at Swarm deployments |
| **Compose Specification** | merged the 2.x and 3.x formats; current files omit `version:` |

**File format 1** put services directly at the root. This format is historical and is not supported by current Compose:

```yaml
web:
  image: nginx
```

**File format 2** grouped them under `services:` and declared a format version:

```yaml
version: "2.4"
services:
  web:
    image: nginx
```

**Today, keep `services:` and omit `version:`.** Compose validates against the current specification; the old field is obsolete.

**CLI versions are separate from file formats.** The original Compose V1 program was written in Python and invoked as `docker-compose`. Modern Compose V2 and V5 are written in Go and use `docker compose`. A file saying `version: "2.4"` does not mean it needs the V2 CLI.

[Docker: Compose history](https://docs.docker.com/compose/intro/history/) · [Docker: Version field](https://docs.docker.com/reference/compose-file/version-and-name/)

</details>

<details>
<summary><b>DEEPDIVE · More about Compose</b></summary>

**The same Docker Engine.** Compose reads the file and sends requests through the [Engine API](#05--docker-architecture):

```text
compose.yaml ──► docker compose ──► Engine API ──► dockerd
```

Docker Engine performs the container operations; these containers also appear in `docker ps`.

**Secret names and paths.** `file:` selects the host file. The secret's name sets its default path inside the container. The long syntax can override that path with `target`.

**`.env` and `env_file` do different jobs.** Compose reads `.env` for `${VARIABLE}` substitutions in the YAML. `env_file` passes variables into a service's containers. A `.env` file alone does not automatically populate every container's environment.

[Docker: Variable interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)

**`build` with `image`.** `image` names the build result. Without a `pull_policy`, Compose normally tries to find or pull that image before building if needed; `up --build` explicitly requests a build.

[Docker: Build and image](https://docs.docker.com/reference/compose-file/build/#using-build-and-image)

**Filenames.** `compose.yaml` is preferred. `compose.yml`, `docker-compose.yaml`, and `docker-compose.yml` are also supported; this project uses `docker-compose.yml`.

[Docker: How Compose works](https://docs.docker.com/compose/intro/compose-application-model/)

</details>

</details>

---

<a id="10--mariadb"></a>
<details>
<summary><h1>10 · MariaDB</h1></summary>

> **MariaDB is an open-source relational database management system (RDBMS) that stores and manages structured data in tables and provides an SQL interface for accessing and manipulating that data.**

<p align="center"><img src="assets/mariadb_image.png" width="400"></p>
<p align="center"><i>Notice how Docker, MariaDB, MySQL, PostgreSQL, Linux, GNU... all have animal logos?</i></p>

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

<br>

<a id="mariadb-history"></a>
<details>
<summary><h2>a · History</h2></summary>

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

<a id="b--mariadb-deep-dive"></a>
<details>
<summary><h2>b · MariaDB deep dive</h2></summary>

<br>

**MariaDB also follows a client-server model.** The client sends SQL queries; `mariadbd`, the server, executes them and manages the data. In this project, WordPress is a client through PHP's database library:

```text
wordpress container
  php-fpm + PHP's client library
    │
    │ SQL over TCP, port 3306
    ▼
mariadb container
  mariadbd, the daemon
    │
    ▼
/var/lib/mysql   (files on disk)  <-- What the hell is MySQL doing here? Isn't this MariaDB?
```

Read [History](#mariadb-history). It'll make sense.

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
  │                                      │  read /var/lib/mysql  <-- MySQL again? See History above.
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

<a id="c--mariadb-the-container"></a>
<details>
<summary><h2>c · MariaDB, the container</h2></summary>


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

CMD ["mariadbd", "--user=mysql"]
```

**Install MariaDB and clear the package-created database files.** This leaves initialisation to the entrypoint. Installation and cleanup share one `RUN`; see § 06 c for layers and cleanup.

`COPY --chmod=755` makes the entrypoint executable. `ENTRYPOINT` selects that script, and `CMD` supplies its default command: `mariadbd --user=mysql`.

<br>

### The configuration file

```ini
[mysqld]
bind-address     = 0.0.0.0
port             = 3306
skip-name-resolve
```

| Setting | Purpose |
|:--|:--|
| `bind-address = 0.0.0.0` | listens on all IPv4 interfaces inside the container, so WordPress can connect |
| `port = 3306` | explicitly keeps MariaDB's default TCP port |
| `skip-name-resolve` | disables DNS lookups for client hostnames |

[MariaDB: Server variables](https://mariadb.com/docs/server/server-management/variables-and-modes/server-system-variables#skip_name_resolve)

<details>
<summary><b>DEEPDIVE · Configuration loading</b></summary>

**The file is not replacing Debian's, it is overriding it.** `/etc/mysql/mariadb.conf.d/` is read in alphabetical order and, in MariaDB's own words, *"if an option is set multiple times, the later setting will override the earlier setting."*

```
50-server.cnf     bind-address = 127.0.0.1
99-inception.cnf  bind-address = 0.0.0.0     ← read later, wins
```

**Both files are read.** Nothing is skipped. `my_print_defaults mysqld` prints the resulting list in order, showing both values, and the daemon applies the last one.

[MariaDB: Option files](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/configuring-mariadb/configuring-mariadb-with-option-files)

</details>

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

	exec "$@" --init-file=/tmp/init.sql
fi

exec "$@"
```

**Initialisation happens when the container starts**, because that is when the data volume, configuration, and secrets are available. This project builds MariaDB from Debian and supplies its own startup script.

**Prepare the runtime directory.** The script creates `/run/mysqld` and gives `mysql` ownership. This container starts the daemon directly, so the entrypoint prepares that directory.

**Read the configuration.** Passwords come from secret files under `/run/secrets/`. The database and account names come from environment variables, passed by Compose's `env_file`.

**Check for system tables.** The guard skips initialisation when `/var/lib/mysql/mysql` exists. That directory is created before the application's SQL runs, so its presence does not prove setup completed. An interrupted setup can leave partial initialisation.

**Start the server.** `"$@"` forwards the command and arguments from `CMD`. `exec` replaces the shell with `mariadbd`, making the daemon PID 1 so it receives Docker's stop signal directly.

```text
system tables missing                 system tables present
          ↓                                     ↓
mariadb-install-db                    skip initialisation
write /tmp/init.sql                             │
          ↓                                     ↓
exec "$@" --init-file=...              exec "$@"
          ↓                                     ↓
mariadbd runs the initial SQL          mariadbd starts normally
          ↓                                     ↓
      serves queries                       serves queries
```

[Docker: Entrypoint](https://docs.docker.com/reference/dockerfile/#entrypoint)

<br>

<details>
<summary><b>DEEPDIVE · Two failures that shaped this script</b></summary>

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

</details>

</details>

<a id="11--wordpress"></a>
<details>
<summary><h1>11 · WordPress</h1></summary>

> **WordPress is open-source content management system (CMS) software, written in PHP, that stores its content in a MySQL or MariaDB database and generates web pages from it on request.**

<p align="center"><img src="assets/wordpress_images.png" width="300"></p>
<p align="center"><i>PHP source code, not a server</i></p>

**WordPress describes itself in one line:** *"built on PHP and MariaDB, and licensed under the GPLv2."* Those two names are not a coincidence for this project. They are the two other containers.

**It does four things:**

- **Stores content in a database**, posts, pages, comments, users, settings.
- **Generates pages on request** by executing PHP that queries that database and returns HTML.
- **Provides an administration interface** at `/wp-admin` for writing and configuring, with no file editing required.
- **Extends itself** through themes, which decide appearance, and plugins, which add behaviour.

<br>

<a id="wordpress-history"></a>
<details>
<summary><h2>a · History</h2></summary>

<br>

**WordPress began in 2003 as a fork of b2/cafelog**, a PHP blogging script whose original developer had stopped maintaining it. Matt Mullenweg and Mike Little forked it and kept it going under the GPL.

**It was a blogging tool for years before it was a CMS.** The vocabulary still shows it: the main content table is `wp_posts`, and pages are stored there too, as posts with a different `post_type`.

**The comparison with MariaDB is worth noticing.** Both projects in this stack exist because of a fork:

```
b2/cafelog  ──abandoned──►  WordPress   (2003)
MySQL       ──acquired──►   MariaDB     (2009)
```

</details>

<a id="b--wordpress-deep-dive"></a>
<details>
<summary><h2>b · WordPress deep dive</h2></summary>

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

**The container named `wordpress` is really php-fpm plus the WordPress files.**

**PHP execution and HTTP serving are separate jobs.** php-fpm executes the WordPress code; nginx handles incoming HTTPS requests.

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

<a id="wordpress-php-fpm-and-fastcgi"></a>
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

**Debian's defaults for both of those do not suit a container.** § 11 c covers what has to change and why.

</details>

<br>

</details>

<a id="c--the-wordpress-container"></a>
<details>
<summary><h2>c · The WordPress container</h2></summary>

**Three files build this service:**

```text
Dockerfile              how the image is built
conf/www.conf           what settings php-fpm runs with
tools/entrypoint.sh     what happens on every container start
```

<details>
<summary><b>The Dockerfile</b></summary>

```dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	php8.2-fpm \
	php8.2-mysql \
	php8.2-redis \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www2.conf

ADD --chmod=755 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar /usr/local/bin/wp

WORKDIR /var/www/html

RUN wp core download --allow-root && chown -R www-data:www-data /var/www/html

COPY --chmod=755 tools/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["php-fpm8.2", "-F"]
```

| Package | Purpose |
|:--|:--|
| `php8.2-fpm` | runs the WordPress PHP code |
| `php8.2-mysql` | lets PHP connect to MariaDB |
| `php8.2-redis` | lets PHP connect to Redis for object caching |
| `ca-certificates` | supplies trusted certificates for HTTPS downloads |

**WP-CLI manages WordPress from the terminal.** The Dockerfile downloads it as a `.phar` (PHP Archive), then uses `wp core download` to put the WordPress files in `/var/www/html`.

`chown` gives `www-data`, the PHP-FPM worker account, ownership of those files so WordPress can write uploads and updates.

`ENTRYPOINT` runs the startup script. `CMD` passes it `php-fpm8.2 -F`; `-F` keeps PHP-FPM in the foreground.

[WP-CLI: Download WordPress](https://developer.wordpress.org/cli/commands/core/download/)

</details>

<details>
<summary><b>The configuration file</b></summary>

The active settings in `conf/www.conf` are:

```ini
[www]
listen = 0.0.0.0:9000
```

**`[www]` selects the worker pool.** `listen` makes it accept FastCGI connections on all IPv4 interfaces inside the container. nginx reaches it at `wordpress:9000` over the Docker network; Compose does not publish this port on the host.

The Dockerfile copies this file to `pool.d/www2.conf`. It loads after Debian's `www.conf`, overriding the listening address while keeping the other pool settings.

[PHP: FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)

</details>

<details>
<summary><b>The entrypoint script</b></summary>

```bash
#!/bin/bash

set -e

DB_HOST=mariadb
DB_NAME=$MYSQL_DATABASE
DB_USER=$MYSQL_USER
DB_PASSWORD=$(cat /run/secrets/db_password)
source /run/secrets/credentials

counter=0
while ! (exec 3<>/dev/tcp/$DB_HOST/3306) 2>/dev/null && (($counter<20)) ; do
	echo "Waiting for Mariadbd setup to finish..."
	sleep 1
	counter=$((counter+1))
done

if (( counter >= 20 )); then
    echo "mariadb never became reachable, giving up" >&2
    exit 1
fi

if [ ! -f "/var/www/html/wp-config.php" ]; then

	wp config create \
	--dbname=${DB_NAME} \
	--dbuser=${DB_USER} \
	--dbpass=${DB_PASSWORD} \
	--dbhost=${DB_HOST} \
	--allow-root

	wp core install \
	--url=https://login.42.fr \
	--title="Inception" \
	--admin_user=saad \
	--admin_password=$ADMIN_PASSWORD \
	--admin_email=admin@example.com \
	--allow-root

	wp plugin install redis-cache --activate --allow-root
	wp config set WP_REDIS_HOST redis --allow-root
	wp redis enable  --allow-root

	wp user create simo \
	simo@gmail.com \
	--user_pass=$USER_PASSWORD \
	--allow-root

fi
exec "$@"
```

**Setup happens at container start**, when Compose supplies the volume, environment variables, and secrets.

1. **Read the configuration.** The database name and database user come from the environment. Two secret files supply three passwords: `db_password` holds the database password; `credentials` defines `ADMIN_PASSWORD` and `USER_PASSWORD`.
2. **Wait for MariaDB's TCP port.** The script retries for about 20 seconds before giving up. This checks whether a connection can be opened, not whether the database and credentials are ready. Short-form `depends_on` only controls startup order.
3. **Set up WordPress if `wp-config.php` is missing.** Create the configuration, install the database tables and administrator account, enable Redis caching, then create the second user. For this project, the administrator's name must not contain `admin` or `administrator`, in any letter case.
4. **Start PHP-FPM.** `exec "$@"` replaces the shell with the command from `CMD`, making PHP-FPM PID 1.

**The guard checks for a file, not a completed installation.** If setup fails after creating `wp-config.php`, the next start skips the remaining steps. `wp core is-installed` checks whether WordPress's database tables exist; it does not check the Redis setup or second account.

`--allow-root` lets WP-CLI run as root in this entrypoint.

[Docker: Startup order](https://docs.docker.com/compose/how-tos/startup-order/) · [WP-CLI: Check installation](https://developer.wordpress.org/cli/commands/core/is-installed/)

</details>

<details>
<summary><b>The shared files</b></summary>

**nginx and PHP-FPM need the same WordPress files at the same path.** Both containers mount `wordpress_volume` at `/var/www/html`:

```text
              named volume: the WordPress files
              /home/login/data/wordpress
                          │
        ┌─────────────────┴─────────────────┐
        ▼                                   ▼
nginx                              wordpress
/var/www/html                      /var/www/html
reads .css .js .jpg                executes .php
```

nginx sends `SCRIPT_FILENAME=/var/www/html/index.php` over FastCGI. PHP-FPM opens that path in its own container, so the shared mount makes the file available on both sides. See the [FastCGI deep dive](#wordpress-php-fpm-and-fastcgi).

</details>

<details>
<summary><b>DEEPDIVE · Configuration and startup</b></summary>

### Configuration loading

**Both pool files are read.** Their `[www]` settings are combined, and a later value overrides an earlier one:

```text
www.conf     [www]  listen = /run/php/php8.2-fpm.sock
www2.conf    [www]  listen = 0.0.0.0:9000
```

The `[www]` header is required so PHP-FPM knows which pool the setting belongs to.

**The filename matters.** An earlier attempt used `www-listen.conf`, which sorts before `www.conf`. Debian's socket setting then won. `www2.conf` sorts after it, so the TCP setting wins.

Check the effective configuration with:

```bash
php-fpm8.2 -tt 2>&1 | grep 'listen ='
```

Using `listen = 9000` can create a dual-stack IPv6 listener. The explicit `0.0.0.0:9000` selects IPv4.

### Build time and run time

| Operation | When in this project | Why |
|:--|:--|:--|
| `wp core download` | build time | puts the application files in the image |
| `wp config create` | run time | uses the supplied database settings and password |
| `wp core install` | run time | creates tables and an administrator in the running database |

WP-CLI executes PHP directly, so installation needs a database connection but no running nginx or PHP-FPM server.

**An empty volume receives the image's existing files by default**, unless copying is disabled with `nocopy`. A non-empty volume hides the image's files at that path. Rebuilding the image therefore does not replace an existing WordPress installation in the volume.

[Docker: Mounting volumes over existing data](https://docs.docker.com/engine/storage/volumes/#mounting-a-volume-over-existing-data) · [WP-CLI: Create configuration](https://developer.wordpress.org/cli/commands/config/create/) · [WP-CLI: Install WordPress](https://developer.wordpress.org/cli/commands/core/install/)

### Secrets and file ownership

**`cat` reads a value; `source` executes shell assignments.** The `credentials` file must contain trusted assignments such as `ADMIN_PASSWORD=...` and `USER_PASSWORD=...`. This service does not receive `db_root_password`.

The PHP-FPM master starts as root, while its workers run as `www-data`. The build's `chown` lets those workers write to the WordPress files; without suitable permissions, uploads and updates fail.

With Docker's usual rootful setup and no user namespace remapping, `www-data`'s UID 33 also appears on the host. Volume copying preserves file ownership; see § 06 f.

</details>

</details>

</details>

<a id="12--nginx"></a>
<details>
<summary><h1>12 · nginx</h1></summary>

> **nginx is a web server: a daemon that listens on a TCP port, speaks HTTP, and answers each request either with a file from disk or with a response produced by another program.**

<a id="a--tls-and-the-certificate"></a>
<details>
<summary><h2>a · TLS and the certificate</h2></summary>


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

<a id="b--the-nginx-container"></a>
<details>
<summary><h2>b · The nginx container</h2></summary>


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

**`rm /etc/nginx/sites-enabled/default` removes the packaged site**, which owns port 80 as its default server. Deleting one symlink is preferable to editing the packaged `nginx.conf`, and it belongs in the same `RUN` for the whiteout reason in § 06 c.

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

**`include snippets/fastcgi-php.conf;` ships with the Debian package**, and it supplies the FastCGI parameters described in the [php-fpm deep dive](#wordpress-php-fpm-and-fastcgi):

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

**The volume is mounted a second time here**, the same named volume wordpress uses. § 11 c explains why: FastCGI sends a path, not code, so both containers must see the same files at the same path.

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

**This project uses `login.42.fr` as its domain name.**

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

https://mlops-for-all.github.io/en/docs/prerequisites/docker/

[Solomon Hykes: The future of Linux Containers (PyCon 2013)](https://www.youtube.com/watch?v=362sHaO5eGU)

[dotScale 2013: Solomon Hykes: Why we built Docker](https://www.youtube.com/watch?v=3N3n9FzebAA&t=1054s)

[Linux Containers: Official website](https://linuxcontainers.org/)

[Evolution of Linux Containers: Tilak Patidar](https://medium.com/@tilakpatidar/evolution-of-linux-containers-660fcfdefa3e)

[Docker: LXC vs. Docker](https://www.docker.com/blog/lxc-vs-docker/)
