import { Ok, Error } from "./gleam.mjs";
import * as engine from "/web/engine.js";

function settle(promise, callback) {
  promise.then(
    (value) => callback(new Ok(value)),
    (error) => callback(new Error(String(error?.message ?? error))),
  );
}

export function preview(game, seed, paper, theme, callback) {
  settle(
    engine.generate(game, seed).then((json) => engine.svg(game, json, paper, theme)),
    callback,
  );
}

export function download_pdf(game, seed, paper, theme, callback) {
  const work = engine
    .generate(game, seed)
    .then((json) => engine.pdf(game, json, paper, theme))
    .then((bytes) => {
      const url = URL.createObjectURL(new Blob([bytes], { type: "application/pdf" }));
      const link = document.createElement("a");
      link.href = url;
      link.download = `${game}-${seed}-${theme}.pdf`;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      return undefined;
    });
  settle(work, callback);
}
