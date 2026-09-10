# Invision Community 4: Installing & Upgrading Applications and Plugins

How IC4's AdminCP actually installs and upgrades third-party applications (`.tar`) and plugins (`.xml`), what it reads, what it writes, and the entry points your code must implement. Verified against IC4 4.7.25 (build 107850) from the actual source tree: `applications/core/modules/admin/applications/applications.php`, `.../plugins.php`, and `system/Application/Application.php`.

> This document covers the **install/upgrade lifecycle and mechanics**. For the `.tar` **build** format (what goes inside, root-level entries, proof checks) see `references/packaging-deployment.md`. For `data/` manifest files (`versions.json`, `build.xml`, `schema.json`, `application.json`) see `references/database-schema.md` and the app-structure notes.

## 1. Two distinct artifacts, two distinct installers

| | Application | Plugin |
|---|---|---|
| Upload type | `.tar` archive (TAR-mode phar) | Single `.xml` file |
| `allowedFileTypes` | `['tar']` | `['xml']` |
| Installer controller | `applications.php` | `plugins.php` |
| Root marker read | `data/application.json` → `app_directory` | `<plugin name=... author=... version=...>` root element |
| DB table | `core_applications` | `core_plugins` |
| Code location | `applications/{app_directory}/` | `plugins/{location}/` |
| Upgrade data source | `setup/install/` + `setup/upg_XXXXX/` dirs | `<versions>` elements (setup classes) |
| Language/word storage | `core_sys_lang_words` (app-scoped) | `core_sys_lang_words` (plugin-scoped, `word_plugin` set) |

**Consequence for packaging:** an application is a *tree* (files + `data/` + `setup/`); a plugin is a *single XML document* whose `<hook>`, `<task>`, `<settingsCode>` child elements contain the actual PHP/HTML/JS **as the element text** — the installer writes those files out itself. You do not ship a hooks directory for a plugin.

## 2. Application install/upgrade — the state machine

The ACP drives app install as a **multi-request step loop** (`applications.php` `install()`, `do=install`). Each request returns `[laststep, key, extra]` + a progress message + progress %, and the next request continues from `laststep`. The steps, in order:

1. **`start`** — determine current `long_version`, resolve the last-run upgrade version, write a `core_upgrade_history` row, then enter the upgrade loop:
   - `getUpgradeSteps($lastRan)` scans the app's `setup/` directory for subdirectories named `upg_XXXXX` and returns those with `XXXXX > $start`, sorted ascending numerically.
   - For each pending version, run `installDatabaseUpdates($version)` (see §3), then look for a PHP upgrader step: method `step{N}` on the app's `_Application` class. `N` starts at 1 and increments while the method exists and returns a truthy value. Returning `true` advances to the next `step`; returning anything else **re-runs the same step** (with `$data['extra']` fed back in).
2. **`basics`** — `installJsonData()` (settings, modules, tasks, hooks, etc. from the `data/` JSON/XML manifests; see `database-schema.md`).
3. **`lang`** — `installLanguages()`.
4. **`emails`** — `installEmailTemplates()`; if `data/cmsTemplates.xml` exists, that step (`cmstemplates`) also imports CMS templates.
5. **`skins`** — `installSkins(true)` + `installJavascript()`.
6. **finish** — `$app->save()`, log `acplog__application_updated`, return `null` (done).

### 2.1 New install vs. upgrade
- **New install** = the same loop, but `long_version` is 0, so *all* `setup/upg_XXXXX` dirs and the `setup/install/` data run, then the JSON data/lang/skins steps run.
- **Upgrade** = only `upg_XXXXX` dirs with `XXXXX > current long_version` run. `data/application.json` version fields are updated to the new version.
- The app's `Application.php` may override **`install()`** and **`upgrade()`** (and per-step `step1/step2/...`). A common, verified pattern is:

```php
public function upgrade()
{
    // IPS4's third-party app upgrade path does NOT call installDatabaseSchema().
    // Do it ourselves so any missing tables/columns from schema.json are created.
    $this->installDatabaseSchema();
    // ... any one-off migration code ...
}
```

## 3. The database upgrade engine (`installDatabaseUpdates`)

Reads `setup/upg_{version}/queries.json` (and `setup/install/queries.json` for installs). The file is a JSON array; entries are `ksort`ed numerically. Each entry:

```json
{ "params": { "method": "addColumn", "params": ["tablename", { "name": "col", "type": "INT", "length": 11, "unsigned": 1, "default": 0 } ] } }
```

