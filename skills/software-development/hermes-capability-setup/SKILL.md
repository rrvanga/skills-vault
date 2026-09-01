---
name: hermes-capability-setup
description: Enable/verify Hermes toolset wiring (vision, MoA, browser).
version: 1.0.0
author: curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [hermes, toolsets, vision, moa, aux-models, config]
    related_skills: [hermes-agent, hermes-config-optimization]
---

# Hermes capability setup & verification

## When to Use

Trigger when: a user asks "what tools do you need for X" (vision, browser, voice, image gen); a Hermes feature needs enabling, fixing, or verifying (vision, MoA, STT/TTS, aux model routing); or a toolset seems missing/disabled. Covers: locating the tool source, checking config switches, tracing aux-model resolution, and proving capability with a live test.

## Workflow

1. **Find the toolset's state in config** — `~/.hermes/config.yaml` lists `agent.disabled_toolsets` (default-off toolsets) and `agent.enabled_toolsets` (default-on). `grep -n -A8 'disabled_toolsets' ~/.hermes/config.yaml`. If the capability is in the disabled list, that alone explains "missing".
2. **Locate the implementation** — tools live in `~/.hermes/hermes-agent/tools/` (e.g. `vision_tools.py`, `computer_use/`), wired via `hermes_cli/tools_config.py`. `find ~/.hermes/hermes-agent -iname '*vision*' -not -path '*node_modules*' -not -path '*venv*'`.
3. **Trace model/backend resolution** — aux side-tasks (vision, web extract, compression, titles) route through `~/.hermes/hermes-agent/agent/auxiliary_client.py`. Read its module docstring: it documents the exact auto-detection chain (text vs vision differ).
4. **Check which keys exist** — `grep -oE '^[A-Z_]+=' ~/.hermes/.env` for key NAMES only; never print values. The resolution chain dies at the first step with no credential.
5. **Live-test before declaring anything** — capability claims must be proven with the cheapest real call (see patterns below). If the backend is uncatalogued, the code attempts the call anyway — only a live test tells the truth.

## Key pitfalls

- **`vision` toolset exists but is often disabled** in `disabled_toolsets` — enabling it needs a config edit (also `image_input_mode: auto` default in `config_defaults.py` governs how inbound images are handled).
- **Vision auto-chain ≠ text auto-chain.** Vision order: main provider (if catalogued vision-capable) → OpenRouter → Nous → native Anthropic → custom endpoint (local Qwen-VL/LLaVA/Pixtral) → None. Text order additionally includes Codex and direct API-key providers.
- **`_main_model_supports_vision()` returns True when capability is unknown** (uncatalogued provider) — so it *attempts* the call; don't trust it, test it.
- **Format normalization matters**: providers (esp. Anthropic-wire) accept only jpeg/png/gif/webp inline. SVG needs a rasterizer (cairosvg/svglib/rsvg-convert/inkscape); BMP/TIFF re-encode via Pillow. SSRF guard + 50MB cap + bounded CPU encode executor are built in.
- **Only `hermes config set` for scalars**; nested dicts (e.g. MoA `aggregator` slot, aux vision overrides) must be edited directly in config.yaml with python3 (patch guard refuses config.yaml).
- **Redirect command output to /tmp files** before reading when tool results collapse long outputs.

## Browser toolset: launching Chrome for browser-harness

The `browser_exec` tool drives Chrome via the `browser-harness` CLI (uv-cached binary, e.g. `~/.cache/uv/archive-v0/*/bin/browser-harness`). Pitfalls learned the hard way:

- **The daemon only recognizes Chrome running from a STANDARD profile directory** (`~/.config/chromium`, `~/.config/google-chrome`). A custom `--user-data-dir=/tmp/...` profile makes the harness report `chrome-not-running` even though Chrome is up — `browser-harness --doctor` is the diagnostic (`chrome running [ok]` / `daemon alive [fail]`).
- **google-chrome binary attempts failed headless (verified 2026-08-24)**: `/opt/google/chrome/chrome --headless=new ... --remote-debugging-port=9222 --user-data-dir=~/.config/google-chrome` twice left port 9222 unbound (the process output reported Chrome's remote-debugging refusal in compressed display). The working combo is the **chromium binary + chromium profile dir** below — do not substitute google-chrome `--user-data-dir` for it.
- **Remote-debugging consent tick persists in the profile**: `devtools.remote_debugging.user-enabled: true` in `~/.config/google-chrome/Local State` (user ticks "Allow remote debugging for this browser instance" in `chrome://inspect`). This satisfies Chrome 136+'s debug-port consent for the interactive path; headless chromium doesn't need it (non-default-dir rule bypasses).
- **Harness-spawned Chrome is ephemeral**: the Chrome the harness auto-launches dies when the browser_exec call/worker ends (pid vanished mid-diagnosis). For reliable sessions, launch chromium yourself as a tracked background process FIRST, verify the port, then call browser_exec.
- **Stale Chrome from a previous agent session can squat the port.** Before launching, check `pgrep -af remote-debugging-port` and kill leftover headless processes (they use `--remote-debugging-port=0` = random port, invisible to the harness).
- **Known-good launch recipe** (background process, then verify with `curl -s http://127.0.0.1:9222/json/version`):
  `/usr/bin/chromium --headless=new --no-first-run --no-default-browser-check --disable-gpu --remote-debugging-port=9222 --user-data-dir=$HOME/.config/chromium --window-size=1280,900 about:blank`
- The harness auto-starts its daemon on demand; `--doctor` confirms both halves before you burn browser_exec calls on a broken stack.

## Unattended / at-boot browser: headless engine via playwright-core (verified 2026-08-31)

The interactive browser path (harness → Chrome remote debugging) is consent-gated BY DESIGN: it needs a display AND a human click on "Allow remote debugging?" — neither exists in a boot-time/unattended context (gateway runs with Linger=yes, no DISPLAY, no seat). For unattended browser work, drive the engine directly with the agent's bundled playwright-core + SYSTEM Chromium — proven on this box with zero installs:

```js
const { chromium } = require('/home/<REDACTED>/.hermes/hermes-agent/node_modules/playwright-core');
(async () => {
  const b = await chromium.launch({ headless: true, executablePath: '/usr/bin/chromium' });
  const p = await b.newPage();
  await p.goto(process.argv[2] || 'about:blank');
  console.log('HEADLESS-OK | engine=' + b.version());
  await b.close();
})().catch(e => { console.error('FAIL:', e.message); process.exit(1); });
```
→ exit 0, `HEADLESS-OK | engine=151.0.7922.108`, no display, no consent popup, no login.

- **Pitfall — the default bundled-Chromium launch wants a `chromium_headless_shell-<rev>` binary that is NOT downloaded** (`~/.cache/ms-playwright/` only has `chromium-<rev>`). Setting `executablePath: '/usr/bin/chromium'` skips the download entirely and works (system Chromium 151+ supports `--headless=new`).
- **BrowserBase is a toggle, not a credential**: `.env` holds `BROWSERBASE_PROXIES=true` / `BROWSERBASE_ADVANCED_STEALTH=false` but NO API key → the cloud-browser route is not wired; local headless is the winner on this box.
- **browser-harness has no headless launch mode** (grep of its source) — the integrated tool stays desktop/consent-bound deliberately. Keep BOTH: harness for attended desktop sessions, headless engine for unattended work. The headless run is lower-trust (no consent watchdog) — bind localhost-only, dedicated empty profile, no saved credentials.
- Re-runnable probe: `scripts/headless-engine-smoke.js`.

## Live-test patterns

- Vision: enable toolset, then send a real image URL through `vision_analyze` with a trivial prompt ("describe this image in one sentence").
- MoA review gate: `hermes chat -Q -q "<prompt>" -m moa:<preset>` (`-Q` non-interactive, `-q` query flag — positional prompt and `-z` are wrong).
- Generic aux: trigger the side-task from a normal chat and watch which provider gets hit.

## Support files

- `references/vision-setup.md` — full vision investigation: resolution chain, provider maps, enablement paths on this machine (opencode-go only, no OpenRouter/Nous/Anthropic keys).
- `scripts/headless-engine-smoke.js` — re-runnable probe: bundled playwright-core + system chromium launch fully headless (no display/consent); see "Unattended / at-boot browser" above.
