# Developer documentation

How to set up a machine from nothing, how the stack is built, and where the state
lives.

Reference environment: Debian 12 Bookworm, Docker CE 29.7.2, Docker Compose
plugin v5.5.0. Use `docker compose`, never `docker-compose`.

---

## Environment setup from scratch

### 1. Install Docker Engine

Do not use Docker Desktop here. It runs the engine inside a Linux VM, so
`device: /home/login/data/...` would resolve inside that VM rather than on the
real filesystem, and the volume setup the subject asks for would break. Install
Docker CE directly:

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

`docker context ls` must show `default` selected, with `DOCKER_HOST` at
`unix:///var/run/docker.sock`.

### 2. Let your user talk to the daemon

```bash
sudo usermod -aG docker $USER
newgrp docker      # or log out and back in
docker run --rm debian:bookworm true
```

### 3. Map the domains

```bash
make hosts                          # appends the line, guarded, asks for sudo
getent hosts login.42.fr login.resume.42.fr
```

`hosts` is kept out of `up` on purpose, because `make` should never ask for a
root password just to start containers. The rule guards itself with `grep -qF`,
so running it again does nothing.

### 4. Recreate the secrets

`secrets/` is gitignored, so a fresh clone has none of it and will not start
until these three files exist:

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

Two things the formats care about:

- `db_password.txt` and `db_root_password.txt` hold **the password and nothing
  else**. Use `printf` rather than `echo`, because the entrypoint reads the file
  with `cat` and a trailing newline would become part of the password.
- `credentials.txt` is *sourced as a shell script* by the WordPress entrypoint, so
  it has to be valid `KEY=value` assignments using those exact two names. Quote
  the value if it contains spaces or shell metacharacters: an unquoted `;` or `$@`
  gets executed, and the container dies with exit 127.

Before you commit anything, check that the gitignore still covers it:

```bash
git check-ignore -v secrets/db_password.txt      # must print a match
git status --short                               # secrets/ must not appear
```

### 5. Recreate the non-secret configuration

```bash
cat > srcs/.env <<'ENV'
MYSQL_USER=wp_user
MYSQL_DATABASE=wordpress
ENV
```

There is no password in here. It stays out of git anyway, so that a credential
added to it later cannot leak through a file git is already tracking.

Compose loads it with `env_file:` into mariadb and wordpress. Changing either
value after the first start does nothing, because both are read only during
first-boot initialisation and the entrypoint guard skips that afterwards. To
really change them, `make fclean` first.

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

Every one of them is built from `debian:bookworm` by its own Dockerfile. No image
is pulled ready-made.

| Target | Command behind it |
|---|---|
| `all`, `up` | create the data directories, then `up -d --build` |
| `down` | `down` |
| `stop` / `start` | `stop` / `start` |
| `re` | `down` then `up` |
| `logs` / `ps` | `logs -f` / `ps` |
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
first `make` and never again. That matters: with `type: none, o: bind`, the mount
fails outright if the host directory is missing.

`fclean` is the only target that needs `sudo`, and it needs it for a real reason.
The files in the volumes belong to `mysql` (uid 999) and `www-data` (uid 33), so
your own account cannot delete them.

### Start order

Compose starts them in `depends_on` order:

```text
mariadb, redis  ->  wordpress, adminer  ->  nginx
resume, netdata        (no dependencies)
```

nginx comes last because it resolves `fastcgi_pass wordpress:9000` and
`fastcgi_pass adminer:9000` when it *parses* its configuration, and refuses to
start if either name is missing.

`depends_on` only waits for a container to be *started*, not *ready*. That is why
the WordPress entrypoint polls the MariaDB port itself before doing anything.

### Caching

A changed `COPY` invalidates every layer after it. In the nginx Dockerfile the
certificate `RUN` is the expensive step, so keeping `COPY conf/default.conf`
after it means editing the server block does not regenerate the key pair. Force
a full rebuild with `build --no-cache`.

### Image names

Each service declares `image: <name>:1.0`, matching its service name. Without
`image:`, Compose would call it `<project>-<service>`, and the evaluation wants
the two to match. The tag is `1.0` and never `latest`, which is only the default
tag string Docker appends when you give none. It does not mean "newest", and the
subject prohibits it.

