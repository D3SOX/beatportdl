// @ts-check

import node from '@astrojs/node';
import { defineConfig } from 'astro/config';
import { checkDependenciesOnStartup } from './src/lib/config.ts';

function checkDependencies() {
  return {
    name: 'check-dependencies',
    hooks: {
      'astro:config:setup': () => {
        checkDependenciesOnStartup();
      }
    }
  }
}

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
  integrations: [checkDependencies()],
});
