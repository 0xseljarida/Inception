# Q&A — WordPress container

---

## 1. Packages

Why these three, and not more: `php8.2-fpm`, `php8.2-mysql`, `ca-certificates`? What breaks if you drop each one?

<details>
<summary>Answer</summary>

- **php8.2-fpm**: PHP is interpreted, not compiled. Fix the term: php-fpm is a process manager that runs PHP worker processes, and those workers execute PHP code.
- **php8.2-mysql**: right idea, more precise, it's a PHP extension (mysqli/pdo_mysql) that gives PHP the functions to speak the MySQL wire protocol to MariaDB. Without it, WordPress's DB calls are undefined functions.
- **ca-certificates**: wrong. This container does no TLS handshake with anything, nginx handles that separately. ca-certificates is here because `ADD` and `wp core download` fetch over HTTPS, it supplies the trusted CA bundle so this container's HTTPS client can verify the remote server's certificate (GitHub, wordpress.org). Drop it and `wp core download` fails cert verification, confirmed by testing.

</details>

---

## 2. php-fpm

What is php-fpm, in your own words? Is it a web server? What protocol does it speak?

<details>
<summary>Answer</summary>

Correct, keep the nuance: the master process doesn't execute PHP itself, it manages a pool of worker processes, and the workers do the executing. "FastCGI Process Manager" is literally the name.

</details>

---

## 3. wp-cli

Why is `ADD .../wp-cli.phar` there instead of `apt-get install wordpress`? What does wp-cli actually let you do that plain files on disk don't?

<details>
<summary>Answer</summary>

wp-cli is a `.phar` that loads WordPress's own PHP source directly (it bootstraps `wp-load.php`) and calls WordPress's internal functions from the shell. No HTTP request, no browser. That's what lets `entrypoint.sh` run `wp config create`, `wp core install`, `wp user create`, etc. as plain shell commands instead of clicking through the browser install wizard, which is required since nothing in this project has a human sitting at a keyboard on first boot.

</details>

---

## 4. Build time vs run time

`RUN wp core download` runs at build time. What WordPress setup step can't run at build time, and why not?

<details>
<summary>Answer</summary>

The step is `wp core install` (creating `wp-config.php` + running the actual install). It can't run at build time for two separate reasons:

- it needs DB credentials, which are secrets and don't exist during `docker build`
- it needs a live, reachable mariadb container, which doesn't exist yet either, `docker build` only ever builds one image in isolation, no other containers are running

Both are runtime facts, so this has to live in `entrypoint.sh`.

</details>

---

## 5. The COPY line

Look at line 9 of the Dockerfile: `COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www-listen.conf`. Is this correct right now? Why or why not?

<details>
<summary>Answer</summary>

Wrong, and this is the live bug. Load order is backwards.

Alphabetical load order compares characters: `-` is `0x2D`, `.` is `0x2E`. So `www-listen.conf` sorts before `www.conf`, meaning `www-listen.conf` loads first, and the shipped default `www.conf` loads last. Per the merge rule (last-loaded directive wins), `www.conf`'s original `listen = /run/php/php8.2-fpm.sock` is what actually takes effect, `0.0.0.0:9000` gets silently discarded. Confirmed with `php-fpm8.2 -tt` and a failed cross-container connect on port 9000.

Still broken in the current Dockerfile. Fix: rename the `COPY` destination to something that sorts after `www.conf`, e.g. `www2.conf` (`2` is `0x32`, sorts after `.`).

</details>

---

## 6. chown

Line 15 ends with `chown -R www-data:www-data /var/www/html`. Who is `www-data`, and what fails if that chown is missing?

<details>
<summary>Answer</summary>

`www-data` is the low-privilege system user the `php8.2-fpm` package creates on install (UID 33). Inside `www.conf` the pool has `user = www-data` / `group = www-data`, meaning php-fpm's worker processes run as www-data, not root.

But `RUN wp core download` runs during `docker build`, as root. So every downloaded WordPress file lands owned by root:root. Without the `chown -R www-data:www-data`, php-fpm workers can still read those files fine (world-readable), but can't write to them, no plugin installs, no core self-update, no file uploads to `wp-content/uploads`. It fails silently on writes only, which makes it an easy bug to miss until uploading media is attempted.

</details>
