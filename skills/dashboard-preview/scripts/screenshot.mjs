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

// Handle Grafana login if presented. Selectors vary across Grafana versions, so try a few.
const userField = page
  .locator('input[name="user"], input[data-testid="data-testid Username input field"], input[aria-label="Username input field"]')
  .first();
if (await userField.count()) {
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

await browser.close();
