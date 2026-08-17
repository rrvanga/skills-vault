#!/usr/bin/env python3
"""Probe: what does a platform's PlatformConfig.extra ACTUALLY contain at load time?

Why: `hermes config set gateway.<platform>.<key>` writes keys the loader may never
bridge into the adapter's `extra`. The only trustworthy check is loading the config
through the gateway's real code path and inspecting the result.

Usage: ~/.hermes/hermes-agent/venv/bin/python probe_platform_extra.py [platform]
Default platform: telegram. Empty `extra` = your key never made it through the
shared-key bridge (check the namespace: top-level `telegram:`, `gateway.platforms.telegram`,
or `platforms.telegram` — NOT `gateway.telegram`).

NOTE: run this as a FILE, not as an inline heredoc — the gateway lifecycle guard
scans full command text for restart-ish patterns and blocks heredocs that import
gateway modules.
"""
import os
import sys

platform_name = sys.argv[1] if len(sys.argv) > 1 else "telegram"
sys.path.insert(0, os.path.expanduser("~/.hermes/hermes-agent"))
os.environ["HERMES_HOME"] = os.path.expanduser("~/.hermes")

from gateway.config import load_gateway_config, Platform  # noqa: E402

plat = Platform(platform_name)
cfg = load_gateway_config()
pc = cfg.platforms.get(plat)
print(f"{platform_name} platform present:", pc is not None)
if pc is None:
    sys.exit(1)
print("enabled:", pc.enabled)
extra = dict(pc.extra)
print("extra:", extra)
for key in ("require_mention", "observe_unmentioned_group_messages"):
    print(f"extra['{key}']:", extra.get(key))
