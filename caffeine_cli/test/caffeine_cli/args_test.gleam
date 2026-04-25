import caffeine_cli/args
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should

// --- commands() ---

pub fn commands_lists_all_subcommands_test() {
  let names = args.command_names()
  ["compile", "validate", "format", "artifacts", "types", "explain", "lsp"]
  |> list.each(fn(expected) {
    case list.contains(names, expected) {
      True -> Nil
      False -> panic as { "expected " <> expected <> " in command list" }
    }
  })
}

pub fn commands_have_unique_names_test() {
  let names = args.command_names()
  let deduped = list.unique(names)
  list.length(names) |> should.equal(list.length(deduped))
}

pub fn every_command_has_summary_test() {
  args.commands()
  |> list.each(fn(c) {
    case string.length(c.summary) > 0 {
      True -> Nil
      False -> panic as { c.name <> " has empty summary" }
    }
  })
}

pub fn every_command_has_description_test() {
  args.commands()
  |> list.each(fn(c) {
    case string.length(c.description) > 0 {
      True -> Nil
      False -> panic as { c.name <> " has empty description" }
    }
  })
}

pub fn every_command_has_at_least_one_example_test() {
  args.commands()
  |> list.each(fn(c) {
    case c.examples {
      [] -> panic as { c.name <> " has no examples" }
      _ -> Nil
    }
  })
}

// --- find ---

pub fn find_known_command_test() {
  case args.find("compile") {
    Some(spec) -> spec.name |> should.equal("compile")
    None -> panic as "expected to find compile"
  }
}

pub fn find_unknown_command_returns_none_test() {
  args.find("xyzzy") |> should.equal(None)
}

pub fn find_help_returns_none_test() {
  // `help` is a meta-command handled by the dispatcher, not a real
  // subcommand — args.find should not return a spec for it.
  args.find("help") |> should.equal(None)
}

// --- usage_message ---

pub fn usage_message_includes_signature_test() {
  let assert Some(spec) = args.find("compile")
  let msg = args.usage_message(spec)
  string.contains(msg, "Usage: caffeine compile") |> should.be_true
  string.contains(msg, "<measurements_dir>") |> should.be_true
  string.contains(msg, "[output_path]") |> should.be_true
}

pub fn usage_message_omits_signature_for_no_arg_command_test() {
  let assert Some(spec) = args.find("artifacts")
  let msg = args.usage_message(spec)
  msg |> should.equal("Usage: caffeine artifacts")
}

// --- usage_for ---

pub fn usage_for_unknown_command_falls_back_test() {
  // Unknown commands still get a sensible (if minimal) usage line.
  args.usage_for("xyzzy")
  |> should.equal("Usage: caffeine xyzzy")
}
