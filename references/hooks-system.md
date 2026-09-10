# Invision Community 4: Hook System & Monkey Patching

IC4 uses a custom class-overriding engine ("Monkey Patching") for **code hooks**. A code hook (hooks.json `type: "C"`) is a file that defines a class *extending a target core/app class*; IC4's `init.php::monkeyPatch()` evals the file and swaps the alias so that everywhere the code refers to the target class, your extension is loaded instead. Verified against IC4 4.7.25.

> **Hooks are the highest-risk surface in the app** because the failure mode is *silent* — a malformed hook file does not produce a PHP error or an IN_DEV message; the original class simply runs un-overridden. Get the format exactly right.

## 1. File format (the format that breaks everything)

- **Line 1 MUST be `//<?php`** (a *commented* PHP open tag), **NOT** an active `<?php`.
- **No `namespace` declaration** in a standard code-hook file. The reason: `init.php::monkeyPatch()` evals the file as `namespace <target-namespace>; ` **+** the file's contents. An active `<?php` would produce `namespace ...; <?php class ...` = a **ParseError that is swallowed** (nothing in IN_DEV) → the hook class is never defined → the original controller runs **without your override and with no error message**.
- All built-in CMS hooks (`applications/cms/hooks/*.php`) start with `//<?php`; your hook file must match exactly.
- The `\IPS\SUITE_UNIQUE_KEY` guard block (403/exit) is **correct and stays** in the file — under eval the constant is already defined, so the `exit` never fires.

```php
//<?php

/* Prevent direct-access errors revealing path (kept for consistency; inert under eval). */
if (!\defined('\IPS\SUITE_UNIQUE_KEY'))
{
    header( (isset($_SERVER['SERVER_PROTOCOL']) ? $_SERVER['SERVER_PROTOCOL'] : 'HTTP/1.0') . ' 403 Forbidden' );
    exit;
}

class myapp_hook_topic extends _HOOK_CLASS_
{
    public function execute()
    {
        /* run the real method first */
        parent::execute();

        /* your override, e.g. set SEO meta after the view has run */
        \IPS\Output::i()->metaTags['description'] = 'my custom description';
    }
}
```

## 2. Class naming convention

`class <appkey>_hook_<filename> extends _HOOK_CLASS_`

- `<filename>` = the `filename` value in `data/hooks.json` (the file name *without* `.php`, or exactly the file name you ship — keep them in sync).
- `_HOOK_CLASS_` is a **literal placeholder** that IC4's `monkeyPatch()` replaces with the real target class name at eval time. You never write the target class name yourself.
- Example: `myapp_hook_topic` for a hook file `topic.php` targeting `\IPS\forums\Topic`.

## 3. `data/hooks.json` — Type C registration

```json
{
    "topic": {
        "type": "C",
        "class": "\\IPS\\forums\\Topic"
    }
}
```

- Key = hook `filename` (drives the class-name suffix and the file name).
- `type: "C"` = code hook (PHP class override). (Other types: `S` = skin/template hook — those mark a template class for recompilation and are *fully replaced on upgrade*, not merged.)
- `class` = the **target** PSR-4 class to override.

On **upgrade**, all existing `core_hooks` rows for the app/plugin are deleted and the hooks are rewritten — so anything you stored *inside* a hook file is lost and re-generated. Keep runtime state in the DB, never in the hook file.

## 4. Overriding the entry point for SEO / meta

The front dispatcher calls `->execute()` on the controller (`Dispatcher/Setup.php`). To set SEO title/description **after** the view runs but **before** `Front::finish()` / `buildMetaTags()`:

- Override **`execute()`**: call `parent::execute()` first, *then* set `\IPS\Output::i()->title` and `\IPS\Output::i()->metaTags['description']`.
- **Do NOT rely on overriding `manage()` alone** — `manage()` is only the `do`-method that `execute()` calls internally; setting meta there may be clobbered by the view's own output. `execute()` is the reliable interception point.

## 5. Debugging: is the hook firing?

The hook is silent when it's not defined, so force an observable marker:

```php
\IPS\Output::i()->title = 'MARKER:: ' . \IPS\Output::i()->title;
file_put_contents( \IPS\ROOT_PATH . 'logs/hook_fire.log', 'fired ' . date('c') . PHP_EOL, FILE_APPEND );
```

Then hit the page and check: **if the marker is completely absent**, the hook *class was never defined* → it is a **format/namespace problem** (usually the `//<?php` or a stray `namespace`), **not** a missing DB row. If the marker is present, the hook fires and your logic has a different bug.

## 6. FPM worker stale state (OPcache / `class_exists`)

`init.php`'s `class_exists()` evals the hook file **once per php-fpm worker process**. After you edit a `hooks/*.php` file, already-running workers keep the *old* class cached:

- `opcache.validate_timestamps` / `revalidate_freq` do **NOT** help — these are classic `class_exists` caches held inside the worker, not OPcache.
- **Fix: restart the php-fpm workers.** Container: `docker exec <php-container> sh -c 'kill -HUP 1'` (the fpm master is PID 1). A bare OPcache flush is insufficient.

## 7. Critical rules (summary)

1. Line 1 = `//<?php` (commented), never an active `<?php`.
2. No `namespace` line in a standard code-hook file.
3. Class name = `<appkey>_hook_<filename>`; `_HOOK_CLASS_` is left literal.
4. Keep hook `filename` in `hooks.json` in sync with the shipped file name.
5. Override `execute()` (call `parent` first) for meta/title changes, not just `manage()`.
6. After editing a hook file, restart the php-fpm workers (`kill -HUP 1`).
7. Hooks are fully replaced on upgrade — keep state in the DB.
