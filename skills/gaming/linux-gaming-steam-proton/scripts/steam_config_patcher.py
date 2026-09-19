#!/usr/bin/env python3
"""Patch Steam localconfig.vdf: force a compat tool + launch options for one game appid.

Safe by design: parses the whole VDF before touching anything (fail = abort), backs up,
dry-runs a diff, writes atomically, re-parses to verify the round trip. Only run with
Steam fully closed (Steam rewrites this file from memory while running).

Usage:
  python3 steam_config_patcher.py --dry-run
  python3 steam_config_patcher.py --appid 2369390 --launch 'gamemoderun prime-run %command%' --tool GE-Proton11-7
"""

import argparse
import os
import shutil
import sys
import time

STEAM3_ID = "677483458"  # numeric dir under userdata/; per-account

DEFAULT_APPID = "2369390"  # Far Cry 6
DEFAULT_LAUNCH = "gamemoderun prime-run %command%"
DEFAULT_TOOL = "GE-Proton11-7"
DEFAULT_CONFIG = os.path.expanduser(
    f"~/.steam/root/userdata/{STEAM3_ID}/config/localconfig.vdf"
)


class VDFError(ValueError):
    pass


class VDFParser:
    """Minimal VDF parser for the subset Steam uses (strings, nested dicts)."""

    def __init__(self, text):
        self.text = text
        self.pos = 0
        self.n = len(text)

    def skip_ws(self):
        while self.pos < self.n and self.text[self.pos] in " \t\r\n":
            self.pos += 1

    def parse_string(self):
        self.skip_ws()
        if self.pos >= self.n or self.text[self.pos] != '"':
            raise VDFError(f"expected string at {self.pos}")
        self.pos += 1
        out = []
        while self.pos < self.n:
            c = self.text[self.pos]
            if c == '"':
                self.pos += 1
                return "".join(out)
            if c == "\\" and self.pos + 1 < self.n:
                nxt = self.text[self.pos + 1]
                if nxt in ('"', "\\"):
                    out.append(nxt)
                    self.pos += 2
                    continue
            out.append(c)
            self.pos += 1
        raise VDFError("unterminated string")

    def parse_value(self):
        self.skip_ws()
        if self.pos >= self.n:
            raise VDFError("unexpected EOF")
        c = self.text[self.pos]
        if c == "{":
            self.pos += 1
            d = {}
            while True:
                self.skip_ws()
                if self.pos >= self.n:
                    raise VDFError("unterminated dict")
                if self.text[self.pos] == "}":
                    self.pos += 1
                    return d
                key = self.parse_string()
                val = self.parse_value()
                d[key] = val
        if c == '"':
            return self.parse_string()
        raise VDFError(f"unexpected token {c!r} at {self.pos}")

    def parse(self):
        """Top level is key->value, exactly like a dict entry."""
        self.skip_ws()
        if self.pos >= self.n:
            raise VDFError("empty file")
        if self.text[self.pos] == "{":
            return self.parse_value()
        self.parse_string()
        return self.parse_value()


def serialize(d, indent=0):
    """Serialize a dict back to VDF (quoted keys/values, braces, tabs)."""
    out = []
    pad = "\t" * indent
    for k, v in d.items():
        out.append(f'{pad}"{k}"\n')
        if isinstance(v, dict):
            out.append(f"{pad}{{\n")
            out.append(serialize(v, indent + 1))
            out.append(f"{pad}}}\n")
        else:
            out.append(f'{pad}\t"{v}"\n')
    return "".join(out)


def load_config(path):
    with open(path, "r", encoding="utf-8") as fh:
        return VDFParser(fh.read()).parse()


def steam_section(cfg):
    try:
        return cfg["UserLocalConfigStore"]["Software"]["Valve"]["Steam"]
    except KeyError:
        raise VDFError("config lacks UserLocalConfigStore/Software/Valve/Steam")


def planned_changes(steam, appid, launch, tool):
    apps = steam.setdefault("apps", {})
    app = apps.setdefault(appid, {})
    old_launch = app.get("LaunchOptions")
    ctm = steam.setdefault("CompatToolMapping", {})
    old_tool = ctm.get(appid)
    return app, old_launch, ctm, old_tool


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--appid", default=DEFAULT_APPID)
    ap.add_argument("--launch", default=DEFAULT_LAUNCH, help="launch options string")
    ap.add_argument("--tool", default=DEFAULT_TOOL, help="compat tool name")
    ap.add_argument("--config", default=DEFAULT_CONFIG, help="localconfig.vdf path")
    ap.add_argument("--dry-run", action="store_true", help="print planned changes, write nothing")
    args = ap.parse_args()

    cfg = load_config(args.config)
    steam = steam_section(cfg)
    app, old_launch, ctm, old_tool = planned_changes(steam, args.appid, args.launch, args.tool)

    print("planned changes:")
    print(f"  LaunchOptions   : {old_launch!r} -> {args.launch!r}")
    print(f"  CompatTool      : {old_tool!r} -> {{\'name\': {args.tool!r}, \'priority\': 250}}")

    if args.dry_run:
        print("dry-run: no changes written")
        return 0

    backup = args.config + ".bak-" + str(int(time.time()))
    shutil.copy2(args.config, backup)
    print(f"backup: {backup}")

    app["LaunchOptions"] = args.launch
    ctm[args.appid] = {"name": args.tool, "config": "", "priority": "250"}

    tmp = args.config + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(serialize(cfg))
    os.replace(tmp, args.config)

    # Round-trip verify: re-parse what we wrote and compare the blocks.
    check = load_config(args.config)
    s = steam_section(check)
    assert s["apps"][args.appid]["LaunchOptions"] == args.launch
    assert s["CompatToolMapping"][args.appid]["name"] == args.tool
    assert s["CompatToolMapping"][args.appid]["priority"] == "250"
    print("applied + verified round-trip parse OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
