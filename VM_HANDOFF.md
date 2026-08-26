# VM handoff

Context for a fresh Claude session running on the evaluation virtual machine.
Read this first, then run the checklist at the end. Nothing here needs to be
re-derived from the transcript of the sessions that built the project.

---

## What this project is

42 "Inception": a WordPress stack built from scratch with Docker Compose, driven
by a Makefile. Three mandatory containers plus five bonus ones.

| Service | Role | Reached at |
|:--|:--|:--|
| nginx | sole entrypoint, terminates TLS | `https://sel-jari.42.fr` (443) |
| wordpress | WordPress + php-fpm, no web server inside | through nginx, `fastcgi_pass wordpress:9000` |
| mariadb | database only | inside the network only |
| redis | object cache in front of MariaDB | inside the network only |
| adminer | web database client, php-fpm behind nginx | `https://sel-jari.42.fr/adminer/` |
| resume | static site, its own nginx | `http://sel-jari.resume.42.fr:1337` |
| netdata | monitoring dashboard | `http://localhost:19999` |
| ftp | vsftpd pointed at the WordPress volume | `ftp://127.0.0.1:21` |

Login is `sel-jari`, domain `sel-jari.42.fr`, persistent data under
`/home/sel-jari/data/`. Those strings appear in the Makefile, the compose
`device:` paths, the nginx `server_name`, and the TLS certificate.

---

## Repositories

Two, and only one is graded.

```text
~/docker/              learning repository: NOTES.md, Q_and_A.md, DEFENSE.md, CLAUDE.md, assets/
~/docker/Inception/    the graded project, pushed separately
```

`~/docker/CLAUDE.md` holds the working rules for the tutoring sessions: Claude
explains, the user writes the files. On the VM the goal is testing, not writing,
so that rule mostly stops mattering, but do not rewrite project files unless
asked.

Layout of the graded repository:

```text
Inception/
  Makefile
  README.md  USER_DOC.md  DEV_DOC.md
  .gitignore                       ignores secrets/
  secrets/                         NOT in git, must be recreated on the VM
  srcs/
    .env                           MYSQL_USER, MYSQL_DATABASE, FTP_USER
    docker-compose.yml
    requirements/{nginx,wordpress,mariadb}/
    requirements/bonus/{redis,adminer,resume,netdata,ftp}/
```

---

## First run on a clean Debian 12

**1. Docker CE, not Docker Desktop.** Desktop was deliberately removed on the
development machine: it runs the daemon inside its own VM, where
`device=/home/sel-jari/data/...` would resolve somewhere else and break the
required volume setup. Install `docker-ce`, `docker-ce-cli`, `containerd.io`,
`docker-compose-plugin` from Docker's apt repository, then
`sudo usermod -aG docker $USER` and log out and back in.

**2. Recreate `secrets/`.** The directory is gitignored, so a fresh clone has
none of it. Four files, one value per file, no trailing spaces:

```text
secrets/db_password.txt        password of the MariaDB account wp_user
secrets/db_root_password.txt   password of root@localhost in MariaDB
secrets/credentials.txt        two lines: ADMIN_PASSWORD=... and USER_PASSWORD=...
secrets/ftp_password.txt       password of the FTP account
```

`DEV_DOC.md` documents this too. Nothing else in the repository holds a
password.

**3. Map the domains.**

```bash
make hosts        # appends 127.0.0.1 sel-jari.42.fr sel-jari.resume.42.fr, needs sudo
```

Kept out of `make all` on purpose, so starting the stack never asks for a root
password. The rule is guarded by `grep -qF`, so running it twice is safe.

**4. Start.**

```bash
make              # mkdir the two data directories, then compose up -d --build
```

First run takes a few minutes: images build, MariaDB initialises its datadir,
WordPress installs itself through wp-cli.

---

## Makefile targets

| Target | Effect |
|:--|:--|
| `make` / `make up` | create the data directories, build, start detached |
| `make hosts` | add the `/etc/hosts` line, needs sudo, idempotent |
| `make ps` `make logs` | status, follow logs |
| `make stop` `make start` | stop and restart containers, data kept |
| `make down` `make re` | remove containers, recreate |
| `make clean` | `down` plus removal of the locally built images |
| `make fclean` | `clean` plus `down -v` plus `sudo rm -rf /home/sel-jari/data/*` |

`fclean` needs sudo because files inside the volumes belong to the container
users, `mysql` and `www-data`, not to the host account.

---

## Known traps, all hit at least once

**A host FTP server steals port 21.** If vsftpd was ever installed on the host,
Debian enables it at boot and the ftp container fails with
`failed to bind host port 0.0.0.0:21/tcp: address already in use`. Fix:
`sudo systemctl disable --now vsftpd`. `disable` as well as `stop`, or it comes
back at the next boot.

**A container that failed to start keeps no port bindings.** After such a
failure, `docker compose up -d` restarts it without publishing anything:
`docker port srcs-ftp-1` prints nothing while the process inside listens fine.
Fix: `docker compose -f srcs/docker-compose.yml up -d --force-recreate ftp`.

**nginx resolves upstream names once, at config-parse time.** Recreating the
wordpress or adminer container gives it a new bridge IP, and nginx keeps calling
the old one: `502` with `connect() failed (111: Connection refused)` in the
error log. Fix: restart nginx after recreating an upstream. Worth knowing at the
defense, it is not a bug in the configuration.

**The certificate is self-signed**, so every browser warns and every `curl`
needs `-k`. There is no certificate authority in this project.

