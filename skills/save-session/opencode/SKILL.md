---
name: save-session
description: Use when wrapping up work and a fresh session must continue it later — end of day, usage limits running out, or switching tasks. Triggers include "save session", "wrap up", "handoff", "dump context", "checkpoint", "continue tomorrow".
---

# Save Session

## Overview

Write a checkpoint under `.ai/sessions/<slug>/` in the **current project**, then stop.

This does not resume, clone, or replay the conversation — the harness's own resume flag
covers that. The checkpoint is what a *fresh* session reads to know the goal, the plan,
the spec, what is done, and the exact next step.

One folder per work stream. Every save updates that folder; never create one folder
per save and never write into `.superpowers/` or another harness directory.

## Output layout

| File | Purpose |
|---|---|
| `handoff.md` | Short one-pager: goal, done, decisions, next step. **Required.** |
| `progress.md` | Plan checklist plus where you stopped. **Required.** |
| `plan.md` | Snapshot of the approved plan. Required when a plan exists. |
| `spec.md` | Snapshot of the design/spec. Required when a spec exists. |
| `meta.md` | Git state, provenance, save history. **Required.** |

`<slug>` is kebab-case derived from the plan/spec filename with any date prefix
stripped (`2026-10-24-retry-logic.md` → `retry-logic`), falling back to the branch. It
never contains a date. If an existing `.ai/sessions/*/` already matches this work,
reuse it; if the branch is generic (`main`, `master`, `develop`) and the existing folder
belongs to unrelated work, ask instead of reusing or inventing a suffix.

## Workflow

1. **Anchor at the project root.** `.ai/sessions/` always lives at the top of the
   project, never beside the subdirectory you happen to be in. Use
   `git rev-parse --show-toplevel`; outside a git repo, use the top-level directory you
   are working in.
2. **Find the stream.** List `.ai/sessions/`. If exactly one folder matches the
   current work, reuse it. Otherwise derive the slug as described above. Ask only when
   the choice is genuinely ambiguous.
3. **Gather facts before writing.** Plan path, spec path, `git branch --show-current`,
   `git rev-parse --short HEAD`, `git status --short`, and the files touched this
   session. If no plan or spec exists, say so in `handoff.md` — never invent one.
4. **Write the files** using the templates below. Snapshots are copies of the current
   plan/spec content, checked state included. Do not edit the originals to match the
   dump, and do not edit `plan.md`/`spec.md` by hand afterwards.
5. **Keep `handoff.md` under ~60 lines.** Facts, not narrative.
6. **Keep the dump local.** Run `git check-ignore -q .ai/sessions`; if it is not
   ignored, append `.ai/sessions/` to `.git/info/exclude`. Do not modify a tracked
   `.gitignore` and do not commit anything. Outside a git repo, record `Git branch:
   none`, `Git HEAD: no commits`, `Dirty files: unknown`, and skip the ignore step.
7. **Report** the folder path, the one-line next step, and: *start a fresh session and
   say "restore"*.

## Templates

`handoff.md`:

```markdown
# Handoff — <work stream>

## Goal
<one or two sentences: what "done" means>

## Done this session
- <change, file, or decision>

## Decisions
- <decision> — <why>   <!-- include decisions made in conversation, not only ones in the plan/spec -->

## Where we stopped
<concrete state: what exists, what is half-done, what is uncommitted>

## Next step
<one concrete action, naming files/functions; the first thing to do next session>

## Open questions
- <question only the human can answer, or "none">
```

`progress.md`:

```markdown
# Progress — <work stream>

- [x] <done step>   <!-- copy task wording from the plan verbatim -->
- [ ] <next step>
- [ ] <later step>

Where I stopped: <one sentence>
Blockers: <or "none">
```

`meta.md`:

```markdown
# Session meta

- Work stream: <slug>
- Updated: <ISO 8601 with timezone>
- Project root: <absolute path>
- Git branch: <branch or "none">
- Git HEAD: <short sha or "no commits">
- Dirty files: <one entry per line, or "clean">
- Plan source: <path or "none">
- Spec source: <path or "none">
- Saved: <comma-separated dates, oldest first; the first save has one date>
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Dumping the chat log or a transcript | Handoff is decisions, current state, and next step only. |
| Vague next step ("keep working on retries") | Name the file, function, and action. |
| Starting a second folder for the same work | Reuse `.ai/sessions/<slug>/`. |
| Saving from a subdirectory | Anchor at the project root first; `.ai/sessions/` lives there. |
| Editing the plan to match progress | Plan stays a snapshot; status lives in `progress.md`. |
| Committing the dump | Local only, excluded via `.git/info/exclude`. |
| Writing secrets, tokens, or personal data | Reference env var names, never values. |
| Falling back to `.superpowers/sdd/` or another harness workspace | `.ai/sessions/` only. |

## Red flags — STOP and fix

- `handoff.md` longer than ~60 lines.
- "continue as discussed" where a next step belongs.
- No `meta.md`, or no git state in it.
- A plan or spec exists but was not snapshotted.
- The dump is inside a tracked directory or would show up in `git status`.
- The dump path is under a subdirectory rather than the project root.

## Runtime note (opencode)

To resume the same conversation instead, use `opencode --continue`. This skill is for a
fresh session.
