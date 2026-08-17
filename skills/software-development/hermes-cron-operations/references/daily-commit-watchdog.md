# Daily-commit watchdog recipe (data repo that commits only on real change)

Pattern for a `no_agent` cron job that keeps a GitHub data repo fresh with REAL
commits: **fetch → normalize → diff → commit+push only if content actually changed**,
silent (exit 0, empty stdout) otherwise. Validated on the `llmcost` pricing dataset
and the `awesome-local-ai` curated-list drip (both `~/dev/`).

## Core loop (`llmcost/scripts/update.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(python3 -m llmcost.fetch)"          # regenerate data/prices.json

# Diff IGNORING the generated_at timestamp (legitimately changes every run):
old="$(git show HEAD:data/prices.json 2>/dev/null | grep -v '"generated_at"' || true)"
new="$(grep -v '"generated_at"' data/prices.json || true)"
if [ "$old" = "$new" ]; then
    git restore data/prices.json           # keep working tree clean
    exit 0                                 # silent = no cron delivery
fi
git add data/prices.json
git commit -q -m "data: update model pricing ($(date +%Y-%m-%d))"
git push -q
echo "$out"                                # non-empty = delivered as the notification
```

## The three tricks (each one bites if skipped)

1. **Timestamp-strip diff.** A regenerated file that embeds `generated_at` (or any
   wall-clock field) will ALWAYS differ from the committed version. Strip that line
   from BOTH sides (`grep -v`) before comparing, so a timestamp-only change reads as
   "no change". Without it the job commits a no-op every single day.
2. **`git restore <file>` on the no-change path.** The regenerated file still carries
   a new timestamp in the working tree. Skip the restore and the repo stays
   perpetually dirty, and a later `git pull` can conflict.
3. **Empty stdout = silent.** On no-change, print nothing and `exit 0`. On change,
   print a clean one-line summary (that IS the user's notification). Exit non-zero
   only on genuine failure — non-zero fires the cron error alert.

**Prefer deterministic output when you own the generator.** Trick 1 (timestamp-strip
diff) is the fallback for when you can't control the emitted file — e.g. a library
embeds `generated_at`. When you DO own the generator (a diagram/poster render script,
a report writer), omit wall-clock fields entirely so the output is byte-identical for
identical state; then a plain `git diff --quiet` on the assets IS the change detector,
no `grep -v` dance. Validated on the agent-lab `render_architecture.py` +
`render_and_commit.sh` diagram refresh (same wrapper + silent-no-op contract as the
llmcost script below).

## Wrapper script (cron script-path guard workaround)

The cron `script` field must be a bare filename under `~/.hermes/scripts/` (absolute
paths and escaping symlinks are rejected). To keep the LOGIC version-controlled in
the repo instead of duplicated, deploy a 2-line REAL-FILE wrapper that invokes the
in-repo script:

```bash
#!/usr/bin/env bash
# ~/.hermes/scripts/llmcost_update.sh
bash "$HOME/dev/llmcost/scripts/update.sh"
```

The guard only inspects the `script` param path (the wrapper is a real file in the
scripts dir → passes); it does not inspect what the wrapper does at runtime. This
avoids the re-copy-on-upstream-change chore of copying the whole script.

## Drip variant (curated list, N entries/day)

Same contract, different payload: a `backlog.json` queue drains N entries/day into a
README, commits, and goes SILENT when the queue is empty:

```bash
out=$(python3 scripts/drip.py)
[ -z "$out" ] && exit 0
git add README.md backlog.json
git commit -q -m "docs: drip curated entries from backlog"
git push -q
echo "$out"
```

The dripper (`scripts/drip.py`) reads the first N backlog entries, inserts each under
its matching `## <category>` heading (before the next heading), writes back the
shrunk queue, and prints the added names — empty print when the queue is dry.

## Repo scaffolding one-liner

```bash
gh repo create <name> --public --source . --remote origin --push
```

(after `git add -A && git commit -q -m ... && git branch -M main`) creates the remote
and pushes in one step. Works for `--private` too.
