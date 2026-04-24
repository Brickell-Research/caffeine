# Caffeine CLI — Visual & Diagnostics Overhaul

A research and design proposal for making the `caffeine` CLI feel as polished as `cargo`, `deno`, `gleam`, or `ruff`. Three concrete directions; recommendation at the end.

> **Status:** Proposal, not implementation. Code snippets are illustrations.

---

## 1. Current state (Phase 1 audit)

### What ships today

The CLI source lives in `caffeine_cli/src/caffeine_cli.gleam` (entry, ~170 LOC) plus six modules under `caffeine_cli/`:

| Module | Role |
|---|---|
| `handler.gleam` (450 LOC) | Help text, command dispatch, compile/validate/format orchestration |
| `compile_presenter.gleam` | Banner, ✓/✗ status, log-level handling |
| `error_presenter.gleam` | rustc-style diagnostic renderer |
| `display.gleam` | Catalog pretty-printer (artifacts, types) |
| `color.gleam` | ANSI wrappers + `NO_COLOR` detection |
| `file_discovery.gleam` | File/dir resolution |

### Subcommands

```
caffeine compile   <measurements_dir> <expectations_dir> [output_path]
caffeine validate  <measurements_dir> <expectations_dir>
caffeine format    <path>
caffeine artifacts
caffeine types
caffeine lsp
```

Flags: `--quiet`, `--check` (format only), `--target=terraform|opentofu`, `-v`/`--version`, `--help`.

### Verbatim outputs (current)

**`caffeine --help` (v5.0.10 source — plain text):**

```
caffeine - A compiler for generating reliability artifacts from service expectation definitions.

Version: 5.0.10

USAGE:
  caffeine <command> [flags] [arguments]

COMMANDS:
  compile <measurements_dir> <expectations_dir> [output_path]
    Compile .caffeine measurements and expectations to output

  validate <measurements_dir> <expectations_dir>
    Validate .caffeine measurements and expectations without writing output

  format <path>
    Format .caffeine files

  artifacts
    List available artifacts from the standard library

  types
    Show the type system reference with all supported types

  lsp
    Start the Language Server Protocol server

FLAGS:
  --quiet       Suppress compilation progress output
  --check       Check formatting without modifying files (format only)
  --target      Code generation target: terraform or opentofu (default: terraform)
  -v, --version Show version information
  --help        Show this help message
```

**`caffeine --version`:** `caffeine 5.0.10 (Brickell Research)`

**`caffeine asdf` (unknown command):** prints `Unknown command: asdf`. No suggestion. No exit-2 distinction.

**`caffeine compile` (missing args):** prints `Usage: caffeine compile <measurements_dir> <expectations_dir> [output_path]`. No subcommand-level `--help`.

**Compile success (verbose, real):**

```
=== CAFFEINE COMPILER (terraform) ===              ← bold cyan

  ✓ Compilation succeeded                          ← green ✓

=== COMPILATION COMPLETE ===                       ← bold green
Successfully compiled terraform to /path/main.tf
```

**Compile error (rustc-style, real — already good):**

```
error[E103]: Unexpected token: expected }, got identifier
  --> /path/to/file.caf:14:8
14 | foo: "bar"
   |        ^
   = help: Did you mean 'foo'?
```

### What `gleam_community/ansi` and `color.gleam` provide

```gleam
detect_color_mode() -> ColorMode  // ColorEnabled | ColorDisabled
red / bold / cyan / blue / green / dim  // wrappers that respect ColorMode
```

Wrappers are missing `yellow` and `magenta`, which `display.gleam` then imports directly from `gleam_community/ansi` — bypassing the color mode.

### Findings worth flagging

1. **`compile_presenter.gleam` and `display.gleam` call `ansi.*` directly** (e.g. `compile_presenter.gleam:27,33,37,47`, `display.gleam:18,30,42,…`). They will emit ANSI escapes even when `NO_COLOR` is set. Only `error_presenter.gleam` honors color mode correctly.
2. **`color.gleam:14`'s `NO_COLOR` check matches `Ok(_)` — including empty string.** The [no-color.org](https://no-color.org) spec says "present and **not an empty string**." Current logic is overzealous.
3. **No TTY detection.** Color is on whenever `NO_COLOR` is unset, even when piped. Modern convention: also disable on `!isatty(stdout)`.
4. **No `--color={auto,always,never}` override**, no `FORCE_COLOR`, `CLICOLOR_FORCE`, `TERM=dumb`, or `CI=true` handling.
5. **Two parallel diagnostic models:**
    - `caffeine_lang/errors.gleam` defines `CompilationError` + `ErrorContext` with `E103`-style codes, used by the CLI.
    - `caffeine_lsp/diagnostics.gleam` defines a separate `Diagnostic` type with kebab-case codes (`measurement-not-found`, `quoted-field-name`), used by the LSP.
    - Neither exposes JSON. The two will drift; CLI and LSP will tell users different things about the same file. This is the single biggest structural finding.
