<h1 align="center">Inception — Notes</h1>
<p align="center"><i>My understanding of the project. Written as I learn it.</i></p>

---

## 01 · What is a container?

> **A container is just a normal Linux process on your kernel, with lies told to it.**

No VM. No emulation. No second kernel. `ps` on the host shows an ordinary process.

Two kernel features tell the lies:

| | Controls | Purpose |
|:--|:--|:--|
| **Namespaces** | what a process can **see** | isolation |
| **cgroups** | what a process can **use** | limits |

<br>

### Namespaces — what it sees

`/proc/<pid>/ns/`

| | Isolates |
|:--|:--|
| `pid` | process IDs — thinks it's PID 1 |
| `mnt` | filesystem — sees Debian's `/`, not the host's |
| `net` | own `eth0`, own IP, own port space |
| `uts` | hostname |
| `ipc` | shared memory |
| `user` | UID / GID mapping |

```
inside container         on host
─────────────────        ─────────────────
PID 1  sleep 300    ═══  PID 50862  sleep 300
```

Same process. Two numbers.

<br>

### cgroups — what it uses

`/sys/fs/cgroup/system.slice/docker-<id>.scope/`

```bash
--memory=64m   →   memory.max   67108864
--cpus=0.5     →   cpu.max      50000 100000
```

The **kernel** enforces this, not Docker.

> ⚠️ A container capped at 64 MB still reports 15 GB from `free` — `/proc/meminfo` isn't namespaced. The limit is real anyway.

---

## 02 · What is Docker?

Docker did **not** invent containers.

```
1979  chroot
2000  FreeBSD Jails
2004  Solaris Containers
2006  cgroups (Google)
2008  LXC
2013  Docker  ← built on LXC at first
```

What it actually added:

| | |
|:--|:--|
| **Images** | layered, cacheable, shippable filesystems |
| **A daemon** | `dockerd` → `containerd` → `runc` |
| **A CLI** | `docker run` instead of a dozen syscalls |

`runc` does the real syscalls.
