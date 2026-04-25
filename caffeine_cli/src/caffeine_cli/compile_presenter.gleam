import caffeine_cli/clock
import caffeine_cli/color.{type ColorMode}
import caffeine_lang/compiler.{type CompilationOutput}
import caffeine_lang/errors
import caffeine_lang/source_file.{
  type ExpectationSource, type SourceFile, type VendorMeasurementSource,
}
import gleam/int
import gleam/io
import gleam/list
import gleam/string

/// Defines the verbosity level for CLI output.
pub type LogLevel {
  Verbose
  Minimal
}

/// Theme controls the brand vocabulary on the status verbs.
/// `Themed` uses Brewmaster verbs (Brewing/Served/Burnt). `Plain` uses
/// neutral cargo-style verbs (Compiling/Finished/Failed) and is the
/// escape hatch for `--no-theme` / `CAFFEINE_NO_THEME=1`.
pub type Theme {
  Themed
  Plain
}

/// Presentation policy: how the run should render itself.
///
/// `unicode` gates box-drawing glyphs (snippet frame, themed status).
/// Detection lives in `tty.detect/1`; this record bundles the result
/// so a single run only pays for capability detection once.
pub type Presentation {
  Presentation(
    log_level: LogLevel,
    color: ColorMode,
    theme: Theme,
    unicode: Bool,
  )
}

/// Compiles with progress output around the pure compiler call.
pub fn compile_with_output(
  measurements: List(VendorMeasurementSource),
  expectations: List(SourceFile(ExpectationSource)),
  target: String,
  pres: Presentation,
) -> Result(CompilationOutput, errors.CompilationError) {
  let start = clock.now_ms()
  let m_count = list.length(measurements)
  let e_count = list.length(expectations)

  log(
    pres.log_level,
    status_line(
      verb_start(pres.theme),
      pres.color,
      pres.theme,
      summarize_inputs(m_count, e_count, target),
    ),
  )

  case compiler.compile(measurements, expectations) {
    Ok(output) -> {
      let elapsed = clock.now_ms() - start
      log(
        pres.log_level,
        status_line(
          verb_success(pres.theme),
          pres.color,
          pres.theme,
          color.green("✓ in " <> clock.format_elapsed(elapsed), pres.color),
        ),
      )
      output.warnings
      |> list.each(fn(warning) {
        io.println_error(color.yellow("warning: ", pres.color) <> warning)
      })
      Ok(output)
    }
    Error(err) -> {
      let elapsed = clock.now_ms() - start
      log(
        pres.log_level,
        status_line(
          verb_failure(pres.theme),
          pres.color,
          pres.theme,
          color.red("✗ in " <> clock.format_elapsed(elapsed), pres.color),
        ),
      )
      Error(err)
    }
  }
}

/// Logs a message at the specified log level.
pub fn log(log_level: LogLevel, message: String) {
  case log_level {
    Verbose -> io.println(message)
    Minimal -> Nil
  }
}

// --- Theme vocabulary ---

/// Width of the right-aligned verb gutter, matching cargo's convention.
const verb_width: Int = 11

fn verb_start(theme: Theme) -> String {
  case theme {
    Themed -> "Brewing"
    Plain -> "Compiling"
  }
}

fn verb_success(theme: Theme) -> String {
  case theme {
    Themed -> "Served"
    Plain -> "Finished"
  }
}

fn verb_failure(theme: Theme) -> String {
  case theme {
    Themed -> "Burnt"
    Plain -> "Failed"
  }
}

/// Render a status line with the verb right-aligned in a fixed gutter,
/// followed by the message. Themed runs use brand amber for the verb;
/// plain runs use bold green to match cargo.
fn status_line(
  verb: String,
  color_mode: ColorMode,
  theme: Theme,
  message: String,
) -> String {
  let pad = string.repeat(" ", int.max(0, verb_width - string.length(verb)))
  let styled = case theme {
    Themed -> color.bold(color.amber(verb, color_mode), color_mode)
    Plain -> color.bold(color.green(verb, color_mode), color_mode)
  }
  pad <> styled <> "  " <> message
}

/// Counts here are *files*, not the definitions inside them — a single
/// .caffeine file can hold many measurements or expectations. The "file"
/// suffix is load-bearing: showing "1 measurement" when the user just
/// added a third expectation to an existing file made it look like the
/// compiler had silently dropped the new one (caffeine_lang#74).
/// Surfacing real definition counts requires richer data from
/// CompilationOutput; that's a separate cross-repo change.
fn summarize_inputs(
  measurements: Int,
  expectations: Int,
  target: String,
) -> String {
  pluralize(measurements, "measurement file", "measurement files")
  <> ", "
  <> pluralize(expectations, "expectation file", "expectation files")
  <> "  ["
  <> target
  <> "]"
}

fn pluralize(n: Int, singular: String, plural: String) -> String {
  let label = case n {
    1 -> singular
    _ -> plural
  }
  int.to_string(n) <> " " <> label
}
