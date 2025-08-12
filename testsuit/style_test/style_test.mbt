///|
fn @test.T::run(t : Self) -> Unit raise {
  let name = t.name
  let source = @fs.read_file_to_string(
    "./testsuit/style_test/fixtures/\{name}.input",
  ) catch {
    _ => ""
  }
  t.writeln("// generated file, do not edit!")
  t.write(@fmt.format(source))
  t.snapshot(filename="\{name}.output")
}

///|
test "compose_case_rhs" (t : @test.T) {
  t.run()
}

///|
test "compose_let_rhs" (t : @test.T) {
  t.run()
}

///|
test "chained_dot" (t : @test.T) {
  t.run()
}

///|
test "mixed_infix" (t : @test.T) {
  t.run()
}

///|
test "compose_arrow_rhs" (t : @test.T) {
  t.run()
}

///|
test "trailing_block" (t : @test.T) {
  t.run()
}

///|
test "cases" (t : @test.T) {
  t.run()
}

///|
test "lab" (t : @test.T) {
  t.run()
}
