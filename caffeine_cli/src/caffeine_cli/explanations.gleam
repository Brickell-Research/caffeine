/// Long-form prose for every error code Caffeine can emit.
///
/// Each error footer points at `caffeine explain <CODE>`, which looks up
/// the entry here and renders it. Keeping this module separate from
/// `caffeine_lang/errors.gleam` means the content can be iterated on by
/// non-compiler contributors (docs team, SRE office hours).
///
/// When you add a new error variant in `caffeine_lang/errors.gleam`, add
/// the matching entry here too — the `explanations_test.gleam` fixture
/// asserts that every known code has prose so the audit catches gaps.
import caffeine_cli/color.{type ColorMode}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option}
import gleam/string

/// Structured explanation for a single error code.
pub type Explanation {
  Explanation(
    code: String,
    title: String,
    summary: String,
    causes: List(String),
    fix: String,
    link: Option(String),
  )
}

const docs_root: String = "https://caffeine.brickellresearch.org/errors/"

/// All explanations, keyed by error code.
pub fn all() -> Dict(String, Explanation) {
  [
    // --- Frontend parser (E1xx) ---
    Explanation(
      code: "E100",
      title: "parse error",
      summary: "The tokenizer or parser couldn't make sense of a .caffeine file. Something about the syntax didn't match what Caffeine expected at that position.",
      causes: [
        "Unterminated string literal (missing closing quote).",
        "Invalid character in a measurement or expectation body.",
        "Unexpected token — a keyword, brace, or separator out of place.",
        "Field name wrapped in quotes (Caffeine field names are bare identifiers, not strings).",
      ],
      fix: "Re-read the line shown in the error. Parse errors point at the exact column where the parser gave up — the fix is usually within one or two tokens of that caret.",
      link: option.Some(docs_root <> "E100"),
    ),

    // --- Frontend validator (E2xx) ---
    Explanation(
      code: "E200",
      title: "validation error",
      summary: "The file parsed, but its shape is inconsistent: an extendable is referenced that doesn't exist, a type alias is defined twice, a circular alias chain, a refinement value isn't the right kind of literal, and so on.",
      causes: [
        "Extendable or type alias referenced before (or without) being defined.",
        "Duplicate extendable, type alias, or field name in the same scope.",
        "Type alias chain that cycles back on itself.",
        "Refinement value (e.g. `OneOf`) with a literal that isn't the declared type.",
        "Dict key type alias that doesn't ultimately resolve to String.",
      ],
      fix: "The error message names the offending identifier. Search the file for that name to find the definition and references; either add the missing definition, remove the duplicate, break the cycle, or correct the type.",
      link: option.Some(docs_root <> "E200"),
    ),

    // --- Linker (E3xx) ---
    Explanation(
      code: "E301",
      title: "linker parse error",
      summary: "The linker tried to re-parse a fragment (typically a templated value or a standard-library artifact reference) and failed. This is distinct from E100 — the original file parsed fine, but a derived fragment didn't.",
      causes: [
        "An artifact reference whose template body is malformed.",
        "A standard-library artifact the linker doesn't recognize.",
      ],
      fix: "Check the artifact name and argument list against `caffeine artifacts`. If you wrote a custom artifact reference, verify its template syntax.",
      link: option.Some(docs_root <> "E301"),
    ),

    Explanation(
      code: "E302",
      title: "value validation error",
      summary: "A literal value (a number, string, list, or record) didn't match the declared type of the field it was assigned to.",
      causes: [
        "Wrong primitive type — e.g. a String literal where an Integer was expected.",
        "List where a single value was expected, or vice versa.",
        "A record missing a required field, or with an unexpected field.",
        "A refinement violated — e.g. a value outside an `InclusiveRange`, or not in a `OneOf` set.",
      ],
      fix: "Look at the type declaration for the field named in the error and adjust the value to match. `caffeine types` shows the full type-system reference.",
      link: option.Some(docs_root <> "E302"),
    ),

    Explanation(
      code: "E303",
      title: "duplicate identifier",
      summary: "Two measurements or expectations in the workspace have the same name. Caffeine requires names to be unique across all files, not just within one file.",
      causes: [
        "Copy-paste of a measurement or expectation without renaming.",
        "Two unrelated files that independently chose the same name.",
        "An identifier shadowed across nested namespaces (if you use them).",
      ],
      fix: "Rename one of the duplicates. If the two definitions should be the same thing, consolidate them into a single file and remove the other.",
      link: option.Some(docs_root <> "E303"),
    ),

    Explanation(
      code: "E304",
      title: "vendor resolution error",
      summary: "An expectation references a measurement whose vendor (Datadog, Honeycomb, etc.) Caffeine couldn't resolve, or the vendor is supported but configured in a way the linker rejected.",
      causes: [
        "Measurement file lives under a directory that doesn't name a known vendor.",
        "Vendor name misspelled in the measurement file's frontmatter.",
        "Measurement references a field the vendor's provider doesn't support.",
      ],
      fix: "Confirm the measurement file is under a vendor-named directory (`measurements/datadog/...`) and that the vendor's required fields are present.",
      link: option.Some(docs_root <> "E304"),
    ),

    // --- Semantic analysis (E4xx) ---
    Explanation(
      code: "E402",
      title: "template parse error",
      summary: "A templated value (like `$window_default` or an artifact argument) couldn't be parsed. Semantic analysis tried to resolve it and the template body itself was syntactically wrong.",
      causes: [
        "Missing or mismatched `{{ }}` in a template body.",
        "A `$`-prefixed reference without a matching parameter definition.",
        "Template argument count doesn't match the template's parameter list.",
      ],
      fix: "Locate the template named in the error and verify its body is well-formed. Artifact templates live in the standard library — `caffeine artifacts` lists them.",
      link: option.Some(docs_root <> "E402"),
    ),

    Explanation(
      code: "E403",
      title: "template resolution error",
      summary: "A template parsed, but couldn't be resolved against the current context. Usually this means a reference to a value the template expected to exist, but didn't.",
      causes: [
        "Referenced parameter isn't defined on the measurement or expectation.",
        "Template used outside the scope it was intended for.",
        "Artifact call missing a required argument.",
      ],
      fix: "Read the error message for the missing name and ensure it's defined in the surrounding block (the measurement or expectation), or add the missing argument to the artifact call.",
      link: option.Some(docs_root <> "E403"),
    ),

    Explanation(
      code: "E404",
      title: "dependency validation error",
      summary: "An expectation's `relations` field names a dependency (another expectation or measurement) that doesn't exist in the workspace.",
      causes: [
        "Typo in a dependency name.",
        "Dependency defined in a file the workspace didn't pick up (wrong directory or filename).",
        "Dependency removed but references to it weren't cleaned up.",
      ],
      fix: "Check that the dependency is defined and lives under the expectations or measurements directory Caffeine is compiling. Either fix the name, add the missing definition, or remove the stale reference.",
      link: option.Some(docs_root <> "E404"),
    ),

    // --- Code generation (E5xx) ---
    Explanation(
      code: "E500",
      title: "terraform resolution error (unknown vendor)",
      summary: "The code generator hit a vendor it doesn't have a Terraform template for. This is the catch-all code — the specific vendor codes (E502–E505) are more informative when they apply.",
      causes: [
        "Measurement uses a vendor Caffeine's current build doesn't support.",
        "Vendor name was normalized unexpectedly (check case and spelling).",
      ],
      fix: "Check `caffeine artifacts` or the project's supported-vendor list. If the vendor should be supported, this is a compiler bug — please file it.",
      link: option.Some(docs_root <> "E500"),
    ),

    Explanation(
      code: "E501",
      title: "SLO query resolution error",
      summary: "Code generation couldn't assemble the metric query for an SLO. The SLO's `query` field references something (a measurement, a template parameter) that didn't resolve to a concrete value at codegen time.",
      causes: [
        "Missing or empty `query` field on an SLO.",
        "Template in the query body references a parameter with no default and no passed value.",
        "Measurement referenced in the query isn't in the workspace.",
      ],
      fix: "Inspect the SLO's `query` field. Ensure every template parameter has a value (either a default or one passed via the expectation) and every measurement name resolves.",
      link: option.Some(docs_root <> "E501"),
    ),

    Explanation(
      code: "E502",
      title: "datadog codegen error",
      summary: "Caffeine couldn't generate the Terraform resource for a Datadog-backed SLO or monitor. The measurement or expectation is valid on its own, but something specific to the Datadog provider template rejected it.",
      causes: [
        "Required Datadog-specific fields missing (e.g. `warning_threshold`, `critical_threshold`).",
        "Unsupported Datadog query shape for the SLO type.",
        "Tag syntax that doesn't match Datadog's `key:value` expectation.",
      ],
      fix: "Check the Datadog provider docs for the specific resource shape, and ensure the expectation declares every field the Datadog template requires.",
      link: option.Some(docs_root <> "E502"),
    ),

    Explanation(
      code: "E503",
      title: "honeycomb codegen error",
      summary: "Caffeine couldn't generate the Terraform resource for a Honeycomb-backed measurement. The measurement or expectation is valid on its own, but the Honeycomb provider template rejected a specific field.",
      causes: [
        "Required Honeycomb-specific fields missing (dataset, query spec).",
        "Derived-column reference that doesn't exist in the dataset.",
      ],
      fix: "Check the Honeycomb provider docs for the resource shape, and ensure the dataset and any derived columns referenced actually exist in Honeycomb.",
      link: option.Some(docs_root <> "E503"),
    ),

    Explanation(
      code: "E504",
      title: "dynatrace codegen error",
      summary: "Caffeine couldn't generate the Terraform resource for a Dynatrace-backed measurement. The measurement or expectation is valid on its own, but the Dynatrace provider template rejected a specific field.",
      causes: [
        "Required Dynatrace-specific fields missing (management zone, metric selector).",
        "Metric selector syntax that doesn't parse as Dynatrace's M2M language.",
      ],
      fix: "Check the Dynatrace provider docs for the resource shape and verify the metric selector is well-formed.",
      link: option.Some(docs_root <> "E504"),
    ),

    Explanation(
      code: "E505",
      title: "new relic codegen error",
      summary: "Caffeine couldn't generate the Terraform resource for a New Relic–backed measurement. The measurement or expectation is valid on its own, but the New Relic provider template rejected a specific field.",
      causes: [
        "Required New Relic–specific fields missing (NRQL query, account ID).",
        "NRQL query syntax that doesn't parse on the New Relic side.",
      ],
      fix: "Check the New Relic provider docs for the resource shape and verify the NRQL query is valid by running it in One.",
      link: option.Some(docs_root <> "E505"),
    ),

    // --- Caffeine Query Language (E6xx) ---
    Explanation(
      code: "E601",
      title: "CQL resolver error",
      summary: "A Caffeine Query Language expression parsed but couldn't be resolved against the workspace. Typically this is a reference to a field or measurement that doesn't exist in scope.",
      causes: [
        "Field name in a CQL expression doesn't match any field on the referenced type.",
        "Measurement alias used before it's bound.",
        "Type mismatch between a CQL operator and its operands.",
      ],
      fix: "Check the names in the CQL expression against the measurement or expectation fields they're pulling from. The error message names the unresolved symbol.",
      link: option.Some(docs_root <> "E601"),
    ),

    Explanation(
      code: "E602",
      title: "CQL parse error",
      summary: "A Caffeine Query Language expression didn't parse. The CQL tokenizer or parser gave up on the syntax before it could build a tree.",
      causes: [
        "Unbalanced parentheses or brackets in a CQL expression.",
        "Operator used in a position the grammar doesn't accept.",
        "Unterminated string or identifier inside a CQL literal.",
      ],
      fix: "Re-read the CQL expression at the column the error points to. Most CQL syntax errors are within one or two tokens of that position.",
      link: option.Some(docs_root <> "E602"),
    ),
  ]
  |> list.map(fn(e) { #(e.code, e) })
  |> dict.from_list
}

/// Look up an explanation by error code. Codes are matched
/// case-insensitively so `caffeine explain e103` works too.
pub fn lookup(code: String) -> Result(Explanation, Nil) {
  dict.get(all(), string.uppercase(code))
}

/// All known error codes, sorted. Used for did-you-mean suggestions when
/// the user types a code that doesn't exist.
pub fn known_codes() -> List(String) {
  all()
  |> dict.keys
  |> list.sort(string.compare)
}

/// Render an explanation as human-readable text, with color when enabled.
pub fn render(explanation: Explanation, color_mode: ColorMode) -> String {
  let header =
    color.bold(color.red(explanation.code, color_mode), color_mode)
    <> color.bold(": " <> explanation.title, color_mode)

  let causes_section = case explanation.causes {
    [] -> ""
    causes ->
      "\n\n"
      <> color.bold(color.cyan("Common causes:", color_mode), color_mode)
      <> "\n"
      <> {
        causes
        |> list.map(fn(cause) { "  • " <> cause })
        |> string.join("\n")
      }
  }

  let fix_section =
    "\n\n"
    <> color.bold(color.cyan("How to fix:", color_mode), color_mode)
    <> "\n  "
    <> explanation.fix

  let link_section = case explanation.link {
    option.Some(url) ->
      "\n\n"
      <> color.bold(color.cyan("More: ", color_mode), color_mode)
      <> color.dim(url, color_mode)
    option.None -> ""
  }

  header
  <> "\n\n"
  <> explanation.summary
  <> causes_section
  <> fix_section
  <> link_section
}
