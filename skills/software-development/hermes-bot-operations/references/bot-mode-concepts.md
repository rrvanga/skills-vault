# Bot Mode concepts (condensed from hermes-agent.nousresearch.com/docs/user-guide/bot-mode, fetched 2026-08-29)

Source cache: `~/.hermes/cache/web/hermes-agent.nousresearch.com-4fd4bdba3a.md`
(the docs are authoritative — re-fetch if the cache goes stale).

## Core model
- "There is no new primitive to learn: a Bot **is** a Hermes profile."
- Everything lives under `~/.hermes/profiles/<name>/` — isolated config, memory,
  skills, credentials, chat history. A Bot adds a **surface**.
- Shared credentials by default: one OAuth/token pool with the launch profile, so
  refreshes can't invalidate each other. Per-bot keys only if explicitly set up.

## The Bot Chat (canonical conversation)
- Persistent forever-conversation per bot; `/new` is rerouted to `/compact`, so the
  relationship never resets.
- Roster (names + roles) injected into every Bot Chat's system prompt — bots know
  who does what before choosing a recipient.
- First message: the bot introduces itself (persona from SOUL.md).

## Team mechanics (group chats)
- Group chats hold 2–6 bots. A message triggers up to 3 serial rounds of turns.
- @-mentioned bots respond; if nobody is mentioned, everyone does.
- A full silent round settles the room. **Hard caps: 10 messages, 3 rounds** — prevents spin-ups.
- Escalation: bots pull each other in with `@name`, and escalate judgment calls to `@user`.
- @mentions in any chat: `@researcher have a look at this` hands off, waits, reports back.

## Agent-to-agent messaging
- `message_agent(target="<bot>", message="…")` tool — DMs a teammate directly.
- Automatic attribution: "Message from 🤖 sender (@sender)".
- Fire-and-forget: delivered into the teammate's Bot Chat; no waiting on a reply.

## Peers (cross-machine)
- `hermes peer add <name> --url <gw-url> --key <key>` registers a remote gateway.
- `hermes peer dm <peer>/<bot> < file` DMs a bot on another machine's gateway over the API server.
- Config: `bot_peers` lists registered peers; `agent.bot_mode_protocol` (default **on**) enables the protocol.
- Tailscale makes cross-machine peering natural (both gateways on the tailnet).

## What each bot owns (vs inherits)
- Model: any provider/model pair, side by side; unset = inherits launch profile.
- Memory, skills, SOUL.md, toolsets, MCP enablement: per-bot, per-skill.
- Routines = recurring tasks that are just cron jobs, namespaced `[bot:<name>]`,
  visible in `hermes cron list`, results delivered to its Bot Chat.

## Surface entry points
- Desktop: `hermes desktop` → **Bots** tab (built-in, on by default) → New Agent →
  Name/Title/Description → advanced: model pin, SOUL, skills, toolsets.
- CLI: `hermes profile create` / `hermes profile list` (bots are profiles — every
  terminal tool works); chat via `hermes -p <bot> chat` or the bot's wrapper script.

## Verified local quirks (this machine, 2026-08-29)
- `hermes profile create --help` flags: name, `--description` (also routes kanban
  decomposer tasks by role), `--no-skills`, `--clone*`.
- New profiles warn "no API keys yet … will inherit keys from your shell environment" — expected noise, not an error.
- `hermes bot --help` → invalid choice; there is no `hermes bot` command.
- Gateway status per profile: stopped by default → zero idle cost.