#!/usr/bin/env bash
# main-branch-guard — the local half of the PR floor.
#
# A PreToolUse hook on Bash. Refuses a `git commit` or `git push` that would
# land directly on a repo's default branch, so an agent has to branch and open
# a PR. Remote branch protection catches the same mistake, but only at push
# time and only on the repos where it is configured; this catches it before the
# commit exists, in every repo on this machine.
#
# It binds Claude sessions only — commands you type in your own terminal never
# reach a PreToolUse hook. That is deliberate: the hook is the floor under
# agents, `enforce_admins: true` on the remote is the floor under you.
#
# Guarded by default. Repos that commit to their default branch *by design* —
# the vault, the journals — are listed in EXEMPT below. A new repo is guarded
# from birth, seed commit included: `git init -b main` then commit is refused,
# and the way through is `git checkout -b <branch>` before the seed. If it turns
# out to be a straight-to-main repo, it trips the hook once and you add a line
# here. That ordering is the point: an opt-in list silently leaves every future
# repo unguarded.
#
# Fails open. If it cannot tell what repo it is in or what the default branch
# is, it allows — a guard that blocks on its own confusion gets switched off.
# It reads one Bash command string, so it parses per shell segment rather than
# per line: a bare `main` in an unrelated `echo` is not a push target, and a
# `push` chained behind a `commit` is still a push.
#
# hooks/main-branch-guard.test.sh covers both halves. Run it after any edit.

set -u

# Repos whose default branch is the working branch by design. Absolute paths,
# matched against the repo toplevel.
EXEMPT="
/Users/amet/Dev/notes
/Users/amet/Dev/accumulus
/Users/amet/Dev/vitanauta
/Users/amet/Running
/Users/amet/Writing/conscium
"

allow() { exit 0; }

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Cheapest possible exit for the overwhelming majority of Bash calls.
case "$cmd" in
  *git*) ;;
  *) allow ;;
esac
case "$cmd" in
  *commit*|*push*) ;;
  *) allow ;;
esac

# Where would this run? Honour a leading `cd <dir> &&` and an explicit
# `git -C <dir>`; otherwise the hook's own cwd is the session's.
dir=$PWD
case "$cmd" in
  cd\ *)
    cd_target=$(printf '%s' "$cmd" | sed -n 's/^cd  *\([^;&|]*\).*/\1/p' | sed 's/ *$//')
    [ -n "$cd_target" ] && dir=$(eval printf '%s' "$cd_target" 2>/dev/null || printf '%s' "$cd_target")
    ;;
esac
case "$cmd" in
  *git\ -C\ *)
    c_target=$(printf '%s' "$cmd" | sed -n 's/.*git  *-C  *\([^ ]*\).*/\1/p')
    [ -n "$c_target" ] && dir=$c_target
    ;;
esac

toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || allow
[ -n "$toplevel" ] || allow

for e in $EXEMPT; do
  [ "$toplevel" = "$e" ] && allow
done

# The default branch: what origin points at, else whichever of main/master
# actually exists.
default=$(git -C "$toplevel" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
default=${default#origin/}
if [ -z "$default" ]; then
  for candidate in main master; do
    if git -C "$toplevel" show-ref --verify --quiet "refs/heads/$candidate"; then
      default=$candidate
      break
    fi
  done
fi
# An unborn branch has no ref yet, so both probes above miss and a brand-new
# repo used to fail open on its very first commit — guarded from its *second*,
# not from birth.
#
# Careful here: before the first commit, the branch HEAD names is necessarily
# both `current` and the only candidate for `default`, so accepting it whole
# refuses the seed commit of *every* new repo — and `checkout -b` is no escape,
# because on an unborn branch it only renames HEAD. So take it as the default
# only when it actually looks like one. `git init -b main` is then guarded from
# birth, with `git checkout -b <branch>` as the honest way through, while
# `git init -b seed` is left alone.
if [ -z "$default" ] && ! git -C "$toplevel" rev-parse --quiet --verify HEAD >/dev/null 2>&1; then
  unborn=$(git -C "$toplevel" symbolic-ref --quiet --short HEAD 2>/dev/null)
  configured=$(git -C "$toplevel" config --get init.defaultBranch 2>/dev/null)
  case "$unborn" in
    main|master) default=$unborn ;;
    "") ;;
    *) [ "$unborn" = "$configured" ] && default=$unborn ;;
  esac
