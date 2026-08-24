#!/usr/bin/env bash
# daylog-trigger — the event the daylog convention was waiting on.
#
# `_conventions.md` §3.1 rules that a daylog is "minted on first append". That
# says what happens *when someone writes*; nothing made anyone write. Eight
# session-days were cold-sealed from git archaeology, two of them opened by
# their own close. Mint-on-append was a policy waiting on an event that did not
# fire. This is the event.
#
# Three hooks, one script, dispatched on hook_event_name:
#
#   SessionStart   Opens or continues the session-day in the state file.
#                  Writes NOTHING to the vault — a session that only reads must
#                  not leave a daylog behind.
#   PostToolUse    On the session-day's first *authoring* action, mints today's
#                  daylog if absent and records that the session opened. This is
#                  the lazy half: the trigger is a session start, the append
#                  waits for evidence that the session did something.
#   SessionEnd     Stamps the true close time. This is the half that answers the
#                  premature seal — 2026-08-10 was sealed at 09:24 into a session
#                  the seal itself records as still open.
#
# What it will not do. It never edits authored prose. `## Log` and `## Seal`
# belong to the human and to /hotwash; this script owns exactly one section,
# `## Session ledger`, and only ever appends to it. A seal written early is not
# rewritten — it is superseded by a ledger line carrying the true span, so the
# discrepancy becomes visible instead of silent.
#
# A day is a working session, not a calendar date (§3.1). A session that runs
# 18:00 -> 03:12 is one day, filed under the 18:00 date. So a new session-day
# begins only when the calendar date has changed AND the machine has been idle
# for NEW_DAY_GAP_HOURS. Date-change alone would split every late night in two;
# idleness alone would split a day around a long meeting.
#
# Idle means "since work stopped", measured from the last *authoring* action and
# from nothing else. Measuring it from the hook's own last run instead is what
# kept the session-day frozen: every session start and every session end
# refreshed the clock, so the gap never opened and closes filed into a day that
# had already been sealed.
#
# Fails open, always. Every path exits 0. A hook that can wedge a session gets
# switched off, and a daylog is a record, not a floor — losing a line is a far
# cheaper failure than losing the ability to work. Where it cannot act it says
# so on stderr and gets out of the way.
#
# hooks/daylog-trigger.test.sh covers all three events. Run it after any edit.

set -u

VAULT=${DAYLOG_VAULT:-$HOME/Dev/notes}
STATE=${DAYLOG_STATE:-$HOME/.claude/state/daylog-session.json}
# The idle clock, and nothing else. It carries no content; only its mtime is
# ever read. It is a separate file from $STATE because $STATE is rewritten on
# paths that are not activity — a session start that records nothing but its own
# id, for one — and every rewrite would otherwise reset the clock that decides
# whether the machine has been idle.
ACTIVITY=${DAYLOG_ACTIVITY:-$STATE.activity}
NEW_DAY_GAP_HOURS=${DAYLOG_NEW_DAY_GAP_HOURS:-4}

LEDGER_HEADING='## Session ledger _(appended by `daylog-trigger`, never by hand)_'

note() { printf 'daylog-trigger: %s\n' "$1" >&2; }
done_ok() { exit 0; }

command -v jq >/dev/null 2>&1 || { note "jq not found; standing down."; done_ok; }

input=$(cat 2>/dev/null) || done_ok

