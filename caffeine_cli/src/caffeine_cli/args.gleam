/// Command specifications — the single source of truth for what
/// `caffeine` accepts.
///
/// Both the dispatcher (`caffeine_cli.gleam`) and the help renderer
/// (`help.gleam`) read from `commands/0` so that adding or renaming a
/// subcommand is a one-line change here, not a sweep across modules.
///
/// Per-command argument validation still lives in the handlers — this
/// module describes shape and prose; it does not enforce it (yet).
import gleam/list
import gleam/option.{type Option, None, Some}

/// Description of one CLI subcommand.
pub type CommandSpec {
  CommandSpec(
    /// The verb the user types — `compile`, `format`, etc.
    name: String,
    /// One-line summary shown in the top-level commands list.
    summary: String,
    /// Argument signature (e.g. "<measurements_dir> <expectations_dir> [output_path]").
    /// Empty string when the command takes no positional args.
    signature: String,
    /// Multi-line description shown in `caffeine help <cmd>`.
    description: String,
    /// Per-command flag rows.
    flags: List(FlagSpec),
    /// Concrete example invocations.
    examples: List(String),
  )
}

/// Description of a flag accepted by a subcommand.
pub type FlagSpec {
  FlagSpec(name: String, description: String)
}

/// All known subcommands, in display order.
pub fn commands() -> List(CommandSpec) {
  [
    CommandSpec(
      name: "compile",
      summary: "Compile measurements + expectations to a target",
      signature: "<measurements_dir> <expectations_dir> [output_path]",
      description: "Compile .caffeine measurements and expectations into the configured "
        <> "code-generation target (Terraform by default, OpenTofu via --target).",
      flags: [
        FlagSpec(
          "--target=<terraform|opentofu>",
          "Codegen target (default: terraform)",
        ),
        FlagSpec("--quiet", "Suppress compilation progress output"),
      ],
      examples: [
        "caffeine compile measurements/ expectations/",
        "caffeine compile measurements/ expectations/ build/main.tf",
        "caffeine compile measurements/ expectations/ --target=opentofu",
      ],
    ),
    CommandSpec(
      name: "format",
      summary: "Format .caffeine files",
      signature: "<path>",
      description: "Format one or more .caffeine files in place. With --check, exits "
        <> "non-zero if any file would change instead of modifying anything.",
      flags: [
        FlagSpec("--check", "Check formatting without modifying files"),
        FlagSpec("--quiet", "Suppress per-file output"),
      ],
      examples: [
        "caffeine format expectations/",
        "caffeine format expectations/ --check",
      ],
    ),
    CommandSpec(
      name: "artifacts",
      summary: "List standard-library artifacts",
      signature: "",
      description: "Print the catalog of artifacts (e.g. SLO) provided by Caffeine's "
        <> "standard library, including each artifact's parameters and types.",
      flags: [FlagSpec("--quiet", "Suppress decorative output")],
      examples: ["caffeine artifacts"],
    ),
    CommandSpec(
      name: "types",
      summary: "Show the type-system reference",
      signature: "",
      description: "Print every type Caffeine accepts, grouped by category "
        <> "(primitives, collections, structured, modifiers, refinements). "
        <> "Useful as a quick reference while writing measurement schemas.",
      flags: [FlagSpec("--quiet", "Suppress decorative output")],
      examples: ["caffeine types"],
    ),
    CommandSpec(
      name: "explain",
      summary: "Explain an error code (e.g. caffeine explain E100)",
      signature: "<CODE>",
      description: "Look up a Caffeine error code (E100, E303, ...) and print its "
        <> "long-form description, common causes, and how to fix it. Codes "
        <> "are matched case-insensitively.",
      flags: [],
      examples: ["caffeine explain E100", "caffeine explain e303"],
    ),
  ]
}

/// All known subcommand names, in declaration order.
pub fn command_names() -> List(String) {
  commands() |> list.map(fn(c) { c.name })
}

/// Look up a command spec by name. Returns `None` for `help` (which is a
/// meta-command handled by the dispatcher, not a real subcommand) and
/// for any unknown name.
pub fn find(name: String) -> Option(CommandSpec) {
  list.find(commands(), fn(c) { c.name == name })
  |> result_to_option
}

/// One-line usage message for a command, suitable for "missing arg" errors.
///
///     caffeine compile <measurements_dir> <expectations_dir> [output_path]
pub fn usage_message(spec: CommandSpec) -> String {
  case spec.signature {
    "" -> "Usage: caffeine " <> spec.name
    sig -> "Usage: caffeine " <> spec.name <> " " <> sig
  }
}

/// Convenience: look up a command by name and produce its usage message.
/// Used by handlers to keep usage strings in lockstep with `commands/0`.
pub fn usage_for(name: String) -> String {
  case find(name) {
    Some(spec) -> usage_message(spec)
    None -> "Usage: caffeine " <> name
  }
}

fn result_to_option(r: Result(a, b)) -> Option(a) {
  case r {
    Ok(v) -> Some(v)
    Error(_) -> None
  }
}
