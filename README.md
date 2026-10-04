# my-ai-workflow

Personal collection of reusable **skills** and **agents** for AI coding CLIs.
Supports Claude Code, Codex CLI, and opencode.

See [`AGENTS.md`](./AGENTS.md) for the full structure and conventions.

## Quickstart

```bash
# Install skills/agents into every CLI you have installed
./bin/setup

# Or target a specific CLI
./bin/setup --cli=opencode,claude-code

# Preview what would be installed
./bin/setup --dry-run
```

## Adding a skill

```bash
mkdir -p skills/<name>
$EDITOR skills/<name>/SKILL.md           # canonical description
mkdir -p skills/<name>/{claude-code,codex,opencode}
# ...write each variant's SKILL.md...
./bin/setup
```