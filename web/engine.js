// Browser engines: SWI-Prolog (WASM, in a worker) generates notebook data,
// Typst (WASM) lays it out as SVG for preview and PDF for print.
// Mirrors scripts/render.sh, which does the same with the native CLIs.

import { TypstSnippet } from "@myriaddreamin/typst.ts/contrib/snippet";
import compilerWasm from "@myriaddreamin/typst-ts-web-compiler/pkg/typst_ts_web_compiler_bg.wasm?url";
import rendererWasm from "@myriaddreamin/typst-ts-renderer/pkg/typst_ts_renderer_bg.wasm?url";

const typstSources = import.meta.glob("/typst/**/*.typ", {
  query: "?raw",
  import: "default",
  eager: true,
});
const typstImages = import.meta.glob("/typst/**/*.png", {
  query: "?url",
  import: "default",
  eager: true,
});

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
    Object.entries(typstImages).map(async ([path, url]) => {
      const bytes = new Uint8Array(await (await fetch(url)).arrayBuffer());
      await $typst.mapShadow(local(path), bytes);
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

export async function svg(game, json, paper, theme) {
  typst ??= loadTypst();
  // The preview shows the pocket pages themselves, not the imposed sheets.
  return (await typst).svg(compileOptions(game, json, pocket(paper) ? "a6" : paper, theme));
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
