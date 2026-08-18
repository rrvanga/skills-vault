# dsh feature inventory (as of 2026-08-17, v0.1.0-rc.7)

Full package map of `deepseek-ai/deepseek-harness` (54 dirs in `packages/`), from a shallow
clone of the monorepo. Grouped by capability family.

## Core control spine
- **core** — service registry, scopes, agent lifecycles
- **boot** — launcher, `cmdline` provider, profile boot
- **bundle / preset / profile-boot** — pluggable bundle patch-layers
- **typert** (`typert-registry`, `typert-loader`), **api-gateway** — typed runtime + routing
- **util** — shared helpers

## LLM & reasoning
- **llm** — `llm-pi-ai` (provider-agnostic, `openai-completions` etc.), `llm-deepseek` (official route)
- **agent-default-model** — deployment-level `{provider, model}` default selection
- **compaction** (`compaction-basic`) — context compaction
- **context** — context window management
- **spill** — long-term memory / overflow storage

## Tools & execution
- **tools** — tool registry + model-facing tool catalog
- **tool-goal, tool-skill, tool-workflow, tool-jobs** — goal tracking, skill loader, workflow runner, job queue
- **code-runtime** (`worker-thread`) — Code Mode execution
- **shell, terminal, subprocess, fs** — local execution capabilities
- **e2b** — E2B cloud sandbox
- **sandbox** — native sandbox (landlock on Linux)
- **lsp** — Language Server Protocol integration

## Agent capabilities
- **subagent** — sub-agent spawning (worker threads)
- **plan** — plan mode (deferred steps)
- **todo** — todo tracking
- **schedule** — time-based triggers (scheduling)
- **guard** — guardrails / constraints
- **hooks** — event hooks (incl. Claude Code / Codex hook bridges)
- **feedback** — feedback collection
- **identity** — agent identity

## Skills
- **skill** family — `skill` (registry, `ctx.skills`), `skill-filesystem` (local discovery),
  `skill-badge` (bundled badge skill), `tool-skill` (catalog + model-facing `skill` loader).
  Provider-neutral: local, embedded, or remote skill providers, host+per-scope layered registry.

## Sessions & persistence
- **session, session-query, session-telemetry, session-title** — durable sessions, titles, projections
- **storage** (`storage-json`), **attachment, interaction, interaction-session** — persistence layer

## Interfaces
- **web, client, client-ui-\*** — browser UI (default locale zh-CN)
- **acp** — Agent Client Protocol server
- **api** (`api-remotes`, `host-apiproxy`) — HTTP/remote API
- **sdk** — SDK surface
- **mcp** — MCP support
- **credentials, settings** — credential-ref storage (`~/.dsh/.credentials.yaml`, write-only keys)
- **workspace, host** — workspace/host abstraction
- **test-support, extensions, examples, runtime-diagnostics, feedback** — dev/ops support

## Key subsystem docs in the repo
- `docs/subsystems/skills.md` — skills registry deep-dive (provider layering, `SkillProviderObservation`)
- `docs/user/guide/providers.md` — model config (custom providers, image input, `modelOverrides`)
- `docs/user/guide/index.md` — setup guide
- `docs/config-catalog.md` — every supported field + default
- `packages/llm/llm-pi-ai/README.md` + `packages/llm/llm-deepseek/README.md` — provider references

## Proven config example (OpenCode Zen route)
```yaml
llm-pi-ai:
  providers:
    opencode-zen:
      apiKeyEnv: OPENCODE_GO_API_KEY
      api: openai-completions
      baseURL: https://opencode.ai/zen/go/v1
      models: [{ id: deepseek-v4-flash }]
agent-default-model:
  provider: opencode-zen
  model: deepseek-v4-flash
```
Run: `. ~/.hermes/.env` then `npx -y @deepseek-ai/dsh@latest --profile headless "task"`.