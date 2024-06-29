import gleam/dict
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import lustre
import lustre/attribute.{style}
import lustre/element.{text}
import lustre/element/html
import lustre/event

const target = "ariana"

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(guesses: List(String), current: String)
}

fn init(_flags) -> Model {
  Model(guesses: [], current: "")
}

type Msg {
  Guess
  OnInput(value: String)
}

fn update(model: Model, msg) {
  case msg {
    OnInput(value) -> {
      Model(guesses: model.guesses, current: value)
    }
    Guess -> {
      case string.length(model.current) {
        l if l > 1 -> {
          Model(
            guesses: list.append(model.guesses, [model.current]),
            current: "",
          )
        }
        _ -> {
          Model(guesses: model.guesses, current: model.current)
        }
      }
    }
  }
}

pub type Color {
  Gray
  Yellow
  Green
}

fn hex_from_color(c) {
  case c {
    Gray -> "#333"
    Yellow -> "#773"
    Green -> "#393"
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

pub fn match_greens(
  guess: List(String),
  target: List(String),
) -> #(List(Letter), dict.Dict(String, Int)) {
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

fn guess_view(guess: String) {
  let guess = string.to_graphemes(guess |> string.lowercase)
  let target = string.to_graphemes(target |> string.lowercase)

  let #(guess, unmatched) = match_greens(guess, target)
  let guess = match_yellows(guess, unmatched)

  html.div(
    [style([#("display", "flex"), #("gap", "1rem")])],
    guess
      |> list.map(fn(letter) {
        html.div(
          [
            style([
              #("width", "1.5em"),
              #("height", "1.5em"),
              #("font-size", "4rem"),
              #("background-color", hex_from_color(letter.color)),
              #("text-transform", "capitalize"),
              #("display", "grid"),
              #("place-items", "center"),
            ]),
          ],
          [element.text(letter.letter)],
        )
      }),
  )
}

fn view(model: Model) {
  html.main(
    [
      style([
        #("display", "flex"),
        #("flex-direction", "column"),
        #("align-items", "center"),
        #("gap", "1.5rem"),
        #("padding", "1.5rem"),
      ]),
    ],
    [
      html.h1([], [element.text("Guess the name!")]),
      element.fragment(list.map(model.guesses, guess_view)),
      html.div([style([#("display", "flex"), #("gap", "2rem")])], [
        html.input([
          style([#("font-size", "2rem"), #("text-transform", "uppercase")]),
          event.on_input(OnInput),
        ]),
        html.button(
          [
            style([
              #("background-color", "#44a"),
              #("font-size", "2rem"),
              #("border", "none"),
              #("padding", "0.5em"),
              #("cursor", "pointer"),
            ]),
            event.on_click(Guess),
          ],
          [text("Guess")],
        ),
      ]),
    ],
  )
}
