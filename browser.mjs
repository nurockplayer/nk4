import { pathToFileURL } from 'node:url';

export const browserNames = ['chromium', 'firefox', 'webkit'];

export function resolveBrowser(value = process.env.NK4_ENGINE) {
  const name = (value || 'chromium').trim().toLowerCase();
  if (!browserNames.includes(name)) {
    throw new Error(`Unsupported browser engine: ${value}. Choose ${browserNames.join(', ')}.`);
  }
  return name;
}

export async function launchBrowser(value, engines) {
  const name = resolveBrowser(value);
  const playwright = engines || await import('playwright');
  return playwright[name].launch({ headless: true });
}

// Shared by setup and both shells so installation and scraping use the same engine.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const name = resolveBrowser(process.argv[3]);
    if (process.argv[2] === 'name') console.log(name);
    else if (process.argv[2] === 'probe') {
      const browser = await launchBrowser(name);
      await browser.close();
    } else throw new Error('Usage: node browser.mjs <name|probe> [chromium|firefox|webkit]');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