6. **Error codes are well-namespaced by phase already** (`parse:100`, `validation:200`, `linker:30x`, `semantic:40x`, `codegen:50x`, `cql:60x`). Don't lose this.
7. **Custom hand-rolled arg parser** in `caffeine_cli.gleam:77`. The `argv` library is in deps but only used to load arguments. No subcommand-level `--help`. No grouped flags. No `--` separator. This is the biggest UX gap.
8. **Source snippet renderer** (`source_snippet.gleam`) shows 1 line of context above/below with ASCII gutter (`14 | …` / `   | ^^^`). Already very rustc-shaped. Only 1 line of context — could be 2.
9. **Banner is `=== CAFFEINE COMPILER (terraform) ===`** wrapping the compile run. This is loud and breaks when piped to logs (the `=== … ===` repeats fight terminal width).
10. **Warnings go to stderr via `io.println_error` ungated** (`compile_presenter.gleam:44`), unstyled, no location info. The compiler emits a `List(String)` of warnings — there's no warning *type* with a span.
11. **`format` doesn't print a diff in `--check` mode** — only the path. Gleam users (the most likely target audience) will expect a `prettier`/`gleam format`-style output; they'll get less.
12. **No `caffeine fix`, no `caffeine init`, no `caffeine explain <CODE>`.** The error renderer carries `suggestion` but nothing acts on it as a machine-applicable fix.
13. **No JSON output mode.** The LSP could share, CI tools could parse — neither is possible today.
14. **No spinner or progress.** For multi-file compiles this is fine for now (Caffeine is fast); for `validate` over 100s of files it'll matter eventually.
15. **Installed v5.0.0 binary uses a colored help generated by what looks like `glint`** (truecolor escapes, doesn't respect `NO_COLOR`). Between 5.0.0 → 5.0.10 the help got *less* polished. We should restore color but do it properly this time.

---

## 2. Research findings (Phase 2)

Full dossier in chat scrollback; the patterns that matter for this proposal:

- **rustc** — `error[CODE]:` header + arrow + line-numbered snippet + caret + labeled secondary spans + `= note:` + `= help:` + footer pointer to `--explain CODE`. JSON output has a `rendered` field carrying the human string verbatim. Suggestion enum: `MachineApplicable | MaybeIncorrect | HasPlaceholders | Unspecified`. ASCII-only by default; Unicode opt-in via `term.unicode = auto|true|false`.
- **Elm** — `-- TYPE MISMATCH ---- src/Main.elm` banner padded to terminal width. Narrative voice ("The 1st argument to `add` is not what I expect"). `Hint:` lines suggest specific named functions.
- **Gleam** — Unicode `┌─ │` boxes, `error: <sentence>` titles, two-space-aligned cargo-style status. No error codes (a gap Caffeine should *not* import).
- **Cargo** — right-aligned 12-column verbs (`Compiling`, `Finished`, `Running`) in bold green; package@version in path; `Finished `dev` profile [unoptimized + debuginfo] target(s) in 4.83s` summary line.
- **Ruff** — one-line `path:line:col: CODE [*] message` by default; rich snippet only with `--show-source`. `[*]` marker = auto-fixable. Trailing `Found N errors. M fixable with --fix.`
- **Biome** — namespaced rule paths (`lint/style/useConst`), `FIXABLE` chip, `>` gutter arrow on the offending line, **inline `- old / + new` diff** for the suggested fix.
- **Terraform** — `╷ │ … ╵` left-bar gutter for *config-block* errors that have no specific span. Useful for "your `caffeine.toml` is wrong" vs "line 14 has a type error."
- **uv** — single-tagline first line of `--help`. `--no-progress` as a top-level flag. Each option that reads from env shows `[env: UV_CACHE_DIR=]` inline.
- **Deno** — subcommands grouped under category headers (`Execution:`, `Tooling:`).
- **Standards consensus**: `--color > $CARGO_TERM_COLOR > NO_COLOR (non-empty) > FORCE_COLOR > CLICOLOR_FORCE > CLICOLOR > isatty`. `TERM=dumb` disables color *and* Unicode. `CI=true` keeps color but kills spinners. `GITHUB_ACTIONS=true` → emit `::error file=…::` annotations on stderr.
- **Accessibility**: never use color as the only signal of severity (always include the literal word `error`). Bright variants of red/green survive deuteranopia better than defaults. Box-drawing chars degrade for screen readers — ASCII is *more* accessible for snippet boxes.

---

## 3. Three design directions (Phase 3)

Each direction picks a different point on the density × personality × iconography space. The shared infra (Phase 4) supports all three; switching directions is a renderer swap, not a rewrite.

### Direction A — **Espresso** (terse, fast, minimal ceremony)

> Pitch: *Ruff for reliability artifacts.* One line per fact. Color used as a highlighter, not a frame. Built for CI logs and seasoned users running `caffeine validate` 50× a day.

**Persona:** SRE running the CLI in tight feedback loops. Knows the codebase. Wants to scan, not read.

**`caffeine` (no args):**
```
caffeine 5.0.10 — A compiler for reliability artifacts.

  compile     Compile measurements + expectations to Terraform/OpenTofu
  validate    Type-check without writing output
  format      Format .caffeine files
  artifacts   List standard-library artifacts
  types       Show the type-system reference
  explain     Explain an error code (e.g. caffeine explain E103)
  lsp         Start the language server

  --help, --version, --color={auto,always,never}, --format={human,json,github}

Run `caffeine help <command>` for details.
```

**`caffeine --version`:** `caffeine 5.0.10 (brickellresearch.org)`

**Compile success:**
```
   Compiling 12 measurements, 8 expectations
    Finished compile in 142ms — wrote main.tf, dependency_graph.mmd
```
- `Compiling` / `Finished` in **bold green**, right-aligned in a 12-col gutter.
- Filenames in **dim**.

**Validate success (no output mode):**
```
    Finished validate in 89ms — 12 measurements, 8 expectations, 0 issues
```

**Validate, errors:**
```
expectations/checkout.caf:14:8: error[E103] unexpected token, expected `}`, got identifier
expectations/checkout.caf:21:1: error[E303] duplicate identifier `latency_p99`
measurements/api.caf:7:5: warning[W201] [*] measurement `cpu_p50` defined but never used

3 issues (2 errors, 1 warning). 1 fixable with `caffeine fix`.
Run `caffeine explain E303` for more on `duplicate identifier`.
```
- Path/line/col in **bold red** (errors) or **bold yellow** (warnings).
- `[*]` in **yellow** = auto-fixable.
- Final summary always present, machine-parseable.

