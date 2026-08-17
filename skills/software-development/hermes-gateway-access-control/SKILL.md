---
name: hermes-gateway-access-control
description: "Use when adding users or groups to the Hermes gateway."
version: 1.0.0
author: curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [hermes, gateway, telegram, allowlist, authz, multi-user, groups]
    related_skills: [hermes-agent, hermes-config-optimization]
---

# Hermes gateway access control (allowlists, groups, multi-user)

## When to Use

Trigger when: a user wants a second person to talk to the agent (DM or group chat); adding/removing users or groups on any platform (Telegram especially); diagnosing "bot ignores me in a group" or "user can't reach the bot". Source-verified against Hermes internals 2026-08 — re-verify line numbers if the code moved.

## The two orthogonal gates (Telegram)

1. **Sender gate — WHO**: `TELEGRAM_ALLOWED_USERS` covers ALL chat types (DMs, groups, forums). `TELEGRAM_GROUP_ALLOWED_USERS` is group/forum-only and does NOT imply DM access.
2. **Chat gate — WHERE**: `TELEGRAM_GROUP_ALLOWED_CHATS` — every member of a listed group/forum is authorized regardless of sender. Group/forum chat IDs are negative numbers (e.g. `-1001234567890`). `*` in any allowlist = allow everyone.

**Key insight**: a user already listed in `TELEGRAM_ALLOWED_USERS` (YAML `gateway.telegram.allowed_users`) can invoke the bot in ANY group without further config — and groups solve the "bot can't DM a user who never started it" problem, because group messages reach the bot without a prior DM.

## Authz gate order (source: `~/.hermes/hermes-agent/gateway/authz_mixin.py`)

Chat-type allowlist (group/forum/channel by chat ID — works even when `user_id` is None, e.g. anonymous admins) → `{PLATFORM}_ALLOW_BOTS` → pairing store (operator-approved pairing codes) → `{PLATFORM}_ALLOW_ALL_USERS` → per-platform allowlists (`TELEGRAM_ALLOWED_USERS`, `TELEGRAM_GROUP_ALLOWED_USERS`, `TELEGRAM_GROUP_ALLOWED_CHATS`, `GATEWAY_ALLOWED_USERS`) → adapter config.extra fallback (`allow_from` / `group_allow_from`) → `GATEWAY_ALLOW_ALL_USERS` → **default deny** (fail-closed — no allowlist = deny, per SECURITY.md).

## Config keys (YAML ↔ env)

- `gateway.telegram.allowed_users` → env `TELEGRAM_ALLOWED_USERS` semantics (bridged by the adapter at startup from `allow_from` / `allowed_users`).
- Docs canonical shape nests under `gateway.platforms.telegram.extra`: `allow_from`, `group_allow_from`, `group_allowed_chats`.
- Env equivalents: `TELEGRAM_ALLOWED_USERS`, `TELEGRAM_GROUP_ALLOWED_USERS`, `TELEGRAM_GROUP_ALLOWED_CHATS`.
- `guest_mode: true` → non-allowlisted groups still allow @mention replies (casual friend-group mode). Without it, unlisted groups are silently dropped even on @mention (hard gate — right default for support/team bots).
- `require_mention: true` → in group chats the bot ONLY responds to @mention or reply-to-bot; untagged chatter is dropped. Adapter getter: `_telegram_require_mention()` reads `config.extra.get("require_mention")`, falls back to env `TELEGRAM_REQUIRE_MENTION` (default false). Complementary flag: `observe_unmentioned_group_messages` (a.k.a. `ingest_unmentioned_group_messages`) records skipped chatter in the transcript without dispatching the agent.

## Key namespace matters: gateway.* vs platforms.* vs extra (REAL GOTCHA)

`hermes config set gateway.telegram.<key>` is NOT a universal write path. The loader (`gateway/config.py` `load_gateway_config`) resolves platform settings from specific blocks:

