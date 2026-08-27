---
name: removing-agent-automation
description: Use when removing agent automation completely, reversibly.
---

# Removing agent automation (completely + reversibly)

User phrasing that triggers this: "drop X completely", "remove the checkers", "kill the watchers", "get rid of Y", "I don't want that anymore".

## Doctrine
- **Hunt first, remove second.** Enumerate every home of the artifact before touching anything. A partial teardown leaves orphaned cron refs, dead skill pointers in memory, or parked kanban cards that resurrect the work later.
- **Reversible only** — user rule: `gio trash`, NEVER `rm`. For skills: trash the whole skill directory — it drops from the registry AND stays recoverable in `~/.local/share/Trash/files/`. Do NOT use `skill_manage delete` (irreversible).
- **Verify after**: registry, board, filesystem, trash — then report.

## 1. Enumerate (batch independent checks in parallel)
- `cronjob action=list` — current jobs.
- `~/.hermes/cron/jobs.json` — grep for the artifact name and skill refs. CRITICAL: cron *output* files (`cron/output/<id>/`) may mention a name without any job loading it — only job definitions matter. Don't chase ghosts.
- `search_files` content across `~/.hermes` (config.yaml, scripts/) for the artifact name.
- Filesystem sweep via terminal `find` — see pitfall #1 about glob vs regex.
- `hermes kanban list` — parked follow-up cards referencing the artifact (e.g. "refresh price anchors").
- Memory entries pointing at the artifact (skill names, file paths) — they go stale when the artifact dies.

## 2. Check for lookalikes
Verify what a file actually IS before trashing. Example: `~/dev/llmcost/data/prices.json` matched a hardware-price sweep but is LLM API pricing for an unrelated tool — distinct purpose = leave it alone.

## 3. Remove
- Files/dirs: `gio trash <path>` (directories work fine).
- Kanban cards: `hermes kanban archive <task_id>` — off the active board, preserved in archive (not deleted).
- Cron jobs: `cronjob action=remove` — list first, never guess job IDs.
- config.yaml: leave disabled-skill list entries alone — a disabled name with no directory is a harmless no-op. Never hand-edit config.yaml (user rule: `hermes config set` only).

## 4. Clean memory
Trim/replace memory entries referencing deleted artifacts (dead skill pointers, stale paths). Keep genuinely useful techniques (e.g. an API workaround), drop the pointer to the gone skill. If the user said "completely", record the drop decision so nothing resurrects it.

## 5. Verify (all cheap, all parallel)
- `skills_list` — skill gone from registry.
- `hermes kanban list` — no matching active cards.
- `ls ~/.local/share/Trash/files/` — artifacts present and restorable.
- Filesystem sweep again — only your own temp scripts should remain.
- Then trash your own temp scripts/cache files too (leave no surprises).

Worked example with the full artifact map: `references/price-checker-teardown-2026-08.md`.

## Pitfalls
1. **`search_files` `target=files` takes a GLOB, not a regex** — a regex pattern (`price|deals|bestbuy`) silently returns 0 results. Use terminal `find` for regex-ish sweeps.
2. **Multi-line terminal output may arrive compressed** ("1 lines output") in tool results. `tee` to a cache file, then `read_file` it. This environment: write the sweep as a `write_file` script, run via `bash` (heredocs/long cmds blocked).
3. **`skill_view` on a disabled skill errors** — inspect the directory on disk instead (`ls -laR`).
4. **jobs.json grep is the truth test**: old cron *output* files referencing a name ≠ active dependents.

## Related
- hermes-cron-operations — cron lifecycle (create/fix/remove).
- hermes-kanban-operations — board verbs (archive, promote, dispatch).
- home-file-organization — general home-dir cleanup/org (same no-rm, gio-trash rule).