Key behaviors (all from the source):
- **Batching + resume:** runs up to `$limit` (default 50) entries per request and respects a `max_execution_time`-based cut-off (half the limit). It stores `$_SESSION['lastJsonIndex']` so an interrupted run resumes from the next entry on the next request.
- **Large-table deferral:** for a non-trivial query against a table the driver flags as big (`recommendManualQuery`), it does **not** run inline — it returns the raw SQL in `queriesToRun` and the ACP prompts the admin to run it manually. (Drops/inserts/renames and unqualified deletes are exempt.)
- **Schema drift tolerance:** on `changeColumn` with error 1054 (column missing) it falls back to `addColumn`; on `createTable` errors 1007/1050 (table exists) it tolerates; on `renameTable` with 1017 (source missing) it tolerates. This is how idempotent re-runs stay safe.
- Errors are logged to the `upgrade_error` log channel.

**`installDatabaseSchema()`** (the `schema.json` path) is separate: it diffs `data/schema.json` against the live DB and emits `ALTER`/`CREATE`/column changes, applying InnoDB FULLTEXT indexes one at a time. It is **not** called automatically on upgrade (see §2.1) — call it explicitly if your app ships a `schema.json`.

## 4. Application packaging markers the installer reads

- **`data/application.json`** — required; the installer reads `app_directory` to know where to extract. Minimal real example (forums):
  ```json
  { "application_title": "Forums", "app_author": "...", "app_directory": "forums", "app_protected": 0, "app_website": null, "app_update_check": null, "app_hide_tab": 0 }
  ```
- **`setup/install/`** — install-time data: `queries.json` (raw DB ops), plus manifest JSON the `installJsonData` step consumes.
- **`setup/upg_XXXXX/`** — one dir per long version; `queries.json` inside is the incremental DB change.
- **`data/versions.json`** — long-version → human-version map (see `database-schema.md`). The installer's "available upgrade" logic compares `longversion` values.

> **Build rule:** the `.tar` must contain these entries at the **root level** (no `appname/` prefix) — the installer reads `phar://file.tar/data/application.json` directly. See `packaging-deployment.md` for the exact phar layout + proof checks.

## 5. Plugin install/upgrade — the element state machine

`plugins.php` reads the uploaded XML and walks its **top-level child elements one per request** (same `laststep`/`done[]` resume pattern as apps, plus a "setup classes" phase after all elements). Each top-level element is a step; progress returns `plugin_step_{element}`. Elements and what they do:

- **`<hooks>`** → creates `plugins/{location}/hooks/` (and `dev/` in dev). On **upgrade it first deletes all existing `core_hooks` rows for the plugin and empties the hooks dir**, then rewrites — so hooks are **fully replaced**, not merged. Each `<hook class= type= filename=>` inserts a `core_hooks` row and writes the file, rewriting the placeholder `class hook{N} extends _HOOK_CLASS_` with the real auto-generated name. Skin hooks (`type="S"`) mark their template class for recompilation.
- **`<settings>`** → upserts each `<setting>` key into `core_sys_conf_settings` (setting `conf_plugin` to the plugin id) and clears the settings cache. In dev it also writes `dev/settings.json`.
- **`<settingsCode>`** → writes the AdminCP settings page `plugins/{location}/settings.php`.
- **`<tasks>`** → creates `plugins/{location}/tasks/`, upserts each `<task key= frequency=>` into the task table, and writes the task file. In dev, writes `dev/tasks.json`.
- **`<htmlFiles>` / `<cssFiles>` / `<jsFiles>` / `<resourcesFiles>`** → writes the corresponding frontend asset files into the plugin dir (sub-types `html`/`css`/`js`/`resources`).
- **`<lang>`** → inserts/updates `core_sys_lang_words` rows scoped to the plugin (`word_plugin`), and in dev writes `dev/lang.php` + `dev/jslang.php`.
- **`<versions>`** → the upgrade mechanism. Each `<version long="10000" human="1.0.0">` child holds a **setup class** as its element text. The installer writes each to `plugins/{location}/dev/setup/{long}.php` and registers a `Data\Store` key. On install it uses the `long="10000"` class; on upgrade it queues every version with `long > currentVersionId`.
- **`<uninstall>`** → code the uninstaller runs.

