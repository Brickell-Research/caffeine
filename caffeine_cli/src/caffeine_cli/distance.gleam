/// String distance utilities for did-you-mean suggestions.
///
/// Used to suggest the nearest command when the user mistypes a
/// subcommand (`caffeine compil` -> "did you mean 'compile'?") and the
/// nearest error code in `caffeine explain`. The implementation is
/// O(n*m) recursive Levenshtein — sufficient for the short strings
/// involved (command names ~10 chars, error codes 4 chars).
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Edit distance between two strings (insertions, deletions,
/// substitutions count as 1 each).
pub fn levenshtein(a: String, b: String) -> Int {
  do_levenshtein(string.to_graphemes(a), string.to_graphemes(b))
}

fn do_levenshtein(a: List(String), b: List(String)) -> Int {
  case a, b {
    [], rest -> list.length(rest)
    rest, [] -> list.length(rest)
    [x, ..xs], [y, ..ys] if x == y -> do_levenshtein(xs, ys)
    [_, ..xs] as a2, [_, ..ys] as b2 -> {
      let delete = do_levenshtein(xs, b2)
      let insert = do_levenshtein(a2, ys)
      let substitute = do_levenshtein(xs, ys)
      1 + min3(delete, insert, substitute)
    }
  }
}

/// Best did-you-mean suggestion for `target` from `candidates`. Returns
/// the candidate with the smallest edit distance, but only when that
/// distance is `<= max_distance` — beyond that threshold the suggestion
/// is more confusing than helpful (a typo of "foo" should not suggest
/// "completely-different-thing").
pub fn nearest(
  target: String,
  candidates: List(String),
  max_distance max_distance: Int,
) -> Option(String) {
  list.fold(candidates, None, fn(best, candidate) {
    let distance = levenshtein(target, candidate)
    case distance <= max_distance {
      False -> best
      True ->
        case best {
          None -> Some(candidate)
          Some(current) ->
            case distance < levenshtein(target, current) {
              True -> Some(candidate)
              False -> Some(current)
            }
        }
    }
  })
}

fn min3(a: Int, b: Int, c: Int) -> Int {
  case a < b, a < c, b < c {
    True, True, _ -> a
    True, False, _ -> c
    False, _, True -> b
    False, _, False -> c
  }
}
