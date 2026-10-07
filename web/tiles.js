// Theme tile images, keyed by path under /typst ("/themes/parkland/tee.png").
// Shared by the Typst engine and the home page covers, which must not pull
// in the engine itself.

const urls = import.meta.glob("/typst/themes/**/*.png", {
  query: "?url",
  import: "default",
  eager: true,
});

export const tiles = Object.fromEntries(
  Object.entries(urls).map(([path, url]) => [path.replace(/^\/typst/, ""), url]),
);

export function tileUrl(theme, name) {
  return tiles[`/themes/${theme}/${name}.png`] ?? "";
}
