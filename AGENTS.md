# AI Workflow Repository

This repo is a personal collection of reusable **skills** and **agents** for
AI coding CLIs. Think of it as a set of recipes — small, opinionated, kept
under version control.

This repo is **public**. Treat everything in it as world-readable.

## Rule for AI agents and human contributors: no secrets, no personal data

When editing, generating, or committing anything in this repo:

- **Never commit** API keys, tokens, passwords, private keys, webhooks with
  secrets, `.env` files with real values, internal hostnames, IPs, or
  machine-specific absolute paths (`/home/<user>/...`).
- **Never commit** personal email addresses, phone numbers, or other
  identifying info unless the user has explicitly asked for it in the
  current conversation.
- In examples and scripts, reference secrets via env vars
  (`api_key="${MY_API_KEY:?…}"`), never literal values.
- If you accidentally stage a secret, **stop** and tell the user before
  committing. Do not run `git commit` on it.

Quick patterns to flag:
`ghp_`/`gho_`/`ghs_`/`ghu_` (GitHub), `sk-`/`sk-proj-` (OpenAI/Anthropic),
`xoxb-`/`xoxp-` (Slack), `AIza…` (Google), `AKIA…` (AWS), `-----BEGIN … PRIVATE
KEY-----`, and any long alphanumeric string adjacent to words like
`key`/`secret`/`token`/`password`.

An optional pre-commit scanner lives at `bin/check-secrets` — opt in with:

```bash
ln -s ../../bin/check-secrets .git/hooks/pre-commit
```

---

## What this repo is

It targets three tools, each of which has its own conventions for how skills
and agents are discovered and invoked:

| CLI            | Skills dir                                            | Agents / subagents dir                       |
| -------------- | ----------------------------------------------------- | -------------------------------------------- |
| Claude Code    | `.claude/skills/<name>/SKILL.md`                      | `.claude/agents/<name>.md`                   |
| Codex CLI      | `.codex/skills/<name>/SKILL.md` *(or `.agents/skills/<name>/SKILL.md`)* | `.codex/agents/<name>/AGENTS.md` (subagents) |
| opencode       | `.opencode/skills/<name>/SKILL.md`                    | `.opencode/agent/<name>.md` *or* `.opencode/agents/<name>.md` |

Each CLI uses its own frontmatter shape and triggers differently, so this
repo keeps **per-CLI variants** of every skill and agent while sharing one
**canonical** human-readable source for each.

### Keep changes simple

This is a personal workflow repo. Prefer the simplest solution that meets the
current need; apply **KISS** and **YAGNI**. Avoid speculative abstractions,
generic frameworks, and production-scale scaffolding. For small personal setup
scripts, prefer syntax checks and dry-run smoke checks over a large maintained
test harness; add automated tests when the actual complexity or risk justifies
their ongoing cost.

---

## Repository layout

```
.
├── AGENTS.md                 # this file
├── README.md                 # quickstart for humans
├── .gitignore
├── bin/
│   └── setup                 # idempotent installer (bash)
├── integrations/
│   └── superpowers.env       # pinned upstream Superpowers source (public metadata only)
├── docs/superpowers/         # global plugin design spec and implementation plan
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md          # canonical / source-of-truth description
│       ├── claude-code/      # Claude Code-flavored SKILL.md + assets
│       ├── codex/            # Codex-flavored SKILL.md + assets
│       └── opencode/         # opencode-flavored SKILL.md + assets
└── agents/
    └── <agent-name>/
        ├── AGENT.md          # canonical / source-of-truth description
        ├── claude-code/
        ├── codex/
        └── opencode/
```

### Canonical vs. variant

- The top-level `SKILL.md` / `AGENT.md` inside each skill or agent folder is
  **canonical**: written for humans, CLI-agnostic, describes intent, triggers,
  inputs/outputs, and any shared resources.
- Each `<cli>/` subfolder contains the actual file(s) the corresponding CLI
  consumes, with the right filename, frontmatter, and any CLI-only assets.

When you add a new skill or agent, write the canonical version first, then
populate the per-CLI subfolders you actually use. Empty subfolders are fine —
the setup script simply skips them.

---

## Per-CLI conventions

### 1. Claude Code

Skills live as `<name>/SKILL.md` under `~/.claude/skills/` (global) or
`.claude/skills/` (project). Required YAML frontmatter:

```yaml
---
name: my-skill
description: One sentence covering what this skill does AND when to trigger it.
---
```

Skills may bundle:

- `scripts/` — executable code (Python/Bash/...)
- `references/` — docs to be loaded into context as needed
- `assets/` — files used in output (templates, icons, fonts, ...)

Subagents live as `<name>.md` under `~/.claude/agents/` or `.claude/agents/`.
Frontmatter uses `name` / `description` and the body is the agent prompt.

In this repo, place Claude Code artifacts at:

- `skills/<name>/claude-code/SKILL.md`
- `agents/<name>/claude-code/<name>.md`

### 2. Codex CLI

Codex discovers skills from several roots; the most useful ones are:

