---
name: invision-v4-dev-agent
description: Specialized Hermes Agent skill for developing, debugging, testing, and architecting Plugins and Applications for Invision Community 4 (IC4) — including bootstrapping a fresh dev-stack installation, fixed development credentials, packaging/deploying, and three-layer verification (build proofs, static analysis, live/runtime). Use when creating, hooking into, testing, or upgrading IC4 plugins/apps.
license: MIT
metadata:
  author: Christoph Reum
  version: 1.0.0
  hermes:
    tags:
      - invision-community
      - php
      - plugin-development
      - application-development
      - active-record
    category: software-development
---

# Invision Community 4 Development Agent Skill (`invision-v4-dev-agent`)

This skill provides expert knowledge and actionable patterns for building custom **Plugins** and **Applications** within the Invision Community v4 ecosystem.

---

## When to Activate

Activate this skill whenever the user asks to:
1. Create a new Invision Community 4 (IC4) Plugin or Application. → **Start with `references/agentic-bootstrap-guide.md`**: run the mandatory top-down clarifying phase (what to program → what functionality → what components, free-form answers) before any scaffolding.
2. Hook into core IC4 classes (`\IPS\...`) or override core behavior.
3. Construct IC4 ActiveRecord models, database schemas, or custom tables.
4. Write IC4 controllers (`\IPS\Dispatcher\Controller`), forms (`\IPS\Helpers\Form`), or templates.
5. Debug IC4-specific runtime errors, class loading issues, or database hooks.
6. Set up or bootstrap a fresh IC4 dev-stack installation (docker-compose), or obtain the fixed development credentials (DB, admin, ports).
7. Install, deploy, or **upgrade** an existing IC4 application (`.tar`) or plugin (`.xml`) via the ACP — including writing `setup/upg_XXXXX/` migrations or plugin `<versions>` setup classes.
8. **Verify/test** IC4 app code — build-time proofs (`.tar` self-test), static analysis (`jakzal/phpqa`), or live/runtime verification (HTTP-200 + DB checks).

> **CRITICAL ARCHITECTURAL WARNING:**
> Invision Community v4 (IC4) uses legacy class aliasing (`\IPS\foo` loading `\IPS\foo\_bar`) and procedural template hooks. Do NOT confuse IC4 patterns with Invision Community v5 (IC5), which uses strictly namespaced, modernized PHP structures.

---

## Skill Execution Procedure

When fulfilling a request:

0. **Clarify before you build (mandatory for new projects).** If the request is to *create* a new IC4 application or plugin, load `references/agentic-bootstrap-guide.md` first and run its top-down clarifying phase — *what to program → what functionality → what components*, free-form answers, one layer at a time — **before** scaffolding anything.
1. **Determine Architecture Scope:**
   - Use a **Plugin** when hooking into existing functionality or modifying standard core methods.
   - Use an **Application** when building standalone features with dedicated database tables, admin CP modules, or front-end controllers.

2. **Retrieve Deep Technical Context:**
   Load the relevant reference file on demand:
   - For hooks/overrides: `references/hooks-system.md`
   - For ActiveRecord / DB queries: `references/active-record-models.md`
   - For Controllers & Form Builders (front + routing): `references/controllers-routing.md`
   - For Templates & Output: `references/template-engine.md`
   - For AdminCP screens (settings, data grids, permissions, ACP login): `references/admincp.md`
   - For scheduled / cron tasks: `references/scheduled-tasks.md`
   - For ModCP (moderator panel) integration: `references/modcp.md`
   - For Frontend controllers (routing, output, pagination, feeds, outbound HTTP): `references/frontend.md`
   - For packaging & deployment (`.tar` build + ACP upload): `references/packaging-deployment.md`
   - For installing & upgrading apps (.tar) and plugins (.xml) — installer mechanics, DB upgrade engine, setup classes: `references/install-upgrade.md`
   - For setup & bootstrapping of a fresh installation (dev stack, credentials, installer): `references/setup-bootstrapping.md` (copy-ready stack in `assets/dev-stack/`)
   - For testing & verification methods (build proofs, phpqa static analysis, live/runtime verification): `references/testing-methods.md`
   - For bootstrapping a NEW app/plugin project end-to-end (clarifying phase, five-step lifecycle, repo layout, bootstrap sequence): `references/agentic-bootstrap-guide.md` — **load this first when starting a new project**
   - For recommended companion skills & tooling (phpqa, git/SSH/Docker/curl) and scaffolding them: `references/tooling.md` + `scripts/bootstrap_skills.sh`

