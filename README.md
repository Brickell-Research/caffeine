# caffeine

<div align="center">

[![GitHub Release](https://img.shields.io/github/v/release/Brickell-Research/caffeine?style=for-the-badge&logo=github)](https://github.com/Brickell-Research/caffeine/releases)
[![Homebrew](https://img.shields.io/badge/homebrew-caffeine__lang-FBB040?style=for-the-badge&logo=homebrew&logoColor=white)](https://github.com/brickell-research/homebrew-caffeine)
[![CI](https://img.shields.io/github/actions/workflow/status/Brickell-Research/caffeine/test.yml?style=for-the-badge&logo=github&label=tests)](https://github.com/Brickell-Research/caffeine/actions/workflows/test.yml)

CLI and Language Server for the [Caffeine](https://caffeine-lang.run) DSL — generates reliability SLOs from service expectation definitions.

</div>

***

## Installation

### Homebrew (macOS / Linux)

```bash
brew tap brickell-research/caffeine
brew install caffeine_lang
```

### GitHub Releases

Download pre-built binaries for Linux (x64/ARM64), macOS (x64/ARM64), and Windows (x64) from [Releases](https://github.com/Brickell-Research/caffeine/releases).

## Usage

```bash
caffeine compile <measurements_dir> <expectations_dir> [output_path]
caffeine validate <measurements_dir> <expectations_dir>
caffeine format <path> [--check]
caffeine lsp        # Start the Language Server
caffeine artifacts  # List SLO params
caffeine types      # Show type system reference
```

## Architecture

This repo contains:
- **caffeine_cli** — CLI wrapping the compiler (compile, validate, format, etc.)
- **caffeine_lsp** — Language Server Protocol implementation (diagnostics, hover, completion, go-to-definition, and more)
- **TypeScript LSP transport** — thin bridge between `vscode-languageserver-node` and compiled Gleam

The compiler core ([`caffeine_lang`](https://github.com/Brickell-Research/caffeine_lang)) is a separate Gleam library consumed from [Hex](https://hex.pm/packages/caffeine_lang).

## Development

```bash
make build    # Build all packages
make test     # Run tests (Erlang target)
make test-js  # Run tests (JavaScript target)
make test-e2e # Run LSP end-to-end tests
make ci       # lint + build + test
```

### Working with a local caffeine_lang

```bash
make dev-link                    # Switch to local ../caffeine_lang
make dev-link CAFFEINE_LANG_PATH=../../caffeine_lang  # Custom path
make dev-unlink                  # Restore Hex dependency
```

## Learn more

- [Website](https://caffeine-lang.run)
- [Compiler core repo](https://github.com/Brickell-Research/caffeine_lang)
- [Hex package](https://hex.pm/packages/caffeine_lang)
