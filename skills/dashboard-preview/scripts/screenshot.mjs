#!/usr/bin/env node
// Playwright CLI: open a Grafana dashboard in a browser session and screenshot it.
// Requires: npm i -D playwright  (and `npx playwright install chromium`)
//
// Usage:
//   node screenshot.mjs <dashboard-url> [output.png] [options]
//
// Session reuse (so you don't re-enter credentials):
//   --storage-state <file>   replay a saved login (capture-session.sh / codegen --save-storage)
//   --cdp <endpoint>         connect to a running Chrome (e.g. http://localhost:9222) and reuse it
//   --cookie <name=value>    inject a cookie (repeatable), e.g. --cookie grafana_session=abc123
// Login fallback (when no session is supplied and a login page appears):
//   --user <u>  --pass <p>   defaults: admin / admin
//
// Env equivalents: GRAFANA_STORAGE_STATE, GRAFANA_CDP_ENDPOINT, GRAFANA_USER, GRAFANA_PASSWORD.
import { chromium } from 'playwright';

// --- tiny arg parser: positionals + --flag value -----------------------------
const argv = process.argv.slice(2);
const positional = [];
const opts = {};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith('--')) {
    const key = a.slice(2);
    if (key === 'cookie') (opts.cookie ||= []).push(argv[++i]);
    else opts[key] = argv[++i];
  } else {
    positional.push(a);
  }
}

const url = positional[0];
const out = positional[1] || 'dashboard.png';
if (!url) {
  console.error('usage: node screenshot.mjs <dashboard-url> [output.png] [--storage-state f] [--cdp url] [--cookie n=v] [--user u] [--pass p]');
  process.exit(1);
}

const storageState = opts['storage-state'] || process.env.GRAFANA_STORAGE_STATE || undefined;
const cdp = opts.cdp || process.env.GRAFANA_CDP_ENDPOINT || undefined;
const user = opts.user || process.env.GRAFANA_USER || 'admin';
const pass = opts.pass || process.env.GRAFANA_PASSWORD || 'admin';

const renderUrl = url.includes('?') ? `${url}&kiosk&refresh=` : `${url}?from=now-6h&to=now&kiosk&refresh=`;

// --- open a browser session --------------------------------------------------
// CDP: reuse a live, already-logged-in Chrome. Otherwise launch our own browser
// and replay a saved storageState if one was provided.
let browser;
let ctx;
let connectedOverCdp = false;
if (cdp) {
  browser = await chromium.connectOverCDP(cdp);
  ctx = browser.contexts()[0] || (await browser.newContext());
  connectedOverCdp = true;
} else {
  browser = await chromium.launch();
  ctx = await browser.newContext({
    viewport: { width: 1600, height: 900 },
    ...(storageState ? { storageState } : {}),
  });
}

// Optional manual cookie injection (e.g. a grafana_session value copied from DevTools).
if (opts.cookie?.length) {
  const { hostname, protocol } = new URL(url);
  await ctx.addCookies(
    opts.cookie.map((c) => {
      const eq = c.indexOf('=');
      return {
        name: c.slice(0, eq),
        value: c.slice(eq + 1),
        domain: hostname,
        path: '/',
        httpOnly: true,
        secure: protocol === 'https:',
      };
    }),
  );
}

const page = await ctx.newPage();
await page.goto(renderUrl, { waitUntil: 'networkidle' });

// Handle a Grafana login page only if a reused session didn't already authenticate us.
const userField = page
  .locator('input[name="user"], input[data-testid="data-testid Username input field"], input[aria-label="Username input field"]')
  .first();
if (await userField.count()) {
  if (storageState || cdp || opts.cookie?.length) {
    console.warn('WARNING: a reused session was supplied but Grafana still shows a login page — the session may be expired or for a different host.');
  }
  const passField = page
    .locator('input[name="password"], input[data-testid="data-testid Password input field"], input[aria-label="Password input field"]')
    .first();
  await userField.fill(user);
  await passField.fill(pass);
  await page.locator('button[type="submit"], button[data-testid="data-testid Login button"]').first().click();
  await page.waitForLoadState('networkidle');
  await page.goto(renderUrl, { waitUntil: 'networkidle' });
}

// Give panels time to run queries and render.
await page.waitForTimeout(4000);

const bodyText = await page.locator('body').innerText().catch(() => '');
if (/No data|Datasource .*error|Query error/i.test(bodyText)) {
  console.warn('WARNING: dashboard contains empty panels or datasource errors.');
}

await page.screenshot({ path: out, fullPage: true });
console.log(`Saved screenshot to ${out}`);

// When connected over CDP, just close our page and leave the user's live browser running.
if (connectedOverCdp) await page.close().catch(() => {});
else await browser.close();