**Do not test PID 1 with `pid: host` in play.** Nothing uses it now, but
`/proc/1/comm` would then show the host's init. `docker inspect --format
'{{.Path}} {{.Args}}'` is the check that always tells the truth.

---

## Verification checklist

Run from `~/docker/Inception`. This is the full sweep; it was green on the
development machine on 2026-08-26 except where noted.

**Cold boot from nothing.**

```bash
make fclean && make && sleep 90 && make ps
```

All eight containers `running`, and `docker ps --format '{{.Names}} {{.Status}}'`
must show no restart counter climbing.

**PID 1 in every container.**

```bash
for c in mariadb wordpress nginx redis adminer resume netdata ftp; do
  printf '%-10s ' $c; docker exec srcs-$c-1 cat /proc/1/comm
done
```

Expected: `mariadbd`, `php-fpm8.2`, `nginx`, `redis-server`, `php-fpm8.2`,
`nginx`, `netdata`, `vsftpd`. A shell anywhere is a failure.

**Every web endpoint.**

```bash
curl -sk -o /dev/null -w 'wordpress %{http_code}\n' https://sel-jari.42.fr/
curl -sk -o /dev/null -w 'wp-admin  %{http_code}\n' https://sel-jari.42.fr/wp-admin/
curl -sk -o /dev/null -w 'adminer   %{http_code}\n' https://sel-jari.42.fr/adminer/
curl -s  -o /dev/null -w 'resume    %{http_code}\n' http://localhost:1337/
curl -s  -o /dev/null -w 'netdata   %{http_code}\n' http://localhost:19999/
```

`200` everywhere except `wp-admin`, which is `302` to the login page.

**TLS versions.** Port 80 must be refused, 1.1 must fail, 1.2 must work.

```bash
curl -k --tls-max 1.1 https://sel-jari.42.fr    # expect failure
curl -k --tls-max 1.2 -o /dev/null -sw '%{http_code}\n' https://sel-jari.42.fr
curl -s http://sel-jari.42.fr                    # expect connection refused
```

Use `--tls-max`, never `--tlsv1.1`: the latter sets the minimum and happily
negotiates 1.3, proving nothing.

**Database.**

```bash
docker exec -it srcs-mariadb-1 mariadb -u wp_user -p wordpress -e "SHOW TABLES;"
```

Twelve tables on a healthy install.

**Redis object cache.**

```bash
docker exec srcs-wordpress-1 wp redis status --allow-root
```

`Status: Connected`, `Drop-in: Valid`. `docker exec srcs-redis-1 redis-cli dbsize`
should be non-zero after browsing the site.

**FTP, the one with moving parts.** Passive mode is the part to demonstrate.

```bash
python3 - <<'PY'
from ftplib import FTP
import io
pw = open('secrets/ftp_password.txt').read().strip()
f = FTP(); f.connect('127.0.0.1', 21, timeout=10)
print(f.login('ftp_user', pw))
f.set_pasv(True)
print(sorted(f.nlst())[:5])
print(f.storbinary('STOR ftp-probe.txt', io.BytesIO(b'uploaded through ftp\n')))
f.retrlines('LIST ftp-probe.txt')
f.quit()
PY
curl -sk -o /dev/null -w 'uploaded file through nginx: %{http_code}\n' https://sel-jari.42.fr/ftp-probe.txt
```

`230 Login successful`, `226 Transfer complete`, then `200` from nginx. If the
file lists as `-rw-------` and nginx answers `403`, `local_umask=022` is missing
from `srcs/requirements/bonus/ftp/conf/vsftpd.conf`. **Delete the probe file
afterwards:** `docker exec srcs-ftp-1 rm -f /var/www/html/ftp-probe.txt`.

**Persistence.** Data must survive container removal and reappear identically.

```bash
make down && make up && sleep 30
curl -sk -o /dev/null -w '%{http_code}\n' https://sel-jari.42.fr/   # still 200
ls /home/sel-jari/data/wordpress                                    # wp-config.php, wp-content
sudo ls /home/sel-jari/data/mariadb                                 # ibdata1, mysql/, wordpress/
```

**Subject compliance, mechanical checks.**

```bash
grep -rn "latest" srcs/requirements/*/Dockerfile srcs/requirements/bonus/*/Dockerfile
grep -rniE "network: *host|--link|links:" srcs/docker-compose.yml
grep -rniE "tail -f|sleep infinity|while true" srcs/
git ls-files | grep -i secret            # must print nothing
git log --all --name-only | grep -i secret
```

All five must come back empty. The last two are the ones that fail the project
outright if they do not.

---

## Defense material

`~/docker/DEFENSE.md` holds the prepared arguments, currently the netdata
section: why it was chosen, what it demonstrates live, and the measurement
showing a container reads host metrics from `/proc` and `/sys` without any mount,
because those files are not namespaced and the OCI runtime spec mounts them by
default. Sections for the other containers are still to be written.

`~/docker/NOTES.md` is the long-form study document, section `13` covers the
bonus containers. The FTP part contains the passive-mode explanation, the
directive-by-directive table for `vsftpd.conf`, and a deep dive on chroot and
privilege separation.

---

## State at handoff, 2026-08-26

**Done and verified on the development machine:** all eight containers build and
run, cold boot clean, every endpoint answers, redis caching confirmed, adminer
reaches MariaDB as `wp_user`, FTP login and upload work through passive mode.

**Open items:**

* `local_umask=022` in the ftp `vsftpd.conf`, without which uploads are mode
  `600` and nginx answers `403` on them. Measured, not yet fixed.
* `DEFENSE.md` covers netdata only.
* `README.md`, `USER_DOC.md`, `DEV_DOC.md` do not yet mention the ftp service.
* The resume site's navigation was never finished.
* `Inception/.gitignore` exists and is correct, but confirm it is committed
  before anything else on the VM.
