#!/usr/bin/env bash
# Regression suite for daylog-trigger.
#
# Run: bash hooks/daylog-trigger.test.sh
#
# The hook signals through the filesystem, not through status — it exits 0 on
# every path by design, so "the hook exited 0" proves nothing at all. Two things
# keep this suite from going green against a hook that is missing, unreadable or
# syntactically broken:
#
#   1. fire() treats any non-zero exit as ERROR and the case fails. bash returns
#      127 for a missing file and 126 for an unexecutable one.
#   2. Most cases assert on content the hook must have *written*. A hook that
#      never ran creates no daylog, so it cannot score the positive cases. The
#      suite is deliberately not all-negative — an all-negative suite for a hook
#      whose correct behaviour is often "do nothing" would pass on an empty file.
#
# That is the same fail-open shape main-branch-guard.test.sh was written to
# reject, in the one place it could reappear.

set -u
HOOK=${HOOK:-$(cd "$(dirname "$0")" && pwd)/daylog-trigger.sh}
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

pass=0
fail=0

TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d 'yesterday' +%Y-%m-%d)
LONG_AGO=$(date -v-5H +%Y%m%d%H%M 2>/dev/null || date -d '5 hours ago' +%Y%m%d%H%M)

# A throwaway vault with the real template shape, plus a fresh state path.
VAULT=""
STATE=""
n=0
fresh_vault() {
  n=$((n + 1))
  VAULT=$W/vault$n
  STATE=$W/state$n.json
  mkdir -p "$VAULT/hq" "$VAULT/_templates"
  cat >"$VAULT/_templates/daylog.md" <<'TPL'
---
repo: hq
artifact: daylog
created: 2026-01-01T00:00-06:00 # real date+time, local CDMX with offset
---

# Daylog — <date>

## Plan _(standup: the day's intended moves, drawn from the sitrep)_

- [ ] <project> — <move> — timebox

## Log _(appended through the day — what actually moved, with its evidence)_

- <time> — <what happened> (commit / artifact / note)
TPL
}

# fire <json> [hook-override] -> exit status, or 99 marking ERROR
fire() {
  local json=$1 hook=${2:-$HOOK} status
  printf '%s' "$json" |
    DAYLOG_VAULT="$VAULT" DAYLOG_STATE="$STATE" bash "$hook" >/dev/null 2>&1
  status=$?
  [ "$status" -ne 0 ] && return 99
  return 0
}

ok() { # ok <label> <condition-result>
  if [ "$2" = 0 ]; then
    pass=$((pass + 1))
    printf '  ok    %s\n' "$1"
  else
    fail=$((fail + 1))
    printf '  FAIL  %s\n' "$1"
  fi
}

log_for() { printf '%s/hq/%s-daylog.md\n' "$VAULT" "${1:-$TODAY}"; }
has() { grep -qF "$2" "$1" 2>/dev/null; }
count() { grep -cF "$2" "$1" 2>/dev/null || echo 0; }

START='{"hook_event_name":"SessionStart","session_id":"abcdef1234","source":"startup","cwd":"/tmp"}'
w_write='{"hook_event_name":"PostToolUse","session_id":"abcdef1234","tool_name":"Write","tool_input":{"file_path":"/tmp/x"}}'
w_edit='{"hook_event_name":"PostToolUse","session_id":"abcdef1234","tool_name":"Edit","tool_input":{"file_path":"/tmp/x"}}'
w_read='{"hook_event_name":"PostToolUse","session_id":"abcdef1234","tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}'
w_ls='{"hook_event_name":"PostToolUse","session_id":"abcdef1234","tool_name":"Bash","tool_input":{"command":"ls -la"}}'
w_gitstatus='{"hook_event_name":"PostToolUse","session_id":"abcdef1234","tool_name":"Bash","tool_input":{"command":"git status --short"}}'
w_gitcommit='{"hook_event_name":"PostToolUse","session_id":"abcdef1234","tool_name":"Bash","tool_input":{"command":"git commit -m wip"}}'
end_logout='{"hook_event_name":"SessionEnd","session_id":"abcdef1234","reason":"logout"}'
end_clear='{"hook_event_name":"SessionEnd","session_id":"abcdef1234","reason":"clear"}'