### 5.1 Plugin "setup classes" (install/upgrade steps)
After all elements are processed, the queued setup classes run, also step-by-step. The element text is PHP that the installer **strips the leading `<?php` tag from, `eval()`s in-process, then instantiates bare** (`new $class()`) — so the class is a **plain class with no base class** (there is no `\IPS\Plugin\Setup` to extend). The class name is **fixed**, not a parameter: **`ips_plugins_setup_install`** (fresh install) or **`ips_plugins_setup_upg_{long}`** (upgrade). The installer then calls `step1()`, `step2()`, … in order:
- Returning **`true`** (`=== true`) advances to the next step (or, if no further step, the next version / completion).
- Returning an **array with an `html` key** displays that HTML to the admin and **re-runs the same step** on the next request (pass data back via `\IPS\Request::i()->extra`).

This is where a plugin does custom install/upgrade logic (DB work, backfills) beyond what the declarative elements handle. See `templates/Plugin-versions.template` for the full shape.

### 5.2 Full plugin XML shape (verified)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<plugin name="MyPlugin" author="Me" version="1.0.0">
    <hooks>
        <hook class="\IPS\forums\Topic" type="C" filename="topicHook.php">
            &lt;?php class hook1 extends \IPS\Plugin\Hook { public function run() { return true; } } ?&gt;
        </hook>
    </hooks>
    <settings>
        <setting>myplugin_enabled</setting>
    </settings>
    <settingsCode>&lt;?php ... AdminCP form ... ?&gt;</settingsCode>
    <versions>
        <version long="10000" human="1.0.0">&lt;?php class ips_plugins_setup_install { public function step1() { return true; } } ?&gt;</version>
    </versions>
    <uninstall>&lt;?php // cleanup ?&gt;</uninstall>
</plugin>
```
> Element text is **XML-escaped PHP**. The `templates/Plugin.xml.template` in this package is the minimal hook-only skeleton.

## 6. Uninstall / delete (both types)
- **App delete** removes the `core_applications` row and (optionally) the app files; the ACP warns that data may remain. The app's `Application.php` may implement `uninstall()` for custom teardown.
- **Plugin delete** removes the `core_plugins` row, runs the `<uninstall>` element, and cleans up the plugin's hooks, tasks, settings, and language words.

## 7. Gotchas (verified)
- **Plugins replace hooks on every upgrade** — anything you store *inside* a hook file is lost and re-generated; keep state in the DB, not the hook file.
- **Plugin setup classes are `eval`'d as plain classes** — the installer strips the leading `<?php` tag and `eval()`s the element text, then `new`s the class with no base class. Do **not** write `extends \IPS\Plugin\Setup` (it doesn't exist) — you'll fatal. Class name is fixed: `ips_plugins_setup_install` / `ips_plugins_setup_upg_{long}`.
- **`installDatabaseSchema()` is NOT called on app upgrade** — if you rely on `data/schema.json`, override `upgrade()` and call it yourself (pattern in §2.1).
- **Resumability is session-based** (`$_SESSION['lastJsonIndex']`, `laststep`) — an interrupted ACP install/upgrade resumes where it left off; don't assume the whole run is atomic.
- **Big-table queries don't run inline** — they're returned for manual execution; a "stuck" upgrade on a large table is this deferral, not a bug.
- **`.tar` vs `.xml`** — uploading an app as `.xml` or a plugin as `.tar` fails at the upload form (`allowedFileTypes`), not later.
- **`app_directory` is load-bearing** — if `data/application.json` lacks `app_directory`, extraction throws and the install aborts immediately.
- **Designers mode blocks app install** — the ACP refuses app uploads while theme designers mode is on (`app_upload_designersmode`).

## 8. Quick decision table
| Goal | Do this |
|---|---|
| Ship a new app | Build root-level `.tar` with `data/` + `setup/install/` + `setup/upg_*` (see `packaging-deployment.md`), upload in ACP → Applications → Install. |
| Ship a new plugin | Author the single `.xml`, upload in ACP → Applications → Plugins → Install. |
| Add DB columns on upgrade (app) | Add `setup/upg_{newLong}/queries.json` + bump `data/versions.json`; override `upgrade()` to call `installDatabaseSchema()` if you use `schema.json`. |
| Custom upgrade logic (plugin) | Add a `<version long="..." human="...">` setup class with `stepN()` methods. Plain class (no base), name fixed to `ips_plugins_setup_upg_{long}` — see `templates/Plugin-versions.template`. |
| Idempotent, re-runnable upgrades | Rely on the engine's drift tolerance (§3); make `queries.json` safe to re-run. |
