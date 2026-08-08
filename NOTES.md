<h1 align="center">Inception — Notes</h1>
<p align="center"><i>My understanding of the project. Written as I learn it.</i></p>

---

# 01 · Why containers were invented

**One server. 200 customers. Each one wants their own isolated website.**

Three options existed:

| | Cost |
|:--|:--|
| **200 machines** | absurd |
| **200 processes on one machine** | no isolation — they read each other's files, one crash starves all |
| **200 VMs** | works, but 200 full operating systems: GBs of RAM, minutes to boot, all running the same Linux |

**The VM wastes everything.** The customer needs an isolated *website* — not an isolated *computer*.

> **Can one machine host many isolated tenants without pretending to be 200 machines?**

**Containers are the answer.** Keep one operating system, and make it **lie to each process about what machine it's on**.

**So containers exist for density and isolation** — not to replace VMs.

| | Virtual Machine | Container |
|:--|:--|:--|
| **Memory** | a lot — a full OS each | far less — only the app |
| **Boot** | slow, a real boot sequence | instant, reuses the running kernel |
| **Scaling** | difficult | trivial |
| **Efficiency** | low | high |
| **Storage** | hard to share between VMs | shared freely between host and containers |
| **Isolation** | strong — hardware level | weaker — same kernel |

**The last row is the trade.** A VM's boundary is a hypervisor and hard to escape. A container's boundary is kernel bookkeeping — so a kernel bug crosses it.

---

# 02 · What is a container?

> **A container is just a normal Linux process on your kernel, with lies told to it.** yep we just lie to the process

**No virtual machine boots. No OS is emulated.** Run `ps` on the host and you find an ordinary process among your others — same kernel, same scheduler.

**So what makes it a container?** Only **what that process is allowed to perceive and consume**. The kernel hands it a distorted view of the machine, and the process believes it.

**Two kernel features do the lying:**

| | Controls | Purpose |
|:--|:--|:--|
| **Namespaces** | what a process can **see** | isolation |
| **cgroups** | what a process can **use** | limits |

<br>

## Containers are much older than Docker

**None of this was invented in 2013.** The mechanism was already solved and in production:

```
1979  chroot              isolate a filesystem
2000  FreeBSD Jails       filesystem + processes + network
2004  Solaris Containers  the word ships in a product
2006  cgroups             Google adds resource limits to Linux
2008  LXC                 first full container manager for Linux
2013  Docker              built on LXC at first
```

**Docker did not invent the container.** It arrived 34 years after `chroot` and 5 years after LXC.

<br>

## The kernel has no "container"

**There is no container object in Linux.** Nothing in the kernel is called that. It only ships namespaces and cgroups as general-purpose primitives — and *anyone* can use them:

| Uses namespaces / cgroups | For what |
|:--|:--|
| **systemd** | every service unit lives in its own cgroup; `PrivateTmp=` and `ProtectSystem=` are mnt namespaces |
| **Chrome / Firefox** | renderer sandbox — user + pid + net namespaces, so a compromised tab sees nothing |
| **Android** | each app in its own uid and namespace set |
| **flatpak / snap / bubblewrap** | desktop app sandboxing |
| **`unshare` / `nsenter`** | plain command-line access, no daemon needed |
| **VPNs** | a net namespace to route one app through the tunnel |

> **"Container" is a userspace word** for a particular combination of these. Docker is just its most famous consumer.

<br>

## Namespaces — what it sees

> **A namespace gives a process its own private view of one part of the system.**

Instead of one global process list, one global network, one global hostname, the kernel keeps a second copy and hands it to the process. **The process never knows it got a copy** — it just looks around and reports what it finds.

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

**Same process, two identities.** Inside it's process number 1 — the first thing that ever ran. Outside it's 50862, with a parent and hundreds of siblings it cannot see.

**The network namespace matters most here.** Each container gets its own interface, IP, routing table, and **its own set of ports** — which is why two containers can both listen on 9000 and never collide.

<br>

## Where namespaces actually live

**A namespace is not the process control block.** In Linux the PCB is `struct task_struct` — one per process, holding PID, state, memory map, open files.

**Each `task_struct` carries a pointer called `nsproxy`**, pointing to the set of namespaces that process belongs to:

```
task_struct  (one per process)
     └─ nsproxy ──> { pid_ns, net_ns, mnt_ns, uts_ns, ipc_ns, ... }
```

<p align="center"><img src="assets/task_struct-nsproxy.png" width="520"></p>
<p align="center"><i>include/linux/sched.h — a pointer, not the namespaces themselves</i></p>

**And what it points to is just a box of pointers**, one per namespace type:

<p align="center"><img src="assets/struct-nsproxy.png" width="560"></p>
<p align="center"><i>include/linux/nsproxy.h</i></p>

**The key word is shared** — and the kernel says so itself in that comment:

> *"The nsproxy is shared by tasks which share all namespaces. As soon as a single namespace is cloned or unshared, the nsproxy is copied."*

**Every process in the same container points to the same namespace structs.** That's what makes them one container — not a flag in the PCB, but a shared set of objects.

