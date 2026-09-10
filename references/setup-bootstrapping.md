# Invision Community 4: Setup & Bootstrapping of a Fresh Installation

Everything below is verified against IC4 4.7.25 (build 107850) on the canonical dev
stack (docker-compose: nginx + php-fpm 8.2 + MariaDB 11.4 + Redis 7.2). The copy-ready
stack files live in `assets/dev-stack/` (compose file, PHP image, nginx vhost,
prepare script, license bypass).

A "fresh installation" means: IC4 source + running stack + a completed web installer
run (system check → license → applications → DB → admin) + the fixed development
credentials below. The goal state is: HTTP 200 on the front, ACP reachable, and the
fixed credentials working — so app/plugin development can start without
re-answering any of the setup questions.

---

## 1. Anatomy of the dev stack

Four containers (names fixed — tooling and scripts rely on them):

| Container | Image | Role |
|---|---|---|
| `ic4-web` | `nginx:1.27-alpine` | Site front on **:8080** (front, installer, ACP) |
| `ic4-php` | `ic4-dev-php:8.2` (built from `assets/dev-stack/php/Dockerfile`) | PHP-FPM, internal :9000 |
| `ic4-db` | `mariadb:11.4` | DB `ic4`, published 127.0.0.1:3306 |
| `ic4-redis` | `redis:7.2-alpine` | Cache, published 127.0.0.1:6379 |

Key structural facts (get these wrong and the stack looks up but IC4 misbehaves):

- **The IC4 source is a bind mount, not an image layer.** It is mounted
  **read-only into `web`** and **read-write into `php`** at `/var/www/html`.
  PHP edits are therefore live with no rebuild; IC4 writes `datastore/`, `cache/`,
  `uploads/` and `conf_global.php` into the host checkout at runtime.
- **`IC4_DEV=1` env on the `php` service** is a dev-only license bypass that
  `init.php::checkLicenseKey()` checks. It is the only way a dev box without a
  valid license key can pass the installer's license step. Never ship it — see §4.
- **`clear_env=yes` in the FPM pool is required.** Without it PHP sees none of the
  compose `environment:` values and the `IC4_DEV` bypass silently never fires
  (symptom: license step re-renders with no error).
- **The vhost pins `fastcgi_param HTTP_HOST localhost:8080`** (and `SERVER_PORT
  8080`). On a non-standard published port IC4 otherwise builds redirect URLs
  without the port (observed: 307 to `http://localhost/...` and broken FURLs).
  Remove the pinning only if you move to standard 80/443.
- **Web healthcheck probes `/Credits.txt`, not `/`.** The site root 307-redirects
  to the installer, which 500s without a session cookie — probing `/` would mark a
  healthy stack unhealthy.

### The docker-compose file

`assets/dev-stack/docker-compose.yml` is the canonical, verified file. Structure
summary (full file in assets):

```yaml
name: ic4

services:
  web:    # nginx:1.27-alpine, ${WEB_PORT:-8080}:80
          # source mounted ro at /var/www/html; healthcheck → /Credits.txt
  php:    # built from ./php (ic4-dev-php:8.2); env IC4_DEV=1, DB_HOST=db,
          # REDIS_HOST=redis; source mounted rw at /var/www/html; tmpfs /tmp;
          # healthcheck fsockopen 127.0.0.1:9000
  db:     # mariadb:11.4; MARIADB_* env from .env defaults; 127.0.0.1:3306;
          # utf8mb4 / utf8mb4_unicode_ci / max_allowed_packet=64M; volume ic4-db-data
  redis:  # redis:7.2-alpine; --maxmemory 128mb --maxmemory-policy allkeys-lru;
          # 127.0.0.1:6379; healthcheck redis-cli ping

volumes:
  ic4-db-data:        # survives `compose down`
  ic4-redis-data:     # survives `compose down`
  ic4-php-sessions:   # survives `compose down`
```

All ports and credentials are overridable via `.env` (see §2 for the fixed
development values). `depends_on` uses `service_healthy` so startup ordering is
deterministic (web waits for php, php waits for db+redis).

Support files in `assets/dev-stack/`:

