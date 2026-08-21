import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://modern-swift-dev.github.io",
  base: "/pathways-swift",
  output: "static",
  outDir: "./dist",
  vite: {
    plugins: [tailwindcss()],
  },
});
