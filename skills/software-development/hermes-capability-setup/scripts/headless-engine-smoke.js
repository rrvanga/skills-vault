#!/usr/bin/env node
// Probe: can a real browser engine run headless on this box (no display, no consent)?
// Proven recipe — bundled playwright-core + SYSTEM chromium (system Chromium 151+ has --headless=new).
// Usage: node headless-engine-smoke.js [url]     (default about:blank)
// Exit 0 + prints HEADLESS-OK when the engine works; non-zero otherwise.
const fs = require('fs');
const os = require('os');
const path = require('path');

const agentDir = process.env.HERMES_AGENT_DIR || path.join(os.homedir(), '.hermes', 'hermes-agent');
const exe = '/usr/bin/chromium'; // system chromium; adjust per distro if absent

if (!fs.existsSync(exe)) { console.error('FAIL: no system chromium at', exe); process.exit(2); }

const pwcPath = path.join(agentDir, 'node_modules', 'playwright-core');
if (!fs.existsSync(pwcPath)) { console.error('FAIL: bundled playwright-core not found at', pwcPath); process.exit(2); }

const { chromium } = require(pwcPath);

(async () => {
  const b = await chromium.launch({ headless: true, executablePath: exe });
  const p = await b.newPage();
  await p.goto(process.argv[2] || 'about:blank');
  console.log('HEADLESS-OK | title=' + JSON.stringify(await p.title()) + ' | engine=' + b.version());
  await b.close();
})().catch(e => { console.error('FAIL:', e.message); process.exit(1); });