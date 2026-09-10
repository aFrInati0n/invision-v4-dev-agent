# Invision Community 4: Testing Methods

How to verify that IC4 application/plugin code is actually correct — not just that it *parses*. The central principle, stated in every IC4 app project's quality bar:

> **Static checks are not proof.** `php -l`, file existence, and a successful build do **not** prove an app works. A build counts as *done* only when (a) the build script's self-test proofs are green **and** (b) HTTP-200 + DB verification exist on a running system. Anything less is explicitly marked "local only, not yet verified".

IC4 ships **no automated unit-test framework** for third-party apps (the `tests/` dir in app repos is empty by design). Verification is therefore a **three-layer** practice. Run all three, in order; only layer 3 is real proof.

```
Layer 1  Build-time proofs      no live system   fast, every commit
Layer 2  Static analysis        no live system   docker/phpqa, per change
Layer 3  Live / runtime         running stack    the actual proof, per feature
```

---

## Layer 1 — Build-time proofs (no live system needed)

The canonical pattern is the app's **`.tar` builder with built-in self-tests** (`scripts/build_tar.php`). It builds the archive and then simulates, in-process, everything the ACP upload handler does. Exit 0 only if all three proofs pass.

**Proof 1 — ACP manifest validation** (mirrors `applications/core/modules/admin/applications/applications.php`):
- Open the archive as `phar://<tar>/data/application.json` (the ACP reads it at the **tar root**).
- `json_decode` must yield an array with `app_directory` set — otherwise the ACP throws `\UnexpectedValueException` → error **1C133/K** ("archive is corrupt").

