<h1 align="center">Inception — Notes</h1>
<p align="center"><i>My understanding of the project. Written as I learn it.</i></p>

---

## 01 · Why containers were invented

**The problem:** one server, 200 customers, each needing their own isolated website.

Three options existed:

| | Cost |
|:--|:--|
| 200 machines | absurd |
| 200 processes on one machine | no isolation — they read each other's files, one crash starves all |
| 200 VMs | works, but 200 full operating systems: GBs of RAM, minutes to boot, all running the same Linux |

The VM wastes everything. The customer needs an isolated *website* — not an isolated *computer*.

> **Can one machine host many isolated tenants without pretending to be 200 machines?**

Containers are the answer: keep one operating system, and make it **lie to each process about what machine it's on**.

So containers were invented for **density and isolation** — not to replace VMs.

| | Virtual Machine | Container |
|:--|:--|:--|
| **Memory** | a lot — a full OS each | far less — only the app |
| **Boot** | slow, a real boot sequence | instant, reuses the running kernel |
| **Scaling** | difficult | trivial |
| **Efficiency** | low | high |
| **Storage** | hard to share between VMs | shared freely between host and containers |
| **Isolation** | strong — hardware level | weaker — same kernel |

The last row is the trade: a VM's boundary is a hypervisor and hard to escape; a container's boundary is kernel bookkeeping, so a kernel bug crosses it.

---

## 02 · What is a container?

> **A container is just a normal Linux process on your kernel, with lies told to it.** yep we just lie to the process

No virtual machine boots. No OS is emulated. Run `ps` on the host and you find an ordinary process among your others — same kernel, same scheduler.

So what makes it a container? Only **what that process is allowed to perceive and consume**. The kernel hands it a distorted view of the machine, and the process believes it.

Two kernel features do the lying:

| | Controls | Purpose |
|:--|:--|:--|
| **Namespaces** | what a process can **see** | isolation |
| **cgroups** | what a process can **use** | limits |

<br>

### Namespaces — what it sees

A namespace is a **private copy of some part of the system**. Instead of one global process list, one global network, one global hostname, the kernel gives a process its own version of each. The process never knows it got a copy — it just looks around and reports what it finds.

| | Isolates | The process believes |
|:--|:--|:--|
| `pid` | process IDs | it's the first process on the machine |
| `mnt` | filesystem | the disk is the image's filesystem |
| `net` | network | it owns a machine with its own IP |
| `uts` | hostname | it has its own machine name |
| `ipc` | shared memory | nothing else shares memory with it |
| `user` | UID / GID | it is root |

One `sleep` command, seen from both sides at once:

```
inside container         on host
─────────────────        ─────────────────
PID 1  sleep 300    ═══  PID 50862  sleep 300
```

Same process, two identities. Inside it's process number 1 — the first thing that ever ran. Outside it's 50862, with a parent and hundreds of siblings it cannot see.

The **network** namespace matters most here: each container gets its own interface, IP, routing table, and **its own set of ports**. That's why two containers can both listen on 9000 and never collide.

<br>

### cgroups — what it uses

Namespaces hide things but restrain nothing. A process that only sees its own filesystem can still eat every byte of RAM on the machine — exactly the hosting problem from section 01.

**Control groups** put a hard ceiling on consumption: memory, CPU time, disk bandwidth, process count.

```bash
--memory=64m     may use 64 MB, no more
--cpus=0.5       gets half a core's worth of time
```

Docker doesn't enforce this. It writes a number to a file, and the **kernel** does the policing — including killing the process if it overruns.

> ⚠️ A container capped at 64 MB still reports the host's full 15 GB when asked how much memory the machine has. It has no idea it's restricted. The limit is real anyway.

<br>

Namespaces answer *"what world does this process live in?"*
cgroups answer *"how much of the real machine may it consume?"*

A container is a process given both: a fabricated view, and a budget.

---

## 03 · The situation that created Docker

Everything above is plain Linux, and it all existed before Docker:

```
1979  chroot              isolate a filesystem
2000  FreeBSD Jails       filesystem + processes + network
2004  Solaris Containers  the word ships in a product
2006  cgroups             Google adds resource limits to Linux
2008  LXC                 first full container manager for Linux
2013  Docker              built on LXC at first
```

So the mechanism was solved and in production. Yet almost nobody used it, because a second problem was still open:

A developer writes code. It runs perfectly on their machine. The tester pulls it and it breaks — a missing library, a different language version, an environment variable that only exists on the first machine. Nobody can say *why*, because nobody can see the difference.

Containers could isolate a process, but there was no way to **hand someone your exact environment**. Building one meant assembling the filesystem by hand, choosing namespaces, wiring the network, then repeating all of it on every machine.

> **Isolation was solved. Distribution wasn't.**

Docker's answer was the **image**: build your environment once — OS libraries, language runtime, dependencies, config — and ship it as a single artifact that runs identically anywhere.

| | |
|:--|:--|
| **Images** | a packaged filesystem you build once and ship anywhere |
| **A registry** | somewhere to publish and download them |
| **A daemon** | a background service doing the kernel work for you |
| **A CLI** | `docker run` instead of a page of manual setup |

The image is the real invention, and the reason "works on my machine" stopped being an excuse.

> **In short:** containers are a Linux feature. Docker is a very good tool for using it.
