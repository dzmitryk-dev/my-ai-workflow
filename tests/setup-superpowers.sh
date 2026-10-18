#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1" expected="$2"
  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_not_contains() {
  local file="$1" unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "did not expect '$unexpected' in $file"
  fi
}

new_world() {
  WORLD="$TMP_ROOT/$1"
  mkdir -p "$WORLD/repo/bin" "$WORLD/repo/integrations" "$WORLD/home/.codex" \
    "$WORLD/home/.config/opencode" "$WORLD/bin"
  cp "$REPO_ROOT/bin/setup" "$WORLD/repo/bin/setup"
  chmod +x "$WORLD/repo/bin/setup"
  if [[ -f "$REPO_ROOT/integrations/superpowers.env" ]]; then
    cp "$REPO_ROOT/integrations/superpowers.env" "$WORLD/repo/integrations/"
  else
    cat > "$WORLD/repo/integrations/superpowers.env" <<'EOF'
SUPERPOWERS_REPOSITORY="https://github.com/obra/superpowers.git"
SUPERPOWERS_REF="v7.0.0"
SUPERPOWERS_CODEX_MARKETPLACE="superpowers-dev"
SUPERPOWERS_CODEX_PLUGIN="superpowers"
EOF
  fi
  : > "$WORLD/calls.log"
  : > "$WORLD/codex-marketplaces.tsv"
  : > "$WORLD/codex-plugins.tsv"
  : > "$WORLD/opencode-plugins.tsv"

  cat > "$WORLD/bin/codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
set -euo pipefail
printf 'codex %s\n' "$*" >> "$FAKE_CALL_LOG"
case "$*" in
  'plugin marketplace list --json')
    python3 - "$FAKE_CODEX_MARKETPLACES" <<'PY'
import json, sys
items = []
with open(sys.argv[1], encoding="utf-8") as source:
    for line in source:
        name, url, ref = line.rstrip("\n").split("\t")
        items.append({"name": name, "source": {"sourceType": "git", "url": url, "ref": ref}})
print(json.dumps({"marketplaces": items}))
PY
    ;;
  'plugin list --json')
    python3 - "$FAKE_CODEX_PLUGINS" <<'PY'
import json, sys
items = []
with open(sys.argv[1], encoding="utf-8") as source:
    for line in source:
        name, marketplace = line.rstrip("\n").split("\t")
        items.append({"name": name, "marketplace": marketplace, "pluginId": name + "@" + marketplace})
print(json.dumps({"installed": items, "available": []}))
PY
    ;;
  'plugin marketplace add '*)
    source="$4"; ref="$6"; name="superpowers-dev"
    if grep -Fq "$name" "$FAKE_CODEX_MARKETPLACES"; then
      if grep -Fqx "$name$(printf '\t')$source$(printf '\t')$ref" "$FAKE_CODEX_MARKETPLACES"; then
        printf '{"marketplaceName":"%s","installedRoot":"/fake/%s","alreadyAdded":true}\n' "$name" "$name"
      else
        printf 'marketplace %s already exists from a different source\n' "$name" >&2
        exit 1
      fi
    else
      printf '%s\t%s\t%s\n' "$name" "$source" "$ref" >> "$FAKE_CODEX_MARKETPLACES"
      printf '{"marketplaceName":"%s","installedRoot":"/fake/%s","alreadyAdded":false}\n' "$name" "$name"
    fi
    ;;
  'plugin marketplace remove '*)
    name="$4"
    awk -F '\t' -v name="$name" '$1 != name' "$FAKE_CODEX_MARKETPLACES" > "$FAKE_CODEX_MARKETPLACES.tmp"
    mv "$FAKE_CODEX_MARKETPLACES.tmp" "$FAKE_CODEX_MARKETPLACES"
    ;;
  'plugin add '*)
    id="$3"; plugin="${id%@*}"; marketplace="${id#*@}"
    printf '%s\t%s\n' "$plugin" "$marketplace" >> "$FAKE_CODEX_PLUGINS"
    ;;
  'plugin remove '*)
    id="$3"; plugin="${id%@*}"; marketplace="${id#*@}"
    awk -F '\t' -v plugin="$plugin" -v marketplace="$marketplace" \
      '$1 != plugin || $2 != marketplace' "$FAKE_CODEX_PLUGINS" > "$FAKE_CODEX_PLUGINS.tmp"
    mv "$FAKE_CODEX_PLUGINS.tmp" "$FAKE_CODEX_PLUGINS"
    ;;
  *) printf 'unexpected fake codex command: %s\n' "$*" >&2; exit 64 ;;
