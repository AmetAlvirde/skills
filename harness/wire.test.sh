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

toml_field() {
  python3 - "$1" "$2" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    value = tomllib.load(handle)[sys.argv[2]]
print(value)
PY
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
RETRY_SKILLS=(codebase-review pr-review refactor)
RETRY_COMMANDS=(codebase-review-retry pr-review-retry refactor-retry)
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
for name in codebase-map codebase-grill "${RETRY_COMMANDS[@]}"; do
  ok "command dry-run reports $name render" grep -Fq \
    "render     $DRY_PROJECT/.opencode/commands/$name.md" "$W/opencode-dry.out"
done
HOME="$DRY_HOME" "$WIRE" --harness claude-code --project "$DRY_PROJECT" \
  >"$W/claude-dry.out"
for name in "${RETRY_COMMANDS[@]}"; do
  ok "Claude dry-run reports $name render" grep -Fq \
    "render     $DRY_PROJECT/.claude/commands/$name.md" "$W/claude-dry.out"
done
ok 'command dry-run creates no global command directory' test \
  ! -e "$DRY_HOME/.config/opencode/commands"
ok 'command dry-run creates no project command directory' test \
  ! -e "$DRY_PROJECT/.opencode/commands"
for name in main-branch-guard daylog-trigger; do
  ok "plugin dry-run reports $name link" grep -Fq \
    "link       $DRY_HOME/.config/opencode/plugins/$name.ts -> $ROOT/harness/opencode/plugins/$name.ts" \
    "$W/opencode-dry.out"
done
ok 'plugin dry-run creates no plugin directory' test \
  ! -e "$DRY_HOME/.config/opencode/plugins"
ok 'OpenCode wiring allowlists only managed plugins' jq -e '
  [.links[] | select(.sourceDir == "harness/opencode/plugins") | .match] | sort ==
    ["daylog-trigger.ts", "main-branch-guard.ts"]
' "$ROOT/harness/opencode/wiring.json"
ok 'OpenCode project skill destination does not drift' jq -e '
  .projectLinks == [{
    sourceDir: "engineering",
    match: "*",
    destination: ".opencode/skills",
    selectable: true,
    scanUnmanaged: true
  }]
' "$ROOT/harness/opencode/wiring.json"
ok 'project skill dry-run reports canonical link' grep -Fq \
  "link       $DRY_PROJECT/.opencode/skills/design -> $ROOT/engineering/design" \
  "$W/opencode-dry.out"
ok 'project skill dry-run creates no skill directory' test \
  ! -e "$DRY_PROJECT/.opencode/skills"

echo 'clean render'
HOME="$HOME_DIR" "$WIRE" --harness claude-code --apply >"$W/claude-first.out"
HOME="$HOME_DIR" "$WIRE" --harness opencode --apply >"$W/opencode-first.out"
for name in main-branch-guard daylog-trigger; do
  plugin="$HOME_DIR/.config/opencode/plugins/$name.ts"
  ok "OpenCode $name plugin is a symlink" test -L "$plugin"
  ok "OpenCode $name plugin uses one-hop canonical target" test \
    "$(readlink "$plugin")" = "$ROOT/harness/opencode/plugins/$name.ts"
done

echo 'OpenCode command roster and scope'
COMMAND_CATALOG="$ROOT/harness/opencode/commands.json"
if [ -f "$COMMAND_CATALOG" ]; then
  expected_dialogue=$(for source in "$ROOT"/global/*/SKILL.md "$ROOT"/engineering/*/SKILL.md; do
    if grep -Fqx 'disable-model-invocation: true' "$source"; then
      basename "$(dirname "$source")"
    fi
  done | sort | jq -Rsc 'split("\n") | map(select(length > 0))')
  catalog_roster=$(jq -c '[.commands | to_entries[] |
    select((.value.kind // "canonical") == "canonical") | .key] | sort' "$COMMAND_CATALOG")
  denial_roster=$(jq -c '.permission.skill | to_entries |
    map(select(.value == "deny") | .key) | sort' "$ROOT/harness/opencode/opencode.jsonc")
  ok 'command catalog matches dialogue-bound skills' test "$catalog_roster" = "$expected_dialogue"
  ok 'base skill denial matches command catalog' test "$denial_roster" = "$catalog_roster"
  while IFS= read -r name; do
    source=$(jq -er --arg name "$name" '.commands[$name].source' "$COMMAND_CATALOG")
    kind=$(jq -r --arg name "$name" '.commands[$name].kind // "canonical"' "$COMMAND_CATALOG")
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
    if [ "$kind" = retry ]; then
      expected_kind='command'
    else
      case "$source_layer" in
        global) expected_kind=user-invoked ;;
        engineering) expected_kind=orchestrator ;;
        *) expected_kind=invalid ;;
      esac
    fi
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
git init -q "$PROJECT"
HOME="$HOME_DIR" "$WIRE" --harness opencode --project "$PROJECT" --apply >"$W/opencode-project.out"
for name in codebase-map codebase-grill "${RETRY_COMMANDS[@]}"; do
  ok "project command renders $name" test -f "$PROJECT/.opencode/commands/$name.md"
done
ok 'OpenCode project skill applies' test -L "$PROJECT/.opencode/skills/design"
ok 'OpenCode project skill uses one-hop canonical target' test \
  "$(readlink "$PROJECT/.opencode/skills/design")" = "$ROOT/engineering/design"

HOME="$HOME_DIR" "$WIRE" --harness claude-code --project "$PROJECT" --apply \
  >"$W/claude-project.out"
for name in "${RETRY_COMMANDS[@]}"; do
  ok "Claude project renders $name" test -f "$PROJECT/.claude/commands/$name.md"
done
ok 'Claude project link coexists with OpenCode' test -L \
  "$PROJECT/.claude/skills/design"
ok 'OpenCode project link remains beside Claude' test -L \
  "$PROJECT/.opencode/skills/design"

FILTERED_PROJECT="$W/filtered-project"
mkdir -p "$FILTERED_PROJECT"
HOME="$HOME_DIR" "$WIRE" --harness opencode --project "$FILTERED_PROJECT" \
  --skill codebase-map --apply >"$W/opencode-filtered.out"
ok 'selected project command renders' test -f "$FILTERED_PROJECT/.opencode/commands/codebase-map.md"
ok 'unselected project command stays absent' test ! -e "$FILTERED_PROJECT/.opencode/commands/codebase-grill.md"
ok 'selected project skill links' test -L "$FILTERED_PROJECT/.opencode/skills/codebase-map"
ok 'unselected project skill stays absent' test \
  ! -e "$FILTERED_PROJECT/.opencode/skills/codebase-grill"
ok 'unrelated project skill stays absent' test \
  ! -e "$FILTERED_PROJECT/.opencode/skills/design"

for skill in "${RETRY_SKILLS[@]}"; do
  retry_project="$W/retry-$skill-project"
  mkdir -p "$retry_project"
  HOME="$HOME_DIR" "$WIRE" --harness opencode --project "$retry_project" \
    --skill "$skill" --apply >"$W/opencode-$skill-retry.out"
  ok "selecting $skill renders its retry command" test -f \
    "$retry_project/.opencode/commands/$skill-retry.md"
  ok "selecting $skill links its canonical skill" test -L \
    "$retry_project/.opencode/skills/$skill"
done

HOME="$HOME_DIR" "$WIRE" --harness opencode --project "$PROJECT" --apply \
  >"$W/opencode-project-second.out"
ok 'OpenCode project links are idempotent' grep -Fq 'summary: 0 change(s)' \
  "$W/opencode-project-second.out"
ok 'OpenCode project skill reports unchanged' grep -Fq \
  "/.opencode/skills/design -> $ROOT/engineering/design" \
  "$W/opencode-project-second.out"

UNMANAGED_PROJECT="$W/unmanaged-project"
mkdir -p "$UNMANAGED_PROJECT/.opencode/skills"
printf '%s\n' 'leave me alone' >"$UNMANAGED_PROJECT/.opencode/skills/local-skill"
if HOME="$HOME_DIR" "$WIRE" --harness opencode --project "$UNMANAGED_PROJECT" --apply \
  >"$W/unmanaged-project.out" 2>&1; then
  unmanaged_project_status=0
else
  unmanaged_project_status=$?
fi
ok 'OpenCode unmanaged project entry returns warning status' test \
  "$unmanaged_project_status" -ne 0
ok 'OpenCode scans and reports unmanaged project entries' grep -Fq \
  "$UNMANAGED_PROJECT/.opencode/skills/local-skill -> review/remove" \
  "$W/unmanaged-project.out"
ok 'OpenCode leaves unmanaged project entries unchanged' grep -Fqx \
  'leave me alone' "$UNMANAGED_PROJECT/.opencode/skills/local-skill"

FOREIGN_SKILL_FILE_PROJECT="$W/foreign-skill-file-project"
mkdir -p "$FOREIGN_SKILL_FILE_PROJECT/.opencode/skills"
printf '%s\n' 'foreign design skill' \
  >"$FOREIGN_SKILL_FILE_PROJECT/.opencode/skills/design"
if HOME="$HOME_DIR" "$WIRE" --harness opencode \
  --project "$FOREIGN_SKILL_FILE_PROJECT" --skill design --apply \
  >"$W/foreign-skill-file.out" 2>&1; then
  foreign_skill_file_status=0
else
  foreign_skill_file_status=$?
fi
ok 'foreign OpenCode project skill file returns warning status' test \
  "$foreign_skill_file_status" -ne 0
ok 'foreign OpenCode project skill file is refused' grep -Fq \
  "$FOREIGN_SKILL_FILE_PROJECT/.opencode/skills/design (refusing to replace)" \
  "$W/foreign-skill-file.out"
ok 'foreign OpenCode project skill file is not replaced' grep -Fqx \
  'foreign design skill' "$FOREIGN_SKILL_FILE_PROJECT/.opencode/skills/design"

FOREIGN_SKILL_LINK_PROJECT="$W/foreign-skill-link-project"
mkdir -p "$FOREIGN_SKILL_LINK_PROJECT/.opencode/skills"
ln -s "$W/foreign-design" "$FOREIGN_SKILL_LINK_PROJECT/.opencode/skills/design"
if HOME="$HOME_DIR" "$WIRE" --harness opencode \
  --project "$FOREIGN_SKILL_LINK_PROJECT" --skill design --apply \
  >"$W/foreign-skill-link.out" 2>&1; then
  foreign_skill_link_status=0
else
  foreign_skill_link_status=$?
fi
ok 'foreign OpenCode project skill symlink returns warning status' test \
  "$foreign_skill_link_status" -ne 0
ok 'foreign OpenCode project skill symlink is refused' grep -Fq \
  "design -> $W/foreign-design (refusing to replace)" \
  "$W/foreign-skill-link.out"
ok 'foreign OpenCode project skill symlink is not replaced' test \
  "$(readlink "$FOREIGN_SKILL_LINK_PROJECT/.opencode/skills/design")" = \
  "$W/foreign-design"

if [ -f "$COMMAND_CATALOG" ]; then
  for name in standup hotwash codebase-map codebase-grill "${RETRY_COMMANDS[@]}"; do
    source=$(jq -er --arg name "$name" '.commands[$name].source' "$COMMAND_CATALOG")
    reference=$(jq -er --arg name "$name" '.commands[$name].modelRef' "$COMMAND_CATALOG")
    kind=$(jq -r --arg name "$name" '.commands[$name].kind // "canonical"' "$COMMAND_CATALOG")
    skill=$(jq -r --arg name "$name" '.commands[$name].skill // $name' "$COMMAND_CATALOG")
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
      if [ "$kind" = retry ]; then
        ok "$name marks a fresh invocation" grep -Fq \
          'not an in-flight tier change' "$command_file"
        ok "$name prevents native default reload" grep -Fq \
          "without invoking the native \`$skill\` skill" "$command_file"
      fi
    else
      ok "$name command available for metadata checks" false
    fi
  done
fi

for skill in "${RETRY_SKILLS[@]}"; do
  claude_retry="$PROJECT/.claude/commands/$skill-retry.md"
  claude_retry_json=$(frontmatter <"$claude_retry")
  default_ref="skillPins.$skill.default.claude-code"
  retry_ref="skillPins.$skill.retry.claude-code"
  ok "Claude $skill retry maps xhigh model" test \
    "$(jq -r '.model' <<<"$claude_retry_json")" = \
    "$(semantic_target_field "$retry_ref" model)"
  ok "Claude $skill retry maps xhigh effort" test \
    "$(jq -r '.effort' <<<"$claude_retry_json")" = \
    "$(semantic_target_field "$retry_ref" effort)"
  ok "Claude $skill retry prevents native default reload" grep -Fq \
    "without invoking the native \`$skill\` skill" "$claude_retry"
  ok "$skill default remains high" test \
    "$(semantic_target_field "$default_ref" effort)" = high
  ok "$skill retry raises effort to xhigh" test \
    "$(semantic_target_field "$retry_ref" effort)" = xhigh
  ok "$skill model matches its default target" grep -Fqx \
    "model: $(semantic_target_field "$default_ref" model)" \
    "$ROOT/engineering/$skill/SKILL.md"
  ok "$skill effort matches its default target" grep -Fqx \
    "effort: $(semantic_target_field "$default_ref" effort)" \
    "$ROOT/engineering/$skill/SKILL.md"
  ok "$skill recommends its retry command" grep -Fq \
    "/$skill-retry <reason>" "$ROOT/engineering/$skill/SKILL.md"
done
ok 'Claude settings default to configured Opus selection' test \
  "$(jq -r '.model' "$ROOT/harness/claude-code/settings.json")" = \
  "$(jq -r '.sessionDefaults["claude-code"].selection' "$MODELS")"
session_model=$(semantic_target_field sessionDefaults.claude-code.target model)
ok 'Claude session selection matches semantic target' test \
  "$(jq -r '.sessionDefaults["claude-code"].selection' "$MODELS")" = \
  "${session_model}[1m]"
ok 'Claude session effort matches semantic target' test \
  "$(jq -r --arg model "$session_model" '.modelSettings[$model].effortLevel' \
    "$ROOT/harness/claude-code/settings.json")" = \
  "$(semantic_target_field sessionDefaults.claude-code.target effort)"
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
      and ([.command["codebase-review-retry"], .command["pr-review-retry"],
        .command["refactor-retry"]] |
        all((has("agent") | not) and .model == "openai/gpt-5.6-sol" and
          .variant == "xhigh"))
  ' \
    "$W/opencode-config.json"
  ok 'OpenCode debug config loads both managed plugins' jq -e '
    ((.plugin // []) | any(contains("main-branch-guard.ts"))) and
    ((.plugin // []) | any(contains("daylog-trigger.ts")))
  ' "$W/opencode-config.json"

  DISCOVERY_HOME="$W/discovery-home"
  DISCOVERY_PROJECT="$W/discovery-project"
  mkdir -p "$DISCOVERY_HOME" "$DISCOVERY_PROJECT"
  git init -q "$DISCOVERY_PROJECT"
  HOME="$DISCOVERY_HOME" "$WIRE" --harness opencode \
    --project "$DISCOVERY_PROJECT" --skill design --apply \
    >"$W/opencode-discovery-wire.out"
  (cd "$DISCOVERY_PROJECT" && HOME="$DISCOVERY_HOME" \
    OPENCODE_DISABLE_EXTERNAL_SKILLS=1 OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1 \
    opencode debug skill --pure) >"$W/opencode-skills.json"
  ok 'isolated OpenCode discovers selected project skill' jq -e \
    'any(.name == "design" and (.location | contains("/.opencode/skills/design/SKILL.md")))' \
    "$W/opencode-skills.json"
  ok 'isolated OpenCode omits unselected project skill' jq -e \
    'all(.name != "audit")' "$W/opencode-skills.json"
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
for name in main-branch-guard daylog-trigger; do
  ok "OpenCode $name plugin is idempotent" grep -Fq \
    "unchanged  $HOME_DIR/.config/opencode/plugins/$name.ts -> $ROOT/harness/opencode/plugins/$name.ts" \
    "$W/opencode-second.out"
done

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

FOREIGN_DAYLOG_HOME="$W/foreign-daylog-home"
mkdir -p "$FOREIGN_DAYLOG_HOME/.config/opencode/plugins"
printf '%s\n' 'foreign daylog definition' \
  >"$FOREIGN_DAYLOG_HOME/.config/opencode/plugins/daylog-trigger.ts"
if HOME="$FOREIGN_DAYLOG_HOME" "$WIRE" --harness opencode --apply \
  >"$W/foreign-daylog.out" 2>&1; then
  foreign_daylog_status=0
else
  foreign_daylog_status=$?
fi
ok 'foreign daylog file returns a warning status' test "$foreign_daylog_status" -ne 0
ok 'foreign daylog file is reported' grep -Fq \
  "$FOREIGN_DAYLOG_HOME/.config/opencode/plugins/daylog-trigger.ts (refusing to replace)" \
  "$W/foreign-daylog.out"
ok 'foreign daylog file is not replaced' grep -Fqx \
  'foreign daylog definition' "$FOREIGN_DAYLOG_HOME/.config/opencode/plugins/daylog-trigger.ts"

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

FOREIGN_DAYLOG_LINK_HOME="$W/foreign-daylog-link-home"
mkdir -p "$FOREIGN_DAYLOG_LINK_HOME/.config/opencode/plugins"
ln -s "$W/foreign-daylog.ts" \
  "$FOREIGN_DAYLOG_LINK_HOME/.config/opencode/plugins/daylog-trigger.ts"
if HOME="$FOREIGN_DAYLOG_LINK_HOME" "$WIRE" --harness opencode --apply \
  >"$W/foreign-daylog-link.out" 2>&1; then
  foreign_daylog_link_status=0
else
  foreign_daylog_link_status=$?
fi
ok 'foreign daylog symlink returns a warning status' test "$foreign_daylog_link_status" -ne 0
ok 'foreign daylog symlink is reported' grep -Fq \
  "daylog-trigger.ts -> $W/foreign-daylog.ts (refusing to replace)" \
  "$W/foreign-daylog-link.out"
ok 'foreign daylog symlink is not replaced' test \
  "$(readlink "$FOREIGN_DAYLOG_LINK_HOME/.config/opencode/plugins/daylog-trigger.ts")" = \
  "$W/foreign-daylog.ts"

echo 'Codex harness'
CODEX_HOME="$W/codex-home"
CODEX_PROJECT="$W/codex-project"
mkdir -p "$CODEX_HOME/.claude" "$CODEX_HOME/.config/opencode" \
  "$CODEX_PROJECT/.claude" "$CODEX_PROJECT/.opencode"
CODEX_PROJECT=$(cd "$CODEX_PROJECT" && pwd -P)
printf '%s\n' '{"sentinel":"claude"}' >"$CODEX_HOME/.claude/settings.json"
printf '%s\n' '{"sentinel":"opencode"}' >"$CODEX_HOME/.config/opencode/config.json"
printf '%s\n' 'claude project sentinel' >"$CODEX_PROJECT/.claude/sentinel"
printf '%s\n' 'opencode project sentinel' >"$CODEX_PROJECT/.opencode/sentinel"
before_other_harnesses=$(find "$CODEX_HOME/.claude" "$CODEX_HOME/.config/opencode" \
  "$CODEX_PROJECT/.claude" "$CODEX_PROJECT/.opencode" -type f -exec shasum {} + | sort)

HOME="$CODEX_HOME" "$WIRE" --harness codex --project "$CODEX_PROJECT" \
  >"$W/codex-dry.out"
ok 'Codex global dry-run reports canonical skill link' grep -Fq \
  "link       $CODEX_HOME/.agents/skills/map -> $ROOT/global/map" "$W/codex-dry.out"
ok 'Codex dry-run reports custom agent render' grep -Fq \
  "render     $CODEX_HOME/.codex/agents/ennio.toml" "$W/codex-dry.out"
ok 'Codex project dry-run reports canonical skill link' grep -Fq \
  "link       $CODEX_PROJECT/.agents/skills/design -> $ROOT/engineering/design" \
  "$W/codex-dry.out"
ok 'Codex dry-run creates no destinations' test ! -e "$CODEX_HOME/.agents"

HOME="$CODEX_HOME" "$WIRE" --harness codex --project "$CODEX_PROJECT" --apply \
  >"$W/codex-first.out"
ok 'Codex global skill applies as a symlink' test -L "$CODEX_HOME/.agents/skills/map"
ok 'Codex global skill has one-hop canonical target' test \
  "$(readlink "$CODEX_HOME/.agents/skills/map")" = "$ROOT/global/map"
ok 'Codex project skill applies as a symlink' test -L \
  "$CODEX_PROJECT/.agents/skills/design"
ok 'Codex project skill has one-hop canonical target' test \
  "$(readlink "$CODEX_PROJECT/.agents/skills/design")" = "$ROOT/engineering/design"

after_other_harnesses=$(find "$CODEX_HOME/.claude" "$CODEX_HOME/.config/opencode" \
  "$CODEX_PROJECT/.claude" "$CODEX_PROJECT/.opencode" -type f -exec shasum {} + | sort)
ok 'Codex wiring does not modify Claude or OpenCode state' test \
  "$before_other_harnesses" = "$after_other_harnesses"

for name in ennio bit vitruv tux linn radar; do
  codex_file="$CODEX_HOME/.codex/agents/$name.toml"
  ok "Codex renders $name TOML" test -f "$codex_file"
  ok "Codex $name carries managed marker" grep -Fq \
    "# managed by harness/wire; source: agents/$name.md" "$codex_file"
  ok "Codex $name has canonical name" test "$(toml_field "$codex_file" name)" = "$name"
  ok "Codex $name reuses canonical description" test \
    "$(toml_field "$codex_file" description)" = \
    "$(jq -r --arg name "$name" '.agents[$name].description' "$ROOT/agents/manifest.json")"
  ok "Codex $name maps model" test \
    "$(toml_field "$codex_file" model)" = "$(target_field "$name" codex model)"
  ok "Codex $name maps effort" test \
    "$(toml_field "$codex_file" model_reasoning_effort)" = \
    "$(target_field "$name" codex model_reasoning_effort)"
  instructions=$(toml_field "$codex_file" developer_instructions)
  ok "Codex $name embeds canonical prompt" grep -Fq \
    "$(head -n 1 "$ROOT/agents/$name.md")" <<<"$instructions"
done

CODEX_FILTERED_PROJECT="$W/codex-filtered-project"
mkdir -p "$CODEX_FILTERED_PROJECT"
CODEX_FILTERED_PROJECT=$(cd "$CODEX_FILTERED_PROJECT" && pwd -P)
HOME="$CODEX_HOME" "$WIRE" --harness codex --project "$CODEX_FILTERED_PROJECT" \
  --skill codebase-map --apply >"$W/codex-filtered.out"
ok 'Codex selected project skill links' test -L \
  "$CODEX_FILTERED_PROJECT/.agents/skills/codebase-map"
ok 'Codex unselected project skill stays absent' test ! -e \
  "$CODEX_FILTERED_PROJECT/.agents/skills/codebase-grill"

HOME="$CODEX_HOME" "$WIRE" --harness codex --project "$CODEX_PROJECT" --apply \
  >"$W/codex-second.out"
ok 'Codex wiring is idempotent' grep -Fq 'summary: 0 change(s)' "$W/codex-second.out"

cp "$CODEX_HOME/.codex/agents/ennio.toml" "$W/ennio-canonical.toml"
printf '%s\n' '# managed by harness/wire; source: agents/ennio.md' 'stale = true' \
  >"$CODEX_HOME/.codex/agents/ennio.toml"
HOME="$CODEX_HOME" "$WIRE" --harness codex --apply >"$W/codex-stale.out"
ok 'Codex stale managed agent is rerendered' grep -Fq \
  "render     $CODEX_HOME/.codex/agents/ennio.toml" "$W/codex-stale.out"
ok 'Codex stale managed agent returns to canonical output' cmp -s \
  "$W/ennio-canonical.toml" "$CODEX_HOME/.codex/agents/ennio.toml"

CODEX_FOREIGN_HOME="$W/codex-foreign-home"
mkdir -p "$CODEX_FOREIGN_HOME/.codex/agents"
printf '%s\n' 'foreign = true' >"$CODEX_FOREIGN_HOME/.codex/agents/ennio.toml"
if HOME="$CODEX_FOREIGN_HOME" "$WIRE" --harness codex --apply \
  >"$W/codex-foreign.out" 2>&1; then
  codex_foreign_status=0
else
  codex_foreign_status=$?
fi
ok 'foreign Codex agent returns warning status' test "$codex_foreign_status" -ne 0
ok 'foreign Codex agent is refused' grep -Fq \
  "$CODEX_FOREIGN_HOME/.codex/agents/ennio.toml (refusing to replace)" \
  "$W/codex-foreign.out"
ok 'foreign Codex agent remains unchanged' grep -Fqx 'foreign = true' \
  "$CODEX_FOREIGN_HOME/.codex/agents/ennio.toml"

CODEX_UNMANAGED_PROJECT="$W/codex-unmanaged-project"
mkdir -p "$CODEX_UNMANAGED_PROJECT/.agents/skills"
CODEX_UNMANAGED_PROJECT=$(cd "$CODEX_UNMANAGED_PROJECT" && pwd -P)
printf '%s\n' 'foreign skill' >"$CODEX_UNMANAGED_PROJECT/.agents/skills/local"
if HOME="$CODEX_HOME" "$WIRE" --harness codex --project "$CODEX_UNMANAGED_PROJECT" \
  --apply >"$W/codex-unmanaged.out" 2>&1; then
  codex_unmanaged_status=0
else
  codex_unmanaged_status=$?
fi
ok 'Codex unmanaged project entry returns warning status' test \
  "$codex_unmanaged_status" -ne 0
ok 'Codex unmanaged project entry is reported' grep -Fq \
  "$CODEX_UNMANAGED_PROJECT/.agents/skills/local -> review/remove" \
  "$W/codex-unmanaged.out"

INVALID_ROOT="$W/invalid-root"
mkdir -p "$INVALID_ROOT"
cp -R "$ROOT/harness" "$ROOT/agents" "$ROOT/global" "$ROOT/engineering" \
  "$INVALID_ROOT/"
jq 'del(.catalogues["codex/openai"])' "$ROOT/harness/models.json" \
  >"$INVALID_ROOT/harness/models.json"
if HOME="$W/invalid-home" "$INVALID_ROOT/harness/wire" --harness codex \
  >"$W/codex-invalid.out" 2>&1; then
  codex_invalid_status=0
else
  codex_invalid_status=$?
fi
ok 'invalid Codex model configuration fails' test "$codex_invalid_status" -ne 0
ok 'invalid Codex model configuration is explained' grep -Fq \
  'model target does not resolve for codex agent' "$W/codex-invalid.out"

dialogue_roster=$(for source in "$ROOT"/global/*/SKILL.md "$ROOT"/engineering/*/SKILL.md; do
  if grep -Fqx 'disable-model-invocation: true' "$source"; then
    basename "$(dirname "$source")"
  fi
done | sort)
codex_policy_roster=$(find "$ROOT/global" "$ROOT/engineering" \
  -path '*/agents/openai.yaml' -print | while IFS= read -r metadata; do
    grep -Fqx '  allow_implicit_invocation: false' "$metadata" && \
      basename "$(dirname "$(dirname "$metadata")")"
  done | sort)
ok 'Codex invocation policy matches dialogue-bound skill roster' test \
  "$dialogue_roster" = "$codex_policy_roster"

PLUGIN="$ROOT/plugins/skills"
MARKETPLACE="$ROOT/.agents/plugins/marketplace.json"
ok 'Codex plugin manifest is valid JSON' jq -e . "$PLUGIN/.codex-plugin/plugin.json"
ok 'Codex marketplace is valid JSON' jq -e . "$MARKETPLACE"
ok 'Codex plugin and marketplace names match' test \
  "$(jq -r '.name' "$PLUGIN/.codex-plugin/plugin.json")" = \
  "$(jq -r '.plugins[0].name' "$MARKETPLACE")"
expected_plugin_skills=$(find "$ROOT/global" "$ROOT/engineering" \
  -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
actual_plugin_skills=$(find "$PLUGIN/skills" -mindepth 1 -maxdepth 1 \
  \( -type l -o -type d \) | wc -l | tr -d ' ')
ok 'Codex plugin flat tree covers every canonical skill' test \
  "$expected_plugin_skills" = "$actual_plugin_skills"
while IFS= read -r skill; do
  ok "plugin skill $(basename "$skill") resolves to canonical source" test -f "$skill/SKILL.md"
done < <(find "$PLUGIN/skills" -mindepth 1 -maxdepth 1 \( -type l -o -type d \) | sort)
ok 'Codex generated plugin projections are current' \
  bash "$ROOT/harness/codex/build-plugin" --check

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
