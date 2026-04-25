/// Background "a new caffeine is available" notice, modeled on
/// Claude Code's `plz update` pattern: the high-frequency tool nudges,
/// the package manager (cvm) doesn't.
///
/// Suppression rules — the check runs only when ALL of these hold:
///   - stdout is a TTY (not piped)
///   - we're not in CI (no `CI`, `GITHUB_ACTIONS`, etc.)
///   - `CAFFEINE_NO_UPDATE_CHECK` is unset (or empty)
///   - the command isn't long-running (`lsp`) or trivial (`explain`)
///
/// Failures are silent. The check is a courtesy, not a critical path —
/// if curl is missing, GitHub is down, or the user is offline, we just
/// skip the notice. The compile/validate result the user actually asked
/// for is unaffected.
import caffeine_cli/color
import caffeine_cli/github
import caffeine_cli/tty
import caffeine_lang/constants
import envoy
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/order.{type Order, Eq, Gt, Lt}
import gleam/string

/// Print an update notice if appropriate.
///
/// `command` is the dispatched subcommand name, used to suppress the
/// notice on `lsp` (long-running, would corrupt the LSP wire) and
/// `explain` (a quick lookup that shouldn't carry a banner).
pub fn maybe_notify(command: String) -> Nil {
  use <- bool.guard(should_skip(command), Nil)
  case github.resolve_latest() {
    Ok(latest) ->
      case is_newer(latest, constants.version) {
        True -> print_notice(latest, constants.version)
        False -> Nil
      }
    Error(_) -> Nil
  }
}

fn should_skip(command: String) -> Bool {
  let caps = tty.detect(tty.Auto)
  !caps.is_tty
  || caps.is_ci
  || env_set("CAFFEINE_NO_UPDATE_CHECK")
  || list.contains(["lsp", "explain"], command)
}

fn env_set(name: String) -> Bool {
  case envoy.get(name) {
    Ok(v) -> v != "" && v != "false" && v != "0"
    Error(_) -> False
  }
}

fn print_notice(latest: String, current: String) -> Nil {
  let mode = color.detect_color_mode()
  let header = color.bold(color.amber("update available", mode), mode)
  io.println("")
  io.println(
    "  " <> header <> color.dim(": " <> current <> " → " <> latest, mode),
  )
  io.println(
    "  "
    <> color.dim("run: ", mode)
    <> color.cyan("cvm install latest", mode)
    <> color.dim("  (silence with CAFFEINE_NO_UPDATE_CHECK=1)", mode),
  )
}

// --- Version comparison ---

/// Compare two semver-ish version strings. Trailing-zero segments are
/// treated as equal (`5.0` == `5.0.0`).
@internal
pub fn is_newer(latest: String, current: String) -> Bool {
  compare_versions(parse(latest), parse(current)) == Gt
}

fn parse(v: String) -> List(Int) {
  v |> string.split(".") |> list.filter_map(int.parse)
}

fn compare_versions(a: List(Int), b: List(Int)) -> Order {
  case a, b {
    [], [] -> Eq
    [], [y, ..ys] ->
      case int.compare(y, 0) {
        Eq -> compare_versions([], ys)
        _ -> Lt
      }
    [x, ..xs], [] ->
      case int.compare(x, 0) {
        Eq -> compare_versions(xs, [])
        _ -> Gt
      }
    [x, ..xs], [y, ..ys] ->
      case int.compare(x, y) {
        Eq -> compare_versions(xs, ys)
        other -> other
      }
  }
}
