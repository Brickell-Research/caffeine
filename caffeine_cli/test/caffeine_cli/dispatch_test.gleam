import caffeine_cli
import gleam/string
import gleeunit/should

/// Use the public `run/1` entry point — it never touches stdout when it
/// returns an Error, so we can assert on the message directly.
pub fn unknown_command_close_typo_suggests_test() {
  let assert Error(msg) = caffeine_cli.run(["compil"])
  string.contains(msg, "Unknown command: compil") |> should.be_true
  string.contains(msg, "Did you mean `compile`?") |> should.be_true
}

pub fn unknown_command_far_off_lists_known_test() {
  let assert Error(msg) = caffeine_cli.run(["xyzzy"])
  string.contains(msg, "Unknown command: xyzzy") |> should.be_true
  // Far-off input falls back to listing known commands.
  string.contains(msg, "Known commands:") |> should.be_true
  string.contains(msg, "compile") |> should.be_true
  string.contains(msg, "explain") |> should.be_true
}

pub fn unknown_command_picks_closest_neighbor_test() {
  // "expalin" is 2 swaps from "explain" — should pick that over the
  // longer-distance candidates.
  let assert Error(msg) = caffeine_cli.run(["expalin"])
  string.contains(msg, "Did you mean `explain`?") |> should.be_true
}

pub fn unknown_command_suggests_help_for_typos_test() {
  // `help` is a meta-command and isn't in args.command_names(), but the
  // dispatcher still includes it in did-you-mean candidates.
  let assert Error(msg) = caffeine_cli.run(["hlep"])
  string.contains(msg, "Did you mean `help`?") |> should.be_true
}

// --- Per-command help routes ---

fn discard(_: String) -> Nil {
  Nil
}

pub fn help_with_known_subcommand_dispatches_test() {
  // `caffeine help compile` should succeed (it prints per-command help
  // via the captured output handler, then returns Ok).
  caffeine_cli.run_with_output(["help", "compile"], discard)
  |> should.equal(Ok(Nil))
}

pub fn help_with_no_arg_dispatches_test() {
  caffeine_cli.run_with_output(["help"], discard)
  |> should.equal(Ok(Nil))
}

pub fn subcommand_help_flag_dispatches_test() {
  // `caffeine compile --help` should also succeed without trying to
  // actually compile (which would fail on missing positional args).
  caffeine_cli.run_with_output(["compile", "--help"], discard)
  |> should.equal(Ok(Nil))
}
