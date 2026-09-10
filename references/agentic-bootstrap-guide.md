# Invision Community 4: Agentic Guide for Bootstrapping a New Project (Application or Plugin)

A working playbook for an agent that is asked to **create a new IC4 4.7.25 application or plugin from scratch**. It codifies the house convention (the *five-step lifecycle* + repo layout) and, most importantly, a **mandatory top-down clarifying phase** before any code is written.

> House style (the `invision-v4-dev-agent` skill and the `ips4_tar_building` skill all agree on this shape). When this guide and the other references conflict, the *other references win on IC4 technical facts*; this guide wins on *process*.

---

## 0. The Golden Rule: clarify first, top-down, free-form

**Do NOT start writing code, scaffolding, or a tar on the first turn.** The single biggest failure mode of an agent bootstrapping an IC4 project is inventing requirements. Before producing any artefact, run a **top-down clarifying dialogue** with the user, in this order, broad → narrow:

1. **What shall be programmed?** (the *what*: a new IC4 **Application** or a **Plugin** — the agent proposes one of the two based on the answer; see the decision rule below.)
2. **What functionality shall it have?** (the *features*: user-visible behaviour, AdminCP screens, front-end pages, scheduled tasks, hooks, DB-backed data.)
3. **What components shall it have?** (the *parts*: modules/controllers, models/tables, settings, templates, CSS/JS, tasks, extensions/hook targets.)

### How to run the clarification
- **Top-down, one layer at a time.** Answer to layer 1 *drives* the questions in layer 2; the answer to layer 2 *drives* the concrete list in layer 3. Do not fire all three as a giant checklist up front — let each layer sharpen the next.
- **Let the user answer freely.** The user's words are the source of truth. Paraphrase back what you understood ("So: a plugin that adds a 'featured' flag to forums, with one ACP setting and a front badge — is that right?") and only then proceed.
- **Fold free-form answers into further clarification.** If the user names a feature you can't yet place, ask a *targeted* follow-up on that feature (which module, which data, which permission) rather than moving on.
- **Default to the cheaper artefact when ambiguous** (plugin over application) and *say so* — the user can override. Never silently pick.
- **Stop clarifying when you can state, in 2–3 sentences, the app key, the type (app/plugin), and the concrete component list.** At that point, restate the plan and ask for a go/no-go before scaffolding.

### Application vs. Plugin — the decision rule (propose, don't assume)
| Signal | → Application | → Plugin |
|---|---|---|
| Owns its own database tables / models | ✅ | |
| Needs its own front-end module + AdminCP module + tasks + settings screen | ✅ | |
| Standalone feature with a URL (`?/<appkey>/`) | ✅ | |
| Only hooks into / modifies *existing* core or app behaviour | | ✅ |
| Only adds a setting, a hook, a small template tweak, a task | | ✅ |
| No own data, no own module | | ✅ |

If the user's answer spans both (e.g. "a feature that both hooks into forums *and* needs a settings screen"), propose the heavier option (application) and note the trade-off — do not pick silently.

### What you must have before scaffolding (the definition of "clarified")
- **app/plugin key** (lowercase, `a-z0-9_`, no spaces; becomes the directory, namespace, and DB prefix)
- **type** (application or plugin) — confirmed by the user
- **feature list** (one line each)
- **component list** (modules, models/tables, settings, templates, tasks, hooks) — this *is* layer 3's output
- **target stack** (which IC4 version / dev-stack to build & verify against — see `references/setup-bootstrapping.md`)

---

## 1. The five-step lifecycle (mandatory, every task)

This is the house workflow (from the app `AGENTS.md` files). It is not optional; it is the operating rhythm.