# ------------------------------------------------------ scope: what mints ----
echo "scope — a session that only reads leaves nothing behind"

fresh_vault
fire "$START"; s=$?
ok "SessionStart exits cleanly"                    "$([ $s -eq 0 ] && echo 0 || echo 1)"
ok "SessionStart writes state"                     "$([ -f "$STATE" ] && echo 0 || echo 1)"
ok "SessionStart records today"                    "$([ "$(jq -r .day "$STATE")" = "$TODAY" ] && echo 0 || echo 1)"
ok "SessionStart mints NO daylog"                  "$([ ! -f "$(log_for)" ] && echo 0 || echo 1)"

fire "$w_read"
ok "a Read mints nothing"                          "$([ ! -f "$(log_for)" ] && echo 0 || echo 1)"
fire "$w_ls"
ok "a bare 'ls' mints nothing"                     "$([ ! -f "$(log_for)" ] && echo 0 || echo 1)"
fire "$w_gitstatus"
ok "a read-only git command mints nothing"         "$([ ! -f "$(log_for)" ] && echo 0 || echo 1)"

# --------------------------------------------------- the append, and once ----
echo "append — the first authoring action opens the day, exactly once"

fire "$w_write"; s=$?
L=$(log_for)
ok "a Write exits cleanly"                         "$([ $s -eq 0 ] && echo 0 || echo 1)"
ok "a Write mints the daylog"                      "$([ -f "$L" ] && echo 0 || echo 1)"
ok "the daylog is titled with its day"             "$(has "$L" "# Daylog — $TODAY" && echo 0 || echo 1)"
ok "the template placeholder date is replaced"     "$(has "$L" '2026-01-01' && echo 1 || echo 0)"
ok "the ledger section exists"                     "$(has "$L" '## Session ledger' && echo 0 || echo 1)"
ok "the session-open line is written"              "$(has "$L" 'session opens' && echo 0 || echo 1)"
ok "the session id is recorded"                    "$(has "$L" 'abcdef12' && echo 0 || echo 1)"
ok "state is marked minted"                        "$([ "$(jq -r .minted "$STATE")" = true ] && echo 0 || echo 1)"

fire "$w_edit"; fire "$w_write"
ok "further writes do not re-open the day"         "$([ "$(count "$L" 'session opens')" -eq 1 ] && echo 0 || echo 1)"

ok "authored sections are untouched"               "$(has "$L" '## Log' && echo 0 || echo 1)"

# A git commit is authoring; it is how work leaves a session that edited nothing.
fresh_vault
fire "$START"; fire "$w_gitcommit"
ok "a git commit mints the daylog"                 "$([ -f "$(log_for)" ] && echo 0 || echo 1)"

# The hook can be installed mid-session, or the state file wiped under it.
fresh_vault
fire "$w_write"
ok "PostToolUse with no SessionStart still mints"  "$([ -f "$(log_for)" ] && echo 0 || echo 1)"

# ------------------------------------------------------------- the close ----
echo "close — the seal end, which is a different bug"

fresh_vault
fire "$START"; fire "$w_write"; fire "$end_logout"
L=$(log_for)
ok "SessionEnd records the close"                  "$(has "$L" 'session closes' && echo 0 || echo 1)"
ok "the close names its reason"                    "$(has "$L" 'logout' && echo 0 || echo 1)"
ok "the close carries a true span"                 "$(has "$L" 'True span' && echo 0 || echo 1)"
ok "no premature-seal warning without a seal"      "$(has "$L" 'was written before' && echo 1 || echo 0)"

# The 2026-08-10 shape: a seal written at 09:24 into a session still running.
fresh_vault
fire "$START"; fire "$w_write"
printf '\n## Seal\n\n**Span:** `09:05 → 09:24`.\n' >>"$(log_for)"
fire "$end_logout"
L=$(log_for)
ok "a premature seal is flagged"                   "$(has "$L" 'was written before this session ended' && echo 0 || echo 1)"
ok "the seal itself is not edited"                 "$(has "$L" '`09:05 → 09:24`' && echo 0 || echo 1)"
ok "the ledger heading is re-emitted after it"     "$([ "$(count "$L" '## Session ledger')" -eq 2 ] && echo 0 || echo 1)"

