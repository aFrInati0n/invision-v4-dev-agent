# Invision Community 4: ModCP (Moderator Control Panel)

ModCP is the moderator-facing panel at `index.php?/modcp/`. It is a **single core controller** (`IPS\core\modules\front\modcp\_modcp`) that does not render its own content — it **aggregates tabs from registered `ModCp` extensions**. To put anything in a moderator's ModCP, your app ships a ModCP **extension**, not a new controller. Verified against IC4 4.7.25 (`core/modules/front/modcp/modcp.php`).

## 1. How the core controller works

`_modcp extends \IPS\Dispatcher\Controller`. Two key behaviors:

- `manage()` (the default tab view) checks, in order:
  1. Logged in — `\IPS\Member::loggedIn()->member_id`, else `403` (`2S194/1`).
  2. Is a moderator — `\IPS\Member::loggedIn()->modPermission() === false` → `403` (`2S194/2`).
  3. Iterates `\IPS\Application::allExtensions('core', 'ModCp', true)`; for each extension that has a `getTab()`, it collects the tab key into `$tabs[<tab>][] = <extKey>`.
- `__call($method, $args)` is the router for `do=` actions: it walks the `ModCp` extensions, finds the one whose `getTab()` matches the active tab **and** which defines the requested `do=` method, then hands off to `manage()`. If nothing matches → `404` (`2C139/5`).

So **a ModCP tab exists only if a `ModCp` extension with a `getTab()` exists**, and **a ModCP `do=` action exists only if that same extension defines the method**.

## 2. Adding a ModCP tab from your app

Three pieces, all required:

1. **Extension class** — `applications/<app>/extensions/core/ModCp/<key>.php`:
   ```php
   <?php
   namespace IPS\<app>\extensions\core\ModCp;

   if (!\defined('\IPS\SUITE_UNIQUE_KEY')) {
       header((isset($_SERVER['SERVER_PROTOCOL']) ? $_SERVER['SERVER_PROTOCOL'] : 'HTTP/1.0') . ' 403 Forbidden');
       exit;
   }

   class _<key>
   {
       public function getTab()
       {
           return '<tabkey>';   // unique slug, e.g. 'myapprovals'
       }

       /* do= actions live on THIS class, matched by the core __call() router */
       public function manage()
       {
           \IPS\Output::i()->title = lang( '<app>_modcp_title' );
           \IPS\Output::i()->output = \IPS\Theme::i()->getTemplate( 'modcp', '<app>', 'front' );
       }

       /* Example do= action — reachable as ?/modcp/?tab=<tabkey>&do=approve */
       public function approve()
       {
           /* ... permission-check the moderator, mutate, redirect ... */
       }
   }
   ```
   - Class name is underscore-prefixed to match the extension autoloader.
   - `getTab()` returns the tab slug. Core only registers the tab when this method exists.
   - Every `do=` action the moderator can trigger must be a public method on this class (the core `__call()` looks for `method_exists($extension, \IPS\Request::i()->do)`).

2. **Register in `data/extensions.json`:**
   ```json
   { "core": { "ModCp": { "<key>": "IPS\\<app>\\extensions\\core\\ModCp\\_<key>" } } }
   ```

3. **Template** — a `modcp` template in the app's `data/theme.xml` (front area), rendering the tab content.

## 3. Tab groups

Core pre-seeds two groups before scanning extensions: `$tabs = array( 'reports' => array(), 'approval' => array() )`. Your extension's `getTab()` value becomes a new group key. Keep it a short unique slug; the visible label comes from a lang key.

## 4. Moderation model — what a ModCP action does

Typical ModCP actions moderate content. The canonical building blocks:

- Load the target by id and check permission: `\IPS\core\Reports\Report::load($id)` (reports) or your own ActiveRecord model. `load()` throws `OutofRangeException` when missing.
- Approve / hide / delete: use the content model's built-in methods (e.g. `approve()`, `unapprove()`, `delete()`, `hide()`), or the content-type traits if you're on a content class.
- Respect the moderator's scope: a moderator may only act in the communities/sections they moderate — check membership before mutating.

## 5. Gotchas

- **No `ModCp` extension = nothing shows in ModCP**, no error. If a tab silently doesn't appear, check the extension class exists, `getTab()` is defined, and the `extensions.json` entry is present and the FQCN is correct.
- The core ModCP controller checks `modPermission()` — a non-moderator gets `403`. A super-admin may still need explicit moderation scope for some actions.
- `do=` routing is by **method name** on the extension. If you rename a method, the ModCP link breaks silently (core `__call()` → `404`).
- ModCP is **front area** (`'front'`), not AdminCP. It uses front templates and front-area extensions. Do not register ModCP content under `admin`.
