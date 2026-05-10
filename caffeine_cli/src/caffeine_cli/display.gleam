import caffeine_cli/color.{type ColorMode}
import caffeine_lang/types.{type TypeMeta}
import gleam/list
import gleam/string

/// Pretty-prints a category with its types for CLI display.
pub fn pretty_print_category(
  name: String,
  description: String,
  types: List(TypeMeta),
  mode: ColorMode,
) -> String {
  let header =
    color.bold(color.cyan(name, mode), mode)
    <> ": "
    <> color.dim("\"" <> description <> "\"", mode)
  let type_entries =
    types
    |> list.map(pretty_print_type_meta(_, mode))
    |> string.join("\n")

  header <> "\n\n" <> type_entries
}

/// Pretty-prints a single type entry.
fn pretty_print_type_meta(meta: TypeMeta, mode: ColorMode) -> String {
  let name_line =
    "  "
    <> color.yellow(meta.name, mode)
    <> ": "
    <> color.dim("\"" <> meta.description <> "\"", mode)
  let syntax_line = "    syntax: " <> color.green(meta.syntax, mode)
  let example_line = "    " <> color.blue("e.g. " <> meta.example, mode)

  name_line <> "\n" <> syntax_line <> "\n" <> example_line
}
