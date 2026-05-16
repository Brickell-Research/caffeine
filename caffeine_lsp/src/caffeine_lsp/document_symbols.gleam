import caffeine_lang/frontend/ast.{
  type ExpectItem, type ExpectsFile, type Extendable, type Field,
  type MeasurementItem, type MeasurementsFile, type Parsed, type TypeAlias,
}
import caffeine_lang/types
import caffeine_lsp/file_utils
import caffeine_lsp/lsp_types.{SkClass, SkProperty, SkTypeParameter, SkVariable}
import caffeine_lsp/position_utils
import gleam/list
import gleam/option
import gleam/result
import gleam/string

/// A document symbol for the editor outline.
pub type DocumentSymbol {
  DocumentSymbol(
    name: String,
    detail: String,
    kind: Int,
    line: Int,
    col: Int,
    name_len: Int,
    children: List(DocumentSymbol),
  )
}

/// Analyze source text and return document symbols for the outline.
pub fn get_symbols(content: String) -> List(DocumentSymbol) {
  let lines = string.split(content, "\n")
  case file_utils.parse(content) {
    Ok(file_utils.Measurements(file)) -> measurements_file_symbols(file, lines)
    Ok(file_utils.Expects(file)) -> expects_file_symbols(file, lines)
    Error(_) -> []
  }
}

fn measurements_file_symbols(
  file: MeasurementsFile(Parsed),
  lines: List(String),
) -> List(DocumentSymbol) {
  let alias_syms =
    list.map(file.type_aliases, fn(ta) { type_alias_symbol(ta, lines) })
  let ext_syms =
    list.map(file.extendables, fn(e) { extendable_symbol(e, lines) })
  let item_syms =
    list.map(file.items, fn(item) { measurement_item_symbol(item, lines) })
  list.flatten([alias_syms, ext_syms, item_syms])
}

fn expects_file_symbols(
  file: ExpectsFile(Parsed),
  lines: List(String),
) -> List(DocumentSymbol) {
  let ext_syms =
    list.map(file.extendables, fn(e) { extendable_symbol(e, lines) })
  let item_syms =
    list.map(file.items, fn(item) { expect_item_symbol(item, lines) })
  list.flatten([ext_syms, item_syms])
}

fn type_alias_symbol(ta: TypeAlias, lines: List(String)) -> DocumentSymbol {
  let #(line, col) =
    position_utils.find_name_position_in_lines(lines, ta.name)
    |> result.unwrap(#(0, 0))
  let detail = types.parsed_type_to_string(ta.type_)
  DocumentSymbol(
    ta.name,
    detail,
    lsp_types.symbol_kind_to_int(SkTypeParameter),
    line,
    col,
    string.length(ta.name),
    [],
  )
}

fn extendable_symbol(ext: Extendable, lines: List(String)) -> DocumentSymbol {
  let #(line, col) =
    position_utils.find_name_position_in_lines(lines, ext.name)
    |> result.unwrap(#(0, 0))
  let detail = ast.extendable_kind_to_string(ext.kind)
  DocumentSymbol(
    ext.name,
    detail,
    lsp_types.symbol_kind_to_int(SkVariable),
    line,
    col,
    string.length(ext.name),
    [],
  )
}

fn measurement_item_symbol(
  item: MeasurementItem,
  lines: List(String),
) -> DocumentSymbol {
  let #(line, col) =
    position_utils.find_name_position_in_lines(lines, item.name)
    |> result.unwrap(#(0, 0))
  let req_fields =
    list.map(item.requires.fields, fn(f) { field_symbol(f, lines) })
  let prov_fields =
    list.map(item.provides.fields, fn(f) { field_symbol(f, lines) })
  let children = list.flatten([req_fields, prov_fields])
  DocumentSymbol(
    item.name,
    "",
    lsp_types.symbol_kind_to_int(SkClass),
    line,
    col,
    string.length(item.name),
    children,
  )
}

fn expect_item_symbol(item: ExpectItem, lines: List(String)) -> DocumentSymbol {
  let #(line, col) =
    position_utils.find_name_position_in_lines(lines, item.name)
    |> result.unwrap(#(0, 0))
  let with_fields = case item.guarantees.measured_by {
    option.Some(mb) -> mb.with_args.fields
    option.None -> []
  }
  let children = list.map(with_fields, fn(f) { field_symbol(f, lines) })
  DocumentSymbol(
    item.name,
    "",
    lsp_types.symbol_kind_to_int(SkClass),
    line,
    col,
    string.length(item.name),
    children,
  )
}

fn field_symbol(field: Field, lines: List(String)) -> DocumentSymbol {
  let #(line, col) =
    position_utils.find_name_position_in_lines(lines, field.name)
    |> result.unwrap(#(0, 0))
  let detail = ast.value_to_string(field.value)
  DocumentSymbol(
    field.name,
    detail,
    lsp_types.symbol_kind_to_int(SkProperty),
    line,
    col,
    string.length(field.name),
    [],
  )
}
