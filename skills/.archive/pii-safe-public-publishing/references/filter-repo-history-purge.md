# Full-history PII containment (git filter-repo)

Proven 2026-08-21 scrubbing `<REDACTED>/skills-vault` after a two-part leak: curator-backup
JSON (names + Telegram chat ID) already removed by history purge, plus real name + chat ID
still live in TWO skill reference files pushed by an older (weaker) scrub pattern. The
local worktree was clean; the REMOTE blobs still carried the strings.

## The invalid-test trap (what bit us first)

A "verification" that stages ONE file and runs the directory-level scrub scans 0/0 files
and reports success — worthless, and worse, it produces confident-sounding output. The
scrub operates on a directory tree; the test must replicate that: copy the whole tree to a
staging dir, scrub, then grep BOTH the staging copy AND the remote refs.

Second trap: `git grep PATTERN origin/main | head -3; echo $?` — `$?` is `head`'s exit
(always 0). The EVIDENCE is the absence of printed match lines, not the exit code. Capture
`git grep` into a variable/file and count matches, or just trust "no lines printed".

## Recipe

```bash
# 1. Verify the FIX list is complete before touching the repo: grep for candidate
#    patterns (names, chat IDs, handles) across the pushed content — not just the
#    patterns you already scrubbed for.
cd repo && git grep -iE 'FirstName|Surname|12345678' origin/main -- '*.md' '*.json'

# 2. Replace-text mapping file (/tmp/vault-replace.txt):
#    <REDACTED>==><REDACTED>
#    <REDACTED>==><REDACTED>
#    <REDACTED>==><REDACTED>
#    filter-repo --replace-text matches LITERAL strings by default. Capitalize exactly
#    as it appears — a lowercase '<REDACTED>' inside the public handle '<REDACTED>' must NOT
#    match, so never use case-insensitive/regex broad strokes on identifiers.

# 3. Rewrite ALL history (rewrites every blob/commit containing the strings):
cd repo && git filter-repo --force --replace-text /tmp/vault-replace.txt
#    filter-repo removes the origin remote afterwards — expected, not an error.

# 4. Re-push:
git remote add origin https://github.com/<user>/<repo>.git
git push --force origin main

# 5. VERIFY AGAINST THE REMOTE REF, not the working tree:
git ls-tree -r origin/main --name-only | grep -c curator     # 0 = hidden dirs gone
git grep -iE 'FirstName|Surname|12345678' origin/main -- '*.md' '*.json' '*.sh'
#    Zero printed lines = clean. Working-tree grep is NOT proof.
```

## Lessons

- Purge the obvious source first, then re-scan with fresh eyes: the second (hidden) leak
  location existed all along but only surfaced when the sync-pattern list grew to include
  real names and the scan covered the whole tree.
- After filter-repo, a normal commit + push continues to work; the daily sync's scrub
  (now with extended patterns) converges the local source to the rewritten history.
- Source of truth (the private tree) KEEPS the real names; only the public mirror is
  scrubbed — local-first, zero-exposure.
- Verify tool-output claims you quote: collapsed one-line results are not evidence.
  Re-run narrowly until the output is readable, then report it.