# One jq for the whole payload. PostToolUse fires on every edit and every Bash
# call, so this path is walked constantly; parsing field-by-field cost five
# subprocesses per tool call for no benefit. @tsv escapes embedded tabs and
# newlines, which is harmless here — every consumer below does substring or
# equality matching, never column arithmetic.
fields=$(printf '%s' "$input" |
  jq -r '[.hook_event_name // "", .session_id // "", .tool_name // "",
          .tool_input.command // "", .reason // ""] | @tsv' 2>/dev/null)
[ -n "$fields" ] || done_ok
# Read on a UNIT SEPARATOR, not on the tab @tsv emits. Tab is IFS whitespace, so
# bash collapses runs of it and drops empty fields entirely — a SessionEnd
# payload (no tool_name, no command) then shifts `reason` into `tool`, and the
# close silently reads as an unhandled event. @tsv has already escaped any real
# tab or newline inside a command, so every tab left in the string is a
# delimiter and the substitution is safe.
IFS=$'\037' read -r event session tool cmd reason <<<"${fields//$'\t'/$'\037'}"

[ -n "${event:-}" ] || done_ok
session=${session:-}
tool=${tool:-}
cmd=${cmd:-}
reason=${reason:-}

short_session=$(printf '%s' "$session" | cut -c1-8)
[ -n "$short_session" ] || short_session="unknown"

# ------------------------------------------------------------------- time ----
# §3.1: local time with an explicit offset. `date +%z` gives -0600; the colon is
# what makes it valid YAML-adjacent ISO 8601, and what makes it survive travel.
stamp_full() { date "+%Y-%m-%dT%H:%M%z" | sed 's/\(..\)$/:\1/'; }
stamp_clock() { date "+%H:%M"; }
today() { date "+%Y-%m-%d"; }
now_epoch() { date "+%s"; }

# ------------------------------------------------------------------ state ----
# Last activity is a file's mtime rather than a JSON field, so the hot path
# (PostToolUse on a session whose open is already filed) is one touch instead of
# a jq rewrite. PostToolUse fires on every edit; it has to stay nearly free.
#
# Exactly one path may touch $ACTIVITY: the PostToolUse authoring path below.
# The clock answers "how long since work stopped", so anything that is not work
# must leave it alone. A SessionEnd touching it is the sharpest version of the
# mistake: the strongest evidence that work has stopped would refresh the very
# timestamp that decides whether work has stopped, and the next start would then
# read as continuous. That inversion is what kept the session-day from ever
# rolling over.
state_dir=$(dirname "$STATE")

# Work happened, now. The only writer of the idle clock.
mark_activity() { touch "$ACTIVITY" 2>/dev/null || true; }

state_read() { # state_read <jq-path> -> value or empty
  [ -f "$STATE" ] || return 0
  jq -r "$1 // empty" "$STATE" 2>/dev/null
}

# The idle clock's reading. Falls back to $STATE's own mtime when $ACTIVITY does
# not exist yet, which is what an install predating the split has: the state
# file's mtime is then the best estimate available, and one stale reading is
# cheaper than declaring a new day on every first run.
state_mtime() {
  local f=$ACTIVITY
  [ -f "$f" ] || f=$STATE
  [ -f "$f" ] || { echo 0; return; }
  local m
  # GNU first, then BSD, and every answer is checked for digits before it is
  # believed. Both halves of that are a real CI failure, not caution: GNU's
  # `stat -f` is not BSD's. On Linux it reports *filesystem* status, so
  # `stat -f %m` prints a mount point and exits 0 — succeeding with the wrong
  # answer, which a `||` chain cannot catch. The gap arithmetic below then read
  # a mount point as an epoch and every day-boundary case went wrong.
  m=$(stat -c %Y "$f" 2>/dev/null) || m=""
  case "$m" in '' | *[!0-9]*) m=$(stat -f %m "$f" 2>/dev/null) ;; esac
  case "$m" in '' | *[!0-9]*) m=0 ;; esac
  printf '%s\n' "$m"
}

# Six fields, in two scopes, and the split is the whole point. `day` / `opened` /
# `minted` describe the session-*day*; `session` / `session_opened` / `logged`
# describe the one session running now. Reporting a day-scoped `opened` as a
# session's own start is what made every close after the day's first claim a
# time it never had.
#
#   day             the session-day this state belongs to
#   opened          when that day began
#   minted          whether the day's daylog exists
#   session         id of the session that owns the two fields below
#   session_opened  when THAT session began
#   logged          id of the session whose open line is already in the ledger
#
# `logged` implies `minted`: a session's open line can only be written after the
# daylog exists. That is what lets the hot path settle both with one grep.
state_write() { # state_write <day> <opened> <minted> <session> <session_opened> <logged>
  mkdir -p "$state_dir" 2>/dev/null || { note "cannot create $state_dir"; return 1; }
  jq -n --arg day "$1" --arg opened "$2" --argjson minted "$3" \
    --arg session "$4" --arg session_opened "$5" --arg logged "$6" \
    '{day: $day, opened: $opened, minted: $minted,
      session: $session, session_opened: $session_opened, logged: $logged}' \
    >"$STATE.tmp" 2>/dev/null &&
    mv "$STATE.tmp" "$STATE" 2>/dev/null
}

# `.minted` as a literal true/false, never empty — state_write takes it as JSON.
state_minted() {
  [ "$(state_read '.minted')" = "true" ] && { echo true; return; }
  echo false
}

