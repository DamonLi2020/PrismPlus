import { defineConfig } from "vite";

export default defineConfig({
  base: "./",
  build: {
    outDir: "../PrismPlus/EditorResources",
    emptyOutDir: true,
    target: "es2022",
  },
});
