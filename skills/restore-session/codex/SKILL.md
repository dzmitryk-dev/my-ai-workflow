---
name: restore-session
description: Use when starting a fresh session and needing to continue saved work — "restore", "continue", "resume", "pick up where we left off", "where did we stop". Rebuilds context from a session checkpoint before touching code.
---

# Restore Session

## Overview

Load a checkpoint written by `save-session`, rebuild just enough context, check for
drift, then confirm the next step before acting.

The checkpoint is a starting point, not a script. Read the small files first; open the
plan and spec snapshots only when the work needs them.

## Workflow

1. **Locate.** Walk up from the current directory looking for `.ai/sessions/`. If there
   is none, say "no saved session found in `<path>`" and stop. Do not invent context.
2. **Choose the stream.** One folder → use it. Several → list each slug with its goal
   and last-updated time, and ask which one, unless the human already named it.
3. **Read only `handoff.md`, `progress.md`, and `meta.md`.** Open `plan.md`/`spec.md`
   later, per step, as the work requires. If `progress.md` is missing or `meta.md` has
   no git fields, say so plainly, play back from what exists, and treat the git drift as
   unknown rather than a failure. Never fill gaps with invented context.
4. **Check for drift** against `meta.md`:
   - `git branch --show-current`, `git rev-parse --short HEAD`, `git status --short`
     (outside a git repo, skip these and report drift as unknown)
   - HEAD moved → `git log --oneline <meta HEAD>..HEAD` and `git diff --stat <meta HEAD>`
   - plan/spec source vs `.ai/sessions/<slug>/plan.md` and `spec.md` → diff them. If the
     source differs, read only the changed parts so the playback can say what changed.
     The source wins.
5. **Play back**, at most ~15 lines: goal, where you stopped, next step, blockers or open
   questions, and drift ("matches the dump" when nothing changed). State facts, never
   secret values copied from the dump.
6. **Ask** whether to proceed with the recorded next step or something else. Do not
   edit files until the human answers. Ask blocking open questions before the step they
   block.
7. **Work from `progress.md` as the live checklist** — tick items after meaningful
   steps, not after every edit. `plan.md` and `spec.md` are frozen snapshots: never
   hand-edit them. If scope changes, the plan source is authoritative — re-snapshot
   through `save-session`.

## Drift handling

| Drift | Action |
|---|---|
| Different branch than recorded | Report it; ask whether to switch or continue here. |
| New commits since recorded HEAD | Read the log, describe what changed, re-derive the next step. |
| Recorded dirty files are now clean or committed | Treat that work as done and confirm it. |
| Recorded dirty file is still dirty but its content changed | Compare with the dump's description, report what changed, and check the next step still holds. |
| Plan/spec source differs from the snapshot | The source wins; read the changed parts before acting. |
| Dump incomplete, or no git fields recorded | Play back from what exists; mark drift unknown. |
| Project root moved | Note it; the current repo root is authoritative for new writes. |

## Common mistakes

| Mistake | Fix |
|---|---|
| Loading the whole plan and spec into context | Handoff and progress first; plan on demand. |
| Acting before confirmation | Always ask before the first edit. |
| Trusting a stale dump | Run the drift checks. |
| Guessing between several streams | List them and ask. |
| Redoing completed items | `progress.md` checkboxes are the source of truth. |
| Silently replacing the recorded next step | Say why, then ask. |
| Repeating token or key values from a stale handoff | Playback repeats facts, not secret values; paraphrase them. |
| Committing or pushing as part of "restore" | Restore ends at a confirmed next step. |

## Red flags — STOP

- Coding before the playback.
- "The handoff is probably still valid" with no git check.
- Reading every file in `.ai/sessions/<slug>/`.
- Editing `plan.md` or `spec.md` to match the code — those snapshots are frozen.