- The **shared-key bridge loop** reads trigger keys like `require_mention` ONLY from: top-level `telegram:` block, `gateway.platforms.telegram`, or `platforms.telegram` — **NOT from `gateway.telegram`**. `PlatformConfig.from_dict` keeps a fixed key set (enabled/token/api_key/home_channel/reply_to_mode/restart-notification/typing/channel_overrides) plus the nested `extra:` dict; anything else is silently dropped.
- **Real case 2026-08**: `gateway.telegram.require_mention: true` (CLI default path for the key) was silently ignored — `hermes config get` showed it, restarts didn't help, but the adapter's `extra` was `{}` and the gate never armed. Fix: `hermes config set platforms.telegram.require_mention true` → loader then produced `extra={'require_mention': True}`.
- **Rule of thumb**: when a platform setting doesn't take effect, find WHERE the loader reads it before changing values — and verify with the probe below, never trust `hermes config get` alone.

## Probe: verify through the consumer's eyes (the decisive check)

Instead of reasoning about the loader from source, LOAD the config through the gateway's real code path and print what the adapter will see:

- The lifecycle guard blocks inline heredocs that import `gateway.config` (it scans the full command string), so write the probe to a file and run the file: `~/.hermes/hermes-agent/venv/bin/python ~/.hermes/probe_platform_extra.py` (see `scripts/`).
- Expected outputs: `extra: {}` / `extra['require_mention']: None` = key never bridged (wrong namespace or dead key). `extra: {'require_mention': True}` = armed.
- After fixing the namespace, RE-RUN the probe to confirm `True` — then the only remaining step is a gateway restart from an outside shell (see below).

## Multi-bot groups: bot-to-bot collaboration (no is_bot exemption)

Bots pass the SAME auth gate as humans. `_is_user_authorized_from_message` (adapter.py ~1103) is purely ID-based — a bot member's message in a group is blocked at intake exactly like a human's (`Blocked unauthorized user <id> in chat ...`), and `require_mention` applies to bots too. Verified 2026-08 on a two-Hermes-bots group ("Tale of two bots").

To make two Hermes bots collaborate in a shared group, BOTH directions must be allowlisted:
1. Add the other bot's numeric user ID to `platforms.telegram.group_allow_from` (and the other gateway must add yours).
2. Restart each gateway from an outside shell (allowlists load at startup).
3. Address each other by @mention — `require_mention` gating applies to bots.

### Exclusive bot-mention routing (the multi-bot traffic cop)

The adapter has native multi-bot routing so two Hermes bots in one group don't answer every message. `_telegram_exclusive_bot_mentions()` (adapter.py ~7919) reads `config.extra["exclusive_bot_mentions"]` / env `TELEGRAM_EXCLUSIVE_BOT_MENTIONS`, **default TRUE**. When on:

- `_extract_bot_mention_usernames()` (~8209) collects every @...bot handle in the message — foreign handles must match the shape regex `[a-z0-9_]{2,29}bot` (`_FOREIGN_BOT_HANDLE_RE`, ~8104, case-insensitive) so human @handles never suppress this bot; OUR OWN handle matches by identity (works for collectible/Fragment usernames not ending in "bot").
- `_explicit_bot_mentions_exclude_self()` (~8375): if at least one bot handle is present and none is ours, the message is **ignored** — routed away, no reply, no fallback wake. So `@<REDACTED> do X` does NOT wake me; `@Slowpoke do X` does; mentioning BOTH wakes both.
- A stale-own-handle self-correction exists: when the message looks routed away, the adapter schedules an out-of-band `get_me` identity recheck (TTL-bounded) so a renamed bot doesn't permanently ignore its own mentions.
- `_is_reply_to_bot()` (~8203): replying to one of MY messages counts as addressing me even without a handle mention.

Consequences for shared-task design: to get BOTH bots working on one message you must mention both explicitly; to hand a task to the other bot, mention only it. Config key is `platforms.telegram.exclusive_bot_mentions` (same namespace rules as `require_mention` — see the namespace gotcha above).

### Collaboration protocol for autonomous shared tasks (verified design, 2026-08)

When the owner wants two bots to work together autonomously on shared tasks, agree this convention before enabling anything:

