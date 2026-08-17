#!/usr/bin/env python3
"""Rollup summarizer for SkillSpector JSON reports.

Usage:  python3 summarize_scan.py [report.json] [rollup.txt]
Defaults: /tmp/skills_scan.json -> /tmp/scan_rollup.txt

Prints: totals, severity/category counts, HIGH findings in NON-test files
(the verify-first list), and per-file issue counts. Writes everything to the
output file so the caller can read_file it (long terminal output collapses
to '1 lines' on the Hermes box).

NOTE: run with `env -u PYTHONPATH python3 ...` on this machine if the hermes
PYTHONPATH is exported (ABI mismatch protection, same rule as skillspector).
"""
import json, collections, os, sys

def main():
    report = sys.argv[1] if len(sys.argv) > 1 else '/tmp/skills_scan.json'
    out = sys.argv[2] if len(sys.argv) > 2 else '/tmp/scan_rollup.txt'
    with open(report) as f:
        d = json.load(f)
    issues = d.get('issues', [])
    sev = collections.Counter(i.get('severity') for i in issues)
    cat = collections.Counter(i.get('category') for i in issues)
    byfile = collections.defaultdict(collections.Counter)
    for i in issues:
        fp = i.get('location', {}).get('file', '')
        byfile[fp][i.get('severity')] += 1

    lines = []
    lines.append("TOTAL ISSUES: %d" % len(issues))
    lines.append("BY SEVERITY: %s" % dict(sev))
    lines.append("\nBY CATEGORY:")
    for c, n in cat.most_common():
        lines.append("  %4d  %s" % (n, c))

    lines.append("\nHIGH findings in NON-test files (verify each before reporting):")
    hits = 0
    for i in issues:
        fp = i.get('location', {}).get('file', '')
        if i.get('severity') == 'HIGH' and '/tests/' not in fp \
                and not os.path.basename(fp).startswith('test_'):
            hits += 1
            ln = i.get('location', {}).get('start_line', '?')
            lines.append("  [%s] conf=%s %s  %s:%s  pat=%s"
                         % (i.get('id'), i.get('confidence'), i.get('category'),
                            fp, ln, i.get('pattern')))
    lines.append("  (count: %d)" % hits)

    lines.append("\nPer-file issue counts (top 20):")
    for fp, c in sorted(byfile.items(), key=lambda kv: -sum(kv[1].values()))[:20]:
        lines.append("  %3d  %s  %s" % (sum(c.values()), dict(c), fp))

    with open(out, 'w') as fh:
        fh.write('\n'.join(lines))
    print("written %d lines -> %s" % (len(lines), out))

if __name__ == '__main__':
    main()