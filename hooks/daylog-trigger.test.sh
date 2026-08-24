#!/usr/bin/env bash
# Regression suite for daylog-trigger.
#
# Run: bash hooks/daylog-trigger.test.sh
#
# The hook signals through the filesystem, not through status. It exits 0 on
# every path by design, so "the hook exited 0" proves nothing at all. Two things
# keep this suite from going green against a hook that is missing, unreadable or
# syntactically broken:
#
#   1. fire() treats any non-zero exit as ERROR and the case fails. bash returns
#      127 for a missing file and 126 for an unexecutable one.
#   2. Most cases assert on content the hook must have *written*. A hook that
#      never ran creates no daylog, so it cannot score the positive cases. The
#      suite is deliberately not all-negative: an all-negative suite for a hook
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
  # The hook derives this from DAYLOG_STATE; the suite has to know the same path
  # to assert on the one thing it carries, which is its mtime.
  ACTIVITY=$STATE.activity
  mkdir -p "$VAULT/hq" "$VAULT/_templates"
  # A faithful replica of ~/Dev/notes/_templates/daylog.md, INCLUDING its `##
  # Seal` stub. That section is not decoration here: an earlier fixture omitted
  # it, and the omission hid a false positive in which every freshly minted
  # daylog was flagged as carrying a premature seal, because the hook keyed on
  # the heading and the template ships the heading from birth. A fixture that is
  # tidier than the real thing tests a file that does not exist.
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

## Seal _(hotwash: what moved, what carries — then the write-back)_

**Span:** <HH:MM → HH:MM>, stating the `(+1d)` when the session ran past
midnight.

**Moved:** what actually happened this session.
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
count() { local c; c=$(grep -cF "$2" "$1" 2>/dev/null); printf '%s\n' "${c:-0}"; }
mtime_of() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# A daylog that already exists, for the cases that begin mid-day rather than
# minting their way in.
seed_daylog() { # seed_daylog <day>
  sed "s|^# Daylog — .*|# Daylog — $1|" "$VAULT/_templates/daylog.md" >"$(log_for "$1")"
}

# seed_state <day> <opened> <minted> <session> <session_opened> <logged>
seed_state() {
  jq -n --arg day "$1" --arg opened "$2" --argjson minted "$3" \
    --arg session "$4" --arg so "$5" --arg logged "$6" \
    '{day:$day, opened:$opened, minted:$minted,
      session:$session, session_opened:$so, logged:$logged}' >"$STATE"
}

OPENS='**session opens**'
CLOSES='**session closes**'

# Assert on the close line itself, never on the whole file. The daylog template
# ships the words "stating the `(+1d)` when the session ran past midnight", so a
# file-wide grep for `(+1d)` matches the template's own prose and scores every
# span case green whatever the hook wrote.
close_line() { grep -F "$CLOSES" "$1" 2>/dev/null | tail -1; }
line_has() { printf '%s' "$1" | grep -qF "$2"; }

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
echo "scope: a session that only reads leaves nothing behind"

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
echo "append: the first authoring action opens the day, exactly once"

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
echo "close: the seal end, which is a different bug"

fresh_vault
fire "$START"; fire "$w_write"; fire "$end_logout"
L=$(log_for)
ok "SessionEnd records the close"                  "$(has "$L" 'session closes' && echo 0 || echo 1)"
ok "the close names its reason"                    "$(has "$L" 'logout' && echo 0 || echo 1)"
ok "the close carries a true span"                 "$(has "$L" 'True span' && echo 0 || echo 1)"
ok "no premature-seal warning without a seal"      "$(has "$L" 'was written before' && echo 1 || echo 0)"
ok "the template's own Seal stub is present"       "$(has "$L" '## Seal' && echo 0 || echo 1)"
ok "an UNFILLED seal stub is not a seal"           "$(has "$L" 'was written before' && echo 1 || echo 0)"

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
echo "boundary: a day is a working session, not a calendar date (§3.1)"

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

# ------------------------------------------------------- the idle clock ----
# The clock answers "how long since work stopped". Every event that is not work
# must leave it alone. A session end refreshing it is the inversion that froze
# the session-day, so this asserts on the mtime directly rather than on any
# downstream symptom.
echo "the idle clock: measured from work, never from the hook's own footprints"

fresh_vault
fire "$START"; fire "$w_write"
ok "authoring creates the idle clock"              "$([ -f "$ACTIVITY" ] && echo 0 || echo 1)"