esac
FAKE_CODEX

  cat > "$WORLD/bin/opencode" <<'FAKE_OPENCODE'
#!/usr/bin/env bash
set -euo pipefail
printf 'opencode %s\n' "$*" >> "$FAKE_CALL_LOG"
case "$*" in
  'plugin list') cat "$FAKE_OPENCODE_PLUGINS" ;;
  'plugin add '*) printf '%s\n' "$3" >> "$FAKE_OPENCODE_PLUGINS" ;;
  'plugin remove '*)
    spec="$3"
    grep -Fvx -- "$spec" "$FAKE_OPENCODE_PLUGINS" > "$FAKE_OPENCODE_PLUGINS.tmp" || true
    mv "$FAKE_OPENCODE_PLUGINS.tmp" "$FAKE_OPENCODE_PLUGINS"
    ;;
  *) printf 'unexpected fake opencode command: %s\n' "$*" >&2; exit 64 ;;
esac
FAKE_OPENCODE
  chmod +x "$WORLD/bin/codex" "$WORLD/bin/opencode"
  export HOME="$WORLD/home" CODEX_HOME="$WORLD/home/.codex"
  export OPENCODE_CONFIG_DIR="$WORLD/home/.config/opencode"
  export PATH="$WORLD/bin:/usr/bin:/bin"
  export FAKE_CALL_LOG="$WORLD/calls.log"
  export FAKE_CODEX_MARKETPLACES="$WORLD/codex-marketplaces.tsv"
  export FAKE_CODEX_PLUGINS="$WORLD/codex-plugins.tsv"
  export FAKE_OPENCODE_PLUGINS="$WORLD/opencode-plugins.tsv"
}

run_setup() {
  "$WORLD/repo/bin/setup" "$@"
}

test_install_repeat_and_separate_state() {
  new_world install
  run_setup > "$WORLD/output"
  assert_contains "$WORLD/calls.log" 'codex plugin marketplace add https://github.com/obra/superpowers.git --ref v7.0.0 --json'
  assert_contains "$WORLD/calls.log" 'codex plugin add superpowers@superpowers-dev'
  assert_contains "$WORLD/calls.log" 'opencode plugin add git+https://github.com/obra/superpowers.git#v7.0.0'
  [[ -s "$WORLD/repo/.setup-state/superpowers.tsv" ]] || fail 'dedicated plugin state was not recorded'
  [[ ! -s "$WORLD/repo/.setup-state/installed.tsv" ]] || fail 'plugin state leaked into installed.tsv'

  run_setup > "$WORLD/output"
  [[ "$(wc -l < "$WORLD/codex-marketplaces.tsv")" -eq 1 ]] || fail 'repeat setup duplicated Codex marketplace'
  [[ "$(grep -c 'codex plugin add' "$WORLD/calls.log")" -eq 1 ]] || fail 'repeat setup re-added Codex plugin'
  [[ "$(grep -c 'opencode plugin add' "$WORLD/calls.log")" -eq 1 ]] || fail 'repeat setup re-added OpenCode plugin'
}

test_cli_filter() {
  new_world cli-filter
  run_setup --cli=codex > "$WORLD/output"
  assert_contains "$WORLD/calls.log" 'codex plugin marketplace add'
  assert_not_contains "$WORLD/calls.log" 'opencode plugin'
  : > "$WORLD/calls.log"
  run_setup --cli=opencode > "$WORLD/output"
  assert_contains "$WORLD/calls.log" 'opencode plugin add'
  assert_not_contains "$WORLD/calls.log" 'codex plugin'
}

