# Developer documentation

How to set up a machine from nothing, how the stack is built, and how the state
is stored.

Reference environment: Debian 12 Bookworm, Docker CE 29.7.2, Docker Compose
plugin v5.4.0. Use `docker compose`, never `docker-compose`.

---

## Environment setup from scratch

### 1. Install Docker Engine

Docker Desktop is deliberately not used. It runs the engine inside a Linux VM,
so `device: /home/sel-jari/data/...` in the volume definitions would resolve
inside that VM and not on the real filesystem, which breaks the required volume
setup. Install Docker CE directly:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Check the context and the socket:

```bash
docker context ls          # default must be selected
docker info | grep -i 'server version'
```

`DOCKER_HOST` must be `unix:///var/run/docker.sock`.

### 2. Let your user talk to the daemon

```bash
sudo usermod -aG docker $USER
newgrp docker      # or log out and back in
docker run --rm debian:bookworm true
```

### 3. Map the domain

```bash
make hosts                          # appends the line, guarded, asks for sudo
getent hosts sel-jari.42.fr
getent hosts sel-jari.resume.42.fr
```

The target is deliberately not a prerequisite of `up`: `make` must never ask for
a root password just to start containers. The guard is a `grep -qF` on the
resume domain, so the rule is idempotent.

`/etc/hosts` is consulted before DNS, so the request never leaves the machine.

### 4. Recreate the secrets

`secrets/` is gitignored, so a fresh clone cannot start until the three files
exist. Create them, then never commit them:

```bash
mkdir -p secrets

printf '%s' 'CHOOSE_A_DB_PASSWORD'      > secrets/db_password.txt
printf '%s' 'CHOOSE_A_ROOT_PASSWORD'    > secrets/db_root_password.txt

cat > secrets/credentials.txt <<'CRED'
ADMIN_PASSWORD=CHOOSE_A_WP_ADMIN_PASSWORD
USER_PASSWORD=CHOOSE_A_WP_USER_PASSWORD
CRED

chmod 600 secrets/*.txt
```

Rules that the file formats impose:

- `db_password.txt` and `db_root_password.txt` hold **the password and nothing
  else**. Use `printf`, not `echo`: a trailing newline becomes part of the
  password, since the entrypoint reads the file with `cat`.
- `credentials.txt` is sourced as a shell script by the WordPress entrypoint, so
  it must be valid `KEY=value` shell assignments with those exact two names. Quote
  the value if it contains spaces or shell metacharacters.

Verify `.gitignore` still covers the directory before committing anything:

```bash
git check-ignore -v secrets/db_password.txt      # must print a match
git status --short                               # secrets/ must not appear
```

### 5. Non-secret configuration

`srcs/.env`, which **is** committed, holds only what is not confidential:

```ini
MYSQL_USER=wp_user
MYSQL_DATABASE=wordpress
```

Compose loads it through `env_file:` into the mariadb and wordpress containers.
Changing `MYSQL_DATABASE` or `MYSQL_USER` after the first start has no effect:
both are consumed only during first-boot initialisation, and the guard in the
MariaDB entrypoint skips that on later starts. To really change them, run `make
fclean` first.

---

## Building and launching

The chain the subject requires is Makefile → Compose → Dockerfiles. Nothing is
built with a bare `docker build`.

```text
make
 └── docker compose -f srcs/docker-compose.yml up -d --build
      ├── build ./requirements/mariadb          -> image mariadb:1.0
      ├── build ./requirements/wordpress        -> image wordpress:1.0
      ├── build ./requirements/nginx            -> image nginx:1.0
      ├── build ./requirements/bonus/redis      -> image redis:1.0
      ├── build ./requirements/bonus/adminer    -> image adminer:1.0
      ├── build ./requirements/bonus/resume     -> image resume:1.0
      └── build ./requirements/bonus/netdata    -> image netdata:1.0
```

Three services are mandatory and four are bonus. Every one of them is built from
its own Dockerfile on `debian:bookworm`, and no image is pulled ready made.

### Makefile targets

| Target | Command behind it |
|---|---|
| `all`, `up` | create the data directories, then `up -d --build` |
| `down` | `down` |
| `stop` / `start` | `stop` / `start` |
| `re` | `down` then `up` |
| `logs` | `logs -f` |
| `ps` | `ps` |
| `clean` | `down`, then `down --rmi local` |
| `fclean` | `clean`, `down -v`, `sudo rm -rf` the data directories |

`up` depends on `$(VOLUMES)`, which are **real directory targets, not phony
ones**:

```make
VOLUMES = $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

$(VOLUMES):
	mkdir -p $@

up: $(VOLUMES)
	$(COMPOSE) up -d --build
```

Make only runs a rule whose target does not exist, so `mkdir -p` runs on the
first `make` and never again. This matters: with `type: none, o: bind`, the
mount fails outright if the host directory is missing, so it must exist before
Compose starts.

