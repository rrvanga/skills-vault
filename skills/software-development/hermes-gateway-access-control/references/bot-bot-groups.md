# Multi-bot Telegram groups: who is actually in the room

Session case 2026-08 ("Tale of two bots" group, chat -1003881519987). The
gateway had 13 `Blocked unauthorized user 211269680 in chat -1003881519987`
entries and the user asked "why isn't the other bot responding". Investigation
assumed 211269680 (username `<REDACTED>`) WAS the other bot. Wrong.

## Roster probe revealed the truth

`getChatAdministrators` on the group returned:

```
id=211269680 username=<REDACTED> first=Kaush is_bot=False   <- a HUMAN (group admin)
id=8820370417 username=<REDACTED>_hermes_bot is_bot=True  <- this gateway's bot
id=<REDACTED> username=<REDACTED><REDACTED> first=<REDACTED> is_bot=False    <- the owner
== getChatMemberCount == 4
```

Three admins + one non-admin 4th member = the real "other bot" (@<REDACTED>).
That member had **never once interacted with the gateway**: zero blocks, zero
processed messages, zero log lines, zero matches in sessions/ or on disk.

Lessons:
- **Never infer bot/human from the username** — `<REDACTED>` sounded like a bot
  account and "the other bot isn't responding" pointed at it; `is_bot=False`
  said human. The user's friend Kaush's human messages were what got blocked.
- **Silent member ≠ absent member.** A member can be in the chat for weeks
  without ever triggering the gateway (never messaged, or messages dropped at
  intake before logging existed).
- **Bot API cannot enumerate members**: only `getChatAdministrators` (admins)
  and `getChatMemberCount` exist. There is no getChatMembers endpoint. A
  non-admin bot's numeric user ID cannot be looked up via the API.
- **Soul-spec / personality fingerprinting**: the owner pasted the bot's soul
  spec ("Alfred 2,3,4,6,5,10 + Captain 4,5,7,1") into the group — matching the
  exact spec another bot runs is how "same soul, different host" bots are
  identified (Dvipru = Kaush's Hermes bot, same personality config).

## Auth gate treats bots like users

`_is_user_authorized_from_message` (plugins/platforms/telegram/adapter.py
~1103–1223) does an ID-based allowlist check (`group_allow_from` for groups,
`allow_from` for DMs, env `TELEGRAM_ALLOWED_USERS` fallback) — there is **no
is_bot exemption** anywhere in the prefilter. A bot member's group message is
blocked identically to a human's. To let two Hermes bots collaborate:

1. Each gateway adds the OTHER bot's numeric user ID to
   `platforms.telegram.group_allow_from` (config set, verify via
   probe_platform_extra.py, restart from outside shell).
2. `require_mention` applies to bots too — they address each other by @mention.

## Discovering a silent member's numeric ID

No API route. Two working paths:
- **Test-message trick**: have the other bot post anything in the group. The
  gateway logs `Blocked unauthorized user <id> in chat ...` — the ID appears in
  the block line even though the message is dropped. Then allowlist it.
- **Operator-side lookup**: the other bot's operator reads its numeric ID from
  their own gateway logs / `getMe` and passes it over.

## Exclusive bot-mention routing (source refs, verified 2026-08)

Two Hermes bots in one group only work because of exclusive routing. In
`plugins/platforms/telegram/adapter.py` (re-verify line numbers if code moved):

- `_FOREIGN_BOT_HANDLE_RE = re.compile(r"[a-z0-9_]{2,29}bot", re.IGNORECASE)` (~8104) — foreign handles only count as bot mentions when bot-shaped, so a human `@username` in a group never suppresses this bot.
- `_extract_bot_mention_usernames(message, self_username)` (~8209–8277) — collects bot handles from `text` + `caption` using Telegram entities (mention + bot_command with `@botname` suffix), with a narrow raw-text fallback for clients that send entity-less mentions. Our OWN handle matches by identity regardless of shape (collectible/Fragment usernames like `@jarvis` need not end in "bot").
- `_explicit_bot_mentions_exclude_self(message)` (~8375–8405) — routing decision: if ≥1 bot handle present and none is ours → return True → the message is ignored upstream (both in the mention-gate ~8458 and the auth/prefilter path ~8841). Also schedules a TTL-bounded `get_me` recheck so a renamed bot self-corrects instead of permanently ignoring its own mentions.
- `_is_reply_to_bot(message)` (~8203–8207) — reply to one of my messages counts as addressing me.
- `_telegram_exclusive_bot_mentions()` (~7919–7926) — reads `config.extra["exclusive_bot_mentions"]`, env fallback `TELEGRAM_EXCLUSIVE_BOT_MENTIONS`, **default "true"**. YAML namespace is `platforms.telegram.exclusive_bot_mentions` (same namespace trap as require_mention — verify via probe_platform_extra.py).

Behavior table (message → which bot wakes):

| Message | Wakes |
|---|---|
| `@Slowpoke do X` | only me |
| `@<REDACTED> do Y` | only Dvipru (I ignore it) |
| `@Slowpoke @<REDACTED> shared task` | BOTH |
| reply to my message | me |
| plain chatter (require_mention on) | neither |

## Probe script

`scripts/probe_group_roster.py <chat_id>` — prints admins with
id/username/is_bot + member count. Token read from `~/.hermes/.env`
(`TELEGRAM_BOT_TOKEN`), never printed. Redirect stdout to a file when the
terminal display collapses long output.
