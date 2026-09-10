# Invision Community 4: Frontend Development

Frontend screens are controllers under `applications/<app>/modules/front/<module>/` plus templates in `data/theme.xml`. Verified against IC4 4.7.25.

## 1. Controller

```php
<?php
namespace IPS\<app>\modules\front\<module>;

/* To prevent PHP errors (extending class does not exist) revealing path */
if (!\defined('\IPS\SUITE_UNIQUE_KEY')) {
    header((isset($_SERVER['SERVER_PROTOCOL']) ? $_SERVER['SERVER_PROTOCOL'] : 'HTTP/1.0') . ' 403 Forbidden');
    exit;
}

class _index extends \IPS\Dispatcher\Controller
{
    public function manage()
    {
        $items = $this->loadItems();

        \IPS\Output::i()->title = lang( '<app>_title' );
        \IPS\Output::i()->cssFiles = array_merge(
            \IPS\Output::i()->cssFiles,
            \IPS\Theme::i()->css( 'style.css', '<app>', 'front' )
        );
        \IPS\Output::i()->output = \IPS\Theme::i()->getTemplate( 'view', '<app>', 'front',
            array( 'items' => $items ) );
    }

    protected function loadItems()
    {
        return \IPS\Db::i()->select( '*', '<table>', 'is_active=1', 'created DESC' );
    }
}
```

Rules:
- Class name underscore-prefixed, matches file name (`_index` in `index.php`).
- **Entry point is `public function manage()`** (or a `do=X` method). The dispatcher (`Dispatcher/Controller.php::execute()`) calls `manage()`. A controller with only `index()`/`default()` renders a handled **404, page error `2S106/2`** — even when the FURL, module, and controller class all resolve. This is the #1 silent-404 cause.
- Extra controllers resolve **by file name** — no `modules.json` entry needed. `Dispatcher/Standard.php` builds the class name `IPS\<app>\modules\<area>\<moduleKey>\<controller>` from the `controller` request param. `modules.json` only names the DEFAULT controller per module. So `?controller=feed` on a registered front module loads `modules/front/<moduleKey>/feed.php` automatically.
- Namespace is `IPS\<app>\modules\front\<module>` (front apps use `\IPS\Dispatcher\Controller`).

## 2. Routing / URL formats

- Legacy query: `index.php?app=<app>&module=<module>` (301 → SEO path) or `index.php?/<app>/<module>/<controller>/`.
- A non-default app **must include `module`** in the query — `?app=` alone only works for the default app's default module, otherwise 404.
- FURLs: build with `\IPS\Http\Url::internal( 'app=<app>&module=<module>&controller=<controller>' )` (returns `\IPS\Http\Url\Internal`, which has `setPage()`).

## 3. Output (`\IPS\Output`)

- Set the title: `\IPS\Output::i()->title = ...`.
- CSS: `\IPS\Output::i()->cssFiles = array_merge( \IPS\Output::i()->cssFiles, \IPS\Theme::i()->css( 'file.css', '<app>', 'front' ) );`
- Render: `\IPS\Output::i()->output = \IPS\Theme::i()->getTemplate( 'name', '<app>', 'front', $params );`
- **CSS trap (non-dev mode):** when `IN_DEV` is `FALSE` (hardcoded in `init.php`), `Theme::i()->css()` returns `array()` because only **built** CSS is served from `uploads/css_built_<theme>/` — an app's dev-CSS is never compiled there, so the merge silently loads nothing. Fallback that works: append a static `<link>` in the controller —
  `\IPS\Output::i()->linkTags[] = array( 'rel' => 'stylesheet', 'href' => '/path/to/dev/file.css' );` — renders a `<link>` in `<head>`, served raw by nginx `try_files`. Also `Output::i()->cssFiles` is **reset during output generation**, so late merges don't survive. The CSS file's **byte 0** must be the `ips:css` header: `/*<ips:css app="<key>">*/`.

## 4. Templates (PHTML, 4.7.25 syntax)

