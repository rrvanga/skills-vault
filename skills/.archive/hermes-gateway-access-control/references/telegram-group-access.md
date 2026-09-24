# Telegram group access — source-verified detail (2026-08)

Verified against the local Hermes checkout (`~/.hermes/hermes-agent/`). Line numbers are
as-of 2026-08; re-check if the code moved.

## Authz gate order — `gateway/authz_mixin.py`

Authorization for an inbound message runs roughly:

1. **Chat-scoped allowlist** (line ~453): if `chat_type ∈ {group, forum, channel}` and
   `chat_id` present, check `TELEGRAM_GROUP_ALLOWED_CHATS` env, then adapter
   `config.extra.group_allowed_chats`. Runs BEFORE the no-user-id guard so anonymous
   admins / channel broadcasts with no `from_user` are honored. `"*"` or matching chat
   ID → authorized.
2. **Bot bypass** (line ~499): `TELEGRAM_ALLOW_BOTS` in {mentions, all} → authorized.
3. **No user_id → deny** (line ~504).
4. **Allow-all flags**: `{PLATFORM}_ALLOW_ALL_USERS` → authorized.
5. **Pairing store** (line ~596): `pairing_store.is_approved(platform, user_id)` →
   authorized (operator-approved pairing codes; inbound senders can never reach approve).
6. **Env allowlists** (line ~601): `TELEGRAM_ALLOWED_USERS` + (in groups/forums)
   `TELEGRAM_GROUP_ALLOWED_USERS` + `TELEGRAM_GROUP_ALLOWED_CHATS` + `GATEWAY_ALLOWED_USERS`.
   If NO env allowlist is set at all, the adapter's own config-driven policy
   (`dm_policy`/`group_policy`/`allow_from`/`group_allow_from` in `config.extra`) decides;
   adapter policies default to "open" but Hermes treats that as **fail-closed** unless the
   adapter actually enforces an allowlist at intake (line ~609).
7. **Group chat allowlist** (line ~696): if `group_chat_allowlist` set and
   `chat_type ∈ {group, forum}`, matching chat ID → authorized.
8. **Backward-compat shim** (line ~709): chat-ID-shaped values (starting with `-`) in
   `TELEGRAM_GROUP_ALLOWED_USERS` are honored as chat IDs with a one-time warning
   (pre-PR-#17686 behavior).
9. **User in any allowlist** (line ~737): union of platform + group + global allowlists;
   `"*"` → everyone. `TELEGRAM_ALLOWED_USERS` "remains the platform-wide allowlist and
   still works everywhere for backward compatibility" — i.e. an allowlisted user can
   invoke the bot in groups even when the group chat itself is not in
   `TELEGRAM_GROUP_ALLOWED_CHATS`.
10. **Default deny** (fail-closed).

## Adapter YAML → env bridge — `plugins/platforms/telegram/adapter.py`

`apply_yaml_config` (near line 10175) bridges config.yaml keys into env vars when the
env var is not already set:

- `allowed_chats` → `TELEGRAM_ALLOWED_CHATS`
- `allowed_topics` → `TELEGRAM_ALLOWED_TOPICS`
- `allow_from` (list or CSV) → `TELEGRAM_ALLOWED_USERS`
- `group_allow_from` → `TELEGRAM_GROUP_ALLOWED_USERS`
- `group_allowed_chats` → `TELEGRAM_GROUP_ALLOWED_CHATS`
- `reply_to_mode` → `TELEGRAM_REPLY_TO_MODE`
- `proxy_url` → `TELEGRAM_PROXY`

Note: the user's live config uses `gateway.telegram.allowed_users:` (YAML list) while the
docs canonical shape uses `gateway.platforms.telegram.extra.allow_from:` — both reach the
same env var semantics. **Always verify with a YAML parse after `hermes config set`** on
list keys: the CLI can store them as quoted strings instead of real lists.

## Sender vs chat gates (docs, telegram.md "Group Allowlisting")

- `TELEGRAM_ALLOWED_USERS` — all chat types (DMs, groups, forums). Also grants DM access.
- `TELEGRAM_GROUP_ALLOWED_USERS` / `group_allow_from` — sender-scoped, groups/forums only;
  does NOT grant DM access.
- `TELEGRAM_GROUP_ALLOWED_CHATS` / `group_allowed_chats` — chat-scoped; ANY member of the
  listed group/forum is authorized. Group membership itself is the access signal.
- `*` in any allowlist → any sender/chat.
- Layers on top of mention/pattern triggers, `group_topics`, `ignored_threads`.

### guest_mode (docs line ~1045)

Without it, `group_allowed_chats` is a HARD gate: messages from unlisted groups are
silently dropped even on explicit @mention. `guest_mode: true` relaxes that for casual
friend-group setups: non-allowlisted groups still work on @mention only (bot mostly
silent, occasionally available on explicit ping).

```yaml
gateway:
  platforms:
    telegram:
      extra:
        group_allowed_chats:
          - "-1001234567890"   # main allowlisted group
        guest_mode: true       # non-allowlisted groups: allow on @mention only
```

## Telegram platform-side checklist (BotFather + group admin)

1. BotFather → `/setprivacy` → **Disable** (otherwise bot only receives commands,
   replies-to-bot, and mentions — @mention-only use still works, but full visibility
   needs privacy disabled).
2. Add the bot to the group **as admin** — alone bypasses privacy mode.
3. Group chat ID is a negative number (e.g. `-1001234567890` for supergroups). Get it via
   @userinfobot inside the group, or from gateway logs when a member posts.

## Multi-user / team pattern (docs: guides/team-telegram-assistant.md)

For a second user: their Telegram user ID in the allowlist is the whole Hermes-side gate.
DM access additionally requires the user to have STARTED the bot at least once (Telegram
bot API: bots cannot initiate DMs). A group solves that: the bot sees group messages
without a prior DM — so a user who never started the bot can still talk to it in a group
where the bot is present. Deep-link workaround for DM-only setups:
`https://t.me/<botname>?start=<slug>` awaits the user pressing Start.

## Tests worth reading

- `tests/gateway/test_telegram_group_gating.py` — authorized-by-chat vs authorized-by-user
  scenarios, `guest_mode` mention-only behavior.
- `tests/plugins/platforms/test_discord_gate_isolation.py` — shared-key loop semantics
  (allowed_chats reaches PlatformConfig.extra).
