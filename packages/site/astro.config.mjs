// @ts-check
import { defineConfig } from 'astro/config';

/**
 * Static output, no adapter, no framework integration.
 *
 * A catalogue that needs a bundle to be read is a catalogue search cannot index, and the
 * install dialog is a native `<dialog>` with a few lines of inline script — a copy button
 * does not earn a framework runtime. AC-1 asserts the absence of a server entrypoint in
 * the emitted tree rather than trusting this file, because a configuration claim is not
 * evidence about what was built.
 */
export default defineConfig({
  output: 'static',
  build: { format: 'file' },
  devToolbar: { enabled: false },
  vite: {
    ssr: {
      /*
       * Both workspace packages resolve paths from their own `import.meta.url` — the
       * registry reads recorded attribution manifests, the data package reads the run
       * records. Vite bundles linked workspace dependencies by default, which rewrites
       * that URL to the bundle's location and breaks the lookup. Keeping them external
       * means they run as the packages that were built and tested, which is also what
       * makes the site's figures the same figures the gates checked.
       */
      external: ['@plugdex/data', '@plugdex/registry'],
    },
  },
});
