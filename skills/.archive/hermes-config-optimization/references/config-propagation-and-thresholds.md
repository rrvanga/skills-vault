# Config propagation & compression-threshold math (verified 2026-09-01, v0.20.6)

## 1. Config edits reach new sessions WITHOUT a gateway restart — headline finding

`hermes config set` writes `~/.hermes/config.yaml`. The running gateway does NOT
hold a stale boot-time snapshot for agent-level keys:

- Gateway calls `_load_gateway_config()` → `read_raw_config()` on **every agent
  construction / turn** (gateway/run.py:23163, 8351).
- `read_user_config_raw()` (hermes_cli/config.py ~282+) is an **mtime-keyed
  cache**: key = (path, mtime_ns, size). `hermes config set` rewrites the file →
  mtime bumps → cache invalidates → next construction reads fresh values.
- Agent compression/context config is read at agent_init (~2096-2115), not baked
  into the gateway process.

**Consequence:** after any `hermes config set`, a `/reset` (or new conversation)
picks up the new values. No gateway restart needed. Only *gateway-level* settings
(boot-time env bridge at run.py:2328, module-level `_cfg`) require a restart.

## 2. Compression firing-point math (`threshold_tokens` cap)

Effective firing point = `min(threshold_tokens_cap, int(context_length × threshold))`

- derived value: `context_engine.py:489` — `int(context_length * threshold_percent)`
- cap parsed: `agent_init.py:2269-2276`; applied as `min(cap, derived)` at ~2790
- The cap is an ABSOLUTE CEILING: it can only lower the firing point, never raise it.
  Codex threshold autoraise (agent_init.py:324-329) also never lowers a user cap.

Worked values (threshold 0.5):
| config                     | derived | cap  | fires at | note |
|----------------------------|---------|------|----------|------|
| 100k + cap 48000 (default) | 50000   | 48000 | 48k (48%)| cap binds, 2k early |
| 96k  + cap 48000           | 48000   | 48000 | 48k (50%)| clamp stops binding; window 4k smaller |
| 100k + cap 50000           | 50000   | 50000 | 50k (50%)| exact 50%, full window — best |

Key insight: the cap governs the firing point; window size only governs overflow
headroom past the trigger. Shrinking the window to make a cap "look tidy" (96k)
is never better than raising the cap to the derived value.

## 3. `compression.in_place` semantics

- `in_place: true` (hardened default since commit 2107b86024): rewrites messages
  in place, one durable session_id forever.
- `in_place: false` (rotation/"summarize and hand off"): mints a NEW physical
  session_id per compaction seeded with a summary handoff
  (context_compressor.py:202, 597-712).
- Code invariant (conversation_compression.py:2700-2703): a MISSING
  `compression_in_place` attribute must NOT fall back to rotation — that re-enables
  the pre-lease drift path and can wedge busy sessions. The switch must be explicit.
- Rotation is risky on busy hosts (kanban workers, cron spawns, session forensics
  assume stable session continuity). Keep in_place true unless a hard reason exists.

## 4. Gateway restart — when a restart IS genuinely needed

Agent runs INSIDE the gateway process tree, so both
`hermes gateway restart` and `systemctl --user restart hermes-gateway` are
BLOCKED by the process-tree guard (would SIGTERM the agent's own tree).

Sanctioned path (exit 0, schedules restart ~3s later via transient unit):

    systemd-run --user --on-active=3 --unit=<name> --collect systemctl --user restart hermes-gateway

Consequences of restarting: the session's own process is SIGTERM'd mid-flight;
the conversation auto-restores afterwards. Prefer `/reset` for agent-level config
changes (see §1); reserve restart for gateway-level changes.

## 5. Verification discipline

- `hermes config set` prints "✓ Set" but ALWAYS confirm with
  `hermes config get <key> --json` — quote only verified values.
- Query one section at a time with `--json`; multi-section `hermes config get`
  returns a merged dump that is easy to misread.
- Terminal output may truncate to a single line on this host: redirect
  (e.g. `... > /tmp/x.txt`) and `read_file` the artifact instead of trusting echo.