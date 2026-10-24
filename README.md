# my-ai-workflow

A personal, version-controlled collection of reusable **skills** and **agents**
for AI coding CLIs. Targets three tools, each with its own conventions:

| CLI            | Skills location                                | Agents / subagents location               |
| -------------- | ---------------------------------------------- | ----------------------------------------- |
| Claude Code    | `.claude/skills/<name>/SKILL.md`               | `.claude/agents/<name>.md`                |
| Codex CLI      | `.codex/skills/<name>/SKILL.md`                | `.codex/agents/<name>/AGENTS.md`          |
| opencode       | `.opencode/skills/<name>/SKILL.md`             | `.opencode/agents/<name>.md`              |

See [`AGENTS.md`](./AGENTS.md) for the full structure, per-CLI conventions,
and the no-secrets rule for this public repo.

## Why per-CLI variants?

Each CLI uses a different frontmatter shape, file naming convention, and
trigger mechanism. Rather than maintain a single shared file with three
flavors wedged together, this repo keeps:

- one **canonical** `SKILL.md` / `AGENT.md` per skill/agent (human-readable,
  CLI-agnostic, describes intent and shared assets), and
- per-CLI variants under `<name>/<cli>/` with the exact filename, frontmatter,
  and any CLI-only resources that CLI expects.

## Layout

```
.
├── AGENTS.md           # repo instructions (loaded by AI agents)
├── README.md           # this file
├── LICENSE             # MIT
├── .gitignore
├── bin/
│   ├── setup           # idempotent installer (also manages Superpowers plugins)
│   └── check-secrets   # pre-commit secret scanner
├── integrations/
│   ├── superpowers.env # pinned upstream Superpowers source (public metadata only)
│   └── opencode/       # managed opencode guardrails (permissions + plugins)
├── docs/superpowers/   # global plugin design spec and implementation plan
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md          # canonical
│       ├── claude-code/
│       ├── codex/
│       └── opencode/
└── agents/
    └── <agent-name>/
        ├── AGENT.md          # canonical
        ├── claude-code/
        ├── codex/
        └── opencode/
```

## Quickstart

```bash
# Clone
git clone https://github.com/dzmitryk-dev/my-ai-workflow.git
cd my-ai-workflow

# Install all skills/agents into every CLI you have installed,
# plus the pinned global Superpowers plugin for Codex and OpenCode
./bin/setup

# Or target a specific CLI
./bin/setup --cli=opencode,claude-code

# Preview what would be installed (safe, no changes)
./bin/setup --dry-run

# Use symlinks instead of copies (edits in this repo are picked up live)
./bin/setup --link
```

## Global Superpowers plugin

`./bin/setup` is the single command for managing the global Superpowers plugin
for Codex and OpenCode. It installs the full upstream plugin, including its
workflow bootstrap, so it applies across your work projects. The plugin is
pinned to upstream release `v7.0.0`. Do not add project-scoped `opencode.json`
or `.codex/config.toml` plugin declarations; they would shadow or duplicate the
global install.

The pin lives in [`integrations/superpowers.env`](./integrations/superpowers.env):
the public repository `https://github.com/obra/superpowers.git`, ref `v7.0.0`,
Codex marketplace `superpowers-dev`, and plugin `superpowers`.

- **Codex:** registers the marketplace at the pinned ref with
  `codex plugin marketplace add --ref`, then installs `superpowers@superpowers-dev`.
- **OpenCode:** adds `git+https://github.com/obra/superpowers.git#v7.0.0` with
  `opencode plugin add`.
- Plugins are handled only for CLIs found on your `PATH`. `--cli=` limits the
  target as it does for skills and agents.
- Setup uses each CLI's native plugin commands, so unrelated plugins and
  settings are preserved. Entries that already existed are not claimed, and a
  marketplace name already bound to a different source is left untouched.
  Entries this setup creates are recorded in the git-ignored
  `.setup-state/superpowers.tsv`.

```bash
./bin/setup --dry-run             # print intended plugin and skill actions
./bin/setup --uninstall           # remove owned plugin entries and tracked paths
./bin/setup --uninstall --dry-run # preview the uninstall
```

`--dry-run` runs no mutating CLI command and records no ownership state.
`--uninstall` removes only the entries recorded in the state file.

### Updating the shared pin

