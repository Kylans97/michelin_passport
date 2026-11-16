import { defineConfig } from 'astro/config';

// The public site, built to plain static HTML so every page is readable
// by search engines without running any script.
export default defineConfig({
  site: 'https://mantelier.app',
  output: 'static',
  trailingSlash: 'never',
  build: { format: 'file' },
});
