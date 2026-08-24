---
name: branch-prune
description: >-
  Prune every local and remote branch whose work has landed, keeping the default
  branch, and refusing on a dirty tree, an open PR, a live worktree, or unmerged
  commits. Use on "prune branches", "clean up branches", "delete merged
  branches".
---

# branch-prune

The front door to a clean branch list, for the current repo only. Run it as
**@tux**, the only writer of git state.

This is a skill rather than the one-liner it looks like, because
`git branch --merged | xargs git branch -d` is blind to the four things that
actually decide whether a branch is disposable: an open PR, a squash-merge, a
live worktree, and commits that exist nowhere else.

1. **Refuse, then fetch.** Stop and report, deleting nothing, when
   `git status --porcelain` is non-empty. Pruning moves `HEAD` to the default
   branch, and a dirty tree makes that move lossy. Name the dirty paths. Then
   `git fetch --prune` so the remote-tracking refs are not stale evidence.
   Resolve the default branch (`git symbolic-ref refs/remotes/origin/HEAD`);
   never assume it is `main`.
2. **Classify every branch.** Each one lands in exactly one bucket:
   - **merged**: appears in `git branch --merged <default>`. Disposable.
   - **squash-merged**: not an ancestor, but `gh pr list --state merged --head
     <branch>` returns a PR. Disposable, and the **common case here**. A
     squash-merge leaves no ancestry, so `--merged` alone would keep these
     forever.
   - **open PR**: `gh pr list --state open --head <branch>` is non-empty. Keep.
   - **live worktree**: checked out per `git worktree list`. Keep; deleting it
     breaks that worktree.
   - **unique work**: unmerged, no PR, and `git log <default>..<branch>` has
     commits. Keep, and print the commit subjects. This is the only bucket where
     deletion destroys something, so the human decides per branch.
3. **Delete the two disposable buckets.** Local: `git branch -d`. Plain `-d`, so
   git's own refusal is a second floor under the classification. Reach for `-D`
   only against an explicit ack for a named branch. Remote:
   `git push origin --delete` for the same set, **confirmed separately**. It
   publishes, and it is the half no local reflog can undo.
4. **Report the ledger**: one line per branch, deleted or kept with its bucket
   as the reason.

**Done means:** `git branch` lists the default branch plus exactly the branches
this run named a keep-reason for, and every deletion was printed before it ran.

Filing: none. The branch list is the artifact.