**Compile error with snippet (`--explain` or single-file mode):**
```
expectations/checkout.caf:14:8: error[E103] unexpected token, expected `}`, got identifier

   12 |   slo {
   13 |     window: 30d
 > 14 |     foo: "bar"
      |        ^ here
   15 |   }
   16 | }

  help: Did you mean `foo_window`?
  note: SLO blocks accept `window`, `target`, and `query`.
  link: https://caffeine.brickellresearch.org/errors/E103
```
- `>` in red marks the offending line; gutter pipe `|` and number in **dim blue**.
- `^` in **bold red**.
- `help:` / `note:` / `link:` labels in **bold cyan**.

**`--help` for a subcommand (`caffeine help compile`):**
```
caffeine compile — Compile measurements + expectations to a target.

Usage:
  caffeine compile <measurements_dir> <expectations_dir> [output_path] [flags]

Args:
  <measurements_dir>   Directory of *.caf measurement files
  <expectations_dir>   Directory of *.caf expectation files
  [output_path]        File or directory to write output to (default: stdout)

Flags:
  --target={terraform,opentofu}    Codegen target  [default: terraform]
  --quiet                          Suppress progress output
  --format={human,json,github}     Output format   [env: CAFFEINE_FORMAT]
  --color={auto,always,never}      Color control   [env: CAFFEINE_COLOR]
  --no-progress                    Disable spinners and progress
  -v, --verbose                    Verbose output (-vv for tracing)
  --explain                        Show full source snippets on errors

Examples:
  caffeine compile measurements/ expectations/
  caffeine compile measurements/ expectations/ build/main.tf
  caffeine compile measurements/ expectations/ --target=opentofu --quiet
```

**Verbose mode (`-v`):** adds one line per phase (`parse`, `link`, `analyze`, `codegen`) to the right-aligned status column.
```
       Parsed 20 files in 12ms
       Linked 12 measurements ↔ 8 expectations in 8ms
     Analyzed dependency graph in 4ms
   Generated terraform (1.2 KB) in 18ms
    Finished compile in 47ms — wrote main.tf
```

**Color palette (Espresso):**

| Role | Hex | ANSI 256 | 16-color fallback |
|---|---|---|---|
| Error | `#D7263D` | 161 | bright red + bold |
| Warning | `#F4A261` | 215 | bright yellow + bold |
| Note / link | `#2EC4B6` | 44 | bright cyan + bold |
| Success / "Compiling" | `#06A77D` | 36 | bright green + bold |
| Path / location | (default fg) + bold | — | bold |
| Gutter / dim | `#8A8A8A` | 244 | dim |
| Highlight (`[*]`, `>`) | `#FFB347` | 215 | bright yellow |

