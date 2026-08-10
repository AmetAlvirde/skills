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
# This is not shell parsing — a separator inside a quoted string splits too. That
# only ever produces an extra fragment to check, never a missed one, and real
# parsing is not worth its weight in a hook that must stay fast and fail open.
segments=$(printf '%s' "$cmd" | tr ';&|' '\n\n\n')

while IFS= read -r seg; do
  case "$seg" in
    *git\ *) ;;
    *) continue ;;
  esac

  git_part=${seg#*git }

  verb=""
  for word in $git_part; do
    case "$word" in
      -*) continue ;;
      -C) continue ;;
      commit) verb=commit; break ;;
      push) verb=push; break ;;
      *) continue ;;
    esac
  done

  if [ "$verb" = "commit" ] && [ "$current" = "$default" ]; then
    deny "Refusing: this would commit straight to '$default' in $repo.

Branch first — 'git switch -c <branch>' — then commit, push, and open a PR.
Direct commits to a default branch are the failure this floor exists to catch;
the remote would only refuse it later, at push time.

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

Push your branch instead and open a PR — 'git push -u origin <branch>' then
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
