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
