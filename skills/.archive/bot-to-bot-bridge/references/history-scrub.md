# Git history scrub — squash-to-one + verify (verified 2026-08-16)

Use when a repo (e.g. bot-bridge) leaks bot IDs, usernames, human handles, or
names in commit messages, and the user wants ALL of it gone, history included.

## What to scrub vs. keep

- **Scrub**: numeric bot IDs, @usernames, human collaborator handles, real host
  paths (e.g. `~/.hermes/bridge-repo`), human names inside message bodies.
- **Keep**: wire-protocol identity values (`from`/`to` keys, outbox dir names,
  `BRIDGE_NAME`). Both bots' RUNNING clients use them; removing them breaks the
  live queue until both hosts update in coordination. Propose that as a
  follow-up, don't bundle it into the scrub.

## Recipe

1. **Re-check repo state first.** The 2-min bridge cron can fire mid-work and
   push a new commit (happened: "bridge 0004" landed while inspecting).
   Compare `git rev-parse HEAD origin/main` and `git log --oneline -8` with
   what you saw earlier before rewriting anything.
2. **Sanitize the tree** (write_file/patch): README.md, SECURITY.md, outbox
   JSON bodies (keep `id/from/to/ts/kind` untouched — the queue depends on
   them; sanitize only the `body` text), code docstrings.
3. **Verify tree clean BEFORE squashing**:
   `grep -rnE "ID1|ID2|@handle|human" --include="*.md" --include="*.py" --include="*.json" .`
   Expect protocol-name hits only in bridge.py (intentional).
4. **Squash to one commit** (orphan-branch technique):
   ```bash
   git checkout --orphan scrubbed
   git add -A
   git commit -m "<scrub message>"
   git branch -D main          # old history now dangling locally
   git branch -m scrubbed main
   git push -f origin main
   ```
5. **Commit-comment hygiene**: the new commit message and any gh comment must
   DESCRIBE the scrub WITHOUT reproducing the IDs/usernames — repeating them
   re-leaks them into the new permanent history.
6. **Post a comment on the commit** (audit note, also ID-free):
   `gh api repos/<org>/<repo>/commits/<SHA>/comments -f body="..." --jq '.id'`
7. **Verify from a fresh clone** (never trust local state):
   ```bash
   rm -rf /tmp/verify && git clone -q <url> /tmp/verify && cd /tmp/verify
   git log --oneline          # expect exactly 1 commit
   git rev-list --all --count # expect 1
   git log --all -p | grep -nE "ID1|ID2|@handle|human" || echo "CLEAN"
   grep -rnE "ID1|ID2|human" . --include="*" | grep -v "^\./\.git" || echo "CLEAN"
   ```

## Pitfalls

- **`git log --all` still shows the old commits after the local squash** — they
  remain reachable via `origin/main` until the force-push replaces that ref.
  Expected, not a failure; verify AFTER push.
- **Old commit messages are part of the leak** — `bridge NNNN -> dvipru`,
  `test msg from dvipru` etc. are killed only by the squash, never by a scrub
  commit alone.
- **Peer side diverges**: after the force-push, the peer's clone holds orphaned
  history and their next push is rejected (non-fast-forward). They need
  `git fetch origin && git reset --hard origin/main`. Local per-host state
  (`.seen_id`, gitignored) survives fine.
- **History rewrite is a one-off correction, not routine** — force-push is
  destructive; get the tree right and verify before pushing.
- Force-push from an HTTPS remote may prompt for approval in Hermes — that is
  the expected safety gate, not a failure.
