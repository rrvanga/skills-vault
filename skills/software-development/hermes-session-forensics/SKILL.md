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

## Pitfalls

- `messages.timestamp` is a **unix epoch** — always convert with `datetime(timestamp,'unixepoch','localtime')`.
- Filter to `role IN ('user','assistant')` and exclude `[CONTEXT COMPACTION` rows or output drowns in tool noise.
- **Assistant messages may appear twice**: the same payload can exist at different ids/timestamps in one session (replayed/appended transcript copies). Dedupe on content; don't treat duplicates as independent events.
- `substr(...,1,600)` keeps huge sessions readable.
- Companion stores for cross-session follow-ups: `~/.hermes/cron/output/<jobid>/*.md` (deliveries), `~/.hermes/kanban.db` (task state incl. `blocked`), `~/.hermes/cache/blocked-scripts/` (intercepted long commands). Check all meanings of the user's "blocked/what's left" phrasing.

## When NOT needed

If the exchange happened in the *current* session (or the immediate compaction summary), the summary is authoritative — don't go digging.