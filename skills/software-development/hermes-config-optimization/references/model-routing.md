# Hermes Model Routing — source-verified axes (2026-08)

Findings from grepping the installed source (`~/.hermes/hermes-agent/hermes_cli/*.py`,
`agent/*.py`, `plugins/model-providers/*/__init__.py`) while configuring task-based
model selection on the OpenCode Go subscription. All claims below were verified in code.

## The five routing axes

| Axis | What runs on it | Config knob | Notes |
|---|---|---|---|
| Main agent | chat turns | `model.default` | the only model most users think about |
| Aux calls | context compression + message titles | provider profile `default_aux_model` | see ladder below; **biggest hidden cost** |
| Cron fleet | scheduled LLM jobs | `cron.model` + `cron.model_provider` | resolution: per-job pin > cron.model > HERMES_MODEL env > model.default (`cron/scheduler.py:3688`) |
| Delegation | subagents | `delegation.model` / `.provider` / `.base_url` / `.api_key` / `.api_mode` | empty = inherit parent (`config_defaults.py:1738`) |
| Manual | `/model <alias>` per session | `model.aliases` (or `model_aliases:` dict) | resolved by `hermes_cli/model_switch.py:resolve_alias` |

## `smart_model_routing` is vestigial — do not recommend it

Grep shows the key only in `hermes_cli/config.py` (known-keys list) and `setup.py`
(wizard default `enabled: false`). **No routing logic consumes it.** Enabling it does
nothing today. If the user asks for automatic per-task model picking, the honest answer
is: the axes above are what exists; true auto-classification is not wired in.

## Aux model resolution ladder (`agent/auxiliary_client.py:_get_aux_model_for_provider`)

1. `prefer_fast=True` only: family match against the provider's LIVE `/v1/models` catalog (latency-ordered).
2. `prefer_fast=True` only: provider's `resolve_aux_model()` hook.
3. `ProviderProfile.default_aux_model` — curated hardcode.
4. Legacy `_API_KEY_PROVIDER_AUX_MODELS_FALLBACK` dict (e.g. `gemini: gemini-3.6-flash`, `zai: glm-4.5-flash`).

**Trap:** for `provider: custom` there is no profile and no fallback entry → aux model
resolves to `""` → compression/titles run on the MAIN model. Every compaction then costs
main-model tokens. Fix: use a provider profile for the endpoint.

## Provider profiles (plugins/model-providers/opencode-zen/__init__.py)

One plugin file registers TWO profiles:

- `opencode-zen`: base `https://opencode.ai/zen/v1`, env `OPENCODE_ZEN_API_KEY`, aux `gemini-3-flash`.
- `opencode-go` (class `OpenCodeGoProfile`): base `https://opencode.ai/zen/go/v1`, env `OPENCODE_GO_API_KEY`, aux `glm-5`, plus per-model reasoning controls (GLM-5.2 reasoning_effort mapping, Kimi K2 thinking, DeepSeek thinking, and a max_tokens cap for `mimo-v2.5-pro`).

Switch with `hermes config set model.provider opencode-go` — same endpoint and key as a
hand-rolled `custom` block, but you inherit `default_aux_model=glm-5` and the reasoning
controls. Config keys `model.base_url` / `model.api_key` become inert (harmless) once a
profile is set; `_openai_discovery_base_url` only special-cases openai providers.

## Cron model-drift guard

- Jobs snapshot their model/provider at creation. Changing the global provider emits:
  `1 enabled unpinned cron job has stored provider_snapshot values that differ from the new
  global provider. They will fail closed on their next run...` — and `cron.model_drift_guard: True`
  (default) enforces exactly that: fail closed rather than silently run on a changed model.
- Clean fix: `hermes config set cron.model <model>` + `cron.model_provider <provider>`.
  Per the config comment, unpinned jobs then follow `cron.model` deliberately and the guard
  does not engage for the model axis.
- The warning text also suggests per-job pinning via `cronjob action=update job_id=<id>
  provider=<p> model=<m>`; the scheduler reads `job.get("model")` — the config-level
  `cron.model` route is the one verified end-to-end in this session.

## Aliases (`hermes_cli/model_switch.py`)

- Direct (user) aliases load first (`_ensure_direct_aliases`), then built-in `MODEL_ALIASES`
  resolved against the current provider's catalog (highest version of `vendor/family`).
- Config formats:
  - `hermes config set model.aliases.<name> <model>` — value with NO `provider/` prefix uses
    the current provider at resolution time; `provider/model` prefix form also accepted.
  - `model_aliases:` dict form in config.yaml: `name: {model: "...", provider: "...", base_url: "..."}`
    for cross-provider switches (e.g. a local Ollama).
- Works in the gateway chat as `/model <alias>`; in CLI as `hermes chat -m <alias>`.

## Live-test recipe (verify before recommending)

```bash
source ~/.hermes/.env   # never echo the key
curl -s --max-time 30 https://opencode.ai/zen/go/v1/models -H "Authorization: Bearer ${OPENCODE_GO_API_KEY}"
# per candidate (tiny max_tokens → cheap availability probe):
for m in glm-5 deepseek-v4-pro kimi-k2.7-code qwen3.8-max; do
  curl -s --max-time 30 https://opencode.ai/zen/go/v1/chat/completions \
    -H "Authorization: Bearer ${OPENCODE_GO_API_KEY}" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":5}" | head -c 200; echo
done
```

All four above returned `chat.completion` objects (2026-08) — the Go subscription key
covers the whole catalog, not just the default model. Note: this curl works without a
special User-Agent (curl sends one by default); bare `urllib` needs a browser UA
(see `references/opencode-go-provider.md`).

## Model catalog (OpenCode Go, 2026-08)

`deepseek-v4-pro`, `deepseek-v4-flash`, `qwen3.8-max`, `qwen3.7-max`, `qwen3.7-plus`,
`qwen3.6-plus`, `qwen3.5-plus`, `glm-5.2`, `glm-5.1`, `glm-5`, `kimi-k3`, `kimi-k2.7-code`,
`kimi-k2.6`, `kimi-k2.5`, `minimax-m3`, `minimax-m2.7`, `minimax-m2.5`, `mimo-v2.5-pro`,
`mimo-v2.5`, `mimo-v2-pro`, `mimo-v2-omni`, `gpt-5.6-luna`, `grok-4.5`, `hy3`, `hy3-preview`.
Source of truth at runtime: `GET /v1/models`.

## Sanity-checked config for the user's box (updated 2026-08-14)

```
model.provider: opencode-go        # official profile (was: custom)
model.default: deepseek-v4-pro     # general workhorse (IQ 53.2, 3450 req/5h) — was flash on 08-11
cron.model: deepseek-v4-flash      # + cron.model_provider: opencode-go (drift-guard satisfied)
model.aliases: pro=deepseek-v4-pro, code=kimi-k3, glm=glm-5.2, max=qwen3.8-max
```
`code` → `kimi-k3` (was `kimi-k2.7-code`): k3 beats the older code-specialist on all
shared coding benches (see llm-model-selection → coding-benchmark-research). Apply with
`hermes config set model.aliases.code kimi-k3`. Note k3 is budget-limited (110 req/5h,
~51s reasoning) — a premium-coder alias, not a daily driver.