# HH:MM out of a stamp_full value.
clock_of() { local t=${1#*T}; printf '%s\n' "${t%%[+-]*}"; }

# Does the clock say a new session-day has begun? Both conditions, never one.
is_new_day() {
  local recorded_day gap_seconds threshold
  recorded_day=$(state_read '.day')
  [ -n "$recorded_day" ] || return 0            # no state at all -> new day
  [ "$recorded_day" = "$(today)" ] && return 1  # same date -> always continue
  gap_seconds=$(( $(now_epoch) - $(state_mtime) ))
  threshold=$(( NEW_DAY_GAP_HOURS * 3600 ))
  [ "$gap_seconds" -ge "$threshold" ]
}

# ---------------------------------------------------------------- daylog -----
daylog_path() { printf '%s/hq/%s-daylog.md\n' "$VAULT" "$1"; }

# Mint from the vault's own template so the frontmatter stays schema-correct.
# If the template is missing we still mint — a daylog with a hand-built header
# beats no daylog, which is the entire failure this script exists to end.
mint() { # mint <path> <day>
  local path=$1 day=$2 template="$VAULT/_templates/daylog.md"
  [ -f "$path" ] && return 0
  mkdir -p "$(dirname "$path")" 2>/dev/null || return 1
  if [ -f "$template" ]; then
    sed -e "s|^created: .*|created: $(stamp_full)|" \
        -e "s|^# Daylog — .*|# Daylog — $day|" \
        "$template" >"$path" 2>/dev/null || return 1
  else
    {
      printf -- '---\nrepo: hq\nartifact: daylog\ncreated: %s\n---\n\n' "$(stamp_full)"
      printf '# Daylog — %s\n\n' "$day"
      printf '_Minted by `daylog-trigger` without a template — `%s` was missing._\n' "$template"
    } >"$path" 2>/dev/null || return 1
  fi
  return 0
}

# The ledger is the only section this script owns. Re-emit the heading whenever
# it is not the file's last one, so that a ritual appending its own section
# after ours does not leave later lines filed under the wrong header.
append_ledger() { # append_ledger <path> <line>
  local path=$1 line=$2 last
  last=$(grep -n '^## ' "$path" 2>/dev/null | tail -1 | cut -d: -f2-)
  if [ "$last" != "$LEDGER_HEADING" ]; then
    printf '\n%s\n\n' "$LEDGER_HEADING" >>"$path" 2>/dev/null || return 1
  fi
  printf '%s\n' "$line" >>"$path" 2>/dev/null
}

# Is this tool call evidence that the session did something worth a record?
# Edits and writes obviously are. A Bash call is only counted when it mutates
# git or the tracker — otherwise `ls` would mint a daylog for a session that
# asked one question, which is exactly the over-minting the SessionStart-only
# design was criticised for.
is_authoring() { # is_authoring <tool_name> <bash-command>
  case "$1" in
    Edit|Write|MultiEdit|NotebookEdit) return 0 ;;
    Bash) ;;
    *) return 1 ;;
  esac
  case "$2" in
    *"git commit"*|*"git push"*|*"git merge"*|*"git tag"*|*"git rebase"*) return 0 ;;
    *"gh pr create"*|*"gh issue create"*|*"gh release create"*) return 0 ;;
    *) return 1 ;;
  esac
}

