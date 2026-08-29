---
name: hermes-bot-operations
description: "Use when creating or managing Hermes bot rosters."
version: 1.0.1
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [hermes, bots, profiles, bot-mode, multi-agent]
    related_skills: [hermes-agent, hermes-cron-operations, hermes-gateway-access-control]
---

# Hermes Bot Operations

In Hermes, **a Bot IS a profile** (Bot Mode) — no new primitive to learn. A roster of named
specialist agents lives under `~/.hermes/profiles/<name>/`, each with its own
memory, skills, SOUL.md, and (on Bot-Mode-managed installs) a canonical Bot Chat.
Everything the desktop Bots tab does has a CLI equivalent below.

## When to Use
- Building a roster of specialist bots (the user asks for a "sleuth"/team of bots).
- Adding one specialist profile, or giving an existing profile (e.g. `horcrux`) a role + curated skills.
- Wiring bot routines (cron jobs) or diagnosing why a bot behaves differently than `default`.
- Distinguishing Bot Mode bots from platform bots / bot-bridge when "bots" come up.

## Disambiguation — three different "bots", never conflate
1. **Bot Mode bots** = profiles (this skill's territory).
2. **Platform bots** = gateway connectivity (Telegram/Discord tokens) — config `qqbot`/`yuanbao` channels are this category.
3. **bot-bridge** = *external* git-queue agent comms (`~/.hermes/bridge-repo`) — NOT a Hermes feature.
Note: `hermes bot` is **not** a command (invalid choice) — all ops go through `hermes profile ...` + per-profile config.

## Design first (user convention — mandatory for this user)
- Survey real workloads **before** naming bots: `hermes cron list`, memory notes, skills inventory. The roster must map 1:1 to recurring work — never invent roles.
- Creating profiles is cheap/reversible; **routines need user sign-off** (design-first): propose the cron wiring as a gated next step, don't just build it.
- Keep every bot **specialized**: curated skills, not the whole library. Specialization = capability, not just persona.

## Creation workflow
1. `hermes profile create <name> --no-skills --description "<role description>"`
   - `--description` routes kanban-decomposer tasks to the right bot by role.
   - `--no-skills` = clean slate (also opts the profile out of `hermes update` skill sync — that's the point: curation stays manual).
2. Curate skills by **symlinking from the master library** (one per skill):
   ```bash
   ln -sfn ~/.hermes/skills/<category>/<skill> ~/.hermes/profiles/<bot>/skills/<category>/<skill>
   ```
   The CLI has NO per-skill enablement flag (that's desktop New Agent → advanced only) — symlinks are the CLI equivalent, and they stay in sync when the master copy is patched via `skill_manage`.
3. Write `~/.hermes/profiles/<bot>/SOUL.md` — persona + **standing rules** (ground-truth sources to trust, PII discipline, journal/trash discipline). Tailor per ownership column; 12–15 lines is plenty.
4. Log everything: run creation via a script writing to `~/.hermes/cache/terminal-output/` and read the log back before reporting.

## Verification (always)
```bash
hermes profile list                                        # roster renders; note gateways stopped
find ~/.hermes/profiles/<bot>/skills -xtype l | wc -l      # 0 = no dangling links
```
- Creation log must show each `linked <skill>` and **zero `MISSING SOURCE` lines**.

## Behavior & economics
- New profiles have **no API keys**: they inherit from the shell env / shared token pool — correct for shared-credential setups; isolated creds need explicit setup.
- Model unset = **inherits default**; pin per bot via `hermes -p <bot> config set` (CLI) or the desktop dialog.
- **Gateways default stopped → zero token cost while idle.** Keep dormant bots stopped; start the gateway only when a bot needs platform reach.
- Routines = plain cron jobs namespaced `[bot:<name>]`, visible in `hermes cron list`.
- Canonical Bot Chats + the `message_agent` tool exist only on Bot-Mode-managed (desktop) installs; `hermes peer add/list/dm` does gateway-to-gateway bot DMs across machines.
- Remove: `hermes profile delete <name>` (the running `default` profile can't be deleted).

## Support files
- `templates/create_bot_roster.sh` — known-good roster-creation script (fresh profiles + skill symlinks + log) to copy and modify.
- `references/bot-mode-concepts.md` — condensed Bot Mode doc facts (canonical Bot Chat, group rooms, peers, protocol flag, shared keys).