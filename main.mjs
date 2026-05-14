// Entry point for Bun compilation
// Intercepts "lsp" arg to launch TypeScript LSP server,
// otherwise runs the Gleam-compiled CLI.
//
// Wrapped in an async IIFE because `bun build --compile --bytecode`
// rejects top-level await in the entry module.

const args = process.argv.slice(2);

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
