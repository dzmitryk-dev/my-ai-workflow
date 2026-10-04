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
│   ├── setup           # idempotent installer
│   └── check-secrets   # pre-commit secret scanner
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

# Install all skills/agents into every CLI you have installed
./bin/setup

# Or target a specific CLI
./bin/setup --cli=opencode,claude-code

# Preview what would be installed (safe, no changes)
./bin/setup --dry-run

# Use symlinks instead of copies (edits in this repo are picked up live)
./bin/setup --link
```

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

## Useful scripts

| Script                    | Purpose                                                       |
| ------------------------- | ------------------------------------------------------------- |
| `./bin/setup`             | Install per-CLI variants into each CLI's expected directories |
| `./bin/setup --uninstall` | Remove previously installed paths (tracked in state file)     |
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