Templates live in `data/theme.xml` (NOT `dev/html/` files — installed apps have no `dev/` dir).

```xml
<template_set id="0" name="default">
  <template_group name="general">
    <template_name>view</template_name>
    <template_location>front</template_location>
    <template_data><![CDATA[
      <h1>{lang="<app>_title"}</h1>
      <ul>
        {{foreach $items as $item}}
        <li>{$item['title']}</li>
        {{endforeach}}
      </ul>
      {{if $hasMore}}<a href='{$baseUrl->setPage( "page", $page + 1 )}'>Next</a>{{endif}}
    ]]></template_data>
  </template_group>
</template_set>
```

Verified 4.7.25 syntax (differs from IPS3):
- **Control tokens are DOUBLE-brace:** `{{if}}` / `{{else}}` / `{{endif}}` / `{{foreach}}` / `{{endforeach}}`. The `<!-- if -->` style is IPS3 and does NOT work here.
- The template body is compiled into a PHP heredoc, so `{$var}` is auto-`htmlspecialchars()`-ed. The only valid modifiers are `|raw` and `|doubleencode`; anything else (e.g. `|substr=0,1|upper|raw`) leaves literal text in the heredoc → parse error at eval.
- Raw `<?php ?>` blocks in templates are echoed as literal text, never executed.
- **`<![CDATA[ ... ]]>` is mandatory** around the template body — the installer's `XMLReader::readString()` returns only direct text nodes, so unwrapped HTML becomes child XML elements and is silently dropped (page renders HTTP 200 with the markup missing — a 200 with missing markup is NOT success).
- Array indexing: `{$item['title']}` (NOT `{$item.title}`).
- Language: `{lang="<key>"}` or `{lang="<key>" sprintf="$page, $pages"}` (the template `lang` tag accepts a `sprintf` attribute; the lang word uses `{0}`/`{1}` placeholders).
- Pre-format dates/hrefs in the controller and pass scalars — `|date=` and `|rawDecode` do NOT exist in 4.7.25. DB content is stored raw and auto-escaped, so decoding manually double-escapes.

## 5. Pagination (front)

```php
$page  = \intval( \IPS\Request::i()->page );          // \IPS\Request magic __get; NULL when absent
if ( $page < 1 ) { $page = 1; }

$where  = 'is_active=1';
$total  = count( \IPS\Db::i()->select( 'item_id', '<table>', $where ) );  // Select is Countable = rows fetched
$pages  = \max( 1, (int) ceil( $total / $perpage ) );
if ( $page > $pages ) { $page = $pages; }
$offset = ( $page - 1 ) * $perpage;

$rows = \IPS\Db::i()->select( '*', '<table>', $where, 'sort_order ASC, item_id ASC', array( $offset, $perpage ) );
$baseUrl = \IPS\Http\Url::internal( 'app=<app>&module=<module>&controller=<controller>' );
```

Template: `href='{$baseUrl->setPage( "page", $page + 1 )}'` — `setPage()` strips the param on page 1 and appends `?page=N` otherwise. Wrap in `{{if $pages > 1}}`. Use the theme's `ipsPagination*` classes for conformance.

**Countable trap:** `count( select( ... ) )` = number of ROWS FETCHED (not `COUNT(*)`). For a total, select ONE column and count it. Never `count( select( 'COUNT(*) AS n', ... ) )` — that is `1` and silently collapses pagination to one page. **Single-column `select()` returns the SCALAR per row** (not a keyed array).

## 6. Front navigation item

Registering a nav item an admin can enable requires **all three**:
1. `Application.php` → `defaultFrontNavigation()` returns e.g. `'browseTabs' => array( array( 'key' => '<key>', 'title' => '<langKey>' ) )`. **The `title` key is required** — `insertMenuItem()` copies it to `menu_item_{id}`; without it the nav item renders as an empty link.
2. Create `extensions/core/FrontNavigation/<key>.php` (`class _<key> extends \IPS\core\FrontNavigation\FrontNavigationAbstract`) implementing at least `title()` (a lang word) and `link()` (returns `\IPS\Http\Url::internal('app=...&module=...&controller=...')`).
3. Register in `data/extensions.json`: `{ "core": { "FrontNavigation": { "<key>": "IPS\\<app>\\extensions\\core\\FrontNavigation\\_<key>" } } }`.

