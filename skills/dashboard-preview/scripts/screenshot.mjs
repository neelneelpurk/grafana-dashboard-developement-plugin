#!/usr/bin/env node
// Playwright CLI fallback: screenshot a Grafana dashboard URL.
// Usage: node screenshot.mjs <dashboard-url> <output.png> [grafanaUser] [grafanaPass]
// Requires: npm i -D playwright  (and `npx playwright install chromium`)
import { chromium } from 'playwright';

const [, , url, out = 'dashboard.png', user = 'admin', pass = 'admin'] = process.argv;
if (!url) {
  console.error('usage: node screenshot.mjs <dashboard-url> <output.png> [user] [pass]');
  process.exit(1);
}

const renderUrl = url.includes('?') ? `${url}&kiosk&refresh=` : `${url}?from=now-6h&to=now&kiosk&refresh=`;

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1600, height: 900 } });
const page = await ctx.newPage();

await page.goto(renderUrl, { waitUntil: 'networkidle' });

// Handle Grafana login if presented.
if (await page.locator('input[name="user"]').count()) {
  await page.fill('input[name="user"]', user);
  await page.fill('input[name="password"]', pass);
  await page.click('button[type="submit"]');
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

await browser.close();
