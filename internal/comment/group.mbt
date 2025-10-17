///|
pub(all) struct Comment {
  start : Position
  end : Position
  left : Triple?
  right : Triple?
  kind : CommentKind
} derive(Show)

///|
fn pretty_triple(x : Triple?) -> @pp.Document {
  match x {
    None => text("None")
    Some(x) =>
      text(x.0.to_string()) +
      space +
      @pp.parens(text(Location::{ start: x.1, end: x.2 }.to_string()))
  }
}

///|
// fn pretty_pos(x : Position) -> @pp.Document {
//   x.to_string() |> text
// }

///|
pub impl Pretty for Comment with pretty(self) {
  @pp.record({
    "kind": pretty(self.kind),
    "loc": text(Location::{ start: self.start, end: self.end }.to_string()),
    "surround": pretty((pretty_triple(self.left), pretty_triple(self.right))),
  })
}

///|
pub(all) enum CommentKind {
  Blank
  Block(String)
  Line(String)
} derive(Show)

///|
pub impl Pretty for CommentKind with pretty(x) {
  match x {
    Blank => text("BLANK")
    Block(s) => text(s.escape())
    Line(s) => text(s)
  }
}
