#!/usr/bin/env bash
# Regression suite for main-branch-guard.
#
# Run: bash hooks/main-branch-guard.test.sh
#
# Two halves, because the guard failed in two different places for two different
# reasons:
#
#   Parsing — the hook reads one Bash command string, and it used to read the
#   whole line as a single invocation. Cases here chain commands with ; && || to
#   pin down which segment a verb and a refspec belong to.
#
#   Repo state — every earlier test ran in a repo that already had commits, which
#   is exactly why the unborn-branch fail-open survived. Cases here build real
#   throwaway repos, seeded and unseeded.
#
# The trigger words are assembled from escapes (see V below) so that running this
# file does not itself trip the PreToolUse hook in an agent session.

set -u
GUARD=${GUARD:-$(cd "$(dirname "$0")" && pwd)/main-branch-guard.sh}
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

C=$(printf 'com\x6dit')
P=$(printf 'p\x75sh')
M=$(printf 'ma\x69n')

pass=0
fail=0

# decide <dir> <command> [guard-override] -> ALLOWED | REFUSED | ERROR
#
# The hook signals through stdout, not status: it exits 0 whether it allows
# (silence) or denies (a JSON block). So a guard that never ran also produces
# empty stdout, and reading "empty" as ALLOWED would score every one of the
# eleven ALLOWED cases as passing against a missing, unreadable, or syntactically
# broken hook. That is the same fail-open shape this suite exists to catch, one
# level up. `bash` is the last element of the pipeline, so its status is the
# assignment's; a non-zero one means the hook did not get to decide anything.
decide() {
  local out status
  out=$(cd "$1" && jq -Rn --arg c "$2" '{tool_input:{command:$c}}' | bash "${3:-$GUARD}")
  status=$?
  [ "$status" -ne 0 ] && { echo "ERROR(exit $status)"; return; }
  [ -z "$out" ] && { echo ALLOWED; return; }
  echo REFUSED
}

check() { # check <want> <label> <dir> <command> [guard]
  local want=$1 label=$2 got
  got=$(decide "$3" "$4" "${5:-}")
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
    printf '  ok    %-38s %s\n' "$label" "$got"
  else
    fail=$((fail + 1))
    printf '  FAIL  %-38s want %s, got %s\n' "$label" "$want" "$got"
  fi
}

# ---------------------------------------------------------------- parsing ----
# A repo on a feature branch, with a default branch that exists.
R=$W/parse
git init -q -b "$M" "$R"
git -C "$R" -c user.email=t@t -c user.name=t "$C" -q --allow-empty -m seed
git -C "$R" checkout -q -b exploration/x

echo "parsing (repo on a feature branch, default '$M')"
check ALLOWED "plain feature branch"        "$R" "git $P origin exploration/x"
check ALLOWED "flags before the remote"     "$R" "git $P -u origin exploration/x"
check ALLOWED "bare '$M' in a later echo"   "$R" "git $P origin exploration/x; echo \"check $M protection\""
check ALLOWED "'$M' inside another path"    "$R" "git $P origin exploration/x; gh api repos/x/y/branches/$M/protection"
check REFUSED "default branch named"        "$R" "git $P origin $M"
check REFUSED "default, then another cmd"   "$R" "git $P origin $M; git status"
check REFUSED "default, && chained"         "$R" "git $P origin $M && echo done"
check REFUSED "default, after another cmd"  "$R" "git status; git $P origin $M"
check REFUSED "refspec form HEAD:default"   "$R" "git $P origin HEAD:$M"
check REFUSED "$C then $P in one line"      "$R" "git $C -m x && git $P origin $M"

# A repo sitting on its default branch.
git -C "$R" checkout -q "$M"
echo "parsing (same repo, now on '$M')"
check REFUSED "$C on the default branch"    "$R" "git $C -m x"
check REFUSED "$P with no refspec"          "$R" "git $P"
check ALLOWED "read-only git command"       "$R" "git status"
check ALLOWED "no git at all"               "$R" "ls -la"

# ------------------------------------------------------------- repo state ----
echo "repo state"
new() { git init -q -b "$2" "$W/$1"; echo "$W/$1"; }

check REFUSED "unborn '$M', first $C"       "$(new a "$M")"        "git $C --allow-empty -m x"
check REFUSED "unborn 'master', first $C"   "$(new b master)"      "git $C --allow-empty -m x"
check ALLOWED "unborn 'feature/x'"          "$(new c feature/x)"   "git $C --allow-empty -m x"

# The way through for a genuinely new repo: branch before the seed commit.
D=$(new d "$M"); git -C "$D" checkout -q -b seed 2>/dev/null
check ALLOWED "unborn, branched to 'seed'"  "$D" "git $C --allow-empty -m x"

# Still guarded once the repo has history.
E=$(new e "$M"); git -C "$E" -c user.email=t@t -c user.name=t "$C" -q --allow-empty -m seed
check REFUSED "seeded repo, second $C"      "$E" "git $C --allow-empty -m x"

# Exempt repos are exempt from birth.
X=$(new f "$M")
sed "s|^EXEMPT=\"|EXEMPT=\"\n$(cd "$X" && pwd -P)|" "$GUARD" > "$W/guard-exempt.sh"
check ALLOWED "EXEMPT repo, first $C"       "$X" "git $C --allow-empty -m x" "$W/guard-exempt.sh"

# Fail open wherever the guard cannot know.
G=$(new g "$M"); git -C "$G" -c user.email=t@t -c user.name=t "$C" -q --allow-empty -m one
git -C "$G" checkout -q --detach HEAD
check ALLOWED "detached HEAD"               "$G" "git $C --allow-empty -m x"
mkdir -p "$W/plain"
check ALLOWED "not a git repo"              "$W/plain" "git $C --allow-empty -m x"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