`NO_COLOR=1` strips all color; `[*]`/`>` markers stay (they're text). On `TERM=dumb`, also strip Unicode (no `→` or `↔` — use `->` and `<->`).

**Tradeoffs:**
- **Best for:** CI logs, `grep`-friendly output, iterative dev loops, large monorepos.
- **Gives up:** narrative friendliness, beginner hand-holding. A first-time user staring at `expectations/checkout.caf:14:8: error[E103] unexpected token, expected '}', got identifier` may not understand what to do — they have to run `caffeine explain E103` to get the prose.
- **Risk:** feels generic. Ruff/cargo do this well; Caffeine adds nothing visually distinctive.

---

### Direction B — **Pour-Over** (rich, narrative, Elm-influenced)

> Pitch: *Elm meets Terraform.* Errors are full-paragraph explanations with banners, prose, and named hints. Built so a junior SRE can fix their own SLO file without Slacking the platform team.

**Persona:** Mid-level engineer adopting Caffeine for the first time. May not know what an SLO target is. Will read every word of the first error they see, then internalize the patterns.

**`caffeine` (no args):**
```
☕ caffeine 5.0.10 — generate reliability artifacts from service expectations

USAGE
   caffeine <command> [flags] [args]

COMMON
   compile      Compile measurements + expectations to Terraform/OpenTofu
   validate     Type-check without writing output
   format       Format .caffeine files

REFERENCE
   artifacts    List artifacts in the standard library
   types        Show the type-system reference
   explain      Explain an error code in detail

INTEGRATION
   lsp          Start the language server (used by editors)

FLAGS
   --help, --version, --color={auto,always,never}, --format={human,json,github}

Learn more at https://caffeine.brickellresearch.org
```
- Section headers in **bold cyan**, small caps tone (one-word labels).
- The `☕` is **the only emoji**, used only on the version banner. Strips on `TERM=dumb`/non-Unicode terminals.

**Compile success:**
```
   Compiling 12 measurements and 8 expectations …
   Linked      measurements ↔ expectations
   Analyzed    dependency graph (no cycles)
   Generated   terraform (1.2 KB)
   ───────────────────────────────────────────
   Finished    in 142ms — wrote main.tf and dependency_graph.mmd

   ✓ All 8 expectations compiled successfully.
```
- Verbs in **bold cyan**, right-aligned 12-col gutter.
- The `───` separator is the only Unicode line; ASCII fallback uses `---`.
- Final `✓` line in **green**.

**Compile error:**
```
-- TYPE MISMATCH ------------------------------ expectations/checkout.caf

The `window` field of slo `latency_p99` expects a Duration, but I found a String:

    14 │     window: "30d"
       │             ^^^^^

Durations are written without quotes:

    window: 30d

Caffeine accepts these duration suffixes: ns, us, ms, s, m, h, d, w.

Hint: if you meant to give the duration as a templated value, prefix it with $:

    window: $window_default

For more information about this error, run:

    caffeine explain E103
```
- Banner `-- TYPE MISMATCH ----- path` padded to terminal width with `-`. Title in **bold red**.
- `│` gutter Unicode by default (ASCII `|` fallback). Line numbers in **dim**.
- `^^^^^` markers in **bold red**.
- Code blocks (the `window: 30d` and `window: $window_default` snippets) indented 4 spaces, no gutter, in **default fg**. Looks like prose.
- `Hint:` paragraph in **default fg** with the leading word **bold cyan**.
- Footer is **always present** and points to `caffeine explain`.

**Multi-file compile error:**
```
-- DUPLICATE IDENTIFIER ----------------------- expectations/checkout.caf

Two expectations both declare `latency_p99`:

    21 │ expect latency_p99 {
       │        ^^^^^^^^^^^

The first definition is in expectations/payments.caf:

     7 │ expect latency_p99 {
       │        ^^^^^^^^^^^

Each expectation name must be unique across the workspace. Either rename
one (e.g. `checkout_latency_p99`) or move them under different namespaces.

For more information, run: caffeine explain E303
```

**Warning:**
```
-- UNUSED MEASUREMENT ------------------------- measurements/api.caf

The measurement `cpu_p50` is defined here:

     7 │ measurement cpu_p50 {
       │             ^^^^^^^

…but no expectation in the workspace references it. Either add an expectation
that uses `cpu_p50`, or remove the measurement.

This is a warning. Compilation succeeded.
```

**Multiple errors at end:**
```
2 errors and 1 warning during compilation.

   ✗ E103 type mismatch                  expectations/checkout.caf:14
   ✗ E303 duplicate identifier            expectations/checkout.caf:21
   ⚠ W201 unused measurement              measurements/api.caf:7

Run `caffeine explain <CODE>` for details on any of these.
```

**`caffeine explain E103`:**
```
E103: type mismatch

A field was assigned a value of the wrong type. Caffeine's type system
distinguishes Durations (30d, 5m, 100ms) from Strings ("30d") so that
durations can be arithmetic-checked.

Common causes:
  • Quoting a literal duration: `window: "30d"` should be `window: 30d`.
  • Forgetting the `$` prefix on a templated value.
  • Using a Duration where a String is expected (or vice versa).

See https://caffeine.brickellresearch.org/errors/E103 for the full reference.
```

**Color palette (Pour-Over):**

| Role | Hex | ANSI 256 | 16-color fallback |
|---|---|---|---|
| Error banner | `#D7263D` + bold | 161 | bright red + bold |
| Warning banner | `#F4A261` + bold | 215 | bright yellow + bold |
| Section heading | `#2EC4B6` + bold | 44 | bright cyan + bold |
| `Hint:` / `Note:` | `#2EC4B6` + bold | 44 | bright cyan + bold |
| Success ✓ | `#06A77D` | 36 | bright green + bold |
| Gutter / line-numbers | `#8A8A8A` | 244 | dim |
| Carets `^^^` | error or warning color, bold | — | — |
| Code snippets | default fg | — | — |

**Tradeoffs:**
- **Best for:** onboarding, docs feel native, screenshots and demo videos. Inviting.
- **Gives up:** density. The same 3 errors that fit on 4 lines in Espresso take 30+ lines here. CI logs become long.
- **Mitigation:** auto-degrade to Espresso-style one-liner format when `!isatty(stdout)` *or* `CI=true`, even at default `--format=human`. Rich format only in interactive mode.
- **Risk:** sounds chatty. Tone has to be tight (Elm itself sometimes feels infantilizing — "let's see if I can help!"). Caffeine should sound competent, not cute.

---

### Direction C — **Brewmaster** (branded, cargo+gleam hybrid with the coffee theme)

> Pitch: *cargo, with a pulled shot.* Cargo's progress vocabulary, Gleam's Unicode framing, plus a deliberately-restrained coffee theme on a few high-impact moments (the banner, the spinner, the success line). Visually distinctive without being twee.

**Persona:** Reliability-tooling team picking Caffeine over hand-rolled Terraform. They'll see the CLI on conference talks, in screenshots, in the docs. They want it to *look like a product*, not a research artifact. The personality has to land in 3 frames or be cut.

**`caffeine` (no args):**
```
caffeine 5.0.10 — reliability artifacts, freshly compiled.

╭─ commands ─────────────────────────────────────────────────╮
│  compile      Compile measurements + expectations          │
│  validate     Type-check without writing output            │
│  format       Format .caffeine files                       │
│  artifacts    List standard-library artifacts              │
│  types        Show the type-system reference               │
│  explain      Explain an error code                        │
│  lsp          Start the language server                    │
╰────────────────────────────────────────────────────────────╯

Flags:  --help  --version  --color  --format  --quiet  -v

Docs:   https://caffeine.brickellresearch.org
```
- Box drawn with `╭ ─ ╮ │ ╰ ╯` Unicode. ASCII fallback uses `+ - + | + +`.
- The "freshly compiled" tagline is the *only* coffee-themed text on `--help`. No bean glyphs, no `☕`.

**Compile success (the one place the brand shines):**
```
   Brewing  12 measurements, 8 expectations  [terraform]
   Linking  measurements ↔ expectations
   Pouring  terraform (1.2 KB → main.tf)
   ────────
   Served   in 142ms.   ✓ 8 expectations, 0 issues.
```
- `Brewing` / `Linking` / `Pouring` / `Served` in **bold amber** (`#F4A261`). These are the *only* themed verbs.
- The substitutions match cargo's slot exactly: 12-col right-aligned, replacing `Compiling/Linking/Generating/Finished` 1:1.
- `--no-theme` flag (and `CAFFEINE_NO_THEME=1`) demotes them to neutral verbs (`Compiling`, `Linking`, `Writing`, `Finished`). Mandatory escape hatch — some users will hate this.

**Validate success:**
```
   Tasting  12 measurements, 8 expectations
   ────────
   Clean    in 89ms.   ✓ no issues.
```

**Compile error:**
```
error[E103]: type mismatch
  ╭─[expectations/checkout.caf:14:13]
  │
12 │   slo latency_p99 {
13 │     target: 99.9
14 │     window: "30d"
   │             ━━━━━ expected Duration, found String
15 │   }
   ╰──
  = help: durations are unquoted: `window: 30d`
  = note: SLO blocks accept window, target, and query
  = link: https://caffeine.brickellresearch.org/errors/E103
```
- `error[E103]:` in **bold red**. `help:` / `note:` / `link:` labels in **bold cyan**.
- Box drawn with Unicode `╭─ │ ╰─` — Gleam-style. ASCII fallback uses `,- | '-`.
- Underline `━━━━━` (heavy horizontal) instead of carets. Bold red.
- Two lines of context above + one below. Snippet line numbers in **dim**.

**Multiple errors:**
```
error[E103]: type mismatch
  ╭─[expectations/checkout.caf:14:13]
  …

error[E303]: duplicate identifier `latency_p99`
  ╭─[expectations/checkout.caf:21:8]
  …

warning[W201]: unused measurement `cpu_p50`
  ╭─[measurements/api.caf:7:13]
  …

   Burnt   3 issues  (2 errors, 1 warning, 1 fixable with `caffeine fix`)
```
- Final summary uses the themed verb `Burnt` for failed runs (parallel to `Served`/`Clean`). With `--no-theme`: `Failed`.

**Verbose `-v`:**
```
   Grinding  parsed 20 files in 12ms
   Brewing   linked 12 measurements ↔ 8 expectations in 8ms
   Tasting   analyzed dependency graph in 4ms
   Pouring   generated terraform (1.2 KB) in 18ms
   ────────
   Served    in 47ms — wrote main.tf
```
- The themed verbs are richer in `-v` since users opted into more output.

**Spinner (long compiles, interactive only):**
```
   Brewing ⠋  12 measurements, 8 expectations
```
- Braille-spinner (`⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`) updated at 8 fps. ASCII fallback `|/-\`. Disabled when `!isatty`, `CI=true`, or `--no-progress`.

**Color palette (Brewmaster):**

| Role | Hex | ANSI 256 | 16-color fallback |
|---|---|---|---|
| Brand amber (themed verbs) | `#C97B3F` | 173 | yellow + bold |
| Error | `#D7263D` | 161 | bright red + bold |
| Warning | `#F4A261` | 215 | bright yellow + bold |
| Success | `#06A77D` | 36 | bright green + bold |
| Note / link | `#2EC4B6` | 44 | bright cyan + bold |
| Box / gutter | `#8A8A8A` | 244 | dim |
| Underline `━━━` | error or warning color | — | — |

The amber is darker than warning yellow on purpose — the eye reads amber as "brand", yellow as "caution." They must not collide.

**Tradeoffs:**
- **Best for:** marketing surface (screenshots, demo videos, conference talks), product feel, recognizability.
- **Gives up:** seriousness in some cultures. `Burnt` for failure may read as flippant when on-call at 3am. The escape hatch (`--no-theme`/env var) is non-negotiable.
- **Risk:** the theme can age into self-parody. Refresh budget: every 6 months, audit whether the verbs still feel right or have gone stale (the same way Spotify renames its email subject lines).

---

## 4. Shared infrastructure recommendations (Phase 4)

These apply regardless of which direction is picked. Switching directions = swapping the renderer module; everything below stays.

### 4.1 ANSI / TTY library

**Keep `gleam_community/ansi` for ANSI styling.** It's already a dep, it's well-maintained, and it's idiomatic. Don't add anything heavier.

**Add a single `tty.gleam` module** for capability detection:

```gleam
pub type ColorMode { Auto Always Never }
pub type Capabilities {
  Capabilities(
    color: Bool,
    unicode: Bool,
    is_tty: Bool,
    is_ci: Bool,
    is_github_actions: Bool,
    width: Int,  // terminal columns; 80 if unknown
  )
}

pub fn detect(flag_color: ColorMode) -> Capabilities
```

Detection precedence (highest wins):
1. `--color` flag (`Always` / `Never`) — explicit override.
2. `CAFFEINE_COLOR={always,never,auto}` — project-specific env.
3. `NO_COLOR` set to **non-empty** string → color off (no-color.org spec).
4. `FORCE_COLOR={1,2,3,true}` → on. `FORCE_COLOR={0,false}` → off.
5. `CLICOLOR_FORCE` non-zero → on.
6. `CLICOLOR=0` → off.
7. `TERM=dumb` → off color **and** off Unicode.
8. `isatty(stdout)` → if false, off.
9. Otherwise → on.

`is_ci` is true when any of `CI`, `GITHUB_ACTIONS`, `GITLAB_CI`, `BUILDKITE`, `CIRCLECI`, `JENKINS_URL` is set — used to disable spinners but **keep color**.

`unicode` is true when locale env (`LC_ALL`/`LC_CTYPE`/`LANG`) contains `UTF-8` and `TERM != dumb` and (on Windows) `WT_SESSION` is set.

For `isatty`: erlang has `io:getopts(standard_io)` which returns `terminal -> true|false`. On the JS target, `process.stdout.isTTY`. Both need a small FFI.

### 4.2 Diagnostic data model — unify the two systems

**The single biggest structural change.** Define one `Diagnostic` type that lives in `caffeine_lang` and is consumed by *both* the CLI renderer and the LSP. Modeled on the rustc shape because it has the richest information:

```gleam
// caffeine_lang/diagnostic.gleam
pub type Severity { Error Warning Note Help }

pub type Span {
  Span(
    file: String,
    start: Position,
    end: Position,
    is_primary: Bool,
    label: Option(String),  // "expected Duration, found String"
  )
}
pub type Position { Position(line: Int, column: Int, byte_offset: Int) }

pub type Suggestion {
  Suggestion(
    span: Span,
    replacement: String,
    applicability: Applicability,
    description: Option(String),  // "use unquoted duration"
  )
}
pub type Applicability { MachineApplicable MaybeIncorrect HasPlaceholders Unspecified }

pub type Diagnostic {
  Diagnostic(
    code: ErrorCode,                // existing E103 + future kebab lints
    severity: Severity,
    message: String,                // single-sentence, no period
    spans: List(Span),              // primary + secondary; first is primary
    notes: List(String),            // = note: lines
    helps: List(String),            // = help: lines
    suggestions: List(Suggestion),  // structured fixes
    docs_url: Option(String),       // …/errors/E103
  )
}

pub type ErrorCode {
  HardError(prefix: String, number: Int)   // E103, parsed from existing codes
  Lint(category: String, rule: String)     // caffeine/window/missing-default
}
```

Map `caffeine_lsp/diagnostics.gleam`'s `Diagnostic` to this type. Map `caffeine_lang/errors.gleam`'s `CompilationError` to this type. Then both CLI and LSP render from one source. Existing `ErrorContext` becomes a "build a `Diagnostic` from this context" helper for back-compat during the transition.

### 4.3 `--format={human,json,github}`

```
--format=human    Default in TTY. Renders via the chosen direction (Espresso/Pour-Over/Brewmaster).
--format=json     One JSON object per line (NDJSON). Includes a `rendered` field with the
                  human-formatted string verbatim — eliminates "the LSP says X but the CLI says Y".
--format=github   Emits `::error file=...,line=...,col=...,title=Code::Message` to stderr,
                  for the GitHub Actions PR-annotation feature. Auto-detected when
                  GITHUB_ACTIONS=true and stdout is not a TTY; explicit override available.
```

The JSON shape mirrors rustc:
```json
{
  "type": "diagnostic",
  "code": "E103",
  "severity": "error",
  "message": "type mismatch",
  "spans": [{"file":"...","line":14,"column":13,"end_line":14,"end_column":18,"is_primary":true,"label":"expected Duration, found String"}],
  "notes": ["SLO blocks accept window, target, and query"],
  "helps": ["durations are unquoted: `window: 30d`"],
  "suggestions": [{"span":{...},"replacement":"30d","applicability":"MachineApplicable","description":"use unquoted duration"}],
  "docs_url": "https://caffeine.brickellresearch.org/errors/E103",
  "rendered": "error[E103]: type mismatch\n  --> ..."
}
```

A *terminating* `{"type":"summary","errors":N,"warnings":M,"fixable":K,"elapsed_ms":...}` line ends every run.

### 4.4 Error code conventions + `caffeine explain <CODE>`

- **Hard errors:** keep the existing `E<nnn>` namespacing (`parse:1xx`, `validation:2xx`, `linker:3xx`, `semantic:4xx`, `codegen:5xx`, `cql:6xx`). Document the ranges in `errors.gleam`'s docstring so codes don't collide as new errors are added.
- **Lints (when added):** Biome-style `caffeine/<category>/<rule>` (e.g. `caffeine/window/missing-default`, `caffeine/naming/snake-case-measurement`). Configurable via a future `caffeine.toml`'s `[lints]` table.
- **`caffeine explain <CODE>`:** ships markdown content embedded as a `Dict(String, String)` in `caffeine_lang/explanations.gleam` (one entry per code). Renders the markdown to terminal text. No web round-trip; works offline. This is `rustc --explain` exactly.
- **Every diagnostic carries `docs_url: Option(String)`** pointing at `https://caffeine.brickellresearch.org/errors/<code>`. The web docs can be auto-generated from the same `Dict`.

### 4.5 Progress / spinner strategy

- One module: `caffeine_cli/progress.gleam`.
- Three implementations, picked at startup based on capabilities:
  1. **Spinner** (interactive TTY, `!is_ci`, `!--no-progress`) — Braille spinner at 8 fps, single-line `\r` overwrite.
  2. **Stepwise** (CI, piped, or `--no-progress`) — one-line-per-event, no overwrites.
  3. **Silent** (`--quiet`) — no output.
- API:
  ```gleam
  pub fn start(label: String) -> Handle
  pub fn step(handle: Handle, label: String) -> Nil
  pub fn finish(handle: Handle, label: String) -> Nil
  pub fn fail(handle: Handle, label: String) -> Nil
  ```
- `--no-progress` flag and `CAFFEINE_NO_PROGRESS=1` env var as overrides.

### 4.6 Snapshot testing strategy

- Use `gleeunit` (already a dep) plus a small `snapshot.gleam` helper.
- Each renderer test runs the CLI with stdout captured, **strips ANSI escapes**, and compares against a `.snap` file under `test/fixtures/cli_snapshots/`.
- Two snapshot variants per case:
  1. `<name>.txt` — colored output (full ANSI, useful when reviewing diffs).
  2. `<name>.plain.txt` — stripped, used for assertion.
- Update with `UPDATE_SNAPSHOTS=1 gleam test`.
- Cases to snapshot at minimum:
  - `--help` (no command)
  - `--help` per subcommand
  - `--version`
  - `unknown_command` (with did-you-mean)
  - `compile_success` (single-file, multi-file, with output path, without)
  - `compile_error_*` (one snapshot per error code in `errors.gleam`)
  - `validate_success`, `validate_with_warnings`
  - `format_check_diff`
  - `JSON output` for each of the above
  - `GitHub annotation output` for each error type

### 4.7 Subcommand `--help`

Replace the hand-rolled parser in `caffeine_cli.gleam:77` with proper subcommand dispatch. Two paths:

1. **Adopt `glint`** — Gleam's de facto CLI library. Gives subcommand `--help` and grouped flags for free. The installed v5.0.0 binary appears to use it (the truecolor help format is glint's). Cost: the existing `parse_args` and `dispatch` get rewritten; the `argv` dep becomes unused.
2. **Extend the existing parser.** Add `command: String` matching, route to per-command help functions. Less work, less polish.

