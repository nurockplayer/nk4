import { chromium } from 'playwright';

const URL = process.argv[2];
if (!URL) {
  console.error('Usage: node scrape.mjs <jable-url>');
  process.exit(1);
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
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

  // Prefer mushroomtrack or similar CDN over edge/media variants
  const sorted = [...m3u8Urls].sort((a, b) => {
    const aScore = a.includes('mushroomtrack') ? 2 : a.includes('edge-hls') ? 1 : 0;
    const bScore = b.includes('mushroomtrack') ? 2 : b.includes('edge-hls') ? 1 : 0;
    return bScore - aScore;
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