```
assets/dev-stack/
├── docker-compose.yml            # the whole stack (canonical)
├── dev-env.example               # copy to .env (git-ignored): ports + DB creds + IC4_SRC
├── bin/prepare-src.sh            # one-time: conf_global.php + FPM ownership
├── php/
│   ├── Dockerfile                # php:8.2-fpm + all required extensions
│   ├── conf/pool.conf            # completes the base image's [www] pool
│   └── entrypoint.sh             # waits for db+redis, then FPM in foreground
├── nginx/conf.d/ic4-dev.conf     # vhost (try_files → index.php, port pinned)
└── snippets/apply-dev-bypass.sh  # idempotent dev-only license bypass
```

---

## 2. Fixed development credentials

These are the **fixed, canonical development credentials** for the IC4 dev stack.
Use them verbatim — they are documented, stable, and shared across every dev
host (they are in `dev-env.example`, not a secret). Never use them outside a dev
install.

### Database (container `ic4-db`)

| Field | Value |
|---|---|
| Host (from inside stack / containers) | `db` |
| Host (from host machine) | `127.0.0.1` port **3306** |
| Database | `ic4` |
| App user | `ic4dev` |
| App password | `ic4devpw` |
| Root password | `devrootpw` (only needed for DB administration, e.g. dumps with routines) |
| Charset / collation | `utf8mb4` / `utf8mb4_unicode_ci` |

Query idiom (from the stack dir):

```bash
docker compose exec db mariadb -uic4dev -pic4devpw ic4 -e "SHOW TABLES;"
```

Note: the MariaDB client binary inside the container is `mariadb` (and
`mariadb-dump`); there is no `mysql`/`mysqldump`. Root requires the password;
the app user (`ic4dev`) works for everything development needs.

### Web (container `ic4-web`)

| Field | Value |
|---|---|
| URL | `http://localhost:8080/` |
| ACP | `http://localhost:8080/admin/` |
| Installer | `http://localhost:8080/admin/install/` |

**Host-mismatch trap (verified):** use `http://localhost:8080/`, NEVER
`http://127.0.0.1:8080/`. The vhost `server_name` is `_` but IC4's FURL router
is host-bound, so `127.0.0.1` returns 404 even when the site is up. If you see a
404 on the front page, suspect the Host header before suspecting the code.

### Admin account (created by the installer)

| Field | Value |
|---|---|
| Username | `admin` |
| Email | `admin@localhost` |
| Password | `admin1234` |
| ACP login | `http://localhost:8080/admin/` — **login is email-only** on this stack |

ACP login mechanics (verified 4.7.25): the login form authenticates by **email**
(`core_login_methods.login_settings = {"auth_types":"2"}`), so a scripted login
POSTs `auth=<email>` (not username) plus `password`, `csrfKey` and
`_processLogin=usernamepassword`. The ACP is a JS app — extract the `csrfKey`
from any rendered ACP page and reuse a cookie jar for the session. After a fresh
login the onboarding `do=initial` GET 403s — POST it with CSRF, then
`?app=core&module=overview` returns 200.

### Ports (all overridable in `.env`)

| Service | Published |
|---|---|
| web | `:8080` |
| db | `127.0.0.1:3306` |
| redis | `127.0.0.1:6379` |

Redis has no fixed credentials (dev only, bound to loopback).

---

## 3. Creating the deployment (fresh bootstrap, step by step)

Prereq: an IC4 4.7.25 source checkout on the host, Docker + docker compose.

1. **Lay down the stack.** Copy `assets/dev-stack/` to a working `dev/` directory
   (it is self-contained). Then:

   ```bash
   cd dev
   cp dev-env.example .env        # adjust IC4_SRC to your checkout path
   ```

   `IC4_SRC` is the only thing you must edit — it is the path to the IC4 source
   checkout that gets bind-mounted into the containers.

2. **Prepare the source tree (once per checkout, on the host, as root/sudo):**

   ```bash
   bash dev/bin/prepare-src.sh /path/to/invision-community
   ```

   This creates `conf_global.php` from `conf_global.dist.php` and chowns the
   runtime paths IC4 writes to (`conf_global.php`, `datastore/`, `cache/`,
   `uploads/`, `applications/`, `plugins/`) to the FPM user (www-data, uid 33).
   Without it the install fails on unwritable paths.

