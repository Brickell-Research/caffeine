import argv
import caffeine_cli/args
import caffeine_cli/color
import caffeine_cli/distance
import caffeine_cli/handler
import caffeine_cli/help
import caffeine_cli/theme
import caffeine_cli/tty
import gleam/bool
import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Parsed CLI arguments.
pub type ParsedArgs {
  ParsedArgs(
    command: String,
    flags: Dict(String, String),
    positional: List(String),
  )
}

/// Parse a list of string arguments into a command, flags, and positional args.
@internal
pub fn parse_args(args: List(String)) -> ParsedArgs {
  parse_loop(args, "", dict.new(), [])
}

/// Entry point for the Caffeine language CLI application.
pub fn main() {
  let args = argv.load().arguments
  case run(args) {
    Ok(Nil) -> Nil
    Error(msg) -> {
      io.println(msg)
      halt(1)
    }
  }
}

/// Entry point for Erlang escript compatibility and testing.
pub fn run(args: List(String)) -> Result(Nil, String) {
  run_with_output(args, io.println)
}

/// Run with a custom output function. Useful for testing to suppress stdout.
@internal
pub fn run_with_output(
  args: List(String),
  output: fn(String) -> Nil,
) -> Result(Nil, String) {
  let parsed = parse_args(args)

  use <- bool.lazy_guard(
    has_flag(parsed.flags, "version") || has_flag(parsed.flags, "v"),
    fn() {
      output(handler.version_string())
      Ok(Nil)
    },
  )

  case help_target(parsed) {
    Some(rendering) -> {
      let caps = tty.detect(tty.Auto)
      let mode = color.from_capabilities(caps)
      let chosen_theme = theme.resolve(get_bool_flag(parsed.flags, "no-theme"))
      let text = case rendering {
        TopLevelHelp -> help.render(mode, chosen_theme, caps.unicode)
        CommandHelp(spec) -> help.render_command(spec, mode)
      }
      output(text)
      Ok(Nil)
    }
    None -> dispatch(parsed)
  }
}

/// What kind of help (if any) the parsed args ask for.
type HelpRendering {
  TopLevelHelp
  CommandHelp(args.CommandSpec)
}

/// Decide whether the parsed args are asking for help, and if so for what.
///
/// Triggers (in order):
///   - command is empty or `help` with no usable arg → top-level
///   - command is `help <X>` and X is a known subcommand → per-command
///   - command is a known subcommand and `--help`/`-h` was passed → per-command
///   - any other `--help`/`-h` (with unknown command) → top-level
fn help_target(parsed: ParsedArgs) -> Option(HelpRendering) {
  let asked_via_flag =
    has_flag(parsed.flags, "help") || has_flag(parsed.flags, "h")

  case parsed.command, asked_via_flag {
    "", _ -> Some(TopLevelHelp)
    "help", _ ->
      case parsed.positional {
        [name, ..] ->
          case args.find(name) {
            Some(spec) -> Some(CommandHelp(spec))
            None -> Some(TopLevelHelp)
          }
        [] -> Some(TopLevelHelp)
      }
    name, True ->
      case args.find(name) {
        Some(spec) -> Some(CommandHelp(spec))
        None -> Some(TopLevelHelp)
      }
    _, False -> None
  }
}

// --- Private functions ---

@external(erlang, "erlang", "halt")
@external(javascript, "./caffeine_cli_ffi.mjs", "halt")
fn halt(code: Int) -> Nil

fn parse_loop(
  args: List(String),
  command: String,
  flags: Dict(String, String),
  positional: List(String),
) -> ParsedArgs {
  case args {
    [] ->
      ParsedArgs(
        command: command,
        flags: flags,
        positional: list.reverse(positional),
      )
    [arg, ..rest] ->
      case string.starts_with(arg, "--") {
        True -> {
          let flag = string.drop_start(arg, 2)
          case string.split_once(flag, "=") {
            Ok(#(key, value)) ->
              parse_loop(
                rest,
                command,
                dict.insert(flags, key, value),
                positional,
              )
            Error(_) ->
              parse_loop(
                rest,
                command,
                dict.insert(flags, flag, "true"),
                positional,
              )
          }
        }
        False ->
          case string.starts_with(arg, "-") {
            True -> {
              let flag = string.drop_start(arg, 1)
              parse_loop(
                rest,
                command,
                dict.insert(flags, flag, "true"),
                positional,
              )
            }
            False ->
              case command {
                "" -> parse_loop(rest, arg, flags, positional)
                _ -> parse_loop(rest, command, flags, [arg, ..positional])
              }
          }
      }
  }
}

fn get_bool_flag(flags: Dict(String, String), key: String) -> Bool {
  case dict.get(flags, key) {
    Ok("true") -> True
    _ -> False
  }
}

fn get_string_flag(
  flags: Dict(String, String),
  key: String,
  default: String,
) -> String {
  dict.get(flags, key) |> result.unwrap(default)
}

fn has_flag(flags: Dict(String, String), key: String) -> Bool {
  dict.has_key(flags, key)
}

/// Dispatch parsed arguments to the appropriate command handler.
fn dispatch(parsed: ParsedArgs) -> Result(Nil, String) {
  let quiet = get_bool_flag(parsed.flags, "quiet")
  let target = get_string_flag(parsed.flags, "target", "terraform")
  let no_theme = get_bool_flag(parsed.flags, "no-theme")

  case parsed.command {
    "compile" -> handler.run_compile(quiet, target, no_theme, parsed.positional)
    "validate" -> handler.run_validate(quiet, target, no_theme, parsed.positional)
    "format" -> {
      let check = get_bool_flag(parsed.flags, "check")
      handler.run_format(quiet, check, parsed.positional)
    }
    "artifacts" -> handler.run_artifacts(quiet)
    "types" -> handler.run_types(quiet)
    "lsp" -> handler.run_lsp()
    "explain" -> handler.run_explain(parsed.positional)
    other -> Error(unknown_command_message(other))
  }
}

/// Build the error message shown when the user types a command Caffeine
/// doesn't know. Includes a did-you-mean when one of the known commands
/// is within edit distance 2. Candidates come from `args.command_names()`
/// plus the `help` meta-command (which is dispatched specially above and
/// would otherwise be missing from the list).
fn unknown_command_message(command: String) -> String {
  let candidates = ["help", ..args.command_names()]
  let suffix = case distance.nearest(command, candidates, max_distance: 2) {
    Some(near) -> "\n\nDid you mean `" <> near <> "`?"
    None -> "\n\nKnown commands: " <> string.join(candidates, ", ")
  }
  "Unknown command: " <> command <> suffix
}
