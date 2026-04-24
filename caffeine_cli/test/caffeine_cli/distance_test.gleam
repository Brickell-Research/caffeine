import caffeine_cli/distance
import gleam/option.{None, Some}
import gleeunit/should

// --- levenshtein ---

pub fn levenshtein_identical_test() {
  distance.levenshtein("compile", "compile") |> should.equal(0)
}

pub fn levenshtein_empty_test() {
  distance.levenshtein("", "") |> should.equal(0)
  distance.levenshtein("", "abc") |> should.equal(3)
  distance.levenshtein("abc", "") |> should.equal(3)
}

pub fn levenshtein_single_substitution_test() {
  distance.levenshtein("compile", "comoile") |> should.equal(1)
}

pub fn levenshtein_single_insertion_test() {
  distance.levenshtein("compil", "compile") |> should.equal(1)
}

pub fn levenshtein_single_deletion_test() {
  distance.levenshtein("compilee", "compile") |> should.equal(1)
}

pub fn levenshtein_unrelated_test() {
  // "kitten" -> "sitting" is the canonical Levenshtein example, distance 3.
  distance.levenshtein("kitten", "sitting") |> should.equal(3)
}

// --- nearest ---

pub fn nearest_finds_close_match_test() {
  let candidates = ["compile", "validate", "format"]
  distance.nearest("compil", candidates, max_distance: 2)
  |> should.equal(Some("compile"))
}

pub fn nearest_picks_closest_when_multiple_test() {
  let candidates = ["explain", "expand", "extra"]
  // "explai" is distance 1 from "explain", 2 from "expand", 4 from "extra".
  distance.nearest("explai", candidates, max_distance: 3)
  |> should.equal(Some("explain"))
}

pub fn nearest_returns_none_when_too_far_test() {
  let candidates = ["compile", "validate", "format"]
  distance.nearest("xyzzy", candidates, max_distance: 2)
  |> should.equal(None)
}

pub fn nearest_empty_candidates_test() {
  distance.nearest("anything", [], max_distance: 5)
  |> should.equal(None)
}

pub fn nearest_max_distance_zero_only_matches_exact_test() {
  let candidates = ["compile", "validate"]
  distance.nearest("compile", candidates, max_distance: 0)
  |> should.equal(Some("compile"))
  distance.nearest("compil", candidates, max_distance: 0)
  |> should.equal(None)
}
