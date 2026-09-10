# Invision Community 4: Recommended Tooling & Companion Skills

IC4 app/plugin work leans on a small set of **general-purpose tools** that this skill deliberately does *not* re-document — each has its own home (vendor docs, dedicated skills). This page lists the recommended companion skills and tools, what they're used for in this workflow, and where their authoritative docs live.

> **Bootstrapping:** the companion skills are not bundled with this package (they are environment-general, not IC4-specific). Run `scripts/bootstrap_skills.sh` to scaffold the missing ones as minimal, doc-linked stubs under your skills directory (idempotent — it never overwrites an existing skill). See §4.

## 1. Companion skill matrix

| Companion skill / tool | Used for (in this workflow) | Where it appears in this skill | Authoritative docs |
|---|---|---|---|
| **phpqa** (`jakzal/phpqa`) | Static analysis on the Docker host: `parallel-lint`, `phpcs` (Security/PSR12), `php-cs-fixer`, `phpmetrics`, `pdepend`, `phpstan` | `references/testing-methods.md` Layer 2 | <https://github.com/jakzal/phpqa> (README + CI examples) · <https://docs.phpstan.org> · <https://phpcsstandards.dev> |
| **git** (GitHub / GitLab / Gitea) | Branching, conventional commits, PR/issue workflows, pushing the repo | everywhere; repo layout in `references/agentic-bootstrap-guide.md` §2 | GitHub: <https://docs.github.com/en/get-started> · GitLab: <https://docs.gitlab.com> · Gitea: <https://docs.gitea.com> (REST API: <https://docs.gitea.com/next/api/>) · `tea` CLI: <https://gitea.com/gitea/tea> (package: `tea-cli`) · `tea` agent skill: <https://gitea.com/gitea/gitea-tea-skill> · `gh` CLI: <https://cli.github.com/manual> |
| **ssh** | Driving the Docker host / dev-stack host remotely (key-based auth, `BatchMode`, quoting rules) | `references/testing-methods.md` (host invocations), `references/setup-bootstrapping.md` | OpenSSH manual: <https://man.openbsd.org/ssh> · config: <https://man.openbsd.org/sshd_config> |
| **docker** | Running the dev stack (compose) and the phpqa image | `references/setup-bootstrapping.md`, `assets/dev-stack/`, `references/testing-methods.md` Layer 2 | <https://docs.docker.com/engine/> · compose: <https://docs.docker.com/compose/> |
| **curl** | Driving the ACP installer/login over HTTP, HTTP-200 verification, reading error responses | `references/testing-methods.md` Layer 3 (ACP login, live checks) | <https://everything.curl.dev> · manual: <https://curl.se/docs/manpage.html> |

Supporting (optional, not stubbed by the bootstrapper):

| Tool | Why | Docs |
|---|---|---|
| **IC4 Developer documentation** (vendor) | The primary IC4 API reference for classes, patterns, and the app/plugin extension model | <https://developer.invisioncommunity.com/> (Invision Community developer docs) |
| **composer** | Only needed if a tool requires `vendor/` (e.g. `phpstan` with extensions) — most QA runs set `SKIP_COMPOSER_INSTALL=true` | <https://getcomposer.org/doc> |
| **mysql client** | DB verification queries in Layer 3 live checks | <https://dev.mysql.com/doc/refman/8.0/en/mysql-command-options.html> |

## 2. How the pieces connect

```
clarify (agentic-bootstrap-guide.md)
  └─ scaffold + code (templates/, app-structure)
       └─ build .tar (packaging-deployment.md)
            └─ verify:  Layer 1 build proofs (local, no tools)
                        Layer 2 phpqa on Docker host  ← phpqa + docker + ssh
                        Layer 3 live checks on stack  ← curl + mysql + docker/ssh
       └─ ship: commit / PR / upload via ACP          ← git (github|gitlab|gitea)
```

## 3. Environment note

This skill is **environment-agnostic**: it never hard-codes hosts, IPs, or users. Wherever your dev stack and Docker host live, point the companion tools at them (SSH config entries, `docker` context, curl targets). The fixed *development credentials* for the bundled dev stack are documented in `references/setup-bootstrapping.md` — those are properties of the stack, not of your machine.

## 4. Bootstrapping the companion skills

```bash
bash scripts/bootstrap_skills.sh --dry-run    # show what would be created
bash scripts/bootstrap_skills.sh              # create missing stubs in ~/.hermes/skills/
bash scripts/bootstrap_skills.sh --dir DIR    # target a different skills directory
```

What it does, per skill in the §1 matrix:
- If the skill already exists (a `<name>/SKILL.md` in the target dir), it is **skipped untouched**.
- Otherwise it creates a minimal `SKILL.md` stub: valid frontmatter (`name`, `description`), a "what it's for" line, the key vendor-doc links, and a pointer back to this reference.
- No network access, no package installs — scaffolding only. Fill in host-specific details (SSH config, Docker context, git remotes) yourself afterwards.

The stubs are intentionally thin. Once you've used a companion skill on a real task, replace the stub with a full skill (the same format: frontmatter + workflow + pitfalls) so your accumulated, host-specific lessons persist.
