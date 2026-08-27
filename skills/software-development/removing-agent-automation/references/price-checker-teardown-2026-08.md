# Worked example: GPU/PC price-checker teardown (2026-08-24)

Second teardown of this class for this user (first was the price-watch cron,
deleted earlier the same month). This run removed the ENTIRE remaining price
checking ecosystem after the user said: "drop the GPU and PC price checkers
completely".

## Artifact map (what lived where)

| Artifact | Path | Disposition |
|---|---|---|
| Skill `web-price-research` (CC recipes, watchdog pattern, `cc_extract.py`/`cc_snapshot.py`) | `~/.hermes/skills/productivity/web-price-research/` | `gio trash` (dir) |
| Skill `product-price-monitor` (disabled) | `~/.hermes/skills/productivity/product-price-monitor/` | `gio trash` (dir) |
| `deals_monitor.py` (20 KB) | `~/dev/agent-lab/scripts/` | `gio trash` |
| `price_watch.py` (4 KB, canonical CC parser) | `~/dev/agent-lab/scripts/` | `gio trash` |
| `deals-monitor.md` | `~/dev/agent-lab/docs/` | `gio trash` |
| `test_deals_monitor.py` (14 KB) | `~/dev/agent-lab/tests/` | `gio trash` |
| Kanban card `t_30b3e766` "Refresh stale 5070 Ti build-price anchors (+350)" | kanban (blocked, unassigned) | `hermes kanban archive` |

## Lookalike that was LEFT ALONE
`~/dev/llmcost/data/prices.json` — LLM API pricing for the unrelated llmcost
tool (its own cron `2785188c1081`), NOT hardware price data. Verified by
purpose before refusing to touch it.

## Config state left as-is
`config.yaml` still lists `product-price-monitor` under the disabled-skills
section. A disabled name with no directory is a no-op — harmless. Per user
rule, no hand-editing config.yaml; would stage via `hermes config set` only
if the user wants it scrubbed.

## Notes that proved out
- cron *output* files referenced the skills but `jobs.json` had **zero**
  skill refs → no active job depended on them. Output-file mentions were
  ghosts (see SKILL.md pitfall #4).
- The only residue after the sweep was the assistant's OWN temp scripts
  (price-sweep-inventory.sh, price-checker-teardown.sh) — trashed at the end.
- Memory update: Best Buy API technique entry kept (still useful), but the
  "CC: web-price-research skill cc_extract.py" dead pointer removed and the
  entry now notes "Price checkers dropped, don't resurrect."