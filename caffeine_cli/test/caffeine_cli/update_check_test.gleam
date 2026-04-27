import caffeine_cli/github
import caffeine_cli/update_check
import gleeunit/should

// --- is_newer (canonical version comparison) ---

pub fn is_newer_patch_test() {
  update_check.is_newer("4.6.1", "4.6.0") |> should.be_true
}

pub fn is_newer_minor_test() {
  update_check.is_newer("4.7.0", "4.6.9") |> should.be_true
}

pub fn is_newer_major_test() {
  update_check.is_newer("5.0.0", "4.99.99") |> should.be_true
}

pub fn is_newer_two_digit_segment_test() {
  // Lex order would say "5.10.0" < "5.9.0"; numeric order is the opposite.
  update_check.is_newer("5.10.0", "5.9.0") |> should.be_true
}

pub fn is_newer_equal_test() {
  update_check.is_newer("5.0.11", "5.0.11") |> should.be_false
}

pub fn is_newer_older_test() {
  update_check.is_newer("5.0.5", "5.0.11") |> should.be_false
}

pub fn is_newer_trailing_zero_test() {
  update_check.is_newer("5.0", "5.0.0") |> should.be_false
}

pub fn is_newer_handles_v_prefix_via_github_helper_test() {
  // is_newer itself doesn't strip `v` — that's github.extract_tag's job.
  // Document the boundary so a future refactor doesn't move responsibility.
  update_check.is_newer("v5.0.1", "5.0.0") |> should.be_false
}

// --- github.extract_tag (JSON peek without a JSON dep) ---

pub fn extract_tag_strips_v_test() {
  let body = "{\"tag_name\": \"v5.2.0\", \"name\": \"5.2.0\"}"
  github.extract_tag(body) |> should.equal(Ok("5.2.0"))
}

pub fn extract_tag_without_v_test() {
  let body = "{\"tag_name\": \"5.2.0\"}"
  github.extract_tag(body) |> should.equal(Ok("5.2.0"))
}

pub fn extract_tag_picks_first_match_test() {
  // Real GitHub responses sometimes have multiple `tag_name` mentions in
  // nested objects (e.g. `target_commitish` blobs). The hand-rolled
  // splitter takes the first occurrence — assert that contract.
  let body = "{\"tag_name\": \"v5.2.0\", \"author\": {\"tag_name\": \"junk\"}}"
  github.extract_tag(body) |> should.equal(Ok("5.2.0"))
}

pub fn extract_tag_missing_returns_error_test() {
  github.extract_tag("{\"name\": \"5.2.0\"}") |> should.equal(Error(Nil))
  github.extract_tag("") |> should.equal(Error(Nil))
}