# /clear ends a session id, not a working day.
fresh_vault
fire "$START"; fire "$w_write"; fire "$end_clear"
ok "/clear does not close the day"                 "$(has "$(log_for)" 'session closes' && echo 1 || echo 0)"

# Closing a session that authored nothing must not mint on the way out.
fresh_vault
fire "$START"; fire "$end_logout"
ok "a read-only session closes silently"           "$([ ! -f "$(log_for)" ] && echo 0 || echo 1)"

# ----------------------------------------------------------- the boundary ----
echo "boundary — a day is a working session, not a calendar date (§3.1)"

# Past midnight, still working: the date changed, the machine never went idle.
fresh_vault
jq -n --arg d "$YESTERDAY" '{day:$d, opened:($d+"T18:00-06:00"), minted:false}' >"$STATE"
fire "$START"
ok "past-midnight work continues the same day"     "$([ "$(jq -r .day "$STATE")" = "$YESTERDAY" ] && echo 0 || echo 1)"

fire "$w_write"
ok "and appends to yesterday's daylog"             "$([ -f "$(log_for "$YESTERDAY")" ] && echo 0 || echo 1)"
ok "not to today's"                                "$([ ! -f "$(log_for "$TODAY")" ] && echo 0 || echo 1)"

# A new morning: the date changed and the machine was idle across it.
fresh_vault
jq -n --arg d "$YESTERDAY" '{day:$d, opened:($d+"T18:00-06:00"), minted:true}' >"$STATE"
touch -t "$LONG_AGO" "$STATE"
fire "$START"
ok "a new morning opens a new session-day"         "$([ "$(jq -r .day "$STATE")" = "$TODAY" ] && echo 0 || echo 1)"
ok "and clears the minted flag"                    "$([ "$(jq -r .minted "$STATE")" = false ] && echo 0 || echo 1)"

# ---------------------------------------------------------- failing open ----
echo "failing open — a record is not a floor"

fresh_vault
rm -rf "$VAULT/_templates"
fire "$START"; fire "$w_write"; s=$?
ok "a missing template still mints"                "$([ -f "$(log_for)" ] && echo 0 || echo 1)"
ok "and says so in the file"                       "$(has "$(log_for)" 'without a template' && echo 0 || echo 1)"

fresh_vault
chmod 500 "$VAULT/hq"
fire "$START"; fire "$w_write"; s=$?
ok "an unwritable vault does not wedge the session" "$([ $s -eq 0 ] && echo 0 || echo 1)"
chmod 700 "$VAULT/hq"

fresh_vault
fire '{"hook_event_name":"SessionStart"}'; s=$?
ok "a payload with no session_id survives"         "$([ $s -eq 0 ] && echo 0 || echo 1)"
fire 'not json at all'; s=$?
ok "a non-JSON payload survives"                   "$([ $s -eq 0 ] && echo 0 || echo 1)"
fire '{"hook_event_name":"Notification"}'; s=$?
ok "an unhandled event is a no-op"                 "$([ $s -eq 0 ] && echo 0 || echo 1)"

# --------------------------------------------------------- failing closed ----
# The suite's own subject. If the hook is gone, every case above that asserts on
# written content already fails; these two make the reason explicit rather than
# leaving a wall of unexplained FAILs.
echo "failing closed — the suite must not pass without its subject"

fresh_vault
fire "$w_write" "$W/no-such-hook.sh"; s=$?
ok "a missing hook is ERROR, not silence"          "$([ $s -eq 99 ] && echo 0 || echo 1)"
ok "a missing hook mints nothing"                  "$([ ! -f "$(log_for)" ] && echo 0 || echo 1)"

printf '#!/usr/bin/env bash\nexit 0\n' >"$W/unreadable.sh"
chmod 000 "$W/unreadable.sh"
fresh_vault
fire "$w_write" "$W/unreadable.sh"; s=$?
ok "an unreadable hook is ERROR"                   "$([ $s -eq 99 ] && echo 0 || echo 1)"
chmod 700 "$W/unreadable.sh"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