3. **Apply the dev-only license bypass (once, idempotent):**

   ```bash
   bash dev/snippets/apply-dev-bypass.sh /path/to/invision-community
   ```

   Inserts a clearly-marked early-return into `checkLicenseKey()` in `init.php`,
   active only when `IC4_DEV` is set AND the request host is
   localhost/127.0.0.1/::1. Re-running is a no-op. Reverse with:
   `grep -n HERMES-DEV-ONLY init.php` and remove the marked block.

4. **Fire up:**

   ```bash
   docker compose up -d --build     # builds ic4-dev-php:8.2 on first run (~5 min)
   docker compose ps                # wait: all four Up (healthy)
   ```

5. **Run the installer.** Point a browser at
   `http://localhost:8080/admin/install/` (the site root 307s there before an
   install exists). Steps:
   1. **System Check** — pure GET, auto-advances (contains the session check).
      Green = all PHP extensions + writable paths OK.
   2. **License** — enter any string (e.g. `dev-test-0000`); the bypass passes it
      without phoning the license server. Gotcha: the EULA checkbox field is
      `eula_checkbox`, not `eula` — POSTing the wrong name silently re-renders.
   3. **Applications** — `core` is **NOT** checked by default; always check it
      (plus `forums`, `nexus`, the rest pre-checked).
   4. **Server Details** — host `db` (in-stack name), port 3306, user `ic4dev`,
      password `ic4devpw`, database `ic4` (already created by the MariaDB image).
   5. **Admin account** — use the fixed creds from §2 (`admin` / `admin1234` /
      `admin@localhost`).

   The install flow needs a **real persistent session** — a stateless `curl`
   round-trip 500s. Use a browser, or `curl -c jar -b jar` with the same jar
   for every request.

   A fully installed state looks like: ~190–240 tables, core + forums (+ other
   chosen apps) enabled, the default theme applied, and the site root serving
   the forum front (HTTP 200) instead of the installer.

6. **Verify (definition of done):**

   ```bash
   curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/          # 200
   curl -s http://localhost:8080/ | grep -o '<title>[^<]*'                # forum title
   docker compose exec db mariadb -uic4dev -pic4devpw ic4 -e \
     "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='ic4'"  # >150
   ```

   A 200 is not enough by itself: grep the body for the app's own content (a 200
   whose body is a handled 404 or the installer redirect is not "installed").

### Bootstrapping without a browser (curl walkthrough)

If a browser is not available, the whole installer can be driven with curl + one
cookie jar (one jar for the entire session):

```bash
JAR=$(mktemp)
curl -s -c "$JAR" -L "http://localhost:8080/admin/install/?start=1" -o step1.html
```

- System Check auto-advances (it stores a flag in `$_SESSION` and 307-redirects
  back with `?sessionCheck=1` — a dead/rotated session is the most common cause
  of a step silently re-rendering).
- License POST success is detected by the **redirect to the Applications step and
  `conf_global.php` being written**, not by body content.
- The installer shows almost no server-side errors in the HTML — when a step
  re-renders, check the **FPM error log** (`docker compose logs php`) for a fatal
  in the step controller.

---

## 4. Maintaining the deployment

### Day-2 commands (from the `dev/` stack dir)

```bash
docker compose ps                          # health at a glance
docker compose logs -f php                 # FPM errors — PHP problems land HERE, not in nginx
docker compose exec db mariadb -uic4dev -pic4devpw ic4   # DB shell
docker compose exec redis redis-cli ping   # redis health
docker compose exec php php -m             # confirm extensions (curl, mbstring, redis, ...)
docker compose exec php php -r '…'         # CLI bootstrap (cwd /var/www/html)
docker compose restart php                 # after pool.conf/Dockerfile changes
docker compose up -d --build               # rebuild (e.g. after Dockerfile changes)
```

### Tear down / reset

```bash
docker compose down        # stop; DB volume survives
docker compose down -v     # stop AND destroy the database (back to fresh install)
```

After `down -v`: re-run `bin/prepare-src.sh` (the runtime dirs are gone again),
and either walk the installer again or re-seed `conf_global.php` + restore a DB
dump. Everything else (source tree, stack files, rebuildable PHP image) is
untouched.

### Persisting the installed state (snapshot pattern)

The installed state relative to the pristine source is just three things —
**DB dump + `conf_global.php` + any installed 3rd-party apps** — everything else
is in the source tree or regenerable:

