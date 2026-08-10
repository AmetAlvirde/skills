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
# Fails open, always. Every path exits 0. A hook that can wedge a session gets
# switched off, and a daylog is a record, not a floor — losing a line is a far
# cheaper failure than losing the ability to work. Where it cannot act it says
# so on stderr and gets out of the way.
#
# hooks/daylog-trigger.test.sh covers all three events. Run it after any edit.

set -u

VAULT=${DAYLOG_VAULT:-$HOME/Dev/notes}
STATE=${DAYLOG_STATE:-$HOME/.claude/state/daylog-session.json}
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
# last_activity is the state file's mtime rather than a JSON field, so the hot
# path (PostToolUse on an already-minted day) is one touch instead of a jq
# rewrite. PostToolUse fires on every edit; it has to stay nearly free.
state_dir=$(dirname "$STATE")

state_read() { # state_read <jq-path> -> value or empty
  [ -f "$STATE" ] || return 0
  jq -r "$1 // empty" "$STATE" 2>/dev/null
}

state_mtime() {
  [ -f "$STATE" ] || { echo 0; return; }
  # BSD stat (macOS) and GNU stat (the CI runner) disagree on flags.
  stat -f %m "$STATE" 2>/dev/null || stat -c %Y "$STATE" 2>/dev/null || echo 0
}

state_write() { # state_write <day> <opened> <minted>
  mkdir -p "$state_dir" 2>/dev/null || { note "cannot create $state_dir"; return 1; }
  jq -n --arg day "$1" --arg opened "$2" --argjson minted "$3" \
    '{day: $day, opened: $opened, minted: $minted}' >"$STATE.tmp" 2>/dev/null &&
    mv "$STATE.tmp" "$STATE" 2>/dev/null
}

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
      state_write "$(today)" "$(stamp_full)" false || done_ok
    else
      # Continuing an open session-day: refresh mtime without disturbing the
      # recorded start or the minted flag.
      touch "$STATE" 2>/dev/null
    fi
    ;;

  PostToolUse)
    is_authoring "$tool" "$cmd" || done_ok

    # Hot path: the day is already open and already recorded. grep rather than
    # jq, so the common case is one cheap read and a touch.
    grep -q '"minted": *true' "$STATE" 2>/dev/null &&
      { touch "$STATE" 2>/dev/null; done_ok; }

    # A PostToolUse can arrive with no SessionStart behind it — a hook installed
    # mid-session, or a state file wiped. Open the day here rather than skip it.
    day=$(state_read '.day')
    opened=$(state_read '.opened')
    if [ -z "$day" ] || is_new_day; then
      day=$(today)
      opened=$(stamp_full)
    fi
    [ -n "$opened" ] || opened=$(stamp_full)

    path=$(daylog_path "$day")
    existed=yes
    [ -f "$path" ] || existed=no
    mint "$path" "$day" || { note "could not mint $path"; done_ok; }

    opened_clock=${opened#*T}
    opened_clock=${opened_clock%%[+-]*}
    if [ "$existed" = no ]; then
      minted_note="minted by this session's first authoring action"
    else
      minted_note="appended to a daylog that already existed"
    fi
    append_ledger "$path" \
      "- \`$opened_clock\` — **session opens** · \`$short_session\` — recorded at \`$(stamp_clock)\`, $minted_note."

    state_write "$day" "$opened" true
    ;;

  SessionEnd)
    # `clear` and `resume` end a session id, not a working day — §3.1 files one
    # unbroken working session as one daylog, and /clear does not end one.
    case "$reason" in
      clear|resume|compact) touch "$STATE" 2>/dev/null; done_ok ;;
    esac

    # A day nothing was written into stays unwritten. Closing a session that
    # never authored anything must not mint a daylog on the way out.
    [ "$(state_read '.minted')" = "true" ] || done_ok

    day=$(state_read '.day')
    opened=$(state_read '.opened')
    [ -n "$day" ] || done_ok
    path=$(daylog_path "$day")
    [ -f "$path" ] || done_ok

    opened_clock=${opened#*T}
    opened_clock=${opened_clock%%[+-]*}
    close_clock=$(stamp_clock)
    span="\`$opened_clock → $close_clock\`"
    [ "$day" = "$(today)" ] || span="\`$opened_clock → $close_clock\` (+1d)"

    line="- \`$close_clock\` — **session closes** · \`$short_session\` (\`${reason:-unknown}\`). True span $span."

    # The premature-seal half. A `## Seal` that was written before this moment
    # described a session that had not ended. Say so, once, without touching it.
    if grep -q '^## Seal' "$path" 2>/dev/null; then
      line="$line
- ⚠ **A \`## Seal\` above was written before this session ended.** Its span is
  not edited here; the true end of the session it was written into is
  \`$close_clock\`. Any work after the seal time is outside what that seal covers."
    fi

    append_ledger "$path" "$line"
    touch "$STATE" 2>/dev/null
    ;;

esac

done_ok
