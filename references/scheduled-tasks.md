# Invision Community 4: Scheduled Tasks

IC4 scheduled tasks are PHP classes under `applications/<app>/tasks/`, registered in `data/tasks.json`, and driven by the core cron (`core_tasks`). Verified against IC4 4.7.25.

## 1. Task class

```php
<?php
namespace IPS\<app>\tasks;

/* To prevent PHP errors (extending class does not exist) revealing path */
if (!\defined('\IPS\SUITE_UNIQUE_KEY')) {
    header((isset($_SERVER['SERVER_PROTOCOL']) ? $_SERVER['SERVER_PROTOCOL'] : 'HTTP/1.0') . ' 403 Forbidden');
    exit;
}

class _cleanup extends \IPS\Task
{
    /**
     * Execute.
     *
     * If ran successfully, return anything worth logging. Only log something
     * worth mentioning (not "task ran successfully"). Return NULL (actual NULL,
     * not '' or 0) to log nothing — which will be most cases.
     * If an error means the task could not finish, throw \IPS\Task\Exception.
     * Tasks should complete within the time of a normal HTTP request.
     *
     * @return mixed|NULL
     * @throws \IPS\Task\Exception
     */
    public function execute()
    {
        /* ... task logic ... */

        return null;   // or a short summary string to log
    }
}
```

Rules:
- Class name is underscore-prefixed and matches the file name (`_cleanup` in `cleanup.php`).
- Extends `\IPS\Task` (alias of `IPS\_Task`, vendor `system/Task/Task.php`).
- The **return value** of `execute()` is the only logging mechanism: `Task::run()` calls `execute()` and `runAndLog()` writes the returned value to `core_tasks_log`. Return `NULL` to log nothing. No extra logging code needed. `runAndLog()` returns **void** — don't read a return value.
- On a fatal, throw `\IPS\Task\Exception` (don't log an error as a normal log).

## 2. Registration — `data/tasks.json`

Maps each task key to an ISO-8601 duration. The key is the file name (without `.php`), the value is the default frequency:

```json
{ "tempFileCleanup": "P0Y0M1DT0H0M0S", "logCleanup": "P0Y0M1DT0H0M0S" }
```

ISO-8601: `P` period, then `Y` years `M` months `D` days, `T`, then `H` hours `M` minutes `S` seconds. `P0Y0M1DT0H0M0S` = daily. This file is consumed by the install pipeline (`installTasks()`), not `build.xml` (a `<task>` entry in `build.xml` also exists for core modules, but third-party apps rely on `tasks.json`).

## 3. DB footprint

On install, tasks land in `core_tasks` (columns `app`, `key`, `frequency`, `next_run`, `running`, …). `key` is a SQL **reserved word** — always quote it (`` `key`=? ``) in any raw where-string against `core_tasks`.

## 4. Manual "Run now" button (ACP)

Load the task by key and run it; this gives a moderator/admin a run-now control without touching core's Tasks view.

```php
try {
    $task = \IPS\Task::load( '<taskKey>', 'key' );   // key is the only $databaseIdFields
    $task->runAndLog();
    $this->lang->add( 'run_success', 'ran' );
} catch ( \Exception $e ) {
    $this->lang->add( 'run_failed', $e->getMessage() );
}
\IPS\Output::i()->redirect( \IPS\Http\Url::internal( '...', 'admin', ... ) );
```

Register the button as a **sidebar action** on the settings screen — not a separate template:
```php
\IPS\Output::i()->sidebar['actions']['runNow'] = array(
    'title' => lang( 'run_now' ),
    'link'  => \IPS\Http\Url::internal( 'app=<app>&module=<module>&controller=<controller>&do=runNow', 'admin', ... )->csrf(),
);
```

## 5. Admin-configurable interval → task frequency

Store the admin's chosen interval, then push it onto `core_tasks` on save.

- Capture the interval with `\IPS\Helpers\Form\Interval` using `valueAs` (e.g. `Interval::SECONDS`) to expose minutes/hours/days/weeks pickers.
- On save, `syncTaskFrequency()` writes `frequency` (ISO-8601, e.g. `P1DT0H0M0S`) and recomputes `next_run` for the row in `core_tasks`.
- **Self-healing migration:** if you change the stored UNIT of an existing setting (e.g. hours → seconds), add a one-time conversion in the task's `execute()` (detect the old unit by magnitude, convert, write back) — `installSettings()` only updates `conf_default`, never existing `conf_value` rows.

## 6. Running tasks from the CLI

There is no `bin/console`. Run a task by constructing it and calling `run()`:

```php
$task = \IPS\Task::constructFromData( '<app>', '<taskKey>', '<taskKey>' );
$task->run();   // returns NULL on success
```

- The task class is **not** autoloaded by name — use the `constructFromData($appKey, $taskKey, $taskKey)` 3-arg form.
- **Lock-leak (verified):** `Task::run()` sets `running=1` **before** `execute()`; a crashed run leaves the row `running=1` and blocks the task permanently. A CLI runner should set `running=0` before re-running. (`setRunning()` does not exist.)

## 7. Cron wiring

IC4's cron is a single core task (the "task runner") that scans `core_tasks` for rows where `next_run <= now()` and executes them. You never add per-app cron entries — you register tasks in `tasks.json` and let core pick them up. Verify a task row exists and is enabled in `core_tasks` after install.