3. **Generate Code using Templates:**
   - Refer to `templates/` for correct boilerplate structure and header declarations.
   - Ensure all class declarations strictly follow `_Classname` internal naming to align with IC4's Monkey Patching engine.
   - To build a packageable `.tar` for an app, adapt `templates/build_tar.php.template` (set `$appKey`); it builds the root-level archive and runs the three self-test proofs from `references/testing-methods.md`.

---

## Core Invision Community 4 Rules & Conventions

### 1. Monkey Patching & Class Extension
In IC4, hookable classes extend `_Classname`. Always define internal classes using the underscore prefix:

```php
namespace IPS\your_app;

/* Implicitly loaded via IC4 autoloader */
class _CustomModel extends \IPS\Patterns\ActiveRecord
{
    public static $databaseTable = 'your_app_custom_table';
    public static $databasePrefix = 'custom_';
}
```

### 2. Request & Form Handling
Never access `$_GET`, `$_POST`, or `$_REQUEST` directly. Always use the `\IPS\Request` singleton:

```php
$id = \IPS\Request::i()->id;
$value = \IPS\Request::i()->form_key;
```

### 3. Database Queries
Always use the `\IPS\Db` abstraction layer:

```php
$rows = \IPS\Db::i()->select('*', 'your_app_custom_table', array('custom_status=?', 1));
```

---

## Reference Navigation Map

- `references/hooks-system.md` → Monkey-patching code hooks: the `//<?php` format (and the *silent* parse-error failure mode), `<appkey>_hook_<filename>` naming, `hooks.json` Type-C registration, `execute()` override for SEO meta, hook-fire debugging, and FPM worker stale-state (`kill -HUP 1`).
- `references/active-record-models.md` → Custom model properties (`$databaseTable`, `$databasePrefix`, `$multitons`), the **core-table column names** (`core_members`, `core_sys_module`, `core_applications`, `core_tasks`, `forums_forums`), and the full `\IPS\Db::i()->select()` signature with its idioms (`first()` UnderflowException, scalar single-column, `count()` row-fetch).
- `references/controllers-routing.md` → Dispatcher patterns, Admin CP vs Front controllers, Form helper construction.
- `references/database-schema.md` → Writing `versions.json` and schema updates for applications.
- `references/template-engine.md` → IC4 PHTML template syntax, double-brace logic tags, `theme.xml` CDATA rule, and theme hook inserts.
- `references/admincp.md` → AdminCP controllers: settings/forms, data grids, permissions, CSRF, ACP login.
- `references/scheduled-tasks.md` → Task classes, `tasks.json` registration, run-now, interval→frequency sync.
- `references/frontend.md` → Frontend controllers: routing, output, CSS, pagination, RSS/Atom, outbound HTTP, content traits.
- `references/packaging-deployment.md` → `.tar` build + ACP upload/install/upgrade (root-level layout, proofs).
- `references/install-upgrade.md` → How the ACP installs/upgrades apps (`.tar`) and plugins (`.xml`): the step state machines, the DB upgrade engine (`setup/upg_XXXXX/queries.json`), plugin `<versions>` setup classes, and uninstall.
- `references/version-differences-v4-vs-v5.md` → Explicit anti-patterns to prevent mixing IC5 code into IC4 environments.
- `references/modcp.md` → ModCP is an extension-agnostic moderator panel: tab aggregation, `do=` router, and the recipe to add a tab.
- `references/setup-bootstrapping.md` → Setup & bootstrapping of a fresh installation: dev-stack deployment (docker-compose), fixed development credentials, installer walkthrough, maintenance & reset.
- `references/testing-methods.md` → Three-layer verification: build-time proofs (`.tar` self-test), static analysis (`jakzal/phpqa` on the Docker host), and live/runtime verification (HTTP-200 + DB checks on the running stack). "Static checks are not proof."
- `references/agentic-bootstrap-guide.md` → Process playbook for creating a new IC4 application/plugin from scratch: mandatory top-down clarifying phase (what/functionality/components, free-form), the five-step lifecycle, repo layout, canonical app structure, and the bootstrap→build→prove→verify sequence.
- `references/tooling.md` → Recommended companion skills & tools (phpqa, git/GitHub/GitLab/Gitea, ssh, docker, curl), vendor-doc links, workflow diagram, and the skill-bootstrapping script.
