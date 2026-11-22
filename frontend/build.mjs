import { build, context } from "esbuild";

const options = {
  entryPoints: { yarus: "frontend/src/main.jsx" },
  loader: { ".woff": "dataurl", ".woff2": "dataurl" },
  outdir: "app/assets/builds",
  bundle: true,
  minify: true,
  jsx: "automatic",
  target: ["chrome110", "firefox115", "safari16"],
  define: { "process.env.NODE_ENV": '"production"' },
  logLevel: "info",
};

if (process.argv.includes("--watch")) {
  const watcher = await context(options);
  await watcher.watch();
} else {
  await build(options);
}
