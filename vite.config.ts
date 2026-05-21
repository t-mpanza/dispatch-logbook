import { defineConfig } from "vite";
import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import { TanStackRouterVite } from "@tanstack/router-plugin/vite";
import viteReact from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import tsConfigPaths from "vite-tsconfig-paths";
import { VitePWA } from "vite-plugin-pwa";

const base = process.env.GITHUB_PAGES ? "/dispatch-logbook/" : "/";

export default defineConfig({
  base,
  plugins: [
    TanStackRouterVite(),
    tanstackStart({
      prerender: {
        enabled: true,
      },
    }),
    viteReact(),
    tailwindcss(),
    tsConfigPaths(),
    VitePWA({
      // We manage SW registration ourselves in __root.tsx via useEffect (SSR-safe).
      // VitePWA's job here is: generate the correct manifest and build the SW.
      strategies: "injectManifest",
      srcDir: "public",
      filename: "sw.js",
      injectRegister: null,
      injectManifest: {
        // Our SW handles its own caching — don't inject a Workbox precache manifest
        injectionPoint: undefined,
      },
      manifest: {
        name: "Dispatch Diary",
        short_name: "Diary",
        description: "Fast-capture operational diary for dispatch work.",
        start_url: base,
        scope: base,
        display: "standalone",
        orientation: "portrait",
        background_color: "#0a0a1a",
        theme_color: "#0a0a1a",
        icons: [
          {
            src: "icon-512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "any maskable",
          },
        ],
      },
    }),
  ],
  server: {
    middlewareMode: true,
  },
  build: {
    target: "esnext",
    minify: "esbuild",
    sourcemap: false,
  },
});
