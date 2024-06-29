import gleam/dict
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import lustre
import lustre/attribute.{class, style}
import lustre/element.{fragment, text}
import lustre/element/html.{button, div}
import lustre/event.{on_click, on_keydown}

const target = "ariana"

const first_row = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]

const second_row = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]

const third_row = ["CR", "z", "x", "c", "v", "b", "n", "m", "BS"]

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(
    guesses: List(String),
    current: String,
    known_letters: dict.Dict(String, Color),
    has_won: Bool,
  )
}

fn init(_flags) -> Model {
  Model(guesses: [], current: "", known_letters: dict.new(), has_won: False)
}

type Msg {
  Guess
  NewLetter(value: String)
  Backspace
}

fn add_known_letters_from_guess(
  known_letters: dict.Dict(String, Color),
  guess: String,
) {
  let guess = match(guess)

  guess
  |> list.fold(known_letters, fn(known_letters, letter) {
    case letter.color, dict.get(known_letters, letter.letter) {
      Green, _ -> known_letters |> dict.insert(letter.letter, Green)
      Yellow, Ok(Gray) | Yellow, Error(_) ->
        known_letters |> dict.insert(letter.letter, Yellow)
      Gray, Error(_) -> known_letters |> dict.insert(letter.letter, Gray)
      _, _ -> known_letters
    }
  })
}

fn update(model: Model, msg) {
  case msg {
    NewLetter(value) -> {
      assert_eq(
        string.length(value),
        1,
        "only one new letter at a time: " <> value,
      )
      case string.length(target) - string.length(model.current) {
        diff if diff > 0 ->
          Model(
            guesses: model.guesses,
            current: model.current <> value,
            known_letters: model.known_letters,
            has_won: model.has_won,
          )
        _ -> model
      }
    }
    Backspace ->
      Model(
        guesses: model.guesses,
        current: model.current |> string.drop_right(1),
        known_letters: model.known_letters,
        has_won: model.has_won,
      )
    Guess -> {
      case string.length(target) - string.length(model.current) {
        diff if diff == 0 -> {
          Model(
            guesses: list.append(model.guesses, [model.current]),
            current: "",
            known_letters: model.known_letters
              |> add_known_letters_from_guess(model.current),
            has_won: model.has_won || model.current == target,
          )
        }
        _ -> model
      }
    }
  }
}

pub type Color {
  Gray
  Yellow
  Green
}

fn color_class(c) {
  case c {
    Green -> "green"
    Yellow -> "yellow"
    Gray -> "gray"
  }
}

pub type Letter {
  Letter(letter: String, color: Color)
}

fn assert_eq(a, b, msg) {
  case a == b {
    True -> Nil
    False -> {
      io.debug(a)
      io.debug(b)
      panic as msg
    }
  }
}

pub fn match_greens(guess: String) -> #(List(Letter), dict.Dict(String, Int)) {
  let guess = string.to_graphemes(guess |> string.lowercase)
  let target = string.to_graphemes(target |> string.lowercase)

  assert_eq(
    list.length(guess),
    list.length(target),
    "guess and target must have same length",
  )

  list.zip(guess, target)
  |> list.fold(from: #([], dict.new()), with: fn(res, val) {
    let #(letters, unmatched) = res
    let #(guess, target) = val
    assert_eq(string.length(guess), 1, "guess longer than 1 char")
    assert_eq(string.length(target), 1, "target longer than 1 char")
    case guess == target {
      True -> #(
        list.append(letters, [Letter(letter: guess, color: Green)]),
        unmatched,
      )
      False -> #(
        list.append(letters, [Letter(letter: guess, color: Gray)]),
        unmatched
          |> dict.update(target, fn(count) {
            case count {
              option.None -> 1
              option.Some(count) -> count + 1
            }
          }),
      )
    }
  })
}

