# Inception — Notes

My understanding of the project. Written as I learn it.

---

## 1. What is a container?

**A container is just a normal Linux process on your kernel, with lies told to it.**

No VM, no emulation, no second kernel. `ps` on the host shows it as an ordinary process.

Two kernel features tell the lies:

- **Namespaces** — control what a process can **see** (isolation)
- **cgroups** — control what a process can **use** (limits)

### Namespaces (what it sees)

| Namespace | Isolates |
|---|---|
| pid | process IDs — the process thinks it's PID 1 |
| mnt | filesystem — sees Debian's `/`, not the host's |
| net | own `eth0`, own IP, own port space |
| uts | hostname |
| ipc | shared memory |
| user | UID/GID mapping |

Proof: `sleep 300` in a container is PID 1 inside, PID 50862 on the host. Same process.

Files: `/proc/<pid>/ns/`

### cgroups (what it uses)

`--memory=64m` writes `67108864` into `memory.max`. The **kernel** enforces it, not Docker.

Files: `/sys/fs/cgroup/system.slice/docker-<id>.scope/`

Gotcha: a container capped at 64 MB still reports 15 GB from `free`, because `/proc/meminfo` is not namespaced. The limit is real anyway.

---

## 2. What is Docker?

Docker did **not** invent containers:

- 1979 `chroot` → 2000 FreeBSD Jails → 2004 Solaris Containers → 2006 cgroups (Google) → 2008 LXC → **2013 Docker** (built on LXC at first)

What Docker actually added:

1. **Images** — layered, cacheable, shippable filesystems
2. **A daemon** — `dockerd` → `containerd` → `runc` (runc does the real syscalls)
3. **A CLI** — `docker run` instead of a dozen syscalls

---

## 3. Why this matters for Inception

- **PID 1** — the container *is* the process. PID 1 exits → namespace destroyed → container dies. So each service must run its real daemon in the foreground as PID 1. `tail -f` is banned because it's a fake PID 1 holding a namespace open around no work.
- **net namespace** — why `fastcgi_pass wordpress:9000` works (Docker DNS resolves the service name), and why unpublished ports are unreachable from outside.
- **mnt namespace** — why volumes exist. The container's filesystem dies with it unless something persistent is mounted in.