**Proof 2 — extraction layout** (the ACP's own method):
- Run `new \PharData($tar, 0, null, \Phar::TAR)->extractTo($dest, null, true)` — the **exact** call the ACP makes.
- If the archive has a stray root `.` entry (injected by `PharData::addEmptyDir()`), this throws `\PharException` → **1C133/9**. So: never call `addEmptyDir()`; build files-only with `RecursiveIteratorIterator(LEAVES_ONLY)` + `addFile()`.
- Assert the app files land **directly in the extract root** (`Application.php`, `data/application.json` present), with **no nested `<appkey>/` folder**.

**Proof 3 — `install()` simulation** (from the extracted tree, reading every artifact the installer consumes):
- Manifest `app_directory` present.
- `Application.php` passes `php -l`.
- Every `data/*.json` is valid JSON.
- `data/theme.xml` is well-formed (`simplexml_load_file` ≠ `false`).
- `data/modules.json` + `data/schema.json` present.
- **Every PHP file in the app passes `php -l`** (the installer autoloads them on first use).

Build is green only when `ALL PROOFS PASSED` is printed. `--no-test` skips proofs but then the build is *not* "done" by the quality bar.

> **`phar.readonly=0` is required.** The builder writes the `.tar` via `PharData`, and PHP refuses to *write* a phar/tar when `phar.readonly=1` (the default) — the build "succeeds" in memory but does not persist to disk. Run it as `php -d phar.readonly=0 scripts/build_tar.php` (or set `phar.readonly=0` in the dev PHP's `php.ini`/`.env`). The builder prints a `NOTE: phar.readonly is set — the build will not persist` line when it detects the default.

**Minimal static checklist** (when there is no builder script — at least these per change):
- `php -l` on every changed `.php` (zero syntax errors).
- All `data/*.json` parse; `data/theme.xml` + `data/lang.xml` well-formed XML.
- Tab-indented PHP (literal `\t` escape sequences are a parse error → 500).
- No `selectRow()` (does not exist); no `index()` controller entry (must be `manage()`, else 404 `2S106/2`).

---

## Layer 2 — Static analysis (`jakzal/phpqa`, on the Docker host)

IC4 has **no composer project at the web root and no test suite**, so heavy static analysis runs through the [`jakzal/phpqa`](https://github.com/jakzal/phpqa) Docker image (~90 PHP QA tools in one image) on **any Docker-capable host** (use the one your dev stack lives on; pin a versioned tag like `php8.4-alpine` for reproducibility). The full tool catalogue, CI YAML, and image-customisation recipes are in the `phpqa` skill; the knowledge repo's `qa/steps/` holds the per-step playbook.

**Canonical invocation** (project mounted at `/project`):
```bash
IMG=jakzal/phpqa:php8.4-alpine
docker run --init --rm \
  -v "$(pwd):/project" \
  -v "$(pwd)/tmp-phpqa:/tmp" \
  -w /project \
  -e SKIP_COMPOSER_INSTALL=true \
  "$IMG" <tool> <args>
```
- `SKIP_COMPOSER_INSTALL=true` — the target has no installable composer project; drop it only when a tool needs `vendor/`.
- `tmp-phpqa/` is the writable scratch for caches / `--summary-xml`; keep it git-ignored.
- Alpine tags have **no `bash` and no `python3`** — run log parsers on the host.

**Tools that matter for app work** (verified against the 4.7.25 tree):

| Tool | Command | What it proves |
|---|---|---|
| `parallel-lint` | `parallel-lint <dirs>` | **Zero syntax errors** (exit 0 = clean) — the authoritative syntax gate |
| `phpcs` | `phpcs --standard=Security --report=summary <dirs>` | Security audit (the image's substitute for `local-php-security-checker`) |
| `phpcs` / `phpcbf` | `--standard=PSR12` | Style compliance (read-only) / auto-fix |
| `php-cs-fixer` | `fix --dry-run --allow-risky=yes` | PSR-12 normalisation |
| `phpmetrics` | `phpmetrics <comma-sep dirs>` | Structural metrics + violations |
| `pdepend` | `pdepend <comma-sep dirs>` | Dependency / complexity (see pitfalls) |
| `phpstan` | `analyse src -l 0` | Static analysis (needs a bootstrap, see below) |
| `phpmd` / `phpcpd` | `phpmd src text codesize` / `phpcpd src` | Code smells / dead code / duplication |

**The 10-step QA pipeline** (knowledge repo `qa/steps/`) is the systematic form of this: 01 syntax+security → 02 baseline metrics → 03 PSR-12 fix → 04 style verify → 05 dead code → 06 DRY → 07 phpstan baseline → 08 complexity → 09 strict typing → 10 boundaries. Steps 1–4 are read-only/safe and complete; 5–9 are logic-changing refactors **stopped at the risk boundary** (no test suite to catch regressions) — that stop is itself a documented testing decision.

**Pitfalls (verified):**
- **`@PSR12` (php-cs-fixer) ≠ `PSR12` (phpcs standard)** — after a `php-cs-fixer fix` pass, `phpcs --standard=PSR12` still reports a large residual gap; that's a rule-mapping difference, **not** a failure of the fixer. **Verify the fix with `parallel-lint`, not with phpcs.**
- **`pdepend`** needs **comma-separated** paths (`a,b,c`), not space-separated, and 2.x can crash on trait-method collisions (e.g. `IPS\Login\Handler\_OAuth2`) — fall back to `phpmetrics` for structural metrics on `system/`.
- **`phpmetrics`** multi-path is also comma-separated; use `--exclude=3rd_party`.
- **`php-cs-fixer` 3.x** requires a `--config` file when targeting **multiple** paths (a single `.` works without one).
- **`phpstan`** on a no-autoloader tree emits thousands of noise errors unless you bootstrap it: a `bootstrap.php` that registers the IC4 `\IPS\` autoloader/aliases + a `phpstan-baseline.neon` ignore file for pre-existing findings.
- **Match the PHP tag to the project's PHP version** (4.7.25 runs on 8.x; a version mismatch gives false positives). Pin a tag (e.g. `php8.4-alpine`) for reproducibility.

---

## Layer 3 — Live / runtime verification (the actual proof)

A running IC4 dev stack (docker-compose: nginx + php-fpm + MariaDB + Redis, see `references/setup-bootstrapping.md`). This is the only layer that proves the app actually runs.

**Definition of done per feature** (from the app quality bars):
1. **HTTP 200 on the real routes** — the front route (e.g. `?/<appkey>/`) and the AdminCP route must return 200, **not** the handled 404 (code `2S106/2`, which means `manage()` is missing) or a 500.
2. **DB verification** — the app's tables exist with the correct prefix (`<prefix><appkey>_…`), and any seeded rows are present. Query via the DB container: `docker compose exec -it mariadb mysql -u ic4dev -pic4devpw ic4dev -e "SHOW TABLES LIKE '<appkey>%';"`.
3. **Error logs clean** — read `core_error_logs` (4.7.25; **`core_sys_log` does NOT exist**) `ORDER BY id DESC` for new entries. On a 500, the PHP-Fatal is in `php-fpm.log` in the container's logs.

**Common error codes (diagnostic key):**

| Code | Meaning |
|---|---|
| `1C133/K` | `data/application.json` missing/invalid at tar root (`app_directory` not set) |
| `1C133/9` | `PharData::extractTo` hit a root `.` entry (`addEmptyDir()` was used) |
| `4C133/6` | `application.json` missing/corrupt at the app dir |
| `2C133/4` | App already installed |
| `2S106/2` | Controller entry is `index()` not `manage()` → front route 404s |

**Driving the running stack with curl:**
- **ACP login is email-only** (auth type 2), not username. Use a **fresh cookie jar** every time — a stale `ips4_IPSSessionAdmin` cookie routes the POST into a dead session and login fails *silently*. Success = HTTP **303** redirect to `/admin/`; then `?app=core&module=overview` → 200. ACP *installation* is a multi-redirect chain that breaks under pure curl (double-CSRF + session rotation → 403); replicate it via a CLI installer instead.
- **Template cache is on disk** (`datastore/template_1_<md5>_<appkey>.<hash>.php`), not just Redis — after template changes, `rm -f datastore/template_1_*<appkey>*`; `FLUSHALL` on Redis is **not** enough. Re-import with `$app->installTemplates(true, $offset, $limit)` (update mode).
- **OPcache** — invalidates written PHP on change, but a stale opcode can mask edits; `opcache_invalidate()` or a php-fpm restart to be sure.

**CLI execution of IPS code** (for tasks / one-off verification without the browser):
- Use the prefix PHP wrapper (`LD_LIBRARY_PATH=<prefix>/usr/lib/…` + `pdo, mysqlnd, mysqli, mbstring, pdo_mysql` — `pdo` before `pdo_mysql`, `mysqlnd` before both, `mysqli` needed by `init.php`'s `mysqli_report()`).
- Set `$_SERVER['SCRIPT_FILENAME']`, `require init.php`, and **override the exception handler before boot** (IPS's default handler renders generic 500 HTML and hides the real error).
- Task runner: `Task::run()` sets `running=1` **before** `execute()` — a crashed run leaves the task locked; set `running=0` first.
- To surface a real error when `IN_DEV` shows only "EX0": in the **installed** copy (never the source), rename `manage()` → `_manageBody()` and wrap it in try/catch that writes the trace to a file; read it with curl; then restore from source.

---

## Testing-methods decision table

| Situation | Use |
|---|---|
| Did the build produce a valid archive? | Layer 1 — the builder's 3 proofs (must be green) |
| Is my changed code syntactically valid? | `php -l` / `parallel-lint` (authoritative) |
| Is my code secure / well-formatted? | Layer 2 — `phpcs --standard=Security`, `php-cs-fixer` (verify with `parallel-lint`, not phpcs) |
| Did I introduce complexity/duplication/dead code? | Layer 2 — `phpmetrics`, `pdepend` (comma paths), `phpmd`, `phpcpd` |
| Does the app actually run? | Layer 3 — HTTP 200 on front + ACP routes, not `2S106/2` |
| Did the DB changes land? | Layer 3 — `SHOW TABLES LIKE '<appkey>%'` + row checks |
| Is something 500-ing silently? | Layer 3 — `core_error_logs` (not `core_sys_log`) + `php-fpm.log` |
| Need to run a task / IPS code headlessly? | Layer 3 — prefix-PHP CLI wrapper, exception handler overridden pre-boot |
| A feature is "done"? | All three layers green, **or** explicitly marked "local only, not yet verified" |
