#!/usr/bin/env python3
"""Probe: list a Telegram group's admins (id/username/is_bot) + member count.

Usage:
    probe_group_roster.py <chat_id> [output_file]

Reads TELEGRAM_BOT_TOKEN from ~/.hermes/.env (never prints it).
Useful to: identify humans vs bots in a group, spot members who have never
interacted with the gateway, and confirm a bot's numeric user ID.

NOTE: the Bot API has no member-list endpoint — non-admin members are NOT
returned. To learn a silent member's ID, have them post a test message and
read the ID from the gateway's "Blocked unauthorized user <id>" log line.
"""
import json
import os
import sys
import urllib.request


def load_env(path: str) -> dict:
    env = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return env


def api_call(token: str, method: str, params: dict) -> dict:
    url = f"https://api.telegram.org/bot{token}/{method}"
    req = urllib.request.Request(
        url,
        data=json.dumps(params).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    chat_id = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else None

    env = load_env(os.path.expanduser("~/.hermes/.env"))
    token = env.get("TELEGRAM_BOT_TOKEN", "")
    if not token:
        print("ERROR: TELEGRAM_BOT_TOKEN not found in ~/.hermes/.env", file=sys.stderr)
        return 1

    lines = []
    try:
        admins = api_call(token, "getChatAdministrators", {"chat_id": chat_id})
        lines.append("== getChatAdministrators ==")
        for a in admins.get("result", []):
            u = a.get("user", {})
            lines.append(
                "  id={} username={} first={} is_bot={}".format(
                    u.get("id"),
                    u.get("username"),
                    u.get("first_name"),
                    u.get("is_bot"),
                )
            )
    except Exception as e:  # noqa: BLE001 - report and continue
        lines.append(f"ERROR getChatAdministrators: {e}")

    try:
        count = api_call(token, "getChatMemberCount", {"chat_id": chat_id})
        lines.append("== getChatMemberCount ==")
        lines.append(f"  {count.get('result')}")
    except Exception as e:  # noqa: BLE001
        lines.append(f"ERROR getChatMemberCount: {e}")

    output = "\n".join(lines)
    if out_path:
        with open(out_path, "w") as f:
            f.write(output + "\n")
        print(f"wrote {out_path}")
    else:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
