# Manage Superpowers as a Global Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make this repository install and remove the full Superpowers v7.0.0 plugin globally for Codex and OpenCode.

**Architecture:** Keep the upstream URL, release ref, and Codex marketplace identity in a small tracked manifest. Extend `bin/setup` to call each harness's native plugin manager, tracking only changes it creates in ignored local setup state. Remove the temporary project-local plugin declarations and document the global setup behavior.

**Tech Stack:** Bash, OpenCode CLI plugin manager, Codex CLI plugin/marketplace manager, shell-based integration tests with fake CLIs.

**Spec:** `docs/superpowers/specs/2026-10-18-superpowers-global-config.md`

## Global Constraints

- Pin OpenCode and Codex to upstream ref `v7.0.0`.
- Preserve unrelated user configuration by using native CLI plugin commands.
- Honor `--cli`, `--dry-run`, and `--uninstall` in `bin/setup`.
- Never uninstall plugin or marketplace entries that existed before this repo managed them.
- Do not vendor RTK, credentials, or machine-specific global config.

## Review Focus

- An already-installed plugin must not be duplicated or claimed as repo-owned; test install when the fake CLI reports a pre-existing plugin.
- A marketplace name already used for another source must not be overwritten; test conflicting marketplace metadata.
- `--dry-run` must not invoke mutating CLI commands or write state; test with command-log fakes.
- `--uninstall` must remove only state-marked entries and preserve unrelated plugins; test mixed owned/pre-existing state.
- Missing Codex or OpenCode executables must not break installation of the other detected harness; test each missing-CLI case.

---

### Task 1: Track Superpowers source and reconcile global plugin installs

**Files:**
- Create: `integrations/superpowers.env`
- Modify: `bin/setup`
- Test: `tests/setup-superpowers.sh`

**Interfaces:**
- Manifest variables: `SUPERPOWERS_REPOSITORY`, `SUPERPOWERS_REF`, `SUPERPOWERS_CODEX_MARKETPLACE`, `SUPERPOWERS_CODEX_PLUGIN`.
- Codex install: register the Git marketplace at the pinned ref, then install `<plugin>@<marketplace>`.
- OpenCode install: add the pinned Git package spec using `opencode plugin add`.
- State: a dedicated ignored setup-state file records marketplace/plugin entries created by this setup; do not overload the existing installed-path TSV.

- [ ] **Step 1: Write fake-CLI tests** for install commands, repeat setup, `--cli` filtering, pre-existing entries, conflicting Codex marketplace identity, dry-run, and ownership-aware uninstall.
- [ ] **Step 2: Run the tests** with `bash tests/setup-superpowers.sh` and confirm they fail because `bin/setup` does not manage plugin installs yet.
- [ ] **Step 3: Add the pinned manifest** with repository `https://github.com/obra/superpowers.git`, ref `v7.0.0`, marketplace `superpowers-dev`, and plugin `superpowers`.
- [ ] **Step 4: Extend `bin/setup`** to detect installed Codex/OpenCode CLIs, invoke their native plugin managers, preserve pre-existing entries, track owned entries, and honor install/dry-run/uninstall/CLI filtering.
- [ ] **Step 5: Re-run the fake-CLI tests** and confirm they pass, including preservation of unrelated plugin entries.

### Task 2: Replace project-local trial configs with global setup documentation

**Files:**
- Verify absent: `opencode.json`
- Verify absent: `.codex/config.toml`
- Add: `docs/superpowers/specs/2026-10-18-superpowers-global-config.md`
- Add: `docs/superpowers/plans/2026-10-18-superpowers-global-config.md`
- Modify: `README.md`
- Modify: `AGENTS.md`

**Interfaces:**
- `./bin/setup` is the single documented command for managing the global plugin setup.
- The docs state that the plugin is pinned, applies across work projects, and includes Superpowers' full workflow bootstrap.

- [ ] **Step 1: Confirm the project-scoped declarations are absent** so they cannot shadow or duplicate the global install. These were untracked drafts in the original checkout and are not part of this implementation worktree; do not recreate them here.
- [ ] **Step 2: Update the repo layout and setup docs** with the manifest path, Codex/OpenCode behavior, dry-run and uninstall behavior, and instructions for updating the shared pin.
- [ ] **Step 3: Review the public diff** to ensure it contains only public URLs/version metadata and no global config contents or credentials.

### Task 3: Verify the complete setup path

**Files:**
- Verify: `bin/setup`, `tests/setup-superpowers.sh`, `README.md`, `AGENTS.md`

- [ ] **Step 1: Run** `bash -n bin/setup tests/setup-superpowers.sh` and require success.
- [ ] **Step 2: Run** `bash tests/setup-superpowers.sh` and require all cases to pass.
- [ ] **Step 3: Run** `./bin/setup --dry-run` and confirm it reports intended Codex/OpenCode actions without changing the working tree or invoking mutating commands.
- [ ] **Step 4: Run** `git diff --check` and inspect `git status --short` to confirm a cleanly scoped, secret-free change set.
