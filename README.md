# Invision Community 4 Development Agent (`invision-v4-dev-agent`)

An open-source Hermes Agent Skill designed according to the `agentskills.io` standard. This skill empowers AI agents to generate, refactor, and maintain Plugins and Applications specifically for **Invision Community 4 (IC4)**.

## Features

- **Setup & Bootstrapping:** Copy-ready docker-compose dev stack (`assets/dev-stack/`), fixed development credentials, and a step-by-step fresh-installation walkthrough (see `references/setup-bootstrapping.md`).
- **Hook System Expertise:** Guidance on IC4 monkey patching, code overrides, and template hooks.
- **ActiveRecord Guidance:** Ready-to-use patterns for custom database models, nodes, and form elements.
- **Application Scaffold Templates:** Pre-configured templates for IC4 Application headers, Extensions, and Plugins.
- **Strict Version Scoping:** Safeguards to prevent LLMs from generating incompatible Invision Community v5 code.

## Installation into Hermes Agent

Clone or copy this folder into your Hermes Agent skills directory:

```bash
cp -r invision-v4-dev-agent ~/.hermes/skills/
```

Or invoke directly via slash command:

```text
/invision-v4-dev-agent
```

## Structure

- `SKILL.md`: Root configuration and agent instruction file.
- `references/`: Deep-dive documentation loaded on-demand by the agent during coding sessions.
- `templates/`: Minimal PHP and XML boilerplate files for generation.
- `assets/dev-stack/`: Complete, copy-ready IC4 dev stack (docker-compose.yml, PHP Dockerfile, FPM pool, nginx vhost, source-prepare script, dev-only license bypass) for bootstrapping a fresh installation.
- `scripts/bootstrap_skills.sh`: Idempotent scaffolder for the recommended companion skills (phpqa, git, ssh, docker, curl) — creates thin doc-linked stubs (see `references/tooling.md`), never overwrites existing skills.