`fclean` is the only place `sudo` appears, and it is justified: the files inside
the volumes were written by the container users, `mysql` (uid 999) and
`www-data` (uid 33), so your account cannot delete them.

### Build order and caching

Compose builds all seven services, then starts them in `depends_on` order:

```text
mariadb, redis  ->  wordpress, adminer  ->  nginx
resume, netdata     (no dependencies, started whenever Compose reaches them)
```

nginx comes last because it resolves both `fastcgi_pass wordpress:9000` and
`fastcgi_pass adminer:9000` when it parses its configuration, and refuses to
start if either name does not exist yet.

`depends_on` waits for the container to be *started*, not for the service inside
it to be *ready*, which is why the WordPress entrypoint polls the MariaDB port
itself before doing anything.

Layer caching follows Dockerfile order: a changed `COPY` invalidates every layer
after it. In the nginx Dockerfile, the certificate `RUN` is the expensive step,
so keeping `COPY conf/default.conf` after it means editing the server block does
not regenerate the key pair.

To force a full rebuild:

```bash
docker compose -f srcs/docker-compose.yml build --no-cache
```

The WordPress image downloads wp-cli from GitHub with `ADD` and then runs `wp
core download`, so building it needs working network access.

### Image names

Each service declares `image: <name>:1.0`, matching its service name. Without
`image:`, Compose would name a built image `<project>-<service>`, and the
evaluation requires the image name to equal the service name. The tag is `1.0`
and never `latest`: `latest` is only the default tag string Docker appends when
no tag is given, it does not mean "newest", and the subject prohibits it.

---

## Container management

```bash
# state
make ps
docker compose -f srcs/docker-compose.yml ps -a

# logs, one service or all
docker compose -f srcs/docker-compose.yml logs -f wordpress

# a shell inside a container
docker exec -it srcs-wordpress-1 bash
docker exec -it srcs-mariadb-1 mariadb -u root -p

# restart one service
docker compose -f srcs/docker-compose.yml restart nginx

# rebuild and replace one service only
docker compose -f srcs/docker-compose.yml up -d --build nginx

# what is PID 1
docker exec srcs-nginx-1 cat /proc/1/comm
```

`stop` and `rm` are different things:

```text
running --stop--> exited --rm--> gone
```

`stop` sends SIGTERM to PID 1 and the container stays in `Exited`; `rm` deletes
the container object and its writable layer. `docker rmi` refuses an image while
a container still references it, so remove the container first.

### PID 1 and signals

Every container runs a real foreground daemon as PID 1: `nginx -g "daemon
off;"`, `php-fpm8.2 -F`, `mariadbd --user=mysql`. Both entrypoint scripts end
with `exec "$@"`, which replaces the shell's process image with the daemon while
keeping PID 1, so `docker stop` delivers SIGTERM to the daemon itself and the
shutdown is clean. Without `exec`, the shell would stay PID 1, ignore SIGTERM,
and every stop would take the full ten-second timeout before SIGKILL.

No `tail -f`, `sleep infinity`, `while true` or bare `bash` is used anywhere,
including inside the entrypoints.

### Configuration details worth knowing

- **nginx** resolves the `fastcgi_pass wordpress:9000` hostname at configuration
  parse time, not per request. If the WordPress container is absent, nginx
  refuses to start with `host not found in upstream`.
- The Debian nginx package ships `sites-enabled/default`, which owns port 80 as
  `default_server`. The Dockerfile deletes that symlink rather than editing
  `nginx.conf`.