1. **Workspace** — work inside the project directory; check `git status` first.
2. **Raw data** — new notes/docs land in `docs/raw/` (inbox); after processing, move to `docs/architecture/` (ADRs), `docs/api/`, or `docs/`, and archive the source to `docs/raw/archive/`.
3. **Context** — read `knowledge/context/` + `docs/` (and the sister app's `knowledge/context/` for IPS4 patterns) *before* writing, to preserve conventions and avoid re-deriving decisions.
4. **Execution** — app code in `src/<appkey>/`; build scripts in `scripts/`; keep local docs current.
5. **Feedforward & commit** — write new findings to `knowledge/learnings/` (one file per topic, imperative + why), run build/proofs, commit with **Conventional Commits** (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`); one logical change per commit.

---

## 2. Repo layout (commit conventions)

| Path | Purpose | Commit? |
|---|---|---|
| `src/<appkey>/` | the IPS4 app (only app code, app key `<appkey>`) | yes |
| `build/` | generated `.tar` artefacts (ACP-uploadable, root layout) | yes |
| `docs/specification.md` | the requirements spec (the written-up result of the clarification) | yes |
| `docs/progress.md` | status, tasks, **verified proofs** | yes |
| `docs/setup.md` | onboarding: stack setup, build, installation | yes |
| `docs/architecture/` | ADRs — one decision per file | yes |
| `docs/api/` | endpoint / config docs | yes |
| `docs/raw/` | unprocessed inputs (inbox) | yes (but `.gitignore`d content) |
| `knowledge/context/` | IPS4 dev patterns & references | yes |
| `knowledge/learnings/` | agent-extracted lessons | yes |
| `scripts/` | build / helper scripts (`build_tar.php`) | yes |
| `tests/` | tests (typically empty for IC4 apps) | yes |
| `<vendor-dir>/ic4-<version>/` (a path you configure) | **outside the repo** — manufacturer source + zips, **READ-ONLY** | no |

**Vendor rule:** the IC4 source code and vendor zips live *outside* the repo and are read-only. Never commit them; reference by path.

---

## 3. The canonical app structure (mirror `applications/blog/`)

`src/<appkey>/` must contain exactly the IC4 app shape (details in `references/database-schema.md`, `references/packaging-deployment.md`, `references/template-engine.md`):

```
src/<appkey>/
├── Application.php            # namespace IPS\<appkey>; class _Application extends \IPS\Application
├── data/
│   ├── application.json       # REQUIRED — app_directory, application_title, app_author, …
│   ├── schema.json            # DB tables (NO prefix in names)
│   ├── modules.json           # front + admin modules
│   ├── acpmenu.json           # ACP sidebar placement
│   ├── acprestrictions.json   # permission keys
│   ├── settings.json          # ACP settings
│   ├── tasks.json             # scheduled tasks (if any)
│   ├── hooks.json / extensions.json
│   ├── lang.xml               # ALL language strings (only place)
│   ├── theme.xml              # ALL templates (only place)
│   ├── versions.json          # long→human version map
│   └── installLang.json
├── modules/front/<appkey>/index.php   # entry: public function manage()  — NEVER index()
├── modules/admin/<appkey>/manage.php, settings.php
├── tasks/<task>.php            # scheduled tasks
└── extensions/core/…           # extensions (hooks)
```

Hard rules (each one has burned a project before):
- **Controller entry is `manage()`.** `index()` → HTTP 404 with code `2S106/2`.
- **Templates only in `data/theme.xml`, language only in `data/lang.xml`** — no `dev/` or `themes/` in the final tree.
- **Real tabs** in PHP files (literal `\t` escape sequences are a parse error → 500).
- **`app_directory` is load-bearing** in `application.json`; the tar must put `data/application.json` at the **root level** (no `<appkey>/` prefix) — see `references/packaging-deployment.md`.

---

## 4. Bootstrap sequence (after clarification, in order)

1. **Scaffold the repo** with the §2 layout + an initial `AGENTS.md` (copied/adapted from a sister app) and `docs/specification.md` capturing the *written result* of the clarification (key, type, features, components).
2. **Scaffold `src/<appkey>/`** to the §3 shape, starting from the `templates/` in this package (`Application.php.template`, `Model.php.template`, `Extension.php.template`, `Plugin.xml.template`, `Plugin-versions.template`) and mirroring `applications/blog/data/`.
3. **Create the build script** `scripts/build_tar.php` — copy `templates/build_tar.php.template` from this package into `scripts/build_tar.php` and set `$appKey`. The three self-test proofs are part of "done".
4. **Build + prove** (`php scripts/build_tar.php` — all 3 proofs green) — Layer 1 of `references/testing-methods.md`.
5. **Deploy + verify live** on the dev stack (ACP upload, HTTP-200 on front + ACP routes, DB tables present) — Layer 3. Only then is the bootstrap "done"; otherwise mark it "local only, not yet verified".
6. **Feedforward**: record anything new in `knowledge/learnings/`, update `docs/progress.md` with the verified proof status, commit.

For **plugins**, steps 3–5 differ: there is no `.tar` — author the single `.xml` (see `references/install-upgrade.md` §5 and `templates/Plugin.xml.template` / `Plugin-versions.template`) and upload it in ACP → Plugins → Install. The clarification (layers 1–3) and the five-step lifecycle are identical.

---

## 5. Quality bar (per feature)

- Every feature: **proof on the running stack** (HTTP-200 + DB verification) **or** explicitly marked "local only, not yet verified" in `docs/progress.md`.
- Static checks (`php -l`, file existence) are **not** proof — see `references/testing-methods.md`.
- No credentials in commits, docs, or skills — they live in the system.
- Conventional Commits; one logical change per commit.