Recommend (1) — the consistency wins outweigh the rewrite cost (~1 day's work; the dispatch is already small).

### 4.8 Other small wins worth scheduling

- **Did-you-mean for unknown commands.** `caffeine compil` → "did you mean `compile`?" Edit-distance ≤ 2. ~30 LOC.
- **`format --check` should print a diff**, not just a path. Use a small unified-diff renderer. ~50 LOC.
- **Move the warnings list off `io.println_error` and onto the diagnostic pipeline** (so they get codes, locations, and JSON output). Requires plumbing a `Span` through to the warnings emitted by the compiler.
- **Replace the `=== CAFFEINE COMPILER (terraform) ===` banner.** It fights every terminal width >80. Replace with a one-line "Compiling for terraform" status (cargo-shaped) — happens automatically once the chosen direction is implemented.

---

## 5. Recommended next step

**Pick Direction C (Brewmaster).** Reasoning:

1. **Caffeine has a brand**, and the CLI is the only place users encounter it day-to-day. Espresso (A) is competent but indistinguishable from `ruff` or `cargo`; Pour-Over (B) is friendly but visually identical to Elm. Brewmaster is the only direction that makes a screenshot recognizable as Caffeine in 1 second.
2. **The theme is contained to ~5 verbs and a banner tagline** — small enough to maintain, large enough to register, easily neutralized via `--no-theme` for users who hate it (and that escape hatch costs ~10 LOC).
3. **The diagnostic format underneath is rustc-shaped** (codes, snippet, help/note/link footer), which is what the *serious* moments need. The brand only shows up on the success/progress path, never on error rendering. Errors stay technical and competent.
4. **It's the most "future-defensible" choice**: if the brand ages, swap the verb table; the rest is rustc/cargo conventions and survives.

**Smallest first PR to validate it:**

> Change *only* the compile-progress verbs and the success/failure summary line, in `compile_presenter.gleam`. Keep everything else identical. Add a `--no-theme` flag and `CAFFEINE_NO_THEME=1` env var (~10 LOC each).

Concrete diff (~40 LOC net):
- `compile_presenter.gleam` — replace `=== CAFFEINE COMPILER ===` banner with one cargo-shaped `   Brewing ...` status line. Replace `✓ Compilation succeeded` / `✗ Compilation failed` with `   Served in Xms` / `   Burnt — N issues`.
- `color.gleam` — add an `amber` wrapper for the brand color.
- `caffeine_cli.gleam` — add `--no-theme` flag parsing.
- `tty.gleam` (new, small) — single `is_tty()` function. Used here only to decide whether to colorize.
- Snapshot test: 4 fixtures (success, success no-theme, failure, failure no-theme).

This is reversible (delete the verbs to back out), low-risk (one module touched), and testable (snapshots). If it lands well, the rest of Direction C — the box-drawn `--help`, the snippet underline change, `caffeine explain`, the `--format=json|github` work — can each ship as its own PR following the shared-infra plan in §4.

Concurrently, but as a **separate** PR: fix `color.gleam:14`'s NO_COLOR check (empty-string bug), route `compile_presenter.gleam` and `display.gleam`'s direct `ansi.*` calls through the color module, and add the `tty.gleam` capability detector. These are pure correctness wins and don't depend on which design direction is picked.

---

## Appendix: file-by-file change map (for whichever direction wins)

| File | Change |
|---|---|
| `caffeine_cli/src/caffeine_cli.gleam` | Replace hand-rolled parser with `glint` (or extend it); add `--color`, `--format`, `--no-progress`, `--no-theme` flags |
| `caffeine_cli/src/caffeine_cli/color.gleam` | Fix NO_COLOR empty-string bug; add `amber`, `yellow`, `magenta` wrappers |
| `caffeine_cli/src/caffeine_cli/tty.gleam` (new) | Capability detection (color, unicode, is_tty, is_ci, width) |
| `caffeine_cli/src/caffeine_cli/progress.gleam` (new) | Spinner / stepwise / silent strategies |
| `caffeine_cli/src/caffeine_cli/compile_presenter.gleam` | Cargo-shaped status lines; remove banner; route through color module |
| `caffeine_cli/src/caffeine_cli/display.gleam` | Route direct `ansi.*` calls through color module |
| `caffeine_cli/src/caffeine_cli/error_presenter.gleam` | Adopt chosen direction's renderer; keep snippet logic; add 2 lines of context above |
| `caffeine_cli/src/caffeine_cli/render_json.gleam` (new) | NDJSON formatter |
| `caffeine_cli/src/caffeine_cli/render_github.gleam` (new) | GHA workflow-command formatter |
| `caffeine_cli/src/caffeine_cli/handler.gleam` | Add `explain` subcommand; per-subcommand help text; did-you-mean for unknowns |
| `caffeine_lang/src/caffeine_lang/diagnostic.gleam` (new) | Unified `Diagnostic` type (§4.2) |
| `caffeine_lang/src/caffeine_lang/explanations.gleam` (new) | `Dict(String, String)` of long-form error explanations for `caffeine explain` |
| `caffeine_lsp/src/caffeine_lsp/diagnostics.gleam` | Map to the unified `Diagnostic` type |
| `caffeine_cli/test/fixtures/cli_snapshots/` (new) | Snapshot fixtures |