touch -t "$LONG_AGO" "$ACTIVITY"
frozen=$(mtime_of "$ACTIVITY")
fire "$START"
ok "a session start does not refresh it"           "$([ "$(mtime_of "$ACTIVITY")" = "$frozen" ] && echo 0 || echo 1)"
fire "$end_clear"
ok "a /clear does not refresh it"                  "$([ "$(mtime_of "$ACTIVITY")" = "$frozen" ] && echo 0 || echo 1)"
fire "$end_logout"
ok "a real close does not refresh it"              "$([ "$(mtime_of "$ACTIVITY")" = "$frozen" ] && echo 0 || echo 1)"
fire "$w_read"; fire "$w_ls"; fire "$w_gitstatus"
ok "a non-authoring tool call does not refresh it" "$([ "$(mtime_of "$ACTIVITY")" = "$frozen" ] && echo 0 || echo 1)"
fire "$w_edit"
ok "authoring does refresh it"                     "$([ "$(mtime_of "$ACTIVITY")" != "$frozen" ] && echo 0 || echo 1)"

# The reported shape end to end: yesterday's session closes, and a session
# starting this morning must still open a new session-day. The close is the
# event that used to prevent it.
fresh_vault
seed_daylog "$YESTERDAY"
seed_state "$YESTERDAY" "${YESTERDAY}T18:00-06:00" true "abcdef1234" "${YESTERDAY}T18:00-06:00" "abcdef1234"
touch -t "$LONG_AGO" "$ACTIVITY"
fire "$end_logout"
ok "yesterday's close lands in yesterday's daylog" "$(has "$(log_for "$YESTERDAY")" "$CLOSES" && echo 0 || echo 1)"
fire "$START"
ok "and the next start still rolls the day over"   "$([ "$(jq -r .day "$STATE")" = "$TODAY" ] && echo 0 || echo 1)"

# -------------------------------------------------------------- the span ----
# `opened` is the day's; the close line names one session and calls its span
# true. Every session after the day's first therefore reported a start it never
# had, and the ledger carried no open line that could contradict it.
echo "the span: a session's close reports the session's own start"

fresh_vault
seed_daylog "$TODAY"
seed_state "$TODAY" "${TODAY}T07:27-06:00" true "" "" ""
fire "$START"; fire "$w_write"
LOG=$(log_for "$TODAY")
ok "an already-minted day still records an open"   "$([ "$(count "$LOG" "$OPENS")" -eq 1 ] && echo 0 || echo 1)"
ok "the open is this session's, not the day's"     "$(has "$LOG" '`07:27` — **session opens**' && echo 1 || echo 0)"
fire "$end_logout"
ok "the close pairs with that open"                "$([ "$(count "$LOG" "$CLOSES")" -eq 1 ] && echo 0 || echo 1)"
ok "and its span does not claim the day's start"   "$(line_has "$(close_line "$LOG")" '`07:27 →' && echo 1 || echo 0)"
ok "opens and closes pair one to one"              "$([ "$(count "$LOG" "$OPENS")" -eq "$(count "$LOG" "$CLOSES")" ] && echo 0 || echo 1)"

# `(+1d)` belongs to a session that really crossed midnight, which is a fact
# about when the session opened, not about which date its session-day is
# filed under.
fresh_vault
seed_daylog "$YESTERDAY"
seed_state "$YESTERDAY" "${YESTERDAY}T18:00-06:00" true "abcdef1234" "${YESTERDAY}T23:40-06:00" "abcdef1234"
fire "$end_logout"
ok "a session opened yesterday closes with (+1d)"  "$(line_has "$(close_line "$(log_for "$YESTERDAY")")" '(+1d)' && echo 0 || echo 1)"

fresh_vault
seed_daylog "$YESTERDAY"
seed_state "$YESTERDAY" "${YESTERDAY}T18:00-06:00" true "abcdef1234" "${TODAY}T09:12-06:00" "abcdef1234"
fire "$end_logout"
ok "one that opened this morning does not"         "$(line_has "$(close_line "$(log_for "$YESTERDAY")")" '(+1d)' && echo 1 || echo 0)"
ok "and spans from 09:12, not from 18:00"          "$(line_has "$(close_line "$(log_for "$YESTERDAY")")" '`09:12 →' && echo 0 || echo 1)"

# A close with no open of its own is the asymmetry that let four closes and zero
# opens share a ledger.
fresh_vault
seed_daylog "$TODAY"
seed_state "$TODAY" "${TODAY}T07:27-06:00" true "99887766aa" "${TODAY}T07:27-06:00" "99887766aa"
fire "$end_logout"
ok "a session that filed no open files no close"   "$([ "$(count "$(log_for "$TODAY")" "$CLOSES")" -eq 0 ] && echo 0 || echo 1)"

# ---------------------------------------------------------- failing open ----
echo "failing open: a record is not a floor"

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
echo "failing closed: the suite must not pass without its subject"

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