test_existing_entries_are_not_claimed() {
  new_world existing
  printf 'superpowers-dev\thttps://github.com/obra/superpowers.git\tv7.0.0\n' > "$FAKE_CODEX_MARKETPLACES"
  printf 'superpowers\tsuperpowers-dev\n' > "$FAKE_CODEX_PLUGINS"
  printf 'git+https://github.com/obra/superpowers.git#v7.0.0\n' > "$FAKE_OPENCODE_PLUGINS"
  run_setup > "$WORLD/output"
  assert_not_contains "$WORLD/calls.log" 'plugin add'
  [[ ! -s "$WORLD/repo/.setup-state/superpowers.tsv" ]] || fail 'pre-existing entries were incorrectly claimed'

  new_world existing-marketplace
  printf 'superpowers-dev\thttps://github.com/obra/superpowers.git\tv7.0.0\n' > "$FAKE_CODEX_MARKETPLACES"
  run_setup --cli=codex > "$WORLD/output"
  assert_contains "$WORLD/repo/.setup-state/superpowers.tsv" 'codex-plugin'
  assert_not_contains "$WORLD/repo/.setup-state/superpowers.tsv" 'codex-marketplace'
  run_setup --uninstall --cli=codex > "$WORLD/output"
  assert_contains "$FAKE_CODEX_MARKETPLACES" 'superpowers-dev'
  [[ ! -s "$FAKE_CODEX_PLUGINS" ]] || fail 'owned Codex plugin was not removed'
}

test_conflicting_codex_marketplace_is_preserved() {
  new_world conflict
  printf 'superpowers-dev\thttps://example.invalid/other.git\tmain\n' > "$FAKE_CODEX_MARKETPLACES"
  run_setup --cli=codex > "$WORLD/output" 2> "$WORLD/error"
  assert_contains "$WORLD/error" 'conflict'
  assert_not_contains "$WORLD/calls.log" 'codex plugin marketplace add'
  assert_not_contains "$WORLD/calls.log" 'codex plugin add'
  assert_contains "$FAKE_CODEX_MARKETPLACES" 'https://example.invalid/other.git'

  new_world conflict-ref
  printf 'superpowers-dev\thttps://github.com/obra/superpowers.git\tmain\n' > "$FAKE_CODEX_MARKETPLACES"
  run_setup --cli=codex > "$WORLD/output" 2> "$WORLD/error"
  assert_contains "$WORLD/error" 'conflict'
  assert_not_contains "$WORLD/calls.log" 'codex plugin add'
}

test_dry_run_changes_nothing() {
  new_world dry-run
  run_setup --dry-run > "$WORLD/output"
  assert_contains "$WORLD/output" '(dry-run)'
  assert_not_contains "$WORLD/calls.log" 'plugin add'
  assert_not_contains "$WORLD/calls.log" 'plugin marketplace add'
  [[ ! -e "$WORLD/repo/.setup-state" ]] || fail 'dry-run created setup-state directory in a fresh repo'
  [[ ! -s "$WORLD/repo/.setup-state/superpowers.tsv" ]] || fail 'dry-run wrote plugin ownership state'
  [[ ! -s "$FAKE_CODEX_MARKETPLACES" && ! -s "$FAKE_CODEX_PLUGINS" && ! -s "$FAKE_OPENCODE_PLUGINS" ]] || fail 'dry-run changed fake manager state'
}

test_uninstall_removes_only_owned_entries() {
  new_world uninstall
  run_setup > "$WORLD/output"
  run_setup --uninstall > "$WORLD/output"
  [[ ! -s "$FAKE_CODEX_MARKETPLACES" ]] || fail 'owned Codex marketplace remains after uninstall'
  [[ ! -s "$FAKE_CODEX_PLUGINS" ]] || fail 'owned Codex plugin remains after uninstall'
  [[ ! -s "$FAKE_OPENCODE_PLUGINS" ]] || fail 'owned OpenCode plugin remains after uninstall'

  new_world uninstall-existing
  printf 'superpowers-dev\thttps://github.com/obra/superpowers.git\tv7.0.0\n' > "$FAKE_CODEX_MARKETPLACES"
  printf 'superpowers\tsuperpowers-dev\n' > "$FAKE_CODEX_PLUGINS"
  printf 'git+https://github.com/obra/superpowers.git#v7.0.0\n' > "$FAKE_OPENCODE_PLUGINS"
  run_setup > "$WORLD/output"
  run_setup --uninstall > "$WORLD/output"
  assert_contains "$FAKE_CODEX_MARKETPLACES" 'superpowers-dev'
  assert_contains "$FAKE_CODEX_PLUGINS" 'superpowers'
  assert_contains "$FAKE_OPENCODE_PLUGINS" 'git+https://github.com/obra/superpowers.git#v7.0.0'
  assert_not_contains "$WORLD/calls.log" 'plugin remove'
  assert_not_contains "$WORLD/calls.log" 'plugin marketplace remove'
}