pub fn match_yellows(
  guess: List(Letter),
  unmatched: dict.Dict(String, Int),
) -> List(Letter) {
  case guess {
    [] -> panic as "empty guess list should never happen"
    [letter] -> {
      [
        case letter.color, dict.get(unmatched, letter.letter) {
          Gray, Ok(count) if count > 0 ->
            Letter(letter: letter.letter, color: Yellow)
          _, _ -> letter
        },
      ]
    }
    [letter, ..rest] -> {
      let #(letter, unmatched) = case
        letter.color,
        dict.get(unmatched, letter.letter)
      {
        Gray, Ok(count) if count > 0 -> #(
          Letter(letter: letter.letter, color: Yellow),
          unmatched |> dict.insert(letter.letter, count - 1),
        )
        _, _ -> #(letter, unmatched)
      }

      [letter, ..match_yellows(rest, unmatched)]
    }
  }
}

fn match(guess: String) -> List(Letter) {
  let #(guess, unmatched) = match_greens(guess)
  match_yellows(guess, unmatched)
}

fn letter_container(children, rainbow) {
  html.div(
    [style([#("display", "flex"), #("gap", "1rem")])],
    children |> list.map(letter_view(_, rainbow)),
  )
}

fn letter_view(letter: Letter, rainbow) {
  html.div(
    [
      style([
        #("width", "1.5em"),
        #("height", "1.5em"),
        #("font-size", "4rem"),
        #("text-transform", "uppercase"),
        #("display", "grid"),
        #("place-items", "center"),
      ]),
      class(case rainbow {
        True -> "rainbow"
        False -> color_class(letter.color)
      }),
    ],
    [text(letter.letter)],
  )
}

fn guess_view(guess: String) {
  let rainbow = guess == target
  let guess = match(guess)

  letter_container(guess, rainbow)
}

fn keyboard_row_view(row, model: Model) {
  div(
    [style([#("display", "flex"), #("gap", "1rem")])],
    row
      |> list.map(fn(letter) {
        button(
          [
            on_click(case letter {
              "BS" -> Backspace
              "CR" -> Guess
              l -> NewLetter(l)
            }),
            class(case model.known_letters |> dict.get(letter) {
              Ok(c) -> color_class(c)
              _ -> "light-gray"
            }),
            style([
              #("display", "grid"),
              #("border", "none"),
              #("place-items", "center"),
              #("cursor", "pointer"),
              #("width", case letter {
                "BS" | "CR" -> "2.75em"
                _ -> "1.675em"
              }),
              #("height", "2.25em"),
              #("font-size", "1.9rem"),
              #("text-transform", "uppercase"),
            ]),
          ],
          [
            case letter {
              "BS" -> text("⌫")
              "CR" -> text("↩")
              l -> text(l)
            },
          ],
        )
      }),
  )
}

fn view(model: Model) {
  html.main(
    [
      on_keydown(fn(l) {
        case l {
          "Backspace" -> Backspace
          "Enter" -> Guess
          l -> NewLetter(l)
        }
      }),
      style([
        #("display", "flex"),
        #("flex-direction", "column"),
        #("align-items", "center"),
        #("gap", "1.5rem"),
        #("padding", "1.5rem"),
      ]),
    ],
    [
      html.h1([], [
        element.text(case model.has_won {
          True -> "Congratulations!"
          False -> "Guess the name!"
        }),
      ]),
      fragment(list.map(model.guesses, guess_view)),
      case model.has_won {
        True -> fragment([])
        False ->
          letter_container(
            model.current
              |> string.pad_right(to: string.length(target), with: " ")
              |> string.to_graphemes
              |> list.map(fn(letter) { Letter(letter: letter, color: Gray) }),
            False,
          )
      },
      case model.has_won {
        False ->
          html.div(
            [
              style([
                #("display", "flex"),
                #("flex-direction", "column"),
                #("align-items", "center"),
                #("gap", "1rem"),
              ]),
            ],
            [
              keyboard_row_view(first_row, model),
              keyboard_row_view(second_row, model),
              keyboard_row_view(third_row, model),
            ],
          )
        True ->
          div([style([#("display", "flex")])], [
            html.img([
              attribute.src("/priv/static/cat1.webp"),
              attribute.attribute("frameBorder", "0"),
              style([#("width", "20rem"), #("height", "20rem")]),
            ]),
            html.img([
              attribute.src("/priv/static/cat2.webp"),
              attribute.attribute("frameBorder", "0"),
              style([#("width", "20rem"), #("height", "20rem")]),
            ]),
          ])
      },
    ],
  )
}
