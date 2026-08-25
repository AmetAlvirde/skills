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

HOME_DIR="$W/home"
mkdir -p "$HOME_DIR"

echo 'clean render'
HOME="$HOME_DIR" "$WIRE" --harness claude-code --apply >"$W/claude-first.out"
HOME="$HOME_DIR" "$WIRE" --harness opencode --apply >"$W/opencode-first.out"

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
  OPENCODE_CONFIG="$ROOT/harness/opencode/opencode.jsonc" \
    OPENCODE_CONFIG_CONTENT="$profile" HOME="$HOME_DIR" \
    XDG_CONFIG_HOME="$HOME_DIR/.config" opencode debug config >"$W/opencode-config.json"
  ok 'OpenCode accepts rendered agents' jq -e \
    '.agent.bit.model == "openai/gpt-5.6-sol" and .agent.tux.permission.edit["*"] == "deny"' \
    "$W/opencode-config.json"
fi

HOME="$HOME_DIR" "$WIRE" --harness claude-code --apply >"$W/claude-second.out"
HOME="$HOME_DIR" "$WIRE" --harness opencode --apply >"$W/opencode-second.out"
ok 'Claude render is idempotent' grep -Fq 'summary: 0 change(s)' "$W/claude-second.out"
ok 'OpenCode render is idempotent' grep -Fq 'summary: 0 change(s)' "$W/opencode-second.out"

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

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