fi
[ -n "$default" ] || allow

# `rev-parse --abbrev-ref HEAD` errors on an unborn branch; `symbolic-ref` is
# correct there and on any normal branch. Fall back only for detached HEAD,
# where symbolic-ref is the one that fails.
current=$(git -C "$toplevel" symbolic-ref --quiet --short HEAD 2>/dev/null)
[ -n "$current" ] || current=$(git -C "$toplevel" rev-parse --abbrev-ref HEAD 2>/dev/null)

repo=$(basename "$toplevel")

# Evaluate each shell segment on its own. Reading the whole line as a single
# invocation caused three separate defects: a bare `main` in an unrelated `echo`
# read as a push target and refused correct work; `push origin main; git status`
# parsed its refspec as `main;` and was allowed through; and `commit && push
# origin main` stopped at the first verb, so the push was never examined at all.
# Splitting first makes each of those the same fix.
#
# The split tracks quoting and heredocs, and this is the one place the hook does
# buy some parsing. It used to split on `;&|` blind, on the reasoning that a
# separator inside a quoted string only ever yields an extra fragment to check,
# never a missed one. True, and it understated the cost: the extra fragment is
# harmless only when the command really is git. `gh issue create --body "... &&
# git commit ..."` splits into a fragment that *is* a git commit as far as the
# guard can see, and the guard refuses a command that touches no repository at
# all — which is how this was found, by being unable to file the issue about it.
#
# Requiring the fragment to begin with git is not enough on its own: the
# fragment after the quoted `&&` above begins with git too. Quote state is the
# only thing that distinguishes an argument from a command, so it is tracked.
# Heredoc bodies are skipped whole for the same reason, since a body is data.
# Both are still approximations of a shell, and both fail in the safe direction
# here: an unbalanced quote leaves the rest of the string unsplit, so it lands
# in one fragment that does not begin with git and is skipped, which is the
# same fail-open posture as the rest of the hook.
segments=$(printf '%s' "$cmd" | awk '
  BEGIN { q = ""; hd = ""; pending = ""; seg = "" }
  {
    line = $0
    if (hd != "") {                       # a heredoc body is data, not commands
      s = line; sub(/^[ \t]*/, "", s)
      if (s == hd) hd = ""
      next
    }
    n = length(line)
    for (i = 1; i <= n; i++) {
      c = substr(line, i, 1)
      if (q != "") { if (c == q) q = ""; seg = seg c; continue }
      if (c == "\047" || c == "\"") { q = c; seg = seg c; continue }
      if (c == "<" && substr(line, i + 1, 1) == "<") {
        rest = substr(line, i + 2)
        if (match(rest, /^-?[ \t]*(\047[^\047]+\047|"[^"]+"|[A-Za-z_][A-Za-z0-9_]*)/)) {
          w = substr(rest, RSTART, RLENGTH)
          sub(/^-?[ \t]*/, "", w); gsub(/[\047"]/, "", w)
          pending = w
        }
        seg = seg c; continue
      }
      if (c == ";" || c == "&" || c == "|") { print seg; seg = ""; continue }
      seg = seg c
    }
    # A newline ends a command too, but only outside a quoted string.
    if (q == "") { print seg; seg = "" } else { seg = seg "\n" }
    if (pending != "") { hd = pending; pending = "" }
  }
  END { if (seg != "") print seg }
')

# A branch-creating verb seen earlier in this same command string. `git switch
# -c x && git commit` was refused by a message telling you to run `git switch
# -c`, because `current` is resolved once from live HEAD before any of this runs
# and the loop had no model of a command that moves HEAD partway through.
#
# Only the verbs that create *and* move HEAD in one step count. That is what
# makes this safe rather than a hole: git refuses to create a branch that
# already exists, so a branch born here is necessarily not the default one, and
# a commit after it cannot be a commit to the default branch. A bare `git switch
# <existing>` gets no such guarantee — the existing branch could be `main` — so
# it does not count, and `git branch x && git switch x && git commit` is still
# refused. Order matters and comes for free: the flag is read in segment order,
# so `git commit && git switch -c x` is refused exactly as before.
branched=no

while IFS= read -r seg; do
  # Strip leading whitespace, then step over any `VAR=value` prefix. What is
  # left has to *begin* with git: merely containing it is what let prose about
  # git in some other command's argument read as a git invocation.
  seg=${seg#"${seg%%[![:space:]]*}"}
  while :; do
    first=${seg%%[[:space:]]*}
    case "$first" in
      [A-Za-z_]*=*) ;;
      *) break ;;
    esac
    rest=${seg#*[[:space:]]}
    [ "$rest" = "$seg" ] && break
    seg=${rest#"${rest%%[![:space:]]*}"}
  done
  case "$seg" in
    git\ *) ;;
    *) continue ;;
  esac

  git_part=${seg#git }

  verb=""
  for word in $git_part; do
    case "$word" in
      -*) continue ;;
      -C) continue ;;
      switch|checkout) verb=$word; break ;;
      commit) verb=commit; break ;;
      push) verb=push; break ;;
      *) continue ;;
    esac
  done

  case "$verb" in
    switch|checkout)
      after=${git_part#*"$verb"}
      for word in $after; do
        case "$word" in
          -c|-C|-b|-B|--create|--force-create) branched=yes; break ;;
          -*) continue ;;
          *) break ;;
        esac
      done
      continue
      ;;
  esac

  if [ "$verb" = "commit" ] && [ "$current" = "$default" ] && [ "$branched" = no ]; then
    deny "Refusing: this would commit straight to '$default' in $repo.

