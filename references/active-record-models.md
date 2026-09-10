# Invision Community 4: ActiveRecord Models & Core Tables

ActiveRecord models in IC4 map database tables to object structures. Custom models extend `\IPS\Patterns\ActiveRecord`; **core table column names are documented in §2** because they differ from what you'd guess and a wrong name yields empty rows, not an error.

## 1. Custom model structure

```php
namespace IPS\your_app;

class _Item extends \IPS\Patterns\ActiveRecord
{
    /**
     * @brief Database Table (name WITHOUT the system prefix)
     */
    public static $databaseTable = 'your_app_items';

    /**
     * @brief Column Prefix (applied to every column: item_id, item_name, ...)
     */
    public static $databasePrefix = 'item_';

    /**
     * @brief Multiton Store (required static cache for loaded instances)
     */
    protected static $multitons = array();

    /**
     * @brief Column Map (optional: model-attr => actual DB column)
     */
    public static $databaseColumnMap = array(
        'title' => 'name',
        'date'  => 'created_at',
    );
}
```

Common properties:
- `$databaseTable`: table name **without** the system DB prefix.
- `$databasePrefix`: prefix applied to columns (e.g. `item_id`, `item_name`).
- `$multitons`: required static cache array for loaded instances.
- `$databaseColumnMap` (optional): maps a model attribute to a differently-named DB column.
- `static::load( $id, $where = null )`: load one row; pass the **column name** for the id field if it isn't `{prefix}id`.

## 2. Core-table column names (verified — these trip up raw queries)

Use `\IPS\Db::i()->select(...)` against these (no ActiveRecord needed). The *expected* names are wrong; use the **actual** names below:

| Table | Actual columns | NOT |
|---|---|---|
| `core_members` | `name`, `email`, `members_pass_hash`, `member_id` | ~~`member_name`~~, ~~`member_email`~~; **no** `email_confirmed` column |
| `core_sys_module` | `module_app` (the app column), `sys_module_default` | ~~`app`~~ |
| `core_applications` | `app_directory` (the dir column), `app_enabled`, `app_position` | ~~`app_key`~~ |
| `core_tasks` | `app`, `` `key` ``, `frequency`, `next_run`, `running` | `key` is a SQL **reserved word** — always quote it (`` `key`=? ``) |
| `forums_forums` | no `name`/`title` column — the display name is a **lang key** `forums_forum_<id>` | resolve via `\IPS\forums\Forum::load($id)->title` (magic property, not a method) or `->get_name_seo()` for the slug |

> **LLM rule:** before a raw `SELECT`, confirm the exact column name. A wrong column name in IC4 typically returns **no rows** (no exception), which looks like "the data isn't there."

## 3. `\IPS\Db::i()->select()` — full signature & idioms

```php
\IPS\Db\i()->select( $columns, $table, $where = NULL, $order = NULL, $limit = NULL, $group = NULL, $having = NULL, $flags = 0 )
```

- **`$where`** — a string or an **array**. For bound parameters pass an array; multiple conditions **self-AND**:
  ```php
  // single condition
  array('col=?', $val)
  // multiple (self-AND)
  array('a=?', $x, 'b=?', $y)
  ```
  Position 4 is **`$order`** — parameters are **NOT** variadic after the where-string; you can't append order/limit by keeping the positional list going. Pass them as their own arguments.
- **`buildAnd()` does NOT exist** in IC4 (it is IC3). Combine conditions in the where-array instead.
- **`selectRow()` does NOT exist** — there is no single-row `select` variant.
- **`->first()` throws `UnderflowException`** on an empty result. The idiom for "first row or nothing" is:
  ```php
  $first = null;
  foreach ( \IPS\Db::i()->select( '*', '<table>', '<where>' ) as $row )
  {
      $first = $row;
      break;
  }
  ```
- **Single-column `select()` returns the SCALAR per row**, not a keyed array — cast with `(string)` / guard with `is_array()` before treating it as an array.
- **`count( select( ... ) )`** = number of **rows fetched** (it fetches then counts), **not** `COUNT(*)`. For a true total, select **one column** and count those rows; never `count( select( 'COUNT(*) AS n', ... ) )` (that is always `1` and collapses pagination to one page).
