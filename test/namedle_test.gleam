import gleam/dict
import gleam/string
import gleeunit
import gleeunit/should
import namedle

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn match_greens_test() {
  let guess = "hi" |> string.to_graphemes
  let target = "di" |> string.to_graphemes
  let match = [
    namedle.Letter(letter: "h", color: namedle.Gray),
    namedle.Letter("i", color: namedle.Green),
  ]
  let dict = dict.from_list([#("d", 1)])
  namedle.match_greens(guess, target)
  |> should.equal(#(match, dict))

  let guess = "laa" |> string.to_graphemes
  let target = "loo" |> string.to_graphemes
  let match = [
    namedle.Letter(letter: "l", color: namedle.Green),
    namedle.Letter("a", color: namedle.Gray),
    namedle.Letter("a", color: namedle.Gray),
  ]
  let dict = dict.from_list([#("o", 2)])
  namedle.match_greens(guess, target)
  |> should.equal(#(match, dict))
}
