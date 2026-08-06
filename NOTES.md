<h1 align="center">Inception — Notes</h1>
<p align="center"><i>My understanding of the project. Written as I learn it.</i></p>

---

Before defining what Docker is, let's define what a **container** is — because containers existed long before Docker, and Docker is only one way of using them. Getting this backwards is what makes Docker feel like magic. It isn't.

---

## 01 · What is a container?

> **A container is just a normal Linux process on your kernel, with lies told to it.**

That's the whole thing.

When you start a container, no virtual machine boots. No operating system is emulated. No second kernel appears. If you run `ps` on the host, you find an ordinary process sitting there among all your others — same kernel as your shell, same scheduler, same memory manager.

So if it's just a process, what makes it a *container*? The difference is entirely in **what that process is allowed to perceive and consume**. The kernel deliberately gives it a distorted view of the machine, and the process believes what it's told.

Two kernel features do the lying:

| | Controls | Purpose |
|:--|:--|:--|
| **Namespaces** | what a process can **see** | isolation |
| **cgroups** | what a process can **use** | limits |

That's it. Everything else — images, Dockerfiles, Compose — is tooling built on top of these two ideas.

<br>

### Namespaces — what it sees

A namespace is a **private copy of some part of the system**. Instead of one global list of processes, one global set of network interfaces, one global hostname, the kernel can hand a process its own version of each.

The process doesn't know it received a copy. It just looks around and reports what it finds.

| | Isolates | What the process believes |
|:--|:--|:--|
| `pid` | process IDs | it is the first process on the machine |
| `mnt` | filesystem | the whole disk is the image's filesystem |
| `net` | network | it owns a machine with its own network card and IP |
| `uts` | hostname | it has its own machine name |
| `ipc` | shared memory | no other program is sharing memory with it |
| `user` | UID / GID | it is root |

The clearest demonstration is the PID namespace. A single `sleep` command running in a container looks like this from both sides at once:

```
inside container         on host
─────────────────        ─────────────────
PID 1  sleep 300    ═══  PID 50862  sleep 300
```

Same process. Two identities. Inside, it is process number 1 — the first thing that ever ran. Outside, it's process 50862 with a parent and hundreds of siblings. It cannot see any of the host's other processes; as far as it is concerned, they don't exist.

The network namespace is worth understanding early, because the whole project depends on it. Each container gets its own network interface, its own IP address, its own routing table, **and its own set of ports**. This is why two containers can both listen on port 9000 without ever colliding — they aren't sharing a port list. They're on separate networks that happen to live on the same machine.

<br>

### cgroups — what it uses

Namespaces hide things. They don't restrain anything. A process that can only see its own filesystem can still consume every byte of RAM and every CPU cycle on the machine, and take the host down with it.

**Control groups** (cgroups) are the other half: they let the kernel put a hard ceiling on what a process may consume — memory, CPU time, disk bandwidth, number of processes.

```bash
--memory=64m     the process may use 64 MB, no more
--cpus=0.5       the process gets half a core's worth of time
```

The important detail: **Docker does not enforce any of this**. It writes a number into a file that the kernel reads, and from then on the kernel does the policing. If the process tries to exceed its memory limit, the kernel kills it — Docker isn't even involved in the decision.

> ⚠️ **A limit isn't the same as knowing about the limit.** A container capped at 64 MB will still cheerfully report the host's full 15 GB when you ask it how much memory the machine has. It has no idea it's restricted. The limit is entirely real and will kill it — the process just can't perceive it.

<br>

### Putting the two together

Namespaces answer *"what world does this process live in?"*
cgroups answer *"how much of the real machine may it consume?"*

A container is a process that has been given both: a fabricated view of the system, and a budget. Nothing more exotic than that.

---

## 02 · What is Docker?

Now the important part: **everything above is plain Linux.** None of it belongs to Docker, and none of it requires Docker. You could assemble a container by hand with standard command-line tools and never install Docker at all.

Docker did not invent containers. The idea is decades old:

```
1979  chroot              first attempt at isolating a filesystem
2000  FreeBSD Jails       filesystem + processes + network isolated together
2004  Solaris Containers  the word "container" ships in a real product
2006  cgroups             Google contributes resource limits to Linux
2008  LXC                 first full container manager for Linux
2013  Docker              built on top of LXC at first
```

By the time Docker arrived, every mechanism it relies on already existed and was in production use. So why did Docker take over and LXC didn't?

Because building a container was possible but **miserable**. You had to assemble the filesystem yourself, know which namespaces to create, wire the network manually, and repeat all of it on every machine. It worked, and almost nobody did it.

Docker's contribution was making it repeatable and shareable:

| | |
|:--|:--|
| **Images** | a packaged filesystem you can build once and ship anywhere — this is Docker's genuine invention, and the reason containers spread |
| **A registry** | somewhere to publish and download those images |
| **A daemon** | a background service that does all the kernel work for you |
| **A CLI** | `docker run` instead of a page of manual setup |

The image is the real breakthrough. Namespaces and cgroups solved *isolation*, but nobody had solved **distribution** — how do you hand your exact environment to someone else and have it behave identically? That's what an image does, and it's why "works on my machine" stopped being an excuse.

> **In short:** containers are a Linux feature. Docker is a very good tool for using it.
