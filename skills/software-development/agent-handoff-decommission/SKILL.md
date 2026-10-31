---
name: agent-handoff-decommission
description: Use when handing off or retiring an agent's operations.
version: 1.0.0
author: hermes-curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [handoff, decommission, lifecycle, takeover, hermes]
---

# Agent handoff and decommission

## When to Use

Requests like "decommission yourself", "hand this over to <other agent>", "what do you
keep notes in", "we're switching agents", or any migration/retirement of this box's
automation. Also use it when the user asks for an inventory of everything the agent
persists — that inventory IS the handoff brief's core section.

## Order of operations (do not reorder)

1. **Inventory first, with real counts.** Read the disk; never narrate from memory.
   `references/state-inventory.md` has the paths and one-line counters.
2. **Write the brief to a durable path** (e.g. `~/.hermes/HANDOFF.md`) plus a short
   pointer note in the knowledge base so a human finds it later.
3. **Notify the successor and verify receipt** (see below).
4. **Only then freeze**: stop timers, pause jobs — smallest reversible action first.
5. **Stop the agent last**, because that ends the only channel to the user.

A written brief is not a handoff. **A handoff is complete only when the successor
demonstrably received it** — a new session in its session list, an ack token echoed
back, or the user confirming. Stopping without that strands the box with no agent and
no successor that knows anything; the correct outcome then is "prepared and reported",
leaving everything running.

## The brief: required sections

1. What is running — units, timers, processes, linger, how to restart each.
2. State map — every durable store with its path and a real count.
3. Secrets policy — where secrets live (`.env`) plus an explicit statement that no
   value appears in the brief. Never copy a value into a note, commit, or chat.
4. Automation roster — job names, schedules, and which are **deliberately disabled**
   with the reason (otherwise the successor re-enables them and re-creates the
   annoyance the user asked to stop).
5. Known defects — verified, with evidence and why each is not fixed yet.
6. Teardown + rollback — copy-paste commands in order, and the one-line undo.
7. Successor first steps — the 3–5 checks that prove the box is healthy.
8. Delivery status — what was attempted, what failed with the exact error, what was
   NOT done. Write this last, after the notification attempts.

## Notifying the successor

Try in this order, stopping at the first that verifiably works:

1. **One-shot run with the brief attached** — `<agent> run "READ-ONLY: read the attached
   brief, modify nothing, reply with TAKEOVER / FIRST CHECKS / RISKS and end with
   ACK=ok" -f HANDOFF.md`, `workdir` = the brief's directory. Then list the successor's
   sessions: **no new session means nothing landed**, whatever the exit code said.
2. **Its global instruction file** (e.g. `~/.config/opencode/AGENTS.md`) so every future
   session loads the pointer automatically. These are protected agent-instruction files:
   the write needs explicit approval.
3. **A durable note in a path the successor reads**, referenced by absolute path.

Hard rules:

- **A refused write whose approval prompt timed out is not consent.** Do not retry it, do
  not reach the same file through terminal/execute_code. Report and ask.
- **Confirm the successor can run a prompt at all before promising a handoff.** Check its
  auth/provider and config: a workspace privacy gate, missing credential, or retired model
  makes "notified" false. Name the unblock action (settings toggle, second provider,
  re-auth) instead of improvising around it.
- **Never report notification because a command exited 0.** Cite the evidence.

## Teardown (Hermes gateway pattern)

```bash
systemctl --user stop llm-watchdog.timer     # 1. silence the watchdog first
hermes cron list --all                       # 2. ids come from the [active] blocks
hermes cron pause <id>                       #    per job; 'disable' is not a subcommand
hermes backup --quick                        # 3. snapshot before stopping
systemctl --user stop hermes-gateway         # 4. LAST, from a shell outside the gateway
systemctl --user disable hermes-gateway
# rollback, any time:
systemctl --user enable --now hermes-gateway
```

- **The gateway cannot stop itself from inside** — the lifecycle guard refuses the
  self-restart/stop path (correctly). Teardown is always out-of-band: paste-ready commands
  for the user, or a shell they open.
- **Freeze means pause/stop, never delete.** Timers disabled rather than removed, jobs
  paused rather than deleted, one command restores each.
- State the coverage gap each freeze creates ("while this timer is stopped, a real outage
  triggers nothing").

## Pitfalls

- **Say plainly what was preserved.** "Nothing was deleted, no job paused, no unit
  disabled" pre-empts the only question that matters next.
- **Inventory must be counted, not remembered.** "583 sessions / 79k messages / 116 skills /
  37 kanban cards" lands; "sessions, skills, kanban" reads as hand-waving. This user asks
  for quantified summaries.
- **Decommission requests are often conditional** ("by letting X know") — X knowing is a
  precondition, not a formality. Failing to notify converts the task into prepare-and-report.
- **Check the successor's live process first** (`ss -ltnp`, session list) before believing it
  is available; an installed binary is not a working agent.
