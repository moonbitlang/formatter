///|
fn @test.T::run(t : Self) -> Unit raise {
  let name = t.name()
  let source = @fs.read_file_to_string(
    "./testsuit/comment_test/__snapshot__/\{name}.input",
  ) catch {
    _ => ""
  }
  let (comments_info, formatted) = @fmt.debug_comment(source)
  t.write(formatted)
  t.writeln("==========================================================")
  t.writeln("// generated file, do not edit!")
  t.writeln(comments_info)
  t.snapshot(filename="\{name}.output")
}

///|
test "expr_sequence" (t : @test.T) {
  t.run()
}

///|
test "expr_sequence_array" (t : @test.T) {
  t.run()
}

///|
test "expr_sequence_array2" (t : @test.T) {
  t.run()
}

///|
test "expr_sequence_array3" (t : @test.T) {
  t.run()
}

///|
test "top_func" (t : @test.T) {
  t.run()
}
