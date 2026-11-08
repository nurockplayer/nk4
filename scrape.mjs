import { chromium, firefox, webkit } from 'playwright';

const URL = process.argv[2];
const engine = (process.argv[3] || process.env.NK4_ENGINE || 'chromium').toLowerCase();
const browserTypes = { chromium, chrome: chromium, firefox, webkit };

if (!URL) {
  console.error('Usage: node scrape.mjs <url|--probe-browser> [engine]');
  process.exit(1);
}
if (!browserTypes[engine]) {
  console.error(JSON.stringify({ error: `不支援的 Playwright 引擎：${engine}` }));
  process.exit(1);
}

async function main() {
  const launchOptions = engine === 'chrome'
    ? { headless: true, channel: 'chrome' }
    : { headless: true };
  const browser = await browserTypes[engine].launch(launchOptions);
  if (URL === '--probe-browser') {
    await browser.close();
    return;
  }
  // Let each engine provide its own correct, current user agent.
  const context = await browser.newContext();
  const page = await context.newPage();

  const m3u8Urls = new Set();
  page.on('response', (response) => {
    const url = response.url();
    if (url.includes('.m3u8')) m3u8Urls.add(url);
  });
  page.on('request', (request) => {
    const url = request.url();
    if (url.includes('.m3u8')) m3u8Urls.add(url);
  });

  await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(5000);

  const ogTitle = await page.$eval('meta[property="og:title"]', el => el.getAttribute('content')).catch(() => null);

  const html = await page.content();
  const m3u8Regex = /https?:\/\/[^"'\s]+\.m3u8[^"'\s]*/g;
  const foundInHtml = html.match(m3u8Regex);
  if (foundInHtml) foundInHtml.forEach(url => m3u8Urls.add(url));

  const scripts = await page.$$eval('script', els => els.map(el => el.textContent || ''));
  for (const script of scripts) {
    const matches = script.match(m3u8Regex);
    if (matches) matches.forEach(url => m3u8Urls.add(url));
  }

  // Domain-specific CDN priority
  const domainPriorities = {
    'jable.tv':   ['mushroomtrack', 'edge-hls'],
    'missav.ai':  ['surrit.com', 'edge-hls'],
  };
  const domain = Object.keys(domainPriorities).find(d => URL.includes(d)) || '';
  const cdnOrder = domainPriorities[domain] || [];

  const sorted = [...m3u8Urls].sort((a, b) => {
    const cdnScore = (url) => {
      const idx = cdnOrder.findIndex(cdn => url.includes(cdn));
      return idx >= 0 ? (cdnOrder.length - idx) * 10 : 0;
    };
    // Prefer resolution-specific video.m3u8 over generic playlist.m3u8
    const specificScore = (url) => url.match(/\d{3,4}p\/video\.m3u8/) ? 5 : url.endsWith('playlist.m3u8') ? 2 : 3;
    return (cdnScore(b) + specificScore(b)) - (cdnScore(a) + specificScore(a));
  });

  const result = {
    title: ogTitle || '',
    m3u8Url: sorted[0] || '',
    allM3u8Urls: sorted
  };

  console.log(JSON.stringify(result));
  await browser.close();
}

main().catch(err => {
  console.error(JSON.stringify({ error: err.message }));
  process.exit(1);
});
