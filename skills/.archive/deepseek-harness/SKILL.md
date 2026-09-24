---
name: deepseek-harness
description: "Use when running or experimenting with the dsh CLI."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [deepseek, agent-harness, plugins, cordis, llm-providers]
    related_skills: [claude-code, codex, opencode, hermes-agent]
---

# DeepSeek Harness (dsh)

DeepSeek's agent harness — `deepseek-ai/deepseek-harness` (~149K★, MIT, TS/Node monorepo,
54 packages). Tagline: *"Everything is a Plugin"* — built on Cordis with services, events, and
effects as first-class plugin citizens. Developer preview (`0.1.0-rc.x`), bilingual docs
(English/中文), Web UI defaults to zh-CN. Not related to `lm-eval-harness`.

The one-line difference from Hermes: dsh is a **plugin-composed runtime** (a profile = an
ordered stack of bundle patch-layers, inspectable via `--dump-config`), while Hermes is a
batteries-included agent with a fixed toolset.

## Install & prerequisites

- Node **^22.19 || >=24** (check `node --version` first). npm/pnpm both work; `npx` needs no install.
- Run latest: `npx -y @deepseek-ai/dsh@latest --help` (downloads to npm cache; no global install).
- From source (for source diving): shallow clone, then `pnpm install && pnpm run build && pnpm dsh web`.

## CLI surface

```
dsh [--profile <name>] [--patch <path.yml>] [--dump-config|--dump-default-config] [args...]
dsh web [--host H] [--port P]            # browser UI (alias of --profile web)
dsh plugin <add|remove|...> <package>    # plugin management via pnpm in the profile dir
```

- Profiles: `web`, `headless`, `tui`, or custom under `$DSH_HOME/profiles`. `--patch` overlays an
  extra patch-list on top of the profile layer.
- `--dump-config` prints the full composed plugin tree (335+ lines for headless);
  `--dump-default-config` skips user layer + patches — excellent for understanding what boots.
- `dsh --profile headless "task"` → one-shot: submits task as a user message, prints final
  assistant text, exit 0 on clean `turn/end`. No listening port.

## Config layout (learned the hard way)

- `$DSH_HOME` defaults to `~/.dsh` (create it). Files: `settings.yaml`, `.credentials.yaml`.
- Secrets NEVER live in settings — only **credential references** (env-var names or credential-
  service refs). Keys stored write-only in `.credentials.yaml` by the Web UI Models page.
- LLM routes in `settings.yaml`:
  ```yaml
  llm-pi-ai:
    providers:
      my-provider:
        displayName: My Gateway
        apiKeyEnv: MY_API_KEY          # env var NAME — the secret is never written here
        api: openai-completions
        baseURL: https://gateway.example/v1
        models:
          - id: model-a
  ```
- **Headless/API entry points need a default model**, independent of the provider:
  ```yaml
  agent-default-model:
    provider: my-provider
    model: model-a
  ```
  Without it: `MISSING_CREDENTIAL: llm-deepseek: no API key for provider route "deepseek-official"`.

## Run dsh against ANY OpenAI-compatible endpoint (zero DeepSeek spend)

Proven recipe: point a custom provider at a non-DeepSeek endpoint (e.g. OpenCode Zen
`https://opencode.ai/zen/go/v1` with the existing Zen key):
1. Write `settings.yaml` per above (`api: openai-completions`, your `baseURL`, `models`).
2. Add `agent-default-model` with that provider + model.
3. Run with the key exported in the environment: `. ~/.hermes/.env` then
   `npx -y @deepseek-ai/dsh@latest --profile headless "task"`.
This is the cheap path for feature experiments — no `DEEPSEEK_API_KEY` needed.

## Pitfalls

- **Verify model IDs against the endpoint's `GET /models` first.** A guessed model id gets
  `401 {"type":"ModelError","message":"Model <id> is not supported"}` straight from the API.
  `curl -H "Authorization: Bearer $KEY" <baseURL>/models` to list real ids. (Found:
  `nemotron-3-ultra-free` presumed-fallback was NOT on the zen catalog as of 2026-08-17.)
- **Don't confuse `MISSING_CREDENTIAL` (provider not selected) with bad key (auth 401).**
  Scope first: check `--dump-config` shows your provider, check `agent-default-model` set.
- **`npx` re-resolves versions** — pin `@latest` for experiments; behavior shifts across
  `0.1.0-rc.x` rapidly (dev preview).
- Web UI default locale is zh-CN; don't read a Chinese-only page as a bug.

## Comparison notes vs Hermes (as of 2026-08-17)

| Dimension | dsh | Hermes |
|---|---|---|
| Runtime | TS/Node, Cordis plugin graph | Python, fixed toolset |
| Config | YAML patch-layers per profile, `--dump-config` | `hermes config set`, single config |
| LLM providers | plugin adapters; custom openai-completions routes | provider-agnostic routing + fallback chains |
| Skills | `ctx.skills` registry (local/embedded/remote providers), `skill` tool | SKILL.md library, curator, skill_manage |
| Subagents | `subagent` package (worker threads) | delegate_task with live orchestration |
| Sandboxing | E2B cloud + native landlock; `code-runtime` | computer_use background driver |
| Task modes | web/headless/tui profiles | CLI, TUI, desktop, gateway (Telegram/Discord/...) |
| Extensions | 54-package monorepo, `dsh plugin add` | plugins + skills + cron + kanban |

Full 54-package feature inventory + subsystem doc paths: `references/features.md`.

Related: `pii-safe-public-publishing` (this skill's experiments must never leak keys —
settings.yaml references env var NAMES only, which is the same principle).