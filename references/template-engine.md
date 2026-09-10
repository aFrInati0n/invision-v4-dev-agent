# Invision Community 4: Template Engine (PHTML)

IC4 front and Admin CP output is rendered from **PHTML** templates. In an installed app they live in `data/theme.xml` (there is **no** `dev/html/` in a final app tree); a few stock globals live under `applications/core/data/html/...`. Verified syntax against IC4 4.7.25.

> **The single most important rule:** 4.7.25 control tokens use **DOUBLE braces** — `{{if}} … {{else}} … {{endif}}` and `{{foreach …}} … {{endforeach}}`. The `<!-- if -->` / `<!-- foreach -->` comment-style tokens are **IPS3 and do NOT work in IC4**.

## 1. Parameter header

Every template declares its inputs on the first line:

```phtml
<ips:template parameters="$url, $message" />
```

The names become template variables. In `theme.xml` this is the first line of the template body.

## 2. Variables (auto-escaped)

The template body is compiled into a PHP heredoc, so `{$var}` is automatically `htmlspecialchars()`-ed. Array access uses brackets, not dots:

```phtml
<p>{$message}</p>
<a href="{$url}">Go</a>
<span>{$item['title']}</span>        <!-- NOT {$item.title} -->
```

Only two modifiers exist in 4.7.25:
- `{$var|raw}` — output raw (skip HTML-encoding). Use when the value is already trusted/safe HTML.
- `{$var|doubleencode}` — force encoding.

There is **no** `|no_cdn`, `|html_entity_decode`, `|trim`, `|date`, or `|rawDecode` — those are IPS3/legacy and leave literal text in the heredoc. **Pre-format everything in the controller** (dates, hrefs, truncation) and pass scalars.

## 3. Language strings

Always pull UI text from lang, not hard-coded:

```phtml
<h1>{lang="yourapp_title"}</h1>
<a>{lang="yourapp_next" sprintf="$page, $pages"}</a>
```

The lang word uses `{0}`/`{1}` placeholders. Never hard-code visible strings (keeps the app translatable).

## 4. Conditionals

```phtml
{{if $show_banner}}
<div class="banner">{$banner_text}</div>
{{else}}
<div class="muted">{$fallback_text}</div>
{{endif}}
```

## 5. Loops

```phtml
{{foreach $items as $item}}
<li>
    <span>{$item['title']}</span>
    <a href="{$item['url']}">Open</a>
</li>
{{endforeach}}
```

## 6. Storing templates in `theme.xml`

`<![CDATA[ … ]]>` is **mandatory** around the body. The installer parses `theme.xml` with `XMLReader::readString()`, which returns only direct text nodes — an un-wrapped body becomes child XML elements and is **silently dropped**, so the page returns HTTP 200 with the markup missing. A 200 with missing markup is NOT success.

```xml
<template_set id="0" name="default">
  <template_group name="general">
    <template_name>view</template_name>
    <template_location>front</template_location>
    <template_data><![CDATA[
      <h1>{lang="yourapp_title"}</h1>
    ]]></template_data>
  </template_group>
</template_set>
```

## 7. Raw PHP

Raw `<?php … ?>` blocks in a template are **echoed as literal text**, never executed. All logic belongs in the controller.

## 8. Theme hooks (extension points)

Themes and apps can inject markup without editing templates. App-side hook points are declared in `data/hooks.json` and implemented as hook classes (see `references/hooks-system.md`); the admin configures them under Appearance → Hooks. A developer does not hand-write the hook marker — it is registered and the system slots it at the chosen location.

> **LLM rules:**
> - No PHP logic in templates — data arrives pre-formatted as variables.
> - Use lang keys for every visible string.
> - Don't reach into `$_GET`/`$_POST`; the controller prepares the variables.
> - Double-brace tokens only; never port IPS3 `<!-- if -->` or IC5 template syntax into IC4.