```bash
./bin/setup --uninstall           # remove the entries this repo created at the old pin
$EDITOR integrations/superpowers.env   # change SUPERPOWERS_REF
./bin/setup                       # install the new pin
```

Uninstall first because re-running setup does not replace an existing entry
(OpenCode matches by package name), and Codex may report a conflict for a
marketplace registered at the old ref. If a conflict is reported for a
marketplace that existed before this repo managed it, resolve it manually.

## Adding a skill

```bash
mkdir -p skills/<name>
$EDITOR skills/<name>/SKILL.md              # canonical, CLI-agnostic

# Add a per-CLI variant for each CLI you want to support
mkdir -p skills/<name>/claude-code
$EDITOR skills/<name>/claude-code/SKILL.md

mkdir -p skills/<name>/codex
$EDITOR skills/<name>/codex/SKILL.md

mkdir -p skills/<name>/opencode
$EDITOR skills/<name>/opencode/SKILL.md

./bin/setup
```

## Adding an agent

```bash
mkdir -p agents/<name>
$EDITOR agents/<name>/AGENT.md             # canonical

# Per-CLI variants. Claude Code and opencode use <name>.md;
# Codex uses AGENTS.md inside the agent's folder.
$EDITOR agents/<name>/opencode/<name>.md
# ...etc.

./bin/setup
```

## opencode guardrails

`integrations/opencode/` is the source of truth for the guardrails installed
into `~/.config/opencode/`. `./bin/setup` copies the plugins and merges the
managed `permissions`/`policies` keys into the global `opencode.jsonc`,
backing it up first and leaving every other key (`mcp`, `plugins`, ...) alone.

| Guardrail | Behaviour |
| --------- | --------- |
| `git commit` / `git push` | Prompts **every** time, even after "Allow always" |
| reading `~/.gradle/**` | Denied outright — no prompt, no approval escape |
| writing `~/.gradle/**` | Allowed — a redirect target reveals nothing |
| `~/.config/opencode/**` | Denied both ways — the harness cannot rewrite its own guardrails |

```bash
./bin/setup --cli=opencode --dry-run   # preview
./bin/setup --cli=opencode             # install
```

Two pieces are needed because neither alone is sufficient:

- **`config.jsonc`** — `permissions` rules. A rule with `effect: "ask"` is
  resolved once; choosing "Allow always" persists a project-scoped `allow` and
  the rule never prompts again.
- **`plugins/git-approval.ts`** — a `permission.evaluate` hook that runs *after*
  configured rules and saved approvals and re-forces `ask`, so the prompt
  returns on every command. It only ever escalates; a configured `deny` is
  final.

`plugins/fs-guard.ts` closes a gap in OpenCode's shell handling: the
`external_directory` permission only inspects a command's *working directory*,
so `cd ~/.gradle` is rejected while `unzip ~/.gradle/caches/.../x.jar` is not.
The hook reads the command text instead.

A path merely appearing in a command is not enough to deny it. What counts is
whether the command reads it: `cat ~/.gradle/x` is denied, `echo x >> ~/.gradle/y`
is not, and `git commit -m "drop ~/.gradle"` passes because the path is message
text. `~/.config/opencode` is the exception — denied in both directions, because
reading it leaks and writing it tampers.

Both plugins are text heuristics, not sandboxes: a binary that opens a denied
path from inside its own logic is invisible to them.

```bash
node --experimental-strip-types integrations/opencode/fs-guard.test.ts
```

## Useful scripts

| Script                    | Purpose                                                       |
| ------------------------- | ------------------------------------------------------------- |
| `./bin/setup`             | Install per-CLI variants and the pinned Superpowers plugin    |
| `./bin/setup --uninstall` | Remove tracked paths and plugin entries this repo created     |
| `./bin/check-secrets`     | Scan staged changes for accidentally-committed secrets        |

To enable the secret scanner as a pre-commit hook:

```bash
ln -s ../../bin/check-secrets .git/hooks/pre-commit
```

## Contributing

This is a personal collection, but the structure is meant to be portable.
If you fork it:

1. **Do not commit secrets.** See the rule at the top of
   [`AGENTS.md`](./AGENTS.md).
2. Write the canonical `SKILL.md` / `AGENT.md` first, then the per-CLI
   variants.
3. Test your skill/agent with at least one CLI before committing.
4. Keep per-CLI variants in sync when the canonical changes.

## License

MIT — see [`LICENSE`](./LICENSE).
