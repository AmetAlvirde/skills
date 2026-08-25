#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
WIRE="$ROOT/harness/wire"
MODELS="$ROOT/harness/models.json"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

pass=0
fail=0

ok() {
  local label=$1
  shift
  if "$@" >/dev/null; then
    pass=$((pass + 1))
    printf '  ok    %s\n' "$label"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "$label"
  fi
}

frontmatter() {
  local ignored json
  IFS= read -r ignored
  : "$ignored"
  IFS= read -r json
  printf '%s\n' "$json"
}

target_field() {
  local name=$1 harness=$2 field=$3 reference catalogue tier
  reference=$(jq -er --arg name "$name" --arg harness "$harness" \
    '.agents[$name].default[$harness]' "$MODELS")
  catalogue=${reference%%:*}
  tier=${reference#*:}
  jq -er --arg catalogue "$catalogue" --arg tier "$tier" --arg field "$field" \
    '.catalogues[$catalogue].targets[$tier][$field]' "$MODELS"
}

semantic_target_field() {
  local reference=$1 field=$2 target_ref catalogue tier
  target_ref=$(jq -er --arg reference "$reference" \
    'getpath($reference | split("."))' "$MODELS")
  catalogue=${target_ref%%:*}
  tier=${target_ref#*:}
  jq -er --arg catalogue "$catalogue" --arg tier "$tier" --arg field "$field" \
    '.catalogues[$catalogue].targets[$tier][$field]' "$MODELS"
}

effectively_denies_skill() {
  local json=$1 skill=$2 pattern decision effective=""
  while IFS=$'\t' read -r pattern decision; do
    # OpenCode applies the last matching permission pattern.
    # shellcheck disable=SC2053
    if [[ $skill == $pattern ]]; then
      effective=$decision
    fi
  done < <(jq -r '.permission.skill | to_entries[] | [.key, .value] | @tsv' <<<"$json")
  [ "$effective" = deny ]
}

HOME_DIR="$W/home"
mkdir -p "$HOME_DIR"

echo 'command dry-run'
DRY_HOME="$W/dry-home"
DRY_PROJECT="$W/dry-project"
mkdir -p "$DRY_HOME" "$DRY_PROJECT"
DRY_PROJECT=$(cd "$DRY_PROJECT" && pwd -P)
HOME="$DRY_HOME" "$WIRE" --harness opencode --project "$DRY_PROJECT" \
  >"$W/opencode-dry.out"
for name in standup hotwash; do
  ok "command dry-run reports $name render" grep -Fq \
    "render     $DRY_HOME/.config/opencode/commands/$name.md" "$W/opencode-dry.out"
done
for name in codebase-map codebase-grill; do
  ok "command dry-run reports $name render" grep -Fq \
    "render     $DRY_PROJECT/.opencode/commands/$name.md" "$W/opencode-dry.out"
done
ok 'command dry-run creates no global command directory' test \
  ! -e "$DRY_HOME/.config/opencode/commands"
ok 'command dry-run creates no project command directory' test \
  ! -e "$DRY_PROJECT/.opencode/commands"
ok 'plugin dry-run reports link' grep -Fq \
  "link       $DRY_HOME/.config/opencode/plugins/main-branch-guard.ts -> $ROOT/harness/opencode/plugins/main-branch-guard.ts" \
  "$W/opencode-dry.out"
ok 'plugin dry-run creates no plugin directory' test \
  ! -e "$DRY_HOME/.config/opencode/plugins"

echo 'clean render'
HOME="$HOME_DIR" "$WIRE" --harness claude-code --apply >"$W/claude-first.out"
HOME="$HOME_DIR" "$WIRE" --harness opencode --apply >"$W/opencode-first.out"
PLUGIN="$HOME_DIR/.config/opencode/plugins/main-branch-guard.ts"
ok 'OpenCode plugin is a symlink' test -L "$PLUGIN"
ok 'OpenCode plugin uses one-hop canonical target' test \
  "$(readlink "$PLUGIN")" = "$ROOT/harness/opencode/plugins/main-branch-guard.ts"

echo 'OpenCode command roster and scope'
COMMAND_CATALOG="$ROOT/harness/opencode/commands.json"
if [ -f "$COMMAND_CATALOG" ]; then
  expected_dialogue=$(for source in "$ROOT"/global/*/SKILL.md "$ROOT"/engineering/*/SKILL.md; do
    if grep -Fqx 'disable-model-invocation: true' "$source"; then
      basename "$(dirname "$source")"
    fi
  done | sort | jq -Rsc 'split("\n") | map(select(length > 0))')
  catalog_roster=$(jq -c '.commands | keys | sort' "$COMMAND_CATALOG")
  denial_roster=$(jq -c '.permission.skill | to_entries |
    map(select(.value == "deny") | .key) | sort' "$ROOT/harness/opencode/opencode.jsonc")
  ok 'command catalog matches dialogue-bound skills' test "$catalog_roster" = "$expected_dialogue"
  ok 'base skill denial matches command catalog' test "$denial_roster" = "$catalog_roster"
  while IFS= read -r name; do
    source=$(jq -er --arg name "$name" '.commands[$name].source' "$COMMAND_CATALOG")
    router_entry=$(awk -F'|' -v wanted="$name" '
      function clean(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/`/, "", value)
        return value
      }
      /^\|/ {
        name = clean($2)
        if (name == wanted) print clean($3) "\t" clean($4)
      }
    ' "$ROOT/README.md")
    router_layer=${router_entry%%$'\t'*}
    router_kind=${router_entry#*$'\t'}
    source_layer=${source%%/*}
    case "$source_layer" in
      global) expected_kind=user-invoked ;;
      engineering) expected_kind=orchestrator ;;
      *) expected_kind=invalid ;;
    esac
    ok "$name catalog source matches Router layer" test "$source_layer" = "$router_layer"
    ok "$name Router kind is command-bound" test "$router_kind" = "$expected_kind"
  done < <(jq -r '.commands | keys[]' "$COMMAND_CATALOG")
else
  ok 'OpenCode command catalog exists' false
fi

for name in standup hotwash; do
  ok "global command renders $name" test -f "$HOME_DIR/.config/opencode/commands/$name.md"
done
for name in codebase-map codebase-grill enn bit vitruv tux linn radar; do
  ok "global apply omits $name command" test ! -e "$HOME_DIR/.config/opencode/commands/$name.md"
done

PROJECT="$W/project"
mkdir -p "$PROJECT"
HOME="$HOME_DIR" "$WIRE" --harness opencode --project "$PROJECT" --apply >"$W/opencode-project.out"
for name in codebase-map codebase-grill; do
  ok "project command renders $name" test -f "$PROJECT/.opencode/commands/$name.md"
done

FILTERED_PROJECT="$W/filtered-project"
mkdir -p "$FILTERED_PROJECT"
HOME="$HOME_DIR" "$WIRE" --harness opencode --project "$FILTERED_PROJECT" \
  --skill codebase-map --apply >"$W/opencode-filtered.out"
ok 'selected project command renders' test -f "$FILTERED_PROJECT/.opencode/commands/codebase-map.md"
ok 'unselected project command stays absent' test ! -e "$FILTERED_PROJECT/.opencode/commands/codebase-grill.md"

if [ -f "$COMMAND_CATALOG" ]; then
  for name in standup hotwash codebase-map codebase-grill; do
    source=$(jq -er --arg name "$name" '.commands[$name].source' "$COMMAND_CATALOG")
    reference=$(jq -er --arg name "$name" '.commands[$name].modelRef' "$COMMAND_CATALOG")
    case "$name" in
      standup|hotwash) command_file="$HOME_DIR/.config/opencode/commands/$name.md" ;;
      *) command_file="$PROJECT/.opencode/commands/$name.md" ;;
    esac
    if [ -f "$command_file" ]; then
      command_json=$(frontmatter <"$command_file")
      # The generated file must retain this literal.
      # shellcheck disable=SC2016
      ok "$name keeps literal arguments" grep -Fq '$ARGUMENTS' "$command_file"
      awk 'NR == 1 && $0 == "---" { frontmatter = 1; next }
           frontmatter && $0 == "---" { frontmatter = 0; next }
           !frontmatter { print }' "$ROOT/$source" >"$W/$name.expected-body"
      awk '/^<!-- canonical body: / { canonical = 1; next }
           canonical { print }' "$command_file" >"$W/$name.actual-body"
      ok "$name injects canonical body" cmp -s \
        "$W/$name.expected-body" "$W/$name.actual-body"
      ok "$name maps OpenCode model" test \
        "$(jq -r '.model' <<<"$command_json")" = "$(semantic_target_field "$reference" model)"
      ok "$name maps OpenCode variant" test \
        "$(jq -r '.variant' <<<"$command_json")" = "$(semantic_target_field "$reference" variant)"
      if [ "$name" = standup ] || [ "$name" = hotwash ]; then
        ok "$name binds Radar" test "$(jq -r '.agent' <<<"$command_json")" = radar
        ok "$name explains one-turn Radar binding" grep -Fq \
          'Radar is already active for this command turn' "$command_file"
      else
        ok "$name has no agent binding" jq -e 'has("agent") | not' <<<"$command_json"
      fi
    else
      ok "$name command available for metadata checks" false
    fi
  done
fi

for name in ennio bit vitruv tux linn radar; do
  claude_file="$HOME_DIR/.claude/agents/$name.md"
  opencode_file="$HOME_DIR/.config/opencode/agents/$name.md"
  claude_json=$(frontmatter <"$claude_file")
  opencode_json=$(frontmatter <"$opencode_file")

  ok "Claude renders $name" test -f "$claude_file"
  ok "OpenCode renders $name" test -f "$opencode_file"
  ok "Claude model matches $name" test \
    "$(jq -r '.model' <<<"$claude_json")" = "$(target_field "$name" claude-code model)"
  ok "Claude effort matches $name" test \
    "$(jq -r '.effort' <<<"$claude_json")" = "$(target_field "$name" claude-code effort)"
  ok "OpenCode model matches $name" test \
    "$(jq -r '.model' <<<"$opencode_json")" = "$(target_field "$name" opencode model)"
  ok "OpenCode variant matches $name" test \
    "$(jq -r '.variant' <<<"$opencode_json")" = "$(target_field "$name" opencode variant)"
  ok "OpenCode mode matches $name" test "$(jq -r '.mode' <<<"$opencode_json")" = all
  for dialogue_skill in standup hotwash codebase-map codebase-grill; do
    ok "$name denies $dialogue_skill skill" effectively_denies_skill \
      "$opencode_json" "$dialogue_skill"
  done
done

bit_json=$(frontmatter <"$HOME_DIR/.config/opencode/agents/bit.md")
tux_json=$(frontmatter <"$HOME_DIR/.config/opencode/agents/tux.md")
ennio_json=$(frontmatter <"$HOME_DIR/.config/opencode/agents/ennio.md")
radar_json=$(frontmatter <"$HOME_DIR/.config/opencode/agents/radar.md")

ok 'Bit cannot commit' jq -e '.permission.bash["git commit*"] == "deny"' <<<"$bit_json"
ok 'Tux cannot edit source' jq -e '.permission.edit["*"] == "deny"' <<<"$tux_json"
ok 'Tux asks before push' jq -e '.permission.bash["git push*"] == "ask"' <<<"$tux_json"
ok 'Ennio task scope defaults deny' jq -e '.permission.task["*"] == "deny"' <<<"$ennio_json"
ok 'Ennio may delegate to Bit' jq -e '.permission.task.bit == "allow"' <<<"$ennio_json"
ok 'Radar writes only in notes' jq -e '
  .permission.edit["*"] == "deny" and
  .permission.edit["~/Dev/notes/**"] == "allow"
' <<<"$radar_json"

echo 'native parsing and idempotence'
if command -v claude >/dev/null 2>&1; then
  ok 'Claude accepts rendered agents' claude plugin validate "$HOME_DIR/.claude/agents"
fi
if command -v opencode >/dev/null 2>&1; then
  profile=$(<"$ROOT/harness/opencode/profiles/openai.jsonc")
  (cd "$PROJECT" && OPENCODE_CONFIG="$ROOT/harness/opencode/opencode.jsonc" \
    OPENCODE_CONFIG_CONTENT="$profile" HOME="$HOME_DIR" \
    XDG_CONFIG_HOME="$HOME_DIR/.config" opencode debug config) >"$W/opencode-config.json"
  ok 'OpenCode accepts rendered agents and commands' jq -e '
    .agent.bit.model == "openai/gpt-5.6-sol" and
    .agent.tux.permission.edit["*"] == "deny" and
    .command.standup.agent == "radar" and
    .command.hotwash.agent == "radar" and
    (.command["codebase-map"] | has("agent") | not) and
    (.command["codebase-grill"] | has("agent") | not) and
    ([.command.standup, .command.hotwash, .command["codebase-map"],
      .command["codebase-grill"]] |
      all(.model == "openai/gpt-5.6-sol" and (.variant == "medium" or .variant == "high")))
  ' \
    "$W/opencode-config.json"
  ok 'OpenCode debug config loads main branch guard plugin' jq -e '
    (.plugin // []) | any(contains("main-branch-guard.ts"))
  ' "$W/opencode-config.json"
fi

cp "$HOME_DIR/.config/opencode/commands/standup.md" "$W/standup-canonical.md"
printf '%s\n' 'stale managed command content' \
  >>"$HOME_DIR/.config/opencode/commands/standup.md"
HOME="$HOME_DIR" "$WIRE" --harness opencode --apply >"$W/opencode-repair.out"
ok 'stale managed command is rerendered' grep -Fq \
  "render     $HOME_DIR/.config/opencode/commands/standup.md" "$W/opencode-repair.out"
ok 'stale managed command returns to canonical output' cmp -s \
  "$W/standup-canonical.md" "$HOME_DIR/.config/opencode/commands/standup.md"

HOME="$HOME_DIR" "$WIRE" --harness claude-code --apply >"$W/claude-second.out"
HOME="$HOME_DIR" "$WIRE" --harness opencode --apply >"$W/opencode-second.out"
ok 'Claude render is idempotent' grep -Fq 'summary: 0 change(s)' "$W/claude-second.out"
ok 'OpenCode render is idempotent' grep -Fq 'summary: 0 change(s)' "$W/opencode-second.out"
ok 'OpenCode commands are idempotent' grep -Fq \
  "unchanged  $HOME_DIR/.config/opencode/commands/standup.md" "$W/opencode-second.out"
ok 'OpenCode plugin is idempotent' grep -Fq \
  "unchanged  $PLUGIN -> $ROOT/harness/opencode/plugins/main-branch-guard.ts" \
  "$W/opencode-second.out"

echo 'ownership boundaries'
MIGRATE_HOME="$W/migrate-home"
mkdir -p "$MIGRATE_HOME/.claude/agents"
ln -s "$ROOT/agents/bit.md" "$MIGRATE_HOME/.claude/agents/bit.md"
HOME="$MIGRATE_HOME" "$WIRE" --harness claude-code --apply >"$W/migrate.out"
ok 'managed Claude symlink becomes a rendered file' test ! -L "$MIGRATE_HOME/.claude/agents/bit.md"
ok 'migrated file carries the managed marker' grep -Fq \
  '<!-- managed by harness/wire; source: agents/bit.md -->' "$MIGRATE_HOME/.claude/agents/bit.md"

FOREIGN_HOME="$W/foreign-home"
mkdir -p "$FOREIGN_HOME/.config/opencode/agents"
printf '%s\n' 'foreign agent definition' >"$FOREIGN_HOME/.config/opencode/agents/bit.md"
if HOME="$FOREIGN_HOME" "$WIRE" --harness opencode --apply >"$W/foreign.out" 2>&1; then
  foreign_status=0
else
  foreign_status=$?
fi
ok 'foreign agent returns a warning status' test "$foreign_status" -ne 0
ok 'foreign agent is reported' grep -Fq 'unmanaged' "$W/foreign.out"
ok 'foreign agent is not replaced' grep -Fqx \
  'foreign agent definition' "$FOREIGN_HOME/.config/opencode/agents/bit.md"

FOREIGN_COMMAND_HOME="$W/foreign-command-home"
mkdir -p "$FOREIGN_COMMAND_HOME/.config/opencode/commands"
printf '%s\n' 'foreign command definition' \
  >"$FOREIGN_COMMAND_HOME/.config/opencode/commands/standup.md"
if HOME="$FOREIGN_COMMAND_HOME" "$WIRE" --harness opencode --apply \
  >"$W/foreign-command.out" 2>&1; then
  foreign_command_status=0
else
  foreign_command_status=$?
fi
ok 'foreign command returns a warning status' test "$foreign_command_status" -ne 0
ok 'foreign command is reported' grep -Fq \
  "$FOREIGN_COMMAND_HOME/.config/opencode/commands/standup.md (refusing to replace)" \
  "$W/foreign-command.out"
ok 'foreign command is not replaced' grep -Fqx \
  'foreign command definition' "$FOREIGN_COMMAND_HOME/.config/opencode/commands/standup.md"

FOREIGN_PLUGIN_HOME="$W/foreign-plugin-home"
mkdir -p "$FOREIGN_PLUGIN_HOME/.config/opencode/plugins"
printf '%s\n' 'foreign plugin definition' \
  >"$FOREIGN_PLUGIN_HOME/.config/opencode/plugins/main-branch-guard.ts"
if HOME="$FOREIGN_PLUGIN_HOME" "$WIRE" --harness opencode --apply \
  >"$W/foreign-plugin.out" 2>&1; then
  foreign_plugin_status=0
else
  foreign_plugin_status=$?
fi
ok 'foreign plugin file returns a warning status' test "$foreign_plugin_status" -ne 0
ok 'foreign plugin file is reported' grep -Fq \
  "$FOREIGN_PLUGIN_HOME/.config/opencode/plugins/main-branch-guard.ts (refusing to replace)" \
  "$W/foreign-plugin.out"
ok 'foreign plugin file is not replaced' grep -Fqx \
  'foreign plugin definition' "$FOREIGN_PLUGIN_HOME/.config/opencode/plugins/main-branch-guard.ts"

FOREIGN_PLUGIN_LINK_HOME="$W/foreign-plugin-link-home"
mkdir -p "$FOREIGN_PLUGIN_LINK_HOME/.config/opencode/plugins"
ln -s "$W/foreign-plugin.ts" \
  "$FOREIGN_PLUGIN_LINK_HOME/.config/opencode/plugins/main-branch-guard.ts"
if HOME="$FOREIGN_PLUGIN_LINK_HOME" "$WIRE" --harness opencode --apply \
  >"$W/foreign-plugin-link.out" 2>&1; then
  foreign_plugin_link_status=0
else
  foreign_plugin_link_status=$?
fi
ok 'foreign plugin symlink returns a warning status' test "$foreign_plugin_link_status" -ne 0
ok 'foreign plugin symlink is reported' grep -Fq \
  "main-branch-guard.ts -> $W/foreign-plugin.ts (refusing to replace)" \
  "$W/foreign-plugin-link.out"
ok 'foreign plugin symlink is not replaced' test \
  "$(readlink "$FOREIGN_PLUGIN_LINK_HOME/.config/opencode/plugins/main-branch-guard.ts")" = \
  "$W/foreign-plugin.ts"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