- `$CODEX_HOME/skills/<name>/SKILL.md` — global user
- `~/.agents/skills/<name>/SKILL.md` — global user (cross-tool)
- `<project>/.agents/skills/<name>/SKILL.md` — repo-scoped
- `<project>/.codex/skills/<name>/SKILL.md` — repo-scoped

Frontmatter is `name` / `description` (same shape as Claude Code). Subagents
are written as `AGENTS.md` files inside their own folder. Codex also has its
own command/agent layer, so check `codex docs` for current command names.

In this repo, place Codex artifacts at:

- `skills/<name>/codex/SKILL.md`
- `agents/<name>/codex/AGENTS.md`

### 3. opencode

opencode searches (in this order, project then global):

- `.opencode/skills/<name>/SKILL.md`
- `~/.config/opencode/skills/<name>/SKILL.md`
- `.claude/skills/<name>/SKILL.md`  *(Claude-compatible)*
- `~/.claude/skills/<name>/SKILL.md` *(Claude-compatible)*
- `.agents/skills/<name>/SKILL.md`  *(Agent-compatible)*
- `~/.agents/skills/<name>/SKILL.md` *(Agent-compatible)*

Recognized frontmatter fields are **only**:

- `name` (required)
- `description` (required)
- `license` (optional)
- `compatibility` (optional)
- `metadata` (optional, string-to-string map)

Unknown fields are ignored. Body is markdown instructions.

Custom agents live as `.opencode/agent/<name>.md` (singular folder name also
accepted: `.opencode/agents/<name>.md`). Frontmatter may include `description`,
`mode` (`primary` / `subagent`), `model`, `temperature`, `permission` blocks,
and per-command permissions such as `bash`. **Do not** put a `prompt` field in
the frontmatter — the file body is the prompt.

In this repo, place opencode artifacts at:

- `skills/<name>/opencode/SKILL.md`
- `agents/<name>/opencode/<name>.md`

---

## Setup

The repo includes a `bin/setup` script that installs everything into the
right locations on your machine. It:

1. Detects which of the three CLIs are installed (`command -v`).
2. For each detected CLI, copies/symlinks each skill's variant into the
   CLI's expected destination.
3. Is idempotent — re-running won't duplicate or break existing links.

Run:

```bash
./bin/setup                 # install for all detected CLIs
./bin/setup --dry-run       # show what would happen, change nothing
./bin/setup --cli=opencode  # only target one CLI
./bin/setup --uninstall     # remove links created by previous runs
```

By default the script uses **copies** so you can edit installed skills
without touching this repo. Pass `--link` to use symlinks instead.

### Global Superpowers plugin

`./bin/setup` is also the single command that manages the global Superpowers
plugin for Codex and OpenCode. It installs the full upstream plugin, including
its workflow bootstrap, so it applies across work projects. Do not add
project-scoped `opencode.json` or `.codex/config.toml` plugin declarations;
they would shadow or duplicate the global install.

- The pin lives in `integrations/superpowers.env`: upstream
  `https://github.com/obra/superpowers.git` at `v7.0.0`, Codex marketplace
  `superpowers-dev`, plugin `superpowers`. Both harnesses share this pin.
- Codex: registers the marketplace at the pinned ref
  (`codex plugin marketplace add --ref`), then installs
  `superpowers@superpowers-dev`.
- OpenCode: adds `git+https://github.com/obra/superpowers.git#v7.0.0` with
  `opencode plugin add`.
- Plugins are handled only for CLIs on `PATH`, and `--cli=` filters them.
- Setup uses the native plugin commands and never claims entries that already
  existed. A marketplace name bound to a different source is left untouched.
  Entries this setup creates are recorded in the git-ignored
  `.setup-state/superpowers.tsv`; `--uninstall` removes only those.
- `--dry-run` prints the intended plugin commands and runs no mutating CLI
  command or ownership writes. `--uninstall --dry-run` previews removals.

To change the shared pin: run `./bin/setup --uninstall`, edit
`SUPERPOWERS_REF` in `integrations/superpowers.env`, then run `./bin/setup`.
Uninstalling first matters because re-running setup does not replace an
existing entry (OpenCode matches by package name), and Codex may report a
conflict for a marketplace registered at the old ref.

---

## Adding a new skill

1. `mkdir -p skills/<name>`
2. Write `skills/<name>/SKILL.md` (canonical, CLI-agnostic).
3. For each CLI you want to support, create a flavored copy:
   - `skills/<name>/claude-code/SKILL.md`
   - `skills/<name>/codex/SKILL.md`
   - `skills/<name>/opencode/SKILL.md`
4. Run `./bin/setup`.

## Adding a new agent

1. `mkdir -p agents/<name>`
2. Write `agents/<name>/AGENT.md` (canonical).
3. Add the per-CLI variants. opencode is a single `.md` file; Claude Code is
   `<name>.md`; Codex is `AGENTS.md`.
4. Run `./bin/setup`.

---

## Editing a skill or agent

- Edit the canonical `SKILL.md` / `AGENT.md` first; that's the source of
  truth for what the skill *means*.
- Then update the per-CLI variants to match.
- If you used `setup --link`, edits in this repo are picked up immediately.
- If you used copies (default), re-run `./bin/setup` to refresh the installed
  copies, or edit the CLI's installed copy directly and back-port to the repo.
