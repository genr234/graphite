// Browser engines: SWI-Prolog (WASM) generates notebook data,
// Typst (WASM) lays it out as SVG for preview and PDF for print.
// Mirrors scripts/render.sh, which does the same with the native CLIs.

import SWIPL from "swipl-wasm";
import { $typst } from "@myriaddreamin/typst.ts";
import compilerWasm from "@myriaddreamin/typst-ts-web-compiler/pkg/typst_ts_web_compiler_bg.wasm?url";
import rendererWasm from "@myriaddreamin/typst-ts-renderer/pkg/typst_ts_renderer_bg.wasm?url";

const prologSources = import.meta.glob("/prolog/**/*.pl", {
  query: "?raw",
  import: "default",
  eager: true,
});
const typstSources = import.meta.glob("/typst/**/*.typ", {
  query: "?raw",
  import: "default",
  eager: true,
});

let prolog;
let typst;

async function loadProlog() {
  const swipl = await SWIPL({ arguments: ["-q"] });
  for (const [path, source] of Object.entries(prologSources)) {
    const dir = path.slice(0, path.lastIndexOf("/"));
    swipl.FS.mkdirTree(dir);
    swipl.FS.writeFile(path, source);
  }
  const loaded = swipl.prolog.query("consult('/prolog/graphite.pl')").once();
  if (loaded.error) throw new Error(loaded.message);
  return swipl;
}

async function loadTypst() {
  $typst.setCompilerInitOptions({ getModule: () => compilerWasm });
  $typst.setRendererInitOptions({ getModule: () => rendererWasm });
  for (const [path, source] of Object.entries(typstSources)) {
    // "/typst/lib/grid.typ" -> "/lib/grid.typ", matching --root typst natively.
    await $typst.addSource(path.replace(/^\/typst/, ""), source);
  }
  return $typst;
}

export async function generate(game, seed) {
  prolog ??= loadProlog();
  const swipl = await prolog;
  const result = swipl.prolog
    .query("graphite:generate_json(Game, Seed, Json)", { Game: game, Seed: seed })
    .once();
  if (!result.success) throw new Error(result.message ?? "generation failed");
  return String(result.Json);
}

function compileOptions(game, json, paper) {
  return { mainFilePath: `/${game}.typ`, inputs: { data: json, paper } };
}

export async function svg(game, json, paper) {
  typst ??= loadTypst();
  return (await typst).svg(compileOptions(game, json, paper));
}

export async function pdf(game, json, paper) {
  typst ??= loadTypst();
  return (await typst).pdf(compileOptions(game, json, paper));
}