`roots()`/`subBars()` skip any child whose class is missing — **silent failure** if only step 1 is done. It takes effect when `buildDefaultFrontNavigation()` re-runs (fresh install or ACP nav reset).

**"Make default Module"** (homepage) is a built-in core ACP feature (Developer → Applications → your front module → "Make default Module", sets `sys_module_default`). No app code needed; just verify the module is registered as a `front` module in `data/modules.json`.

## 7. RSS / Atom feed controller

Build XML with the canonical `\IPS\Xml\Rss` helper (do NOT hand-roll `<rss>` markup):

```php
$doc = \IPS\Xml\Rss::newDocument( $baseUrl, $title, $description );  // $baseUrl = \IPS\Http\Url
$doc->addItem( $title, $link, $description, \IPS\DateTime::ts( $ts ), $guid );  // $link = \IPS\Http\Url
$xml = $doc->asXML();
\IPS\Output::i()->sendOutput( $xml, 200, 'text/xml' );
```

`newDocument()` takes a `\IPS\Http\Url` (not a string); `addItem()` takes a `\IPS\DateTime` and a unique guid. Titles are CDATA-wrapped by the helper — pass raw strings. Mirror the index controller's WHERE (active + date-gated) but drop pagination and display-only fields; cap at ~25 items.

## 8. Outbound HTTP

Canonical idiom is `\IPS\Http\Request\Curl` (not `file_get_contents`/`curl_*`/raw Guzzle):

```php
$request = \IPS\Http\Request\Curl::i( $endpointUrl );
$request->setHeaders( array( 'Authorization: Bearer ' . $apiKey, 'Content-Type: application/json' ) );
$request->post( $jsonBody );                       // pre-json_encode()'d string
$response = $request->getResponse();               // response body string
```

`setHeaders()` takes an ARRAY of `Name: value` strings. `json_decode()` the response and check for an `error` key before trusting the payload.

## 9. Content types & capability traits

Content classes don't carry per-feature code. Base chain `_Content` → `_Item` / `_Comment` / `_Widget` (all `extends \IPS\Patterns\ActiveRecord`); concrete classes **mix in feature traits** from `system/Content/`: `Reportable`, `Reactable`, `Solvable` (method aliasing on collision: `use \IPS\Content\Solvable { toggleSolveComment as protected _toggleSolveComment; }`), `Statistics`, `ViewUpdates`, plus `Recognizable`, `ClubContainer`, `ItemTopic`. "Is this reportable/reactable?" = which traits the class `use`s. (Note: `Featurable`/`Searchable`/`Shareable` are NOT `system/Content/` traits — read the class's actual `use` line.)

## 10. Autoloading pitfall — app-root helper classes are NOT autoloaded

The IPS4 autoloader walks the namespace; a lowercase app-key segment maps to `applications/<app>/`, but any UPPERCASE segment fails the `^[a-z0-9]` test and is routed into `sources/`. So `IPS\<app>\Llm` (a class at the app root) is only found at `applications/<app>/sources/Llm.php` / `sources/Llm/Llm.php` — the root file is never found → `Class "IPS\<app>\Llm" not found` even though the file ships in the tar. Fix: put autoloaded helpers under `sources/` (`namespace IPS\<app>\<Segment>`), or `require_once` them from every entry point (`../Llm.php` from `tasks/`, `../../../Llm.php` from `modules/admin/<app>/`).

## 11. Forum display name

A forum's name is NOT a `forums_forums` column. Read it via the model: `\IPS\forums\Forum::load( $id )->title` (a magic **property**, not a method — `->title()` is a fatal) or `->get_name_seo()` for slugs. The raw lang key `forums_forum_<id>` returns the key verbatim when uncached → cryptic labels.
