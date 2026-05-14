// Entry point for Bun compilation.
// Routes "lsp" to the TypeScript LSP server, fast-paths --version to skip the
// Gleam CLI import on probe-style invocations (CI, IDE update checks),
// otherwise runs the Gleam-compiled CLI.
//
// Wrapped in an async IIFE because `bun build --compile --bytecode`
// rejects top-level await in the entry module.

import pkg from "./package.json" with { type: "json" };

const args = process.argv.slice(2);

// Mirrors caffeine_cli.gleam:67-72: --version/-v anywhere in args wins,
// except when "lsp" is the first arg (LSP subcommand takes precedence).
if (args[0] !== "lsp" && args.some((a) => a === "--version" || a === "-v")) {
  process.stdout.write(`caffeine ${pkg.version} (Brickell Research)\n`);
  process.exit(0);
}

(async () => {
  if (args.includes("lsp")) {
    await import("./lsp_server.ts");
  } else {
    const { main } = await import(
      "./caffeine_cli/build/dev/javascript/caffeine_cli/caffeine_cli.mjs"
    );
    main();
  }
})();
