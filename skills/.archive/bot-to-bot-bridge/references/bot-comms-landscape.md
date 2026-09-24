# Bot-to-Bot Communication Landscape (research + platform capabilities)

Condensed from live research (2026-08) + on-disk adapter source inspection.
The git-queue bridge in SKILL.md is ONE transport; this is the map of the others.

## Industry protocol verdict: A2A is the standard

- **A2A (Agent-to-Agent, v1.0)** — open standard for AI-agent↔AI-agent comms,
  Linux Foundation-style governance, Google primary driver, 50+ vendors
  (Microsoft, Salesforce, SAP, MongoDB...). Task-centric: `SendMessage`,
  `GetTask`, `ListTasks`, `CancelTask`, `Subscribe`. Transports: HTTP + JSON-RPC
  2.0 + SSE streaming. **Agent Card** = JSON identity/capabilities/skills/endpoint
  for discovery. Async-first, human-in-the-loop, auth/tracing in design goals.
  Opaque execution — agents collaborate on declared capabilities without sharing
  internals. This is THE industry answer to inter-agent interop.
- **MCP (Model Context Protocol)** — NOT a peer protocol. Spec contains zero
  agent-to-agent/peer-to-peer mentions; it's LLM↔tools/data. Official framing:
  "A2A = how agents talk to each other; MCP = how agents use tools." Complementary,
  not competing.
- **FIPA (1996)** — the original bot-to-bot standard (FIPA-ACL, KQML-style
  performatives). Academically elegant, never got commercial traction. Historical
  footnote only.
- **ACP (IBM/Cisco, 2024)** — effectively superseded; site relocated/deprecated.

## KEY: Hermes ships A2A built in (`plugins/platforms/a2a/`)

Full A2A v1.0 platform plugin, stdlib only (http.server + urllib, no a2a-sdk).
Both directions:

**Outbound client tools** (a2a toolset): `a2a_discover(url)` (fetch+summarize a
peer's Agent Card, v1.0 `supportedInterfaces` aware), `a2a_call(agent, message,
context_id?)` (JSON-RPC `message/send`, multi-turn via context_id, surfaces
`TASK_STATE_INPUT_REQUIRED`), `a2a_list()`, `a2a_history(context_id, limit?)`,
`a2a_orchestrate(capability, message, mode)` (fan-out: all/first/best). Peers
resolved from `config.yaml` → `a2a_agents`, or direct URL. Works with any
A2A-compliant peer (another Hermes, LangChain, CrewAI, Google ADK, OpenClaw).

**Inbound platform adapter**: stdlib http.server on daemon thread, port **9900**,
Agent Card at `/.well-known/agent-card.json` (legacy `agent.json` also answers).
JSON-RPC: `message/send`, `message/stream` (SSE), `tasks/get|list|cancel|subscribe`,
`tasks/pushNotificationConfig/create`. Inbound tasks route into the LIVE gateway
session (same memory/context, not a throwaway clone).

**Security layers (all on by default, opt-out only via explicit config)**:
1. No token configured ⇒ bind **127.0.0.1 only** (no remote access at all)
2. Per-peer bearer tokens `A2A_PEER_TOKENS=alice:tok1,bob:tok2`; shared
   `A2A_BEARER_TOKEN` falls back to ip:<addr> identity; rate limiting + trust
   gate key on identity, never on request-body claims
3. Prompt-injection filters strip ChatML/role-prefix/override patterns from
   inbound task text
4. Outbound redaction of credential-shaped strings
5. Append-only JSONL audit log of every exchange
6. Trusted-peers allow-list; 7. HMAC-SHA256 push auth + SSRF-safe callback URLs

Env vars: `A2A_PEER_TOKENS`, `A2A_BEARER_TOKEN`, `A2A_HOST` (default 127.0.0.1;
only widens to 0.0.0.0 with token AND explicit opt-in), `A2A_PORT` (9900),
`A2A_AGENT_NAME`, `A2A_ALLOW_ALL_USERS` (dev only), `A2A_HOME_CHANNEL`.

**Implication**: for 2+ hosts, A2A-over-Tailscale/SSH-tunnel gives the industry
protocol with zero public exposure (localhost bind + private mesh). The git-queue
bridge remains the zero-network-surface option; A2A is the protocol option.

## Chat-platform bot-to-bot capability (adapter source facts)

### Discord — native bot-to-bot support ✅ (best common forum)
- Hermes has a full Discord gateway adapter (`plugins/platforms/discord/adapter.py`).
- **`DISCORD_ALLOW_BOTS`** env, modes `none | mentions | all`, **default `none`**
  — set `all` to accept every bot message; `mentions` = only when @-mentioned.
  Also `discord_bots_require_inline_mention` check.
- **Critical**: Discord's API does NOT strip bot→bot messages (unlike Telegram).
  Two Hermes bots in one server with `DISCORD_ALLOW_BOTS=all` can talk directly,
  real-time — no bridge, no polling. Root-cause fix for Telegram stripping.
- Multi-user forum: `DISCORD_ALLOWED_USERS` (list), `DISCORD_ALLOWED_ROLES`,
  `DISCORD_ALLOWED_CHANNELS` — supports 2+ human users with their own accounts.
- Security posture: outbound WebSocket only, no inbound ports — same threat model
  as Telegram (which user already accepts). Threads = native many-to-many topics.
- Setup per host: Discord bot token (separate bot account per Hermes instance),
  Message Content Intent enabled in Developer Portal, both bots + both humans in
  one shared server, `DISCORD_ALLOW_BOTS=all` on each gateway, restart gateways.

### Matrix — no bot-stripping found ✅ (privacy option)
- Adapter only excludes the bot's OWN account (`_is_bot_mentioned` for replies);
  no bot-author filtering equivalent to Telegram's stripping. E2EE available.
- Heavier setup (homeserver choice: self-host vs matrix.org).

### Telegram — bot→bot structurally impossible ❌
- Bot API strips messages sent by bots from other bots' update streams — nothing
  an adapter can do; verified against adapter source + gateway logs (exactly one
  hit ever = human relay). Human-relay or another transport required.

## Recommended 3-layer architecture (2 humans + 2 hosts)

```
FORUM:    Discord server (humans + all bots, real-time, DISCORD_ALLOW_BOTS=all)
PROTOCOL: A2A over Tailscale/SSH (bot↔bot tasks, many-to-many, zero exposure)
FALLBACK: git-queue bridge (already live, hardened, audit log)
```
Layers serve different needs; not either/or. Stand up Discord first (solves
"everyone talks to everyone" today), keep git bridge, add A2A when N≥3 bots.
