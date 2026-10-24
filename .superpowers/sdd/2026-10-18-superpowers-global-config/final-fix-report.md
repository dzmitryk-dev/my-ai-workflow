# Final fix wave report

## Scope

Addressed both Important findings in the final Kimi review, limited to
`bin/setup` and `tests/setup-superpowers.sh` as requested. The approved
specification and implementation plan were reviewed. No docs or global
configuration were modified, and no real plugin install/remove commands were
run.

## Changes

- Added fake-CLI install coverage for absent Codex and absent OpenCode, proving
  the available harness still installs independently.
- Added uninstall coverage for each unavailable CLI: the available harness is
  still processed, while the unavailable CLI's plugin and marketplace ownership
  records remain available for a later retry.
- Added injected Codex marketplace/plugin add failures and Codex/OpenCode plugin
  removal failures, plus Codex marketplace removal failure. Warnings are
  asserted; failed installs do not claim plugin ownership; failed removals keep
  ownership records; and the sibling harness continues.
- Added subsequent-uninstall assertions to verify retained failed-removal
  records can be retried and cleared after the fake CLI succeeds.
- Wrapped native plugin install/removal commands so command failures are
  handled under `set -e`. Codex marketplace registration already used a
  conditional command substitution; its failure path is exercised and does not
  prevent OpenCode from proceeding. Failed removal of a temporary unexpected
  marketplace now warns rather than aborting setup.

## Verification

- Test-first check: after adding the fake-CLI regressions but before the
  installer change, `bash tests/setup-superpowers.sh` exited nonzero at the
  injected Codex plugin-add failure, confirming the prior `set -e` abort.
- `bash tests/setup-superpowers.sh` — passed:
  `PASS: setup-superpowers fake-CLI tests`.
- `bash -n bin/setup tests/setup-superpowers.sh` — passed.
- `git diff --check` — passed.
- Self-review confirmed each non-dry-run `plugin_run` add/remove operation is
  guarded, install state is recorded only on successful plugin add, and failed
  removal records are retained for retry. The Codex marketplace-add command
  remains conditional and has an explicit failure warning.

## Concerns

None identified in the requested scope. All plugin-manager behavior was
validated only through the isolated fake-CLI test harness.
