#!/usr/bin/env bash
# bootstrap_skills.sh — scaffold recommended companion skills for the
# invision-v4-dev-agent workflow (see references/tooling.md).
#
# Companion skills: phpqa, git (GitHub/GitLab/Gitea), ssh, docker, curl
#
# Behaviour:
#   - Targets $SKILLS_DIR (default: ~/.hermes/skills).
#   - For each companion skill: if <dir>/<name>/SKILL.md exists, skip it.
#   - Otherwise create a thin, doc-linked stub (no network, no installs).
#   - Idempotent: running twice is safe; existing skills are never touched.
#
# Usage:
#   bash scripts/bootstrap_skills.sh                # scaffold into ~/.hermes/skills
#   bash scripts/bootstrap_skills.sh --dry-run      # show what would be created
#   bash scripts/bootstrap_skills.sh --dir DIR      # target a different skills dir
#
# Exit codes: 0 = ok, 1 = bad usage, 2 = target dir not creatable.

set -eu

SKILLS_DIR=""
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --dir)
            if [ $# -lt 2 ]; then
                echo "ERROR: --dir needs a value" >&2
                exit 1
            fi
            SKILLS_DIR="$2"
            shift
            ;;
        --dir=*) SKILLS_DIR="${1#--dir=}" ;;
        -h|--help)
            sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1 (use --dry-run, --dir DIR)" >&2
            exit 1
            ;;
    esac
    shift
done

if [ -z "$SKILLS_DIR" ]; then
    SKILLS_DIR="$HOME/.hermes/skills"
fi

# --- companion skill definitions (name | description | doc links) ----------

create_stub() {
    local name="$1" desc="$2" links="$3"
    local dest="$SKILLS_DIR/$name"
    local file="$dest/SKILL.md"

    if [ -f "$file" ]; then
        echo "skip   $name  (exists: $file)"
        return
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "create $name  (stub at $file)"
        return
    fi

    mkdir -p "$dest"
    {
        echo "---"
        echo "name: $name"
        echo "description: $desc"
        echo "---"
        echo ""
        echo "# $name"
        echo ""
        echo "Scaffolded by \`invision-v4-dev-agent\` \`scripts/bootstrap_skills.sh\` — a thin"
        echo "doc-linked stub, not a full skill. Companion of the Invision Community 4"
        echo "development skill; see its \`references/tooling.md\` for the full matrix."
        echo ""
        echo "## What it's for"
        echo ""
        echo "$desc"
        echo ""
        echo "## Authoritative documentation"
        echo ""
        printf '%s\n' "$links"
        echo ""
        echo "## Notes"
        echo ""
        echo "- This stub is intentionally minimal: fill in your environment specifics"
        echo "  (hosts, remotes, contexts) and workflows as you use the tool, or replace"
        echo "  it with a full skill (same format: frontmatter + workflow + pitfalls)."
        echo "- Keep it environment-specific *here*, not in the IC4 skill — the IC4 skill"
        echo "  stays environment-agnostic."
    } > "$file"
    echo "create $name  ($file)"
}

# --- run --------------------------------------------------------------------

if [ "$DRY_RUN" -eq 0 ] && [ ! -d "$SKILLS_DIR" ]; then
    if ! mkdir -p "$SKILLS_DIR"; then
        echo "ERROR: cannot create skills dir: $SKILLS_DIR" >&2
        exit 2
    fi
fi

echo "Target skills dir: ${SKILLS_DIR}"$([ "$DRY_RUN" -eq 1 ] && echo " (dry run)")
echo ""

create_stub "phpqa" \
    "Run PHP static analysis (parallel-lint, phpcs Security/PSR12, php-cs-fixer, phpmetrics, pdepend, phpstan) via the jakzal/phpqa Docker image." \
    "- jakzal/phpqa image (tools, tags, CI examples): https://github.com/jakzal/phpqa
- PHPStan: https://docs.phpstan.org
- PHP_CodeSniffer standards: https://phpcsstandards.dev
- php-cs-fixer: https://cs.symfony.com/doc"

create_stub "git" \
    "Git workflows across hosting providers (GitHub, GitLab, Gitea): branching, conventional commits, PRs/issues, remotes, REST APIs." \
    "- Git: https://git-scm.com/doc
- GitHub docs: https://docs.github.com/en/get-started
- GitLab docs: https://docs.gitlab.com
- Gitea docs: https://docs.gitea.com (REST API: https://docs.gitea.com/next/api/)
- Gitea tea CLI: https://gitea.com/gitea/tea (package: tea-cli)
- Gitea tea agent skill: https://gitea.com/gitea/gitea-tea-skill
- gh CLI: https://cli.github.com/manual"

create_stub "ssh" \
    "Drive remote dev/Docker hosts over SSH: key-based auth, ssh_config entries, BatchMode, and quoting rules for remote command execution." \
    "- OpenSSH manual: https://man.openbsd.org/ssh
- ssh_config reference: https://man.openbsd.org/ssh_config
- Best practices: https://www.ssh.com/ssh"

create_stub "docker" \
    "Operate Docker and docker compose: dev stacks, pinned image tags, healthchecks, volumes, and log inspection." \
    "- Docker Engine docs: https://docs.docker.com/engine/
- Docker Compose: https://docs.docker.com/compose/
- Best practices: https://docs.docker.com/engine/faq/#best-practices"

create_stub "curl" \
    "Drive HTTP endpoints from the shell: ACP install/login flows, HTTP-200 verification, cookie jars, and reading error responses." \
    "- curl everything (recipes): https://everything.curl.dev
- curl man page: https://curl.se/docs/manpage.html
- HTTP reference: https://developer.mozilla.org/en-US/docs/Web/HTTP"

echo ""
echo "Done. Review the stubs, then fill in environment specifics or replace them with full skills."
echo "Full companion matrix: references/tooling.md in invision-v4-dev-agent."
