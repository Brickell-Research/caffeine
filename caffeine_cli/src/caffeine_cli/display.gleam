import caffeine_cli/color.{type ColorMode}
import caffeine_lang/linker/artifacts.{type ParamInfo}
import caffeine_lang/types.{
  type AcceptedTypes, type TypeMeta, Defaulted, ModifierType, OneOf, Optional,
  RefinementType,
}
import gleam/dict
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

/// Pretty-prints SLO params showing name, description, and type details.
pub fn pretty_print_slo_params(
  params: dict.Dict(String, ParamInfo),
  mode: ColorMode,
) -> String {
  let header =
    color.bold(color.cyan("SLO", mode), mode)
    <> ": "
    <> color.dim(
      "\"A Service Level Objective that monitors a metric query against a threshold over a rolling window.\"",
      mode,
    )
  let param_lines =
    params
    |> dict.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
    |> list.map(fn(pair) {
      let #(name, param_info) = pair
      "  "
      <> color.yellow(name, mode)
      <> ": "
      <> color.dim("\"" <> param_info.description <> "\"", mode)
      <> "\n    type: "
      <> color.green(types.accepted_type_to_string(param_info.type_), mode)
      <> "\n    "
      <> param_status(param_info.type_, mode)
    })
    |> string.join("\n")

  header <> "\n\n" <> param_lines
}

/// Returns the status of a parameter: "required", "optional", or "default: <value>".
fn param_status(typ: AcceptedTypes, mode: ColorMode) -> String {
  case typ {
    ModifierType(Optional(_)) -> color.dim("optional", mode)
    ModifierType(Defaulted(_, default)) ->
      color.blue("default: " <> default, mode)
    RefinementType(OneOf(inner, _)) -> param_status(inner, mode)
    _ -> color.magenta("required", mode)
  }
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
