# Kanban event inspection — raw SQL ground truth

`hermes kanban show <id>` summarizes, but the `task_events` table tells the exact story when a card's status differs from what you set:

```sql
SELECT id, kind, created_at, payload FROM task_events
WHERE task_id='<task_id>' ORDER BY id;
```

(DB: `~/.hermes/kanban.db`, read-only connect: `sqlite3 "file:/home/<user>/.hermes/kanban.db?mode=ro"`)

## What the rows mean

- Every state change is a row: `created`, `promoted`, `blocked`, `unblocked`, `claimed {'lock': 'slick:<pid>'}`, `spawned {'pid': ...}`, `complete`, `failed`, `archived`.
- **`created` events carry `{"status": ...}` in the payload — they are NOT status-change events.** `create --initial-status blocked` writes only a `created` row with `status: blocked` in payload, NO `blocked` event row.
- A real `blocked` event row (from `hermes kanban block <id>`) is what `recompute_ready()`'s `_has_sticky_block()` looks for. No row → not sticky → auto-promotable.
- Timestamps let you prove auto-promotion: observed real sequence `created 00:41:40 → promoted 00:41:43` (no manual action between) = the dispatcher promoted a supposedly-blocked card.

## When to use

1. Card went `ready`/`running` when you created it `blocked` → check for a `promoted` row without a matching `blocked` row.
2. `hermes kanban block <id>` "worked" but the card is still `ready` → confirm the `blocked` row landed.
3. Debug dispatcher activity → look for `claimed`/`spawned` rows with the gateway lock/pid.