# Superpowers Global Plugin Setup

## Goal

Manage the full Superpowers plugin for Codex and OpenCode from this repository,
so one setup command configures it globally for the user's work projects.

## Approved scope

- Install the upstream Superpowers plugin, not a vendored copy of its skills.
- Pin both harnesses to upstream release `v7.0.0`.
- Manage global Codex and OpenCode plugin configuration through their native
  plugin commands, preserving unrelated user settings.
- Integrate with `bin/setup`: install for detected/requested harnesses, honor
  `--dry-run` and `--uninstall`, and track only artifacts created by this repo.
- Remove the temporary project-scoped plugin declarations; they don't meet the
  requirement to apply across work repositories.
- Keep RTK and other binaries out of scope.

## Constraints

- A repeated setup must not create duplicate plugin or marketplace entries.
- Uninstall must not remove pre-existing user-managed plugin entries.
- The full plugin includes its workflow bootstrap; this trial intentionally
  enables the complete Superpowers set.
- The repository is public. Do not copy credentials or machine-specific global
  configuration into it.