test_filtered_and_dry_run_uninstall() {
  new_world filtered-uninstall
  run_setup > "$WORLD/output"
  run_setup --uninstall --dry-run --cli=codex > "$WORLD/output"
  assert_contains "$WORLD/output" '(dry-run) codex plugin remove superpowers@superpowers-dev'
  assert_contains "$WORLD/output" '(dry-run) codex plugin marketplace remove superpowers-dev'
  [[ -s "$WORLD/repo/.setup-state/superpowers.tsv" ]] || fail 'dry-run uninstall removed ownership state'
  [[ -s "$FAKE_CODEX_PLUGINS" && -s "$FAKE_CODEX_MARKETPLACES" ]] || fail 'dry-run uninstall changed Codex manager state'

  run_setup --uninstall --cli=codex > "$WORLD/output"
  [[ ! -s "$FAKE_CODEX_MARKETPLACES" && ! -s "$FAKE_CODEX_PLUGINS" ]] || fail 'filtered uninstall retained owned Codex entries'
  assert_contains "$FAKE_OPENCODE_PLUGINS" 'git+https://github.com/obra/superpowers.git#v7.0.0'
  assert_contains "$WORLD/repo/.setup-state/superpowers.tsv" 'opencode-plugin'
  assert_not_contains "$WORLD/repo/.setup-state/superpowers.tsv" 'codex-'

  cp "$FAKE_OPENCODE_PLUGINS" "$WORLD/opencode-before-dry-uninstall"
  run_setup --uninstall --dry-run --cli=opencode > "$WORLD/output"
  cmp -s "$FAKE_OPENCODE_PLUGINS" "$WORLD/opencode-before-dry-uninstall" || fail 'dry-run uninstall changed OpenCode state'
  assert_contains "$WORLD/repo/.setup-state/superpowers.tsv" 'opencode-plugin'
  assert_contains "$WORLD/output" '(dry-run) opencode plugin remove'
  run_setup --uninstall --cli=opencode > "$WORLD/output"
  [[ ! -s "$FAKE_OPENCODE_PLUGINS" ]] || fail 'filtered OpenCode uninstall retained owned plugin'
  [[ ! -s "$WORLD/repo/.setup-state/superpowers.tsv" ]] || fail 'uninstall left stale ownership state'

  new_world manually-removed
  run_setup > "$WORLD/output"
  : > "$FAKE_CODEX_MARKETPLACES"
  : > "$FAKE_CODEX_PLUGINS"
  : > "$FAKE_OPENCODE_PLUGINS"
  run_setup --uninstall > "$WORLD/output"
  assert_not_contains "$WORLD/calls.log" 'codex plugin remove'
  assert_not_contains "$WORLD/calls.log" 'codex plugin marketplace remove'
  assert_not_contains "$WORLD/calls.log" 'opencode plugin remove'
  [[ ! -s "$WORLD/repo/.setup-state/superpowers.tsv" ]] || fail 'uninstall retained state for manually removed plugins'
}

test_install_repeat_and_separate_state
test_cli_filter
test_existing_entries_are_not_claimed
test_conflicting_codex_marketplace_is_preserved
test_dry_run_changes_nothing
test_uninstall_removes_only_owned_entries
test_filtered_and_dry_run_uninstall
printf 'PASS: setup-superpowers fake-CLI tests\n'
