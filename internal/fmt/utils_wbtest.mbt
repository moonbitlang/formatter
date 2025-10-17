///|
test "series" {
  let integer = fn(x : Int) { text(x.to_string()) }
  let r1 = series(@list.of([1, 2, 3, 4]), comma, integer)
  inspect(
    r1,
    content=(
      #|1,
      #|2,
      #|3,
      #|4,
    ),
  )
  let r2 = series(@list.of([1, 2, 3, 4]), comma, integer, trailing=AlwaysHidden)
  inspect(
    r2,
    content=(
      #|1,
      #|2,
      #|3,
      #|4
    ),
  )
  let r3 = group(series(@list.of([1, 2, 3, 4]), comma, integer))
  inspect(r3, content="1, 2, 3, 4")
}
