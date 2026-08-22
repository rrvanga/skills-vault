# Public-vault PII purge (post-leak remediation — proven 2026-08)

Incident: `.curator_backups/2026-08-18T02-15-08Z/cron-jobs.json` (full cron prompts: real
name, Telegram chat ID) was committed and pushed to a public skills mirror. The scrub guard
passed because the pattern list had handles (`<REDACTED>`, `<REDACTED>`) but NOT the user's
real name or numeric chat ID. A second pass found the SAME strings in two skill reference
files — always scan the whole tree for novel shapes, not just the obvious artifact.

## Workflow (in order)

1. **Confirm what's public.** After a sync, local working tree == remote HEAD. Scan the
   working tree first, then the remote: `git fetch origin main` and
   `git grep -lE '<pat1>|<pat2>' FETCH_HEAD -- '*.md' '*.json'` (or no pathspec for ALL blobs).
   Local-only hits are the leak candidates; remote hits are the actual exposure.
2. **Purge whole paths from history** (generated junk dirs):
   `git filter-repo --force --invert-paths --path <dir> --path <file> ...`
   Run it on a clean tree (no uncommitted changes).
3. **Scrub strings from ALL history** (names/IDs that live inside files you keep):
   - Write a map file, one line each: `Name==><REDACTED>` (literal match by default).
   - Capitalization matters: `<REDACTED>==>` must NOT be used if the handle `<REDACTED>` also exists —
     `<REDACTED>` (cap) vs `<REDACTED>` (lowercase inside the handle) are distinct literal strings, so
     the uppercase mapping is safe; verify with per-pattern grep after.
   - `git filter-repo --force --replace-text <map-file>`
4. **Re-attach and rewrite the remote**: filter-repo REMOVES the `origin` remote —
   `git remote add origin <url>` then `git push --force origin main`.
5. **Fix the source (or the next sync re-leaks it):**
   - Extend the scrub pattern list with the novel shapes (real names, platform IDs).
   - Exclude the artifact class at staging rsync (`--exclude '.curator*'` etc.) — generated
     backup dirs inside the mirrored tree are not content.
6. **Verify the REMOTE, not the local tree**: `git fetch origin main` +
   `git grep -lE '<patterns>' FETCH_HEAD` must return ZERO hits (and the file count should be
   unchanged apart from removals). Only a clean REMOTE scan means the purge is done.
7. **Regression-test the scrub properly** (the scrub script is DIRECTORY→DIRECTORY):
   `rsync -a <source-tree>/ /tmp/stage/` → run scrub stage→out → assert
   `grep -rl <patterns> /tmp/out/` is empty → confirm exit 0 (`guard clean`).
   A file-level invocation scans 0/0 files and "guard clean" proves nothing — that
   non-test was the mistake the user caught ("make no mistakes. do better.").

## Commands recap

```bash
git filter-repo --force --invert-paths --path skills/.curator_backups \
    --path skills/.curator_ledger.jsonl --path skills/.curator_state
# map file:  Name==><REDACTED>   per line (literal)
git filter-repo --force --replace-text /tmp/replace.txt
git remote add origin <REDACTED>:<handle>/<repo>.git
git push --force origin main
git fetch origin main && git grep -lE 'Name|<REDACTED>' FETCH_HEAD   # expect: no output
```

## Notes

- `pip install git-filter-repo` when absent.
- filter-repo refuses to run with an existing remote unless `--force`; it then removes the
  remote — always re-add before pushing.
- Force-push to a personal repo is acceptable after a real PII leak; forks/clones of a
  personal skills mirror are rare and the scrub fix protects all future pushes.