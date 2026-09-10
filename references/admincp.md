# Invision Community 4: AdminCP Development

AdminCP (Admin Control Panel) screens are PHP controllers under `applications/<app>/modules/admin/<module>/`. Everything below is verified against IC4 4.7.25.

## 1. Controller skeleton

```php
<?php
namespace IPS\<app>\modules\admin\<module>;

/* To prevent PHP errors (extending class does not exist) revealing path */
if (!\defined('\IPS\SUITE_UNIQUE_KEY')) {
    header((isset($_SERVER['SERVER_PROTOCOL']) ? $_SERVER['SERVER_PROTOCOL'] : 'HTTP/1.0') . ' 403 Forbidden');
    exit;
}

class _settings extends \IPS\Dispatcher\Controller
{
    /**
     * Protect this controller's do= actions with CSRF.
     */
    public static $csrfProtected = TRUE;

    public function execute()
    {
        parent::execute();

        /* Gate access to a specific restriction */
        \IPS\Dispatcher::i()->checkAcpPermission( 'settings_manage' );
    }

    public function manage()
    {
        /* Build the form, handle submit, render */
    }
}
```

Rules:
- Class name is underscore-prefixed and matches the file name (`_settings` in `settings.php`).
- `manage()` is the entry point (the dispatcher calls `manage()` or a `do=X` method). A controller with only `index()`/`default()` yields a handled **404 (page error `2S106/2`)** even though the route resolves.
- `public static $csrfProtected = TRUE;` turns on framework CSRF protection for `do=` actions. **Caveat:** on a `csrfProtected` controller the framework DISABLES its automatic CSRF check for `do=`-named methods (verified `Dispatcher/Admin.php`), so a `do=` AJAX endpoint (e.g. `do=testLlm`) must validate CSRF itself — see §5.

## 2. Permissions

Two parts, both required:
1. `data/acprestrictions.json` — registers the restriction **under the controller key**:
   ```json
   { "<controller>": { "settings_manage": "settings_manage" } }
   ```
2. In the controller, `checkAcpPermission( '<restriction>' )` (usually in `execute()`).

## 3. Data grid (table) — `\IPS\Helpers\Table\Db`

The standard for listing/editing rows:

```php
$table = new \IPS\Helpers\Table\Db( '<table_name>', $url );

$table->include      = array( 'col1', 'col2' );
$table->langPrefix   = '<app>_';
$table->mainColumn   = 'col1';
$table->sortBy       = \IPS\Request::i()->sortBy       ?: 'col1';
$table->sortDirection= \IPS\Request::i()->sortDirection ?: 'DESC';

/* Format a column */
$table->parsers = array(
    'col1' => function( $val, $row ) { return \IPS\Output::i()->url( ... ); },
);

/* Per-row action buttons; destructive links must carry ->csrf() */
$table->rowButtons = function( $row ) {
    $buttons['edit'] = array( 'icon' => 'edit', 'title' => lang('edit'), 'link' => \IPS\Http\Url::internal( '...', 'admin', ... ) );
    $buttons['delete'] = array( 'icon' => 'bin', 'title' => lang('delete'), 'link' => \IPS\Http\Url::internal( '...', 'admin', ... )->csrf() );
    return $buttons;
};

\IPS\Output::i()->output = (string) $table;
```

- Row links use `\IPS\Http\Url::internal(...)` (FURL). Destructive links get `->csrf()`.
- Sidebar primary action:
  `\IPS\Output::i()->sidebar['actions']['add'] = array( 'primary' => TRUE, 'icon' => 'plus', 'title' => lang('add'), 'link' => ...->csrf() );`

## 4. Settings screens (Form helpers)

Build forms from `\IPS\Helpers\Form\*` objects — never hand-roll `<input>` tags. Verified helpers: `\IPS\Helpers\Form\Select`, `Text`, `Number`, `TextArea`, `Date`, `Interval`.

```php
$form = new \IPS\Helpers\Form\Text( '<key>', null, TRUE, 'settings', '<langPrefix>' );
// ... ->add( $helper ) ...
if ( $values = $form->values() ) {
    \IPS\Settings::i()-><key> = $values['<key>'];
    \IPS\Settings::i()->save();
    /* post-save hook, e.g. syncTaskFrequency() */
    $this->lang->add( 'saved_success', 'saved' );
    \IPS\Output::i()->redirect( \IPS\Http\Url::internal( '...', 'admin', ... ) );
}
\IPS\Output::i()->output = $form;
```

Key form-building gotchas (full detail in the stack skill's form reference):
- **Do NOT set `->label` or `->description` on settings fields.** Name the lang keys to match the field (`<field>` and `<field>_desc`); the framework resolves the label and renders the description via the `rowDesc` template. Setting `$field->description` bypasses `rowDesc` and inlines the description next to the input (looks like a CSS bug, is a template-path bug).
- **Secret / API-key fields:** render the input EMPTY (never echo the stored key into ACP HTML). On submit, if the field is blank, KEEP the existing value; overwrite only when a new one was typed.
- **Combine two fields in one row** (value + unit): render the second field's HTML as the first's `endSuffix`; the suffix field isn't in `$form->elements`, so read it from the request on save and validate it yourself.
- **`\IPS\Helpers\Form\Interval`** uses ISO-8601 durations (`P1DT0H0M0S`); use `valueAs` (e.g. `Interval::SECONDS`) to expose a unit picker and convert for storage.
- **`\IPS\Helpers\Form\Date`** — default and return value are UNIX timestamps (suitable for `DATE` DB columns).

## 5. AJAX `do=` endpoint on a `csrfProtected` controller

Because the framework auto-CSRF-check is disabled on `do=` methods here, validate manually. The settings form renders a hidden `csrfKey`; the JS reads it from the form and sends it as a query param; the handler:

```php
\IPS\Session::i()->csrfCheck( \IPS\Request::i()->csrfKey );   // throws on failure
/* ... do work ... */
\IPS\Output::i()->json( array( 'ok' => TRUE, 'data' => ... ) ); // sendOutput() terminates
```

## 6. Admin menu registration

`data/acpmenu.json` wires the controller into the ACP navigation:

```json
{ "<module>": { "<controller>": { "tab": "community", "controller": "<controller>", "do": "", "restriction": "settings_manage" } } }
```

## 7. ACP login (curl) — automation note

The ACP is a JS/AJAX SPA: a curl POST that "succeeds" silently returns the login page with **HTTP 200** (no error). Reliable scripted login:
1. Fresh cookie jar (a stale `ips4_IPSSessionAdmin` cookie makes the login silently fail).
2. GET the login page, extract the `csrfKey` form field.
3. POST with `auth=<EMAIL>` (email-only on most stacks — NOT username), `password`, `csrfKey`, `rememberMe=1`, `_processLogin=usernamepassword`.
4. Success = **HTTP 303** redirect to `/admin/`; then `?app=core&module=overview` → 200 Dashboard.

A DB-coined `core_sessions` row is **not** sufficient for ACP auth (you cannot forge the session hash). For structural proof without a live login: `php -l` all controllers + a CLI smoke-test that instantiates every app class without a fatal + confirm the `acpmenu.json`/`acprestrictions.json` entries exist.
