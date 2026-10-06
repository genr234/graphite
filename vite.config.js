import { defineConfig } from "vite";
import { execFileSync } from "node:child_process";

// Compile Gleam to JS before Vite resolves it, and again on every .gleam edit.
function gleam() {
  const build = () => execFileSync("gleam", ["build"], { stdio: "inherit" });
  return {
    name: "gleam",
    buildStart: build,
    handleHotUpdate({ file, server }) {
      if (!file.endsWith(".gleam")) return;
      try {
        build();
        server.ws.send({ type: "full-reload" });
      } catch {
        // gleam already printed the compile error
      }
      return [];
    },
  };
}

export default defineConfig({
  plugins: [gleam()],
  optimizeDeps: {
    // Pre-bundling breaks the wasm-pack glue's relative .wasm lookups.
    exclude: ["@myriaddreamin/typst-ts-web-compiler", "@myriaddreamin/typst-ts-renderer"],
  },
});
