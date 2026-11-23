import react from "@astrojs/react";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://evabar.michaeljier.cn",
  integrations: [react()],
  vite: { plugins: [tailwindcss()] },
});