```sh
SRC=source/sourcecode/invision-community
# 1) DB dump (app user; the client is mariadb-dump, not mysqldump)
docker exec ic4-db mariadb-dump -h127.0.0.1 -uic4dev -pic4devpw \
  --single-transaction --routines --triggers --events --databases ic4 \
  | gzip > db-ic4-$(date +%Y%m%d).sql.gz
# 2) the only config file not in the pristine source
cp $SRC/conf_global.php snapshot-delta/
# 3) installed 3rd-party apps
cp -r $SRC/applications/<appkey> snapshot-delta/applications/
```

Restore = copy the delta onto the source tree, `prepare-src.sh`,
`compose up -d --build`, import the dump **only if the DB volume is fresh/empty**
(safe to re-run against a live stack). Keep snapshots slim (~5 MB): never bundle
the source tree or a prebuilt image (large tarballs hit remote size limits,
observed HTTP 413 on the internal Gitea).

### Resetting a single credential

- **Admin password lost:** from the stack dir,
  `docker compose exec db mariadb -uic4dev -pic4devpw ic4 -e "UPDATE core_members SET members_pass_hash='$2y$10$…' WHERE member_id=1;"`
  (bcrypt hash; verify with
  `docker compose exec php php -r 'var_dump(password_verify("admin1234", "…"));'`).
- **DB password lost / volume half-corrupt:** `docker compose down -v` and
  re-bootstrap (the fixed creds in §2 come back by construction).

---

## 5. Gotchas (verified)

| Symptom | Root cause | Fix |
|---|---|---|
| License step re-renders silently | `clear_env` not `yes` in FPM pool → PHP never sees `IC4_DEV` | Set `clear_env=yes` in the `[www]` pool |
| FPM container exits: `[pool www] user has not been defined` | Pool file used a new section name; base image's `[www]` (no user) stays broken | Reuse the `[www]` section name (sections merge) |
| FPM container exits immediately | Entrypoint ran `php-fpm -D` (daemonizes, container main process dies) | `exec php-fpm` (base image has `daemonize=no`) |
| Theme install dies: `No JPEG support in this PHP build` | PHP ≥ 8.2: `docker-php-ext-install gd` no longer enables JPEG/WebP | `docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype` before install |
| 404 on the front, site is up | Used `http://127.0.0.1:8080/` — FURL router is host-bound | Always `http://localhost:8080/` |
| Redirects to `http://localhost/...` (port dropped) | Vhost missing the `HTTP_HOST`/`SERVER_PORT` pin on the non-standard port | Keep the `fastcgi_param HTTP_HOST localhost:8080` pin |
| Web container "unhealthy" though the site works | Healthcheck probed `/` (307 → installer → 500 w/o cookie) | Probe `/Credits.txt` |
| Installer 500s / step re-renders | Stateless session (no cookie jar) or wrong field name (`eula` vs `eula_checkbox`) | One cookie jar for the whole session; use `eula_checkbox` |
| App installed but disabled (`app_enabled=0`) after upload | Stopped at the `done` MR step; `finished()` runs only on the NEXT request | Send one more numeric-MR request after `done` (see `packaging-deployment.md`) |
| PHP edits not picked up | Expecting a rebuild; the source is a bind mount | No rebuild needed for PHP; `docker compose restart php` only for FPM-level changes or stale OPcache |
| Install fails on unwritable paths | `prepare-src.sh` not run after a fresh checkout / after `down -v` | Re-run `bash dev/bin/prepare-src.sh <checkout>` |

## 6. OPcache after deployment changes

After ANY app code change that lands in the bind-mounted tree, restart PHP-FPM
before re-testing: `docker compose restart php`. OPcache serves stale bytecode
from the previous build, so a deployed "fix" appears to do nothing and you waste
turns re-diagnosing correct code. (Bumping the app version in `data/versions.json`
is a separate concern for the ACP treating a tar as a new version.)

## 7. Production warning

This stack is **development-only**: fixed, documented credentials; `IC4_DEV=1`
license bypass; loopback-only DB/redis exposure; `display_errors=stderr`; no
TLS. Do not expose port 8080 publicly and do not ship the license bypass or the
fixed credentials into a production install.
