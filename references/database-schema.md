# Invision Community 4: Database Schema & Data Manifest

IC4 applications define their database footprint and installation footprint through two files in the application's `data/` directory: `versions.json` (version history) and `build.xml` (what the installer registers). Tables themselves are created/updated via schema migrations keyed off the versions.

## 1. `data/versions.json`

Maps IC4's internal integer version keys to human-readable version strings. The installer uses the highest known key to decide whether an upgrade is needed.

```json
{
    "40000": "4.0.0",
    "40100": "4.1.0",
    "41000": "4.1.0 RC 1",
    "41005": "4.1.0"
}
```

- Keys are integers (`MAJOR*1000 + MINOR*100 + PATCH`-style; RC/beta steps are added sequentially).
- Always append a new key when you change the schema or installable data. Never reuse a key for a different change.
- The **highest** key in the file is the "current" version the installer will target.

## 2. `data/build.xml` — the installation manifest

`build.xml` declares what the app registers at install/upgrade time: modules, settings, tasks, hooks, widgets, and Admin CP search entries. Payload values are JSON stored in `<![CDATA[...]]>`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<build>
    <!-- Admin CP module -->
    <module key="admin/yourapp"><![CDATA[{"default_controller":"","protected":0,"default":1}]]></module>
    <!-- Front module -->
    <module key="front/yourapp"><![CDATA[{"default_controller":"view","protected":0,"default":1}]]></module>

    <!-- Application settings (also appear in settings.json / lang.xml) -->
    <setting key="yourapp_enabled"><![CDATA[{"key":"yourapp_enabled","default":"1","report":"full"}]]></setting>

    <!-- Scheduled task (ISO 8601 duration as frequency) -->
    <task frequency="P0Y0M1DT0H0M0S">yourappCleanup</task>

    <!-- Code hook onto a core/app class -->
    <hook key="YourAppHook"><![CDATA[{"type":"C","class":"\\IPS\\core\\Member"}]]></hook>
</build>
```

Rules:
- `key` values are unique per element type within the file.
- `<setting>` keys must match a key defined in the app's settings definition so the Admin CP renders them.
- `<task frequency="...">` name matches a task class in the app's `tasks/` namespace (e.g. `\IPS\yourapp\tasks\yourappCleanup`).
- `<hook>` entries reference the class the hook is patched onto.

## 3. Table schema & migrations

Custom tables follow the `{app}_{table}` convention and use the app's column prefix (see `references/active-record-models.md`). Schema changes are applied as migration steps that run once when the version key advances.

Common table conventions:
- Primary key column: `{prefix}id` (int, auto-increment).
- Foreign keys to members: `{prefix}member_id` or `author_id`.
- Timestamps: `{prefix}created` / `{prefix}updated` (int, unix epoch).
- Soft-delete / status flags: `{prefix}approved`, `{prefix}hidden`.

```sql
CREATE TABLE {prefix}yourapp_items (
    item_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    item_name      VARCHAR(255) NOT NULL DEFAULT '',
    item_member_id INT UNSIGNED NOT NULL DEFAULT 0,
    item_created   INT UNSIGNED NOT NULL DEFAULT 0,
    item_status    TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (item_id),
    KEY item_member_id (item_member_id)
) ENGINE=MyISAM;
```

> **LLM rule:** Never write raw `CREATE TABLE` in application code. Declare tables/migrations in the data layer and let IC4's upgrade engine apply them. Always bump the highest key in `versions.json` when schema changes land.
