# Custom-Layer Decision Gate

**Trigger:** any task that would BUILD or SUSTAIN custom tooling around Hermes — scripts, wrapper layers, automation, cron jobs, retention logic, alternative backup systems, sidecars.

**Why:** 2026-08/09 backup saga. A custom GPG-backup layer was built on top of built-ins that had shipped 4 months earlier (`hermes backup`/`import` 2026-04-11, `--quick` + `/snapshot` 2026-04-13); the false "no backup tooling existed" claim then propagated into docs until the MOA gate caught it via git history. Root cause: absence in skill/docs was treated as absence in the product, with no evidence captured.

**The rule:** absence in this skill is NOT evidence of absence in Hermes. A negative claim ("there's no built-in X") requires captured evidence from the audit below, recorded where the decision is made.

## The four failure moments

1. **Build-time** — custom layer greenlit without an audit (the saga's root cause)
2. **Record-time** — "why custom" narrative repeated unverified claims
3. **Sustain-time** — automation went dormant silently (old cron died, nobody noticed)
4. **Drift-time** — CLI surface changed across releases; snapshots rotted

## Mandatory audit (build-time)

Run ALL steps before proposing or building custom tooling. Capture the output of each check.

1. `hermes --help` — full top-level surface (61 commands, v0.21.0)
2. `hermes <candidate> --help` — subcommand help for anything plausibly related (backup, checkpoints, import, sessions, cron, sync, hooks, security…)  
3. `skills_list` / `hermes skills list` — existing skills for the task area
4. Official docs: https://hermes-agent.nousresearch.com/docs/
5. `search_files` in `~/.hermes/hermes-agent` source for feature names — source is the ultimate truth
6. `hermes doctor` + `hermes status` — built-in health/status tooling (know what exists before writing your own)
7. If a feature looks absent: `git log --diff-filter=A -- <file>` in the upstream checkout to confirm it NEVER existed (see moa-gate skill — verify product-history claims)

## Decision ladder

**Built-in > thin wrapper around built-in > custom layer.**
- If a built-in exists: use it. 
- If built-in is close but retention/format/retry needs tuning: a THIN wrapper is acceptable — 
  - but re-check built-in options first (`--help`; e.g. `_QUICK_DEFAULT_KEEP`/prune semantics in source — a prune flag may already exist)
  - and record WHY the wrapper is needed (missing flag, wrong retention, wrong delivery)
- Custom layer only when the above are exhausted — and the audit evidence MUST be recorded in the issue/plan/PR.

## Evidence recording (record-time)

Wherever the decision lives (issue, plan, PR description, docs note), write:
- The commands run (step list) and the captured output proving absence
- The built-ins considered and why each was rejected (missing flag/behavior, not "doesn't exist")
- The exact gap the custom layer fills

A claim like "no built-in X exists" with no `--help`/source evidence = review blocker (MOA gate enforces this).

## Sustain-time (dormancy prevention)

User preference (2026-09-05): cron MONITORS are SILENT ON SUCCESS — empty stdout on the happy path, clear message + non-zero exit on failure. Deliverable/report jobs keep reporting. Dormancy detection (a job silently not running) is centralized in `~/.hermes/scripts/cron_sentinel.py`, scheduled as a cron job: it runs the built-in `hermes cron doctor` (failed runs, overdue `next_run_at`, delivery/config issues) and diffs live job ids against a baseline file (`~/.hermes/cron/.cron-sentinel-baseline.json`) to catch jobs REMOVED from the schedule; it prints ONLY anomalies and exits 1 (alert), silently exits 0 otherwise. NOTE: `hermes cron doctor` ALWAYS exits 0 — findings appear only in stdout; gate on output content, never on return code.

## Drift-time (refresh)

- `references/cli-surface.md` is a version snapshot — after ANY `hermes update`, regenerate it: `hermes --help` (and note the new version in the header).
- Re-run step 7 of this gate whenever a "missing" feature is a premise of new work.

## Worked example (the saga, annotated)

| Audit step | What it would have surfaced 2026-08-13 |
|---|---|
| 1. `hermes --help` | `backup`, `checkpoints`, `import` commands present |
| 5. source grep | `hermes_cli/backup.py`, `_QUICK_DEFAULT_KEEP`, `/snapshot` |
| 7. git history | `fa7cd44b92` (2026-04-11), `381810ad50` (2026-04-13) |