**One exception: `user` is not in nsproxy.** Look at the screenshot — there's no `user_ns` field. It lives in `struct cred`, the process's credentials, because it's about *permissions*, not resources:

```
task_struct ──> nsproxy ──> uts, ipc, mnt, pid, net, time, cgroup
            ──> cred    ──> user_ns
```

<br>

## How a pid namespace tracks processes

**A namespace is a place, not a record.** It stores information about a *resource*, never about who is using it — `task_struct` is what describes a process.

**The `pid` namespace is the near-exception**, because process IDs *are* the resource it isolates. Inside `struct pid_namespace`:

| Field | Holds |
|:--|:--|
| `idr` | the PID → process map **for this namespace only**, numbering from 1 |
| `child_reaper` | the task acting as **init** here — adopts orphans, reaps zombies |
| `parent` | pointer to the parent pid namespace |
| `level` | how deep it's nested |

**`idr` is a radix tree**, and it does *not* store `task_struct` directly:

```
pid_namespace
  └─ idr (radix tree)
       ├─ PID 1 ──> struct pid ──> task_struct
       ├─ PID 2 ──> struct pid ──> task_struct
       └─ PID 7 ──> struct pid ──> task_struct
```

**Why `struct pid` in the middle?** Because one process has **several PIDs**, one per namespace level. A plain integer couldn't express that — `struct pid` holds the whole list. So `sleep` really is 1 and 50862 at the same time; both are true, at different levels.

**PID namespaces are a tree, not a flat set.** That `parent` pointer means the host can see into every container, but a container can never see out or sideways.

> **`child_reaper` is why PID 1 matters in Inception.** Your container's main process *is* the reaper. If it can't handle signals and reap children, the container ignores `docker stop` and accumulates zombies — the reason the subject bans `tail -f` and `bash` as PID 1.

<br>

## cgroups — what it uses

**Namespaces hide things but restrain nothing.** A process that only sees its own filesystem can still eat every byte of RAM on the machine — exactly the hosting problem from section 01.

**Control groups put a hard ceiling on consumption:** memory, CPU time, disk bandwidth, process count.

```bash
--memory=64m     may use 64 MB, no more
--cpus=0.5       gets half a core's worth of time
```

**Docker doesn't enforce this.** It writes a number to a file, and the **kernel** does the policing — including killing the process if it overruns.

> ⚠️ A container capped at 64 MB still reports the host's full 15 GB when asked how much memory the machine has. It has no idea it's restricted. The limit is real anyway.

<br>

**Namespaces answer** *"what world does this process live in?"*
**cgroups answer** *"how much of the real machine may it consume?"*

**A container is a process given both:** a fabricated view, and a budget.

---

# 03 · The situation that created Docker

**Everything above is plain Linux, and all of it predates Docker.** Yet almost nobody used containers, because a second problem was still wide open.

**A developer writes code. It runs perfectly on their machine.** The tester pulls it and it breaks — a missing library, a different language version, an environment variable that only exists on the first machine. Nobody can say *why*, because nobody can see the difference.

**There was no way to hand someone your exact environment.** Building a container meant assembling the filesystem by hand, choosing namespaces, wiring the network — then repeating all of it on every machine.

> **Isolation was solved. Distribution wasn't.**

**Docker's answer was the image.** Build your environment once — OS libraries, language runtime, dependencies, config — and ship it as a single artifact that runs identically anywhere.

| | |
|:--|:--|
| **Images** | a packaged filesystem you build once and ship anywhere |
| **A registry** | somewhere to publish and download them |
| **A daemon** | a background service doing the kernel work for you |
| **A CLI** | `docker run` instead of a page of manual setup |

**That's the reason "works on my machine" stopped being an excuse.**

> **In short:** containers are a Linux feature. Docker is a very good tool for using it.

---

# 04 · The image — Docker's actual invention

**Namespaces and cgroups gave isolation.** Union filesystems (AUFS, later OverlayFS) already gave **layering**. Neither belongs to Docker.

**What nobody had built was a way to name, version, and ship an environment.** That's the image:

> a layered filesystem with a manifest, identified by hash, taggable, and pushable to a registry.

**That's what made containers spread.** It has since been standardized as the **OCI Image Spec**, so images aren't Docker-owned anymore — Podman, containerd and Kubernetes all use the same format.

<br>

## Image vs container

> An **image** is a read-only filesystem.
> A **container** is that filesystem + a **writable layer** on top, with a process running in it.

Two containers started from the same image:

```
c1       8.19kB   (virtual 8.11MB)   ← wrote a file
c2       4.10kB   (virtual 8.11MB)   ← didn't
```

- **virtual 8.11MB** — the shared image. Both read the same bytes on disk. Not copied.
- **8.19kB / 4.10kB** — each container's own writable layer. Only what *it* changed.

**`c1` created `/note.txt`; `c2` never saw it.** Same image, separate writable layers.

**The mechanism is copy-on-write.** Reads fall through to the image; writes copy the file up into your own layer first. 50 containers from one image = the image stored once, plus 50 tiny diffs.

**Two consequences:**

- **Images are immutable** — nothing a container does can change its image.
- **The writable layer dies with the container** — `docker rm` deletes it. Which is exactly why volumes exist.