Branch first: 'git switch -c <branch>', then commit, push, and open a PR.
Direct commits to a default branch are the failure this floor exists to catch;
the remote would only refuse it later, at push time.

'git switch -c <branch> && git commit ...' in one command is allowed. Switching
to a branch that already exists is not, since this hook cannot tell that branch
from '$default'; run that switch as its own command first.

If $repo is a repo that works on its default branch by design, add its path to
EXEMPT in ~/Dev/skills/hooks/main-branch-guard.sh rather than working around
this."
  fi

  if [ "$verb" = "push" ]; then
    # Everything after `push` in *this segment*, minus flags: [remote] [refspec...]
    after=${git_part#*push}
    remote=""
    targets=""
    for word in $after; do
      case "$word" in
        -*) continue ;;
      esac
      if [ -z "$remote" ]; then
        remote=$word
      else
        targets="$targets $word"
      fi
    done

    # No refspec named: git pushes the current branch.
    if [ -z "$targets" ]; then
      targets=$current
    fi

    for t in $targets; do
      dest=${t#+}
      case "$dest" in
        *:*) dest=${dest#*:} ;;
      esac
      dest=${dest#refs/heads/}
      if [ "$dest" = "$default" ]; then
        deny "Refusing: this would push directly to '$default' in $repo.

Push your branch instead and open a PR: 'git push -u origin <branch>' then
'gh pr create'. A PR is the floor; on the protected repos the remote refuses
this too, and this hook catches it on the ones where it would not.

If $repo works on its default branch by design, add its path to EXEMPT in
~/Dev/skills/hooks/main-branch-guard.sh."
      fi
    done
  fi
done <<SEGMENTS
$segments
SEGMENTS

allow
