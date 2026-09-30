---
name: hermes-session-forensics
description: Recover past-session context from Hermes logs/state.db.
---

# Hermes session forensics

Recover what was said/agreed in an earlier session when memory and the current context don't have it. This machine's conversation history is queryable — no need to guess or ask the user to repeat themselves.

**Triggers:** user references a past conversation/agreement/decision not in current context (post-compaction, older session, or another agent's session); phrases like "what did we decide", "what's left on my side", "is X done yet".

## Workflow

1. **Find the original message** — search the gateway log for a distinctive phrase from the user's reference:
   `search_files(pattern="<their distinctive phrase>", path="~/.hermes/logs")`
   gateway.log lines carry `platform=`, `user=`, `chat=`, `msg='...'` **and the session id + timestamp**. E.g. `2026-08-22 07:16:08 INFO gateway.run: inbound message: ... session=20260819_221304_acec367e`.
2. **Pull the transcript** from `~/.hermes/state.db` (SQLite). Tables: `sessions` (id, title, started_at, message_count) and `messages` (session_id, role, timestamp, content):
   ```sql
   SELECT id, role, datetime(timestamp,'unixepoch','localtime'),
          substr(replace(content,char(10),' '),1,600)
   FROM messages
   WHERE session_id='<id>'
     AND datetime(timestamp,'unixepoch','localtime') >= '<YYYY-MM-DD HH:MM>'
     AND role IN ('user','assistant')
     AND content NOT LIKE '[CONTEXT COMPACTION%'
   ORDER BY id;
   ```
   Run the query with `workdir=/tmp` if the session cwd is wedged.
3. **Verify ground truth** — the transcript is a *narrative*, not proof. Before reporting "X was done / Y is pending", check live state:
   - sysfs values, `/etc` drop-ins, `~/.hermes/cron/jobs.json`, kanban db
   - **Did the user run a staged command?** `grep -c "<script>" ~/.bash_history` — 0 hits = never run, even if the assistant already handed them the command.

## Cost/token accounting (when the question is "which session/message burned tokens")

Sessions table holds the REAL API token counts (input/output/cache_read columns; `token_count` on messages rows is unpopulated — don't use it). `reasoning_content` column on messages can be the largest stored char sink (invisible in normal views) — SUM it if the question is storage size. Tool-role rows store NULL content: use `SUM(COALESCE(length(content),0))` for char totals. Exact-duplicate replays (same content, many ids) inflate stored chars but cost pennies on the wire.

**Pricing — distinguish TOKENS from DOLLARS before alarming anyone.** The meter lives in `~/.hermes/scripts/token_usage_report.py` (GO_RATES dict, $ per 1M tokens incl. cache_read; comment says what was verified when). Price a session: `calls_in/1e6*rate_in + out/1e6*rate_out + cache/1e6*rate_cache`. Cache_read is ~50x cheaper than input, so giant cache-replay totals (millions of tokens) usually price out to a few cents. Ultra-lightweight session databases but the model is what matters — rerun the same numbers with a pro model's rate to see why routing a chatty task to flash saved real money. On this box, the EVERYTHING-ever grand total across all sessions was ~$19 at flash rates; one long 6-day session ran $0.20. Chart big token numbers with matplotlib for the user (they like quantified visuals) but always pair the token chart with the dollar figure.

## Pitfalls

- `messages.timestamp` is a **unix epoch** — always convert with `datetime(timestamp,'unixepoch','localtime')`.
- Filter to `role IN ('user','assistant')` and exclude `[CONTEXT COMPACTION` rows or output drowns in tool noise.
- **Assistant messages may appear twice**: the same payload can exist at different ids/timestamps in one session (replayed/appended transcript copies). Dedupe on content; don't treat duplicates as independent events.
- `substr(...,1,600)` keeps huge sessions readable.
- Companion stores for cross-session follow-ups: `~/.hermes/cron/output/<jobid>/*.md` (deliveries), `~/.hermes/kanban.db` (task state incl. `blocked`), `~/.hermes/cache/blocked-scripts/` (intercepted long commands). Check all meanings of the user's "blocked/what's left" phrasing.

## When NOT needed

If the exchange happened in the *current* session (or the immediate compaction summary), the summary is authoritative — don't go digging.