---

## Managing containers

```bash
make ps                                                        # state
docker compose -f srcs/docker-compose.yml logs -f wordpress    # logs
docker exec -it srcs-wordpress-1 bash                          # a shell inside
docker exec -it srcs-mariadb-1 mariadb -u root -p              # a SQL prompt
docker compose -f srcs/docker-compose.yml restart nginx        # restart one
docker compose -f srcs/docker-compose.yml up -d --build nginx  # rebuild one
docker exec srcs-nginx-1 cat /proc/1/comm                      # what is PID 1
```

`stop` and `rm` are not the same thing: `running --stop--> exited --rm--> gone`.
`stop` sends SIGTERM to PID 1 and leaves the container `Exited`, while `rm`
deletes the container object and its writable layer. `docker rmi` refuses an
image while a container still references it, so remove the container first.

### PID 1 and signals

Every container runs a real foreground daemon as PID 1:
`nginx -g "daemon off;"`, `php-fpm8.2 -F`, `mariadbd --user=mysql`. Both
entrypoints end with `exec "$@"`, which replaces the shell's process image with
the daemon while keeping PID 1, so `docker stop` delivers SIGTERM to the daemon
itself. Without `exec`, the shell would stay PID 1, ignore SIGTERM, and every
stop would burn the full ten-second timeout before SIGKILL.

No `tail -f`, `sleep infinity`, `while true` or bare `bash` appears anywhere,
entrypoints included.

## Managing volumes

```bash
docker volume ls
docker volume inspect srcs_wordpress_volume | grep -i device
docker compose -f srcs/docker-compose.yml down       # containers only, volumes kept
docker compose -f srcs/docker-compose.yml down -v    # volume objects removed too
sudo rm -rf /home/login/data/mariadb /home/login/data/wordpress
```

Compose prefixes volume names with the project name, the directory holding the
Compose file, so `mariadb_volume` becomes `srcs_mariadb_volume`.

`down -v` removes the Docker volume objects, but with `type: none, o: bind` the
files stay on the host. The volume is only a mount definition pointing at a
directory Docker never created, which is why `make fclean` deletes the
directories explicitly.

Forgetting that second half is the trap everyone hits once: the next `make up`
finds a populated datadir, the guards skip initialisation, and the old database
comes back with the old password.

---

## Where the data lives, and how it persists

```text
/home/login/data/
├── mariadb/       <- srcs_mariadb_volume    -> /var/lib/mysql
│   ├── mysql/                system tables
│   ├── wordpress/            the project database
│   └── ibdata1, ib_logfile*  InnoDB
└── wordpress/     <- srcs_wordpress_volume  -> /var/www/html
    ├── wp-config.php         generated on first boot by wp-cli
    ├── wp-content/           themes, plugins, uploads
    └── wp-admin/, wp-includes/, index.php, ...
```

A container's writable layer is deleted with the container, so anything that must
outlive it is written under a mount point:

```text
container writes /var/lib/mysql
   -> mount namespace: that path is a bind mount
   -> /home/login/data/mariadb on the host filesystem
```

`wordpress_volume` is mounted into **two** containers: php-fpm executes the PHP
files and nginx serves the static ones from the same bytes. That is why nginx
needs no copy of the site, and why `root /var/www/html/` points at the same
directory `SCRIPT_FILENAME` resolves against.

Because removing a container never loses the data, the second boot is not the
first boot. Both entrypoints are written with that in mind:

```bash
# mariadb
if [ ! -d "/var/lib/mysql/mysql" ]; then          # system tables absent -> first boot
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    exec "$@" --init-file=/tmp/init.sql
fi
exec "$@"

# wordpress
if [ ! -f "/var/www/html/wp-config.php" ]; then   # not installed -> first boot
    wp config create ... && wp core install ...
fi
exec "$@"
```

Those guards are what make `restart: unless-stopped` safe. A container that
crashes and comes back finds the state already there, skips initialisation, and
does not recreate the database or reset the WordPress users.

```bash
make down && make up
curl -k https://login.42.fr        # same site, same posts, same users
```

And `make fclean` followed by `make` proves a clean first boot still works.
