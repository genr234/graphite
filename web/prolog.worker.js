// SWI-Prolog runs here so a multi-second notebook generation never blocks the UI.

import SWIPL from "swipl-wasm";

const sources = import.meta.glob("/prolog/**/*.pl", {
  query: "?raw",
  import: "default",
  eager: true,
});

const ready = (async () => {
  const swipl = await SWIPL({ arguments: ["-q"] });
  for (const [path, source] of Object.entries(sources)) {
    swipl.FS.mkdirTree(path.slice(0, path.lastIndexOf("/")));
    swipl.FS.writeFile(path, source);
  }
  const loaded = swipl.prolog.query("consult('/prolog/graphite.pl')").once();
  if (loaded.error) throw new Error(loaded.message);
  return swipl;
})();

self.onmessage = async ({ data: { id, game, seed } }) => {
  try {
    const swipl = await ready;
    const result = swipl.prolog
      .query("graphite:generate_json(Game, Seed, Json)", { Game: game, Seed: seed })
      .once();
    if (!result.success) throw new Error(result.message ?? "generation failed");
    self.postMessage({ id, json: String(result.Json) });
  } catch (error) {
    self.postMessage({ id, error: String(error?.message ?? error) });
  }
};
