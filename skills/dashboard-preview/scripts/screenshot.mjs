#!/usr/bin/env node
// Playwright CLI: open a Grafana dashboard in a browser session and screenshot it.
// Requires: npm i -D playwright  (and `npx playwright install chromium`)
// Built to run cleanly: launches with --no-sandbox (root/containers), navigates on
// domcontentloaded with bounded waits (no hanging on live dashboards), and times out fast.
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
let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch {
  console.error('Playwright is not installed. Install it first:');
  console.error('  npm i -D playwright && npx playwright install chromium');
  console.error('(Or just use Playwright MCP, which is bundled with this plugin.)');
  process.exit(1);
}

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
  // --no-sandbox is required to launch Chromium as root (containers/CI); --disable-dev-shm-usage
  // avoids crashes on small /dev/shm.
  browser = await chromium.launch({ args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  ctx = await browser.newContext({
    viewport: { width: 1600, height: 900 },
    ...(storageState ? { storageState } : {}),
  });
}

// Fail fast instead of hanging if Grafana is slow/unreachable.
ctx.setDefaultNavigationTimeout(20000);
ctx.setDefaultTimeout(20000);

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

// Live Grafana dashboards keep network activity open (Grafana Live, streaming queries), so
// 'networkidle' often never settles and would hang until timeout. Navigate on 'domcontentloaded'
// (fast) and wait for panels to actually render below.
async function settle() {
  // Wait for at least one panel to mount, then a brief networkidle window — both bounded, so a
  // busy or empty dashboard never blocks the screenshot.
  await page
    .waitForSelector('[data-panelid], [data-viz-panel-key], .panel-container, section[data-testid^="data-testid Panel"]', { timeout: 12000 })
    .catch(() => {});
  await page.waitForLoadState('networkidle', { timeout: 4000 }).catch(() => {});
}

await page.goto(renderUrl, { waitUntil: 'domcontentloaded' });

const reusedSession = Boolean(storageState || cdp || opts.cookie?.length);

// Built-in Grafana username/password form (e.g. the local example stack). This only handles a
// basic-auth form — it deliberately does NOT try to drive OIDC/SSO. For SSO, supply a reused
// session instead (see the "still on login page" guidance below).
const userField = page
  .locator('input[name="user"], input[data-testid="data-testid Username input field"], input[aria-label="Username input field"]')
  .first();
const passField = page
  .locator('input[name="password"], input[data-testid="data-testid Password input field"], input[aria-label="Password input field"]')
  .first();
if (!reusedSession && (await userField.count()) && (await passField.count())) {
  await userField.fill(user);
  await passField.fill(pass);
  await page.locator('button[type="submit"], button[data-testid="data-testid Login button"]').first().click();
  await page.waitForLoadState('domcontentloaded').catch(() => {});
  await page.goto(renderUrl, { waitUntil: 'domcontentloaded' });
}

// Let panels finish querying and rendering (bounded — see settle()).
await settle();

// If we're still on a login/SSO page, a screenshot would just capture the login screen. Stop and
// tell the user how to reuse a logged-in session — the only viable path for OIDC/SSO.
if (/\/login(\/|\?|$)/.test(page.url()) || (await page.locator('a[href*="/login/"], a[href*="oauth"], a[href*="saml"], a[href*="oidc"]').count())) {
  console.error('ERROR: not authenticated — still on the Grafana login/SSO page.');
  if (reusedSession) {
    console.error('The reused session looks expired or is for a different host. Re-capture it.');
  } else {
    console.error('This Grafana needs a login. For OIDC/SSO, log in interactively once and reuse that session:');
    console.error('  1) ./capture-session.sh <grafana-url> grafana-auth.json   # complete the full SSO flow in the opened browser');
    console.error('  2) re-run with:  --storage-state grafana-auth.json');
    console.error('     (or use your live Chrome:  --cdp http://localhost:9222)');
  }
  if (connectedOverCdp) await page.close().catch(() => {});
  else await browser.close();
  process.exit(2);
}

const bodyText = await page.locator('body').innerText().catch(() => '');
if (/No data|Datasource .*error|Query error/i.test(bodyText)) {
  console.warn('WARNING: dashboard contains empty panels or datasource errors.');
}

await page.screenshot({ path: out, fullPage: true });
console.log(`Saved screenshot to ${out}`);

// When connected over CDP, just close our page and leave the user's live browser running.
if (connectedOverCdp) await page.close().catch(() => {});
else await browser.close();