- Debian's `nginx.conf` explicitly sets `ssl_protocols TLSv1 TLSv1.1 TLSv1.2
  TLSv1.3`, so the server block overrides it with `TLSv1.2 TLSv1.3`.
- **php-fpm** loads `pool.d/*.conf` in glob order and pool sections with the same
  name merge, last value winning. `www2.conf` re-declares `[www]` with
  `listen = 0.0.0.0:9000`, overriding the packaged unix socket without editing the
  packaged file.
- **MariaDB** reads `mariadb.conf.d/*.cnf` the same way; `99-inception.cnf` sets
  `bind-address = 0.0.0.0` so the server accepts connections from the Docker
  network, and `skip-name-resolve` so it does not try a reverse DNS lookup on
  every connection.
- There is no init system in a container, so nothing recreates `/run`. The
  MariaDB entrypoint has to `mkdir -p /run/mysqld` and chown it itself.

### The bonus services

- **redis** runs with no configuration file at all. `redis-server` reads
  `/etc/redis/redis.conf` only when the path is passed as its first argument, so
  giving none makes it start from built-in defaults, which is what avoids the
  packaged `daemonize yes` and `bind 127.0.0.1`. The cache policy is set on the
  command line instead: `--maxmemory 256mb --maxmemory-policy allkeys-lru`.
- **The WordPress side of redis** is three commands in the entrypoint, inside the
  first-boot guard and after `wp core install`: install and activate the
  `redis-cache` plugin, set `WP_REDIS_HOST`, then `wp redis enable`, which writes
  the `wp-content/object-cache.php` drop-in. Running them before `wp core install`
  fails with `Error: The site you have requested is not installed.`
- **adminer** is a single PHP file served by php-fpm, with no web server of its
  own. The mandatory nginx routes to it with `location ^~ /adminer/`. The `^~`
  matters: nginx checks regex locations before prefix ones, so without it
  `/adminer/index.php` would match `location ~ \.php$` and be sent to the
  WordPress container instead.
- **resume** bakes its files into the image with `COPY ./srcs/ /var/www/static`
  rather than mounting a volume, because a static site has no runtime state.
  Copy the directory, not `srcs/*`, since the glob flattens subdirectories: with
  `srcs/*` a file at `srcs/css/style.css` lands at `/var/www/static/style.css`
  and every stylesheet link returns 404.
- **netdata** declares no mounts and no environment variables, which is
  deliberate. Its own documentation asks for the host's `/proc` and `/sys` to be
  bind mounted in with `NETDATA_HOST_PREFIX=/host`, but measuring on this host
  showed the identical 257 charts, including the host disk and the laptop
  battery, with and without them. Docker already bind mounts the host's `sysfs`
  into every container, and `/proc/stat`, `/proc/meminfo` and `/proc/uptime` are
  not namespaced, so the data was never hidden. Its config file must carry
  `run as user = netdata`, since `COPY` replaces the packaged file wholesale and
  the internal fallback user, `nobody`, cannot write `/var/lib/netdata`.
- **netdata is deliberately host-wide, not per container.** Breaking metrics down
  per container requires mounting `/var/run/docker.sock` and setting `pid: host`,
  which are the two heaviest privileges available in a Compose file: a writable
  Docker socket is effectively root on the host, and `:ro` does not restrain it,
  since a socket is used by sending on it rather than by writing the file. That
  cost was not worth a cosmetic gain, so the feature was dropped and the container
  keeps only read-only access to `/proc` and `/sys`.

---

## Volume management

```bash
docker volume ls
docker volume inspect srcs_mariadb_volume
docker volume inspect srcs_wordpress_volume | grep -i device
```

Compose prefixes volume names with the project name, which is the directory
holding the Compose file, so `mariadb_volume` becomes `srcs_mariadb_volume`.

Removing them:

```bash
docker compose -f srcs/docker-compose.yml down       # containers only, volumes kept
docker compose -f srcs/docker-compose.yml down -v    # volumes removed too
sudo rm -rf /home/sel-jari/data/mariadb /home/sel-jari/data/wordpress
```

`down -v` removes the Docker volume objects, but with `type: none, o: bind` the
files stay on the host: the volume is only a mount definition pointing at a
directory Docker did not create. That is why `make fclean` deletes the
directories explicitly. Forgetting the second half is the classic trap, since the
next `make up` then finds a populated datadir, the entrypoint guards skip
initialisation, and the old database comes back with the old password.

---

## Where the persistent data lives

```text
/home/sel-jari/data/
├── mariadb/       <- srcs_mariadb_volume    -> /var/lib/mysql
│   ├── mysql/                system tables
│   ├── wordpress/            the project database
│   └── ibdata1, ib_logfile*  InnoDB
└── wordpress/     <- srcs_wordpress_volume  -> /var/www/html
    ├── wp-config.php         generated on first boot by wp-cli
    ├── wp-content/           themes, plugins, uploads
    └── wp-admin/, wp-includes/, index.php, ...
```

`wordpress_volume` is mounted into **two** containers: php-fpm executes the PHP
files, nginx serves the static ones from the same bytes. This is why nginx needs
no copy of the site and why `root /var/www/html/` in the server block points at
the same directory `SCRIPT_FILENAME` resolves against.

---

## How persistence works

```text
container writes to /var/lib/mysql
        │
        ▼
  mount namespace: the path is a bind mount
        │
        ▼
  /home/sel-jari/data/mariadb on the host filesystem
```

A container's writable layer is deleted with the container. Anything that must
outlive it has to be written under a mount point, and both mount points here are
named volumes whose backing store is a host directory.

The consequence is that **removing a container never loses data, and the second
boot is not the first boot**. Both entrypoints are written for that:

```bash
# mariadb
if [ ! -d "/var/lib/mysql/mysql" ]; then   # system tables absent -> first boot
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    ...
    exec "$@" --init-file=/tmp/init.sql
fi
exec "$@"
```

```bash
# wordpress
if [ ! -f "/var/www/html/wp-config.php" ]; then   # not installed -> first boot
    wp config create ...
    wp core install ...
fi
exec "$@"
```

The guards are what make `restart: unless-stopped` safe: a container that
crashes and restarts finds the state already there, skips initialisation, and
does not recreate the database or reset the WordPress users.

To prove persistence:

```bash
make down
make up
curl -k https://sel-jari.42.fr        # the same site, the same posts, the same users
```

To prove a clean first boot still works, `make fclean` and then `make`.