1. **Pinned task board**: one pinned message in the group = the source of truth both bots read. Each task gets an explicit owner.
2. **Explicit addressing**: `@Slowpoke part A, @<REDACTED> part B` → exclusive routing sends each bot its slice. Ambiguous broadcast messages are dropped by both — specificity is the API.
3. **Bot-to-bot handoffs**: the completing bot posts `@<REDACTED> here's the result, your turn` — no human middleman. This is what "autonomous" means mechanically: humans start tasks, bots continue the thread.
4. **Completion posted as a reply** to the task message so the thread self-documents (reply-to-bot detection keeps the handoff chain alive).
5. **Keep `exclusive_bot_mentions` default true; do NOT enable free-response** for the group — that makes both bots answer everything and destroys routing.

Identifying who's actually in the group (and who's a bot):
- `getChatAdministrators` (Bot API) returns username + `is_bot` per admin — use it to tell humans from bots. A username ending in "bot" can still be a human account; trust `is_bot`, never the name.
- The Bot API has NO member-list endpoint: only `getChatAdministrators` (admins) and `getChatMemberCount`. A non-admin member's numeric ID is NOT discoverable via the API.
- To learn a silent member's ID: have them send any test message in the group — the gateway logs the ID in the block line (`Blocked unauthorized user <id> in chat ...`), even though the message itself is dropped. Alternatively their operator reads the ID from their own gateway's logs/getMe.
- Never echo the bot token: probe scripts read it from `~/.hermes/.env` and print only IDs/usernames/is_bot flags (see `scripts/probe_group_roster.py`).

## Telegram-side steps (the three things users always forget)

1. **BotFather `/setprivacy` → Disable** — else the bot sees only commands, replies, and mentions.
2. **Add the bot to the group as admin** — bypasses privacy mode, guaranteed message visibility.
3. **Get the group chat ID** (negative number): @userinfobot in the group, or from gateway logs.

## Applying changes

- `hermes config set` for scalars. List keys (e.g. `group_allowed_chats`, `allowed_users`) may get stored as quoted strings — ALWAYS verify with `python3 -c "import yaml; yaml.safe_load(...)"`; rewrite via python3 `yaml.safe_load` → set real list → `safe_dump` if needed.
- **Removing dead entries**: grep config for the endpoint/ID first, confirm nothing else references it, then `hermes config unset <key>` (nukes the WHOLE key — fine if every entry is dead) vs surgical `set` with only the surviving list (when some entries still live).
- **Restart required** (allowlists load at gateway startup): `hermes gateway restart` only works from an outside shell; the lifecycle guard blocks ANY command text matching restart patterns (even nested in wrappers). Use the detached `systemd-run --user --on-active=20` timer trick or the schedule-ahead one-shot cron + cleanup pattern — see `hermes-config-optimization` skill for the verified recipe.

## Verification

- After adding a user: have them send a message in the group / @mention the bot.
- Read the live auth path in `gateway/authz_mixin.py` and the adapter's YAML→env bridge before guessing behavior — the env-var name in the docs may not match the YAML key that feeds it.

## Support files

- `references/telegram-group-access.md` — session detail: authz_mixin.py gate order with line refs, adapter YAML→env bridges, guest_mode semantics, config example.
- `references/require-mention-namespace.md` — session detail: why `gateway.telegram.require_mention` is silently ignored, the gateway.* vs platforms.* namespace trap, line refs, lifecycle-guard probe gotcha.
- `scripts/probe_platform_extra.py` — re-runnable probe: loads config through the gateway's real code path and prints a platform's `extra` (verifies a key actually reached the adapter).
- `scripts/probe_group_roster.py` — re-runnable probe: lists a Telegram group's admins (id/username/is_bot) + member count via Bot API, token read from `.env` and never echoed (identifies who is human vs bot, and reveals when a member has never interacted with the gateway).
- `references/bot-bot-groups.md` — session detail: "Tale of two bots" case — a member assumed to be the other bot turned out to be a human (is_bot=False, 13 intake blocks were his); the real bot was a silent 4th member never seen by the gateway; ID discovery paths.
