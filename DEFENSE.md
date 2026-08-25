# Defense notes

**Arguments prepared for the defense, one section per container.**

---

## netdata

**The claim to defend:** the netdata container declares no volumes, no bind mounts, and no environment variables, yet its dashboard shows the host's CPU, memory, disk, and network. Nothing was handed to it.

**The question an evaluator asks:** "How can it see the host if you mounted nothing?"

---

### The answer, in one sentence

**A container is isolated in what it can change, far more than in what it can see.** The kernel wide files under `/proc`, and the whole of `/sys`, are available to every container by default, because they describe the kernel and there is only one kernel.

---

### Three arguments

**The strongest argument is that a whole tool exists to fix it.** LXCFS is a filesystem whose entire purpose is to overlay container aware versions of exactly these files. Its README lists them: `/proc/cpuinfo`, `/proc/diskstats`, `/proc/meminfo`, `/proc/stat`, `/proc/swaps`, `/proc/uptime`, and says the point is to make values "really reflect how long the container is running and not how long the host is running". If those files were already namespaced, LXCFS would have nothing to do.

**The second is the OCI runtime spec**, which Docker implements through runc. Its Linux mount example gives the container a real `proc` and a real `sysfs`:

```json
{ "destination": "/proc", "type": "proc",  "source": "proc"  },
{ "destination": "/sys",  "type": "sysfs", "source": "sysfs" }
```

Not a filtered view, the actual filesystems. Namespacing affects which `/proc/<pid>` entries are listed, not the kernel wide files.

**The third is what you can demonstrate live**, which is usually what wins a defense: run `head -1 /proc/stat` on the host and inside the container and show the same counters.

---

### The live demonstration

```bash
head -1 /proc/stat
docker exec srcs-netdata-1 head -1 /proc/stat
```

Both print the same counters, a few clock ticks apart:

```text
host       cpu  2513777 554938 916969 37368567 96461 0 36960 0 0 0
container  cpu  2513781 554944 916972 37368590 96461 0 36960 0 0 0
```

**Then show that nothing was configured to allow it:**

```bash
docker exec srcs-netdata-1 cat /proc/self/mountinfo | awk '$5=="/proc" || $5=="/sys"'
cat /etc/docker/daemon.json          # does not exist, so these are stock defaults
```

```text
/proc  proc   rw
/sys   sysfs  ro
```

---

### The measurement behind the decision

**netdata's own documentation asks for the host `/proc` and `/sys` to be bind mounted in, with `NETDATA_HOST_PREFIX=/host`.** That was tried, then tested against the alternative. Three variants of the same image, each given twelve seconds to settle, then asked for its chart list:

```text
no mounts, no prefix     charts=257   battery=7   sda=5
mounts, NO prefix        charts=257   battery=7   sda=5
mounts + prefix          charts=257   battery=7   sda=5
```

**Identical, including the host's disk `sda` and the laptop battery `BAT0`.** So the mounts were removed. Keeping configuration that demonstrably does nothing means keeping something that has to be defended for no benefit.

**Where they would matter:** a host that masks `/proc` and `/sys` more aggressively than Docker's default, which is the situation netdata's documentation is written against.

---

### What differs on the evaluation VM

**The mechanism is the OCI default, not something about this laptop**, so a fresh Debian 12 with Docker CE behaves the same. Three things will look different, none of them failures:

| On this laptop | On a VM |
|:--|:--|
| `powersupply.capacity` for `BAT0` | absent, a VM has no battery |
| `disk.sda` | possibly `disk.vda` under virtio |
| 257 charts | a different number |

---

### Sources

* https://github.com/lxc/lxcfs (README, list of virtualized files)
* https://linuxcontainers.org/lxcfs/introduction/
* https://github.com/opencontainers/runtime-spec/blob/main/config.md
