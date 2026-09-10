# Invision Community 4: Packaging & Deployment (.tar)

IC4 **Applications** are deployed by uploading an archive in the ACP (Developer → Applications → Upload Application). The archive format is **`.tar`**, read by the installer through PHP's `PharData` in TAR mode. Verified against IC4 4.7.25 installer (`applications/core/modules/admin/applications/applications.php`).

## 1. Format: `.tar` (not `.zip`)

- The ACP installer constructs `new \PharData($application_file, 0, null, \Phar::TAR)` and reads `phar://<file>/data/application.json` to discover the app.
- **If the uploaded file does not end in `.tar`, the installer force-renames it to `.tar`** before processing. So the canonical, safe extension is `.tar` — upload a `.tar` and the rename path is never taken.
- There IS a `\IPS\Archive\Zip\Zip` class in the system, but it is **not** the Application install path (it serves theme/other uploads). For Applications, build and upload **`.tar`**.
- The ACP's own "Download application" button produces a `.tar` too (`\PharData(..., \Phar::TAR)` → `sendOutput($output, 200, 'application/tar', …)`), so a re-download of a stock app is a reference tar you can diff against.

## 2. Internal layout — root-level entries (critical)

The archive entries sit **at the tar root**, with **no app-directory prefix** and **no `./` root entry**. The installer extracts with `PharData::extractTo(\IPS\ROOT_PATH . '/applications', false)`, so what you see at the tar root becomes what lands in `applications/<appkey>/`.

Example layout for a typical app (30 entries, generic `myapp` appkey):

```
Application.php
data/acpmenu.json
data/acprestrictions.json
data/application.json
data/extensions.json
data/furl.json
data/hooks.json
data/index.html
data/installLang.json
data/lang.xml
data/modules.json
data/schema.json
data/settings.json
data/tasks.json
data/themesettings.json
data/theme.xml
data/versions.json
extensions/core/FrontNavigation/myapp.php
extensions/index.html
modules/admin/myapp/index.html
modules/admin/myapp/manage.php
modules/admin/myapp/settings.php
modules/admin/index.html
modules/front/myapp/index.html
modules/front/myapp/index.php
modules/front/myapp/rss.php
modules/front/index.html
modules/index.html
tasks/maintenance.php
tasks/index.html
```

Top-level entries: `Application.php`, `data/`, `extensions/`, `modules/`, `tasks/`. The `index.html` files are per-directory placeholder markers (empty or `<html></html>`); including one per shipped directory is the observed convention.

**What NOT to do:**
- No `<appkey>/` wrapper dir at the tar root → the app lands in `applications/<appkey>/<appkey>/…` and never loads.
- No `./` root entry (PharData/TAR edge cases) → keep entries clean.
- No `PharData::addEmptyDir()` for the root — that re-introduces a nesting artifact.
- `data/application.json`, `data/schema.json`, and `data/hooks.json` **must be at the root `data/`** or install silently skips them.

## 3. Build the tar

Canonical build script (bash, plain GNU tar):

```bash
#!/usr/bin/env bash
# Build <app>.tar — files directly at tar root (ACP PharData-compatible layout).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPKEY="<appkey>"                   # EDIT: your app key
SRC="$ROOT/src/$APPKEY"             # the app tree (only app code)
OUT="$ROOT/build"; mkdir -p "$OUT"

cd "$SRC"
FILES=$(find . -type f | sed 's|^\./||' | LC_ALL=C sort)
rm -f "$OUT/$APPKEY.tar"
tar -cf "$OUT/$APPKEY.tar" -C "$SRC" $(echo "$FILES" | tr '\n' ' ')
```

`-C "$SRC"` puts entries at the tar root (no prefix). The app tree is `src/<appkey>/` containing exactly the IC4 app layout (`Application.php`, `data/…`, `modules/…`, `tasks/…`, `extensions/…`).

A ready-to-adapt **PHP builder** lives in this package at `templates/build_tar.php.template` (parametrised on the app key). It builds the same root-level `.tar` via `PharData` and runs the three automated proofs from §4 (ACP manifest check, `PharData::extractTo` layout check, `install()` simulation) in one step. Copy it to `scripts/build_tar.php`, set `$appKey`, and run `php -d phar.readonly=0 scripts/build_tar.php`. (PHP must have `phar.readonly=0` — with the default `1` the `.tar` is not written to disk.) Use the bash builder above when a PHP builder is not present.

## 4. Post-build verification (proofs)

A build is "done" only when its checks are green — do not trust the exit code alone:

1. **No nesting:** `tar -tf out/<app>.tar | grep -q '^<appkey>/'` must be empty (no appkey dir at root).
2. **No `./` entry:** `tar -tf out/<app>.tar | grep -q '^\./'` must be empty.
3. **Manifests at root:** confirm `data/application.json`, `data/schema.json`, `data/hooks.json` (and `data/tasks.json` if the app has tasks) appear with no prefix.
4. **`Application.php` at root:** confirm the file is present with no prefix.
5. **Entry count sanity** matches the source tree.

The PHP builder in `templates/build_tar.php.template` runs the three automated proofs above and only counts green as a valid build. Where a PHP builder exists, run it; where only the bash builder exists, run the five manual checks above.

## 5. Deployment (upload + install)

1. Build the `.tar` (section 3), run the proofs (section 4).
2. ACP → Developer → Applications → **Upload Application** → choose the `.tar` → the installer reads `data/application.json`, extracts to `applications/<appkey>/`, and runs the install (creates DB tables from `schema.json`, registers settings/hooks/tasks/modules).
3. Verify on the live system: the app row appears in the ACP Applications list; front/admin routes resolve (HTTP 200, not the handled 404 `2S106/2`); and the DB has the app's tables (`<prefix>_<appkey>_…`).

## 6. Upgrade an already-installed app

The same `.tar` upload path upgrades in place. Keep the appkey and `data/application.json` stable across versions so the installer treats the upload as an update of the same app rather than a new one. What actually runs on upgrade (full mechanics in `references/install-upgrade.md`):

- The ACP runs the multi-step state machine, but on upgrade **only** the `setup/upg_XXXXX/` directories whose `XXXXX` is greater than the app's current `long_version` are processed (via `getUpgradeSteps()`), plus the JSON/lang/skin re-registration steps.
- DB changes come from `setup/upg_XXXXX/queries.json` (`installDatabaseUpdates`), **not** by re-running `data/schema.json`. If your app relies on `schema.json`, override `Application::upgrade()` and call `installDatabaseSchema()` yourself.
- To ship an upgrade: bump the highest key in `data/versions.json`, add `setup/upg_<newLong>/queries.json` (and any `stepN()` PHP in `Application.php`), rebuild the `.tar`, and re-upload.
