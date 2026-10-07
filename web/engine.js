// Browser engines: SWI-Prolog (WASM, in a worker) generates notebook data,
// Typst (WASM) lays it out as SVG for preview and PDF for print.
// Mirrors scripts/render.sh, which does the same with the native CLIs.

import { TypstSnippet } from "@myriaddreamin/typst.ts/contrib/snippet";
import compilerWasm from "@myriaddreamin/typst-ts-web-compiler/pkg/typst_ts_web_compiler_bg.wasm?url";
import rendererWasm from "@myriaddreamin/typst-ts-renderer/pkg/typst_ts_renderer_bg.wasm?url";
import { tiles } from "./tiles.js";

const typstSources = import.meta.glob("/typst/**/*.typ", {
  query: "?raw",
  import: "default",
  eager: true,
});

// Monster Builder parts for LABYRINTH (typst/lib/monster.typ), keyed like tiles.
const monsterUrls = import.meta.glob("/typst/monsters/*.png", {
  query: "?url",
  import: "default",
  eager: true,
});
const images = {
  ...tiles,
  ...Object.fromEntries(
    Object.entries(monsterUrls).map(([path, url]) => [path.replace(/^\/typst/, ""), url]),
  ),
};

// Prolog ------------------------------------------------------------------

const worker = new Worker(new URL("./prolog.worker.js", import.meta.url), { type: "module" });
const pending = new Map();
let nextId = 0;

worker.onmessage = ({ data: { id, json, error } }) => {
  const { resolve, reject } = pending.get(id);
  pending.delete(id);
  error ? reject(new Error(error)) : resolve(json);
};

// Generation only depends on game and seed, so theme or paper changes reuse it.
const generated = new Map();

export function generate(game, seed) {
  const key = `${game}\u0000${seed}`;
  if (!generated.has(key)) {
    const id = nextId++;
    const job = new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
    job.catch(() => generated.delete(key));
    worker.postMessage({ id, game, seed });
    generated.set(key, job);
  }
  return generated.get(key);
}

// Typst -------------------------------------------------------------------

let typst;

async function loadTypst() {
  // A private instance rather than the global $typst, which can only be
  // initialised once per page and would break on hot reload.
  const $typst = new TypstSnippet();
  $typst.setCompilerInitOptions({ getModule: () => compilerWasm });
  $typst.setRendererInitOptions({ getModule: () => rendererWasm });
  // "/typst/lib/course.typ" -> "/lib/course.typ", matching --root typst natively.
  const local = (path) => path.replace(/^\/typst/, "");
  for (const [path, source] of Object.entries(typstSources)) {
    await $typst.addSource(local(path), source);
  }
  await Promise.all(
    Object.entries(images).map(async ([path, url]) => {
      const bytes = new Uint8Array(await (await fetch(url)).arrayBuffer());
      await $typst.mapShadow(path, bytes);
    }),
  );
  return $typst;
}

function compileOptions(game, json, paper, theme) {
  return { mainFilePath: `/${game}.typ`, inputs: { data: json, paper, theme } };
}

// "pocket-a4" lays the notebook out on A6 pages, then imposes them onto A4
// sheets as a fold-and-staple booklet (typst/impose.typ). Mirrors render.sh.
const pocket = (paper) => paper === "pocket-a4";

// The preview SVG plus the page stops the game template marks with `<stop>`
// metadata, for the preview's page rail (web/ui/scroller.js). Both come from
// one compile. The preview shows the pocket pages themselves, not the imposed
// sheets.
export async function preview(game, json, paper, theme) {
  typst ??= loadTypst();
  const $typst = await typst;
  const options = compileOptions(game, json, pocket(paper) ? "a6" : paper, theme);
  const compiler = await $typst.getCompiler();
  const { vectorData, stops } = await compiler.runWithWorld(options, async (world) => {
    const { diagnostics } = await world.compile({ diagnostics: "unix" });
    if (diagnostics?.length) throw new Error(diagnostics.join("\n"));
    return {
      vectorData: world.vector().result,
      stops: await world.query({ selector: "<stop>", field: "value" }),
    };
  });
  return { svg: await $typst.svg({ vectorData }), stops };
}

export async function svg(game, json, paper, theme) {
  return (await preview(game, json, paper, theme)).svg;
}

export async function pdf(game, json, paper, theme) {
  typst ??= loadTypst();
  const $typst = await typst;
  if (!pocket(paper)) return $typst.pdf(compileOptions(game, json, paper, theme));

  const options = compileOptions(game, json, "a6", theme);
  const pages = await stage("pocket pages", () => $typst.pdf(options));
  const count = pageCount(pages);
  await $typst.mapShadow("/pocket-pages.pdf", pages);
  return stage("imposition", () => $typst.pdf({
    mainFilePath: "/impose.typ",
    inputs: { src: "/pocket-pages.pdf", pages: String(count) },
  }));
}

// Typst writes page objects uncompressed, so they can be counted directly.
function pageCount(pdf) {
  const text = new TextDecoder("latin1").decode(pdf);
  return text.match(/\/Type\s*\/Page(?![s\w])/g)?.length ?? 0;
}

async function stage(name, run) {
  try {
    return await run();
  } catch (error) {
    throw new Error(`${name}: ${error?.message ?? error}`);
  }
}
