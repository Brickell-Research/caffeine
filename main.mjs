// Entry point for Bun compilation.
// Routes "lsp" to the TypeScript LSP server, fast-paths --version to skip the
// Gleam CLI import on probe-style invocations (CI, IDE update checks),
// otherwise runs the Gleam-compiled CLI.

import pkg from "./package.json" with { type: "json" };

const args = process.argv.slice(2);

// Mirrors caffeine_cli.gleam:67-72: --version/-v anywhere in args wins,
// except when "lsp" is the first arg (LSP subcommand takes precedence).
if (args[0] !== "lsp" && args.some((a) => a === "--version" || a === "-v")) {
  process.stdout.write(`caffeine ${pkg.version} (Brickell Research)\n`);
  process.exit(0);
}

if (args.includes("lsp")) {
  // Dynamic import keeps vscode-languageserver out of the CLI hot path;
  // the LSP module installs stdin listeners that keep the process alive.
  import("./lsp_server.ts");
} else {
  // Dynamic import keeps the Gleam CLI off the --version fast-path above.
  import("./caffeine_cli/build/dev/javascript/caffeine_cli/caffeine_cli.mjs")
    .then(({ main }) => main());
}