# ----------------------------------------------------------------- events ----
case "$event" in

  SessionStart)
    if is_new_day; then
      now=$(stamp_full)
      # A new day's first session opens both scopes at the same instant.
      state_write "$(today)" "$now" false "$session" "$now" "" || done_ok
    else
      # Continuing an open session-day. The day's own start, its minted flag and
      # the idle clock are all left exactly as they are; the only new fact is
      # that a different session is now running, and when it began. Writing
      # nothing when the session is unchanged keeps a re-fired SessionStart from
      # moving a start time backwards or forwards.
      if [ "$(state_read '.session')" != "$session" ]; then
        state_write "$(state_read '.day')" "$(state_read '.opened')" \
          "$(state_minted)" "$session" "$(stamp_full)" ""
      fi
    fi
    ;;

  PostToolUse)
    is_authoring "$tool" "$cmd" || done_ok

    # Hot path: this session's open line is already filed. grep rather than jq,
    # so the common case is one cheap read and a touch. Keying on `logged`
    # rather than `minted` is what lets a second session of an already-minted
    # day still record its own open — under the old key it short-circuited here
    # and the day ended with more closes in the ledger than opens.
    grep -q "\"logged\": *\"$session\"" "$STATE" 2>/dev/null &&
      { mark_activity; done_ok; }

    # A PostToolUse can arrive with no SessionStart behind it — a hook installed
    # mid-session, or a state file wiped. Open the day here rather than skip it.
    day=$(state_read '.day')
    opened=$(state_read '.opened')
    session_opened=$(state_read '.session_opened')
    if [ -z "$day" ] || is_new_day; then
      day=$(today)
      opened=$(stamp_full)
      session_opened=""
    fi
    [ -n "$opened" ] || opened=$(stamp_full)
    # This session's own start, when no SessionStart recorded one.
    if [ "$(state_read '.session')" != "$session" ] || [ -z "$session_opened" ]; then
      session_opened=$(stamp_full)
    fi

    path=$(daylog_path "$day")
    existed=yes
    [ -f "$path" ] || existed=no
    mint "$path" "$day" || { note "could not mint $path"; done_ok; }

    # The session's own start, not the day's. On the day's first session they
    # are the same value; on every later one they are not, and this is the line
    # the close below has to pair with.
    open_clock=$(clock_of "$session_opened")
    if [ "$existed" = no ]; then
      minted_note="minted by this session's first authoring action"
    else
      minted_note="appended to a daylog that already existed"
    fi
    append_ledger "$path" \
      "- \`$open_clock\` — **session opens** · \`$short_session\` — recorded at \`$(stamp_clock)\`, $minted_note."

    state_write "$day" "$opened" true "$session" "$session_opened" "$session"
    mark_activity
    ;;

  SessionEnd)
    # `clear` and `resume` end a session id, not a working day — §3.1 files one
    # unbroken working session as one daylog, and /clear does not end one.
    case "$reason" in
      clear|resume|compact) done_ok ;;
    esac

    # A day nothing was written into stays unwritten, and a session that filed
    # no open files no close. `logged` is the record of an open line actually
    # reaching the ledger, so keying on it is what makes opens and closes pair
    # exactly. It implies `minted`, so the daylog is known to exist.
    [ "$(state_read '.logged')" = "$session" ] || done_ok

    day=$(state_read '.day')
    [ -n "$day" ] || done_ok
    path=$(daylog_path "$day")
    [ -f "$path" ] || done_ok

    # The span is this session's. `.opened` is the *day's* open and reporting it
    # here is what made every session after the day's first announce a start it
    # never had, under a line that calls itself the true span.
    session_opened=$(state_read '.session_opened')
    [ -n "$session_opened" ] || session_opened=$(state_read '.opened')
    [ -n "$session_opened" ] || done_ok

    open_clock=$(clock_of "$session_opened")
    close_clock=$(stamp_clock)
    span="\`$open_clock → $close_clock\`"
    # Keyed on the date this session began, not on the day the daylog is filed
    # under. A session opened at 23:40 and closed at 00:20 ran past midnight; a
    # session that opened and closed this morning did not, whichever date its
    # session-day carries.
    [ "${session_opened%%T*}" = "$(today)" ] || span="\`$open_clock → $close_clock\` (+1d)"

    line="- \`$close_clock\` — **session closes** · \`$short_session\` (\`${reason:-unknown}\`). True span $span."

    # The premature-seal half. A `## Seal` that was written before this moment
    # described a session that had not ended. Say so, once, without touching it.
    #
    # Match a *filled* seal, never the heading. The vault's own daylog template
    # ships a `## Seal` stub, so every daylog carries that heading from birth —
    # keying on it warned that a seal predated the session on files where no
    # seal had been written at all. A real seal states a span with real clock
    # digits; the stub reads `**Span:** <HH:MM → HH:MM>`, and the `[^<]*` is
    # what keeps the placeholder from counting as one.
    if grep -A6 '^## Seal' "$path" 2>/dev/null |
      grep -qE '\*\*Span:\*\*[^<]*[0-9]{2}:[0-9]{2}'; then
      line="$line
- ⚠ **A \`## Seal\` above was written before this session ended.** Its span is
  not edited here; the true end of the session it was written into is
  \`$close_clock\`. Any work after the seal time is outside what that seal covers."
    fi

    append_ledger "$path" "$line"
    ;;

esac

done_ok
