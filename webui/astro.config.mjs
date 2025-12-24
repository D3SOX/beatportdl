// @ts-check

import node from '@astrojs/node';
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  output: 'server',
  server: {
    host: '0.0.0.0',
    port: 3000,
  },
  adapter: node({
    mode: 'standalone',
  }),
});
