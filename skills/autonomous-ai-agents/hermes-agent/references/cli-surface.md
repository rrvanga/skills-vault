# Hermes CLI surface — snapshot (v0.21.0, 2026.8.31, git a6e10e69)

Generated live 2026-09-05 from `hermes --help` (binary: ~/.hermes/hermes-agent/venv/bin/hermes).
Regenerate with the same command when the version changes — this file rots with releases.

## Top-level commands (61)

| Command | Purpose (from help) |
|---|---|
| chat | Interactive chat with the agent |
| model | Select default model and provider |
| moa | Configure Mixture of Agents provider/model slots |
| fallback | Manage fallback providers (tried when the primary model fails) |
| worktree | Audit and reclaim accumulated git worktrees and merged branches |
| browser | Real-profile browsing helpers (close a browser locking its profile) |
| secrets | Manage external secret sources (Bitwarden, 1Password) |
| egress | Manage the iron-proxy egress credential-injection firewall |
| migrate | Migrate configuration for retired models or deprecated settings |
| gateway | Messaging gateway management |
| proxy | Local OpenAI-compatible proxy to OAuth providers |
| lsp | Language Server Protocol management |
| setup | Interactive setup wizard |
| whatsapp / whatsapp-cloud / slack | Platform integration helpers |
| send | Send a message to a configured platform (scripts, cron jobs, CI) |
| login / logout / auth | Provider auth (auth = pooled credentials) |
| status | Show status of all components |
| pause / resume | Emergency stop / lift: pause cron+kanban dispatch and new gateway turns |
| cron | Cron job management |
| sync | Skill Sync — skills across devices/team |
| webhook | Manage dynamic webhook subscriptions |
| peer | Bot-to-bot DMs across machines (peer gateways) |
| portal | Nous Portal (login, model pick, Tool Gateway) |
| kanban | Multi-profile collaboration board |
| project | Projects (named multi-folder workspaces) |
| hooks | Inspect/manage shell-script hooks |
| doctor | Check configuration and dependencies |
| verify | Detect a project's run recipe and smoke-test it |
| security | Supply-chain audit (OSV.dev) for venv, plugins, MCP servers |
| approvals | Approval-prompt tools (mine history into allowlist proposals) |
| dump / debug | Setup summary / upload logs+info for support |
| **backup** | **Back up Hermes home directory to a zip file** |
| **checkpoints** | **Inspect / prune / clear ~/.hermes/checkpoints/** |
| **import** | **Restore a Hermes backup from a zip file** |
| import-agent | Import a Claude Code or Codex CLI setup into Hermes |
| config | View and edit configuration |
| skin | List, switch, tweak skins |
| console | Safe Hermes command console |
| pairing | DM pairing codes for user authorization |
| skills | Search, install, configure, manage skills |
| bundles | Skill bundles (aliases for multiple skills) |
| plugins | Manage and validate plugins |
| curator | Background skill maintenance — status, run, pause, pin |
| pets | Petdex animated pets |
| journey (learning, memory-graph) | Timeline of learned skills + memories |
| memory | Configure external memory provider |
| tools | Configure per-platform tool enablement |
| computer-use | Manage cua-driver backend |
| mcp | MCP server management / run Hermes as MCP server |
| sessions | Manage session history (list, rename, export, prune, delete) |
| insights | Usage insights and analytics |
| monitoring | Gateway monitoring (health & diagnostics export) |
| claw | OpenClaw migration tools |
| update / uninstall | Version management |
| acp | Run as ACP server |
| profile | Profiles — multiple isolated instances |
| completion | Shell completion script |
| dashboard | Web UI dashboard |
| serve | Backend server (headless; powers desktop app) |
| desktop (gui) | Native desktop app |
| logs | View and filter Hermes log files |
| prompt-size | Byte breakdown of system prompt + tool schemas |

## Notable flags (from --help)

- `-z/--oneshot PROMPT` — single prompt, prints ONLY final response text; tools/memory/rules/AGENTS.md load normally; approvals auto-bypassed; for scripts/pipes
- `--usage-file PATH` — oneshot only: JSON usage report (cost, tokens, model, api_calls); written even on failure
- `-m/--model`, `--provider`, `--reasoning` — invocation overrides (persistent state lives in config.yaml)
- `-t/--toolsets` — comma-separated toolsets for this run
- `-r/--resume SESSION`, `--continue [NAME]` — session resume

## Lessons baked into this snapshot

- Backup saga failure (2026-09-04): `hermes backup` (zip), `--quick` snapshots, and `/snapshot` all existed since 2026-04-11/04-13 — an audit at build time would have prevented the custom layer.
- `hermes checkpoints` manages pruning of `~/.hermes/checkpoints/` — check it before writing custom retention logic.
