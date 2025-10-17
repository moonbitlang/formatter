///|
fn @test.T::run(
  t : Self,
  enable_ast_check? : Bool = true,
  enable_idempotent_check? : Bool = true,
) -> Unit raise {
  let name = t.name()
  let source = @fs.read_file_to_string(
    "./testsuit/style_test/fixtures/\{name}.input",
  ) catch {
    _ => ""
  }
  let round1 = @fmt.format(source)
  if enable_ast_check {
    ast_check(name~, source~, round1~)
  }
  let round2 = @fmt.format(round1)
  if enable_idempotent_check {
    idempotent_check(name~, round1~, round2~)
  }
  t.writeln("// generated file, do not edit!")
  t.write(round1)
  t.snapshot(filename="\{name}.output")
}

///|
fn idempotent_check(
  name~ : String,
  round1~ : String,
  round2~ : String,
) -> Unit raise {
  if round1 != round2 {
    fail(
      (
        $| format(\{name}.mbt) is not idempotent. 
        $|================= round1 =================
        $|\{round1}
        $|================= round2 =================
        $|\{round2}
      ),
    )
  }
}

///|
fn ast_check(name~ : String, source~ : String, round1~ : String) -> Unit raise {
  @basic.show_loc.val = String
  let (source_ast, report1, _) = @fmt.parse(source)
  let (round1_ast, report2, _) = @fmt.parse(round1)
  if report1.length() != 0 {
    fail(
      (
        $| format(\{name}.mbt) produced diagnostics on the original source.
        $|================= diagnostics =================
        $|\{report1.to_json().stringify(indent=2)})}
      ),
    )
  }
  if report2.length() != 0 {
    fail(
      (
        $| format(\{name}.mbt) produced diagnostics on the formatted source.
        $|================= diagnostics =================
        $|\{report2.to_json().stringify(indent=2)}
      ),
    )
  }
  @basic.show_loc.val = Hidden
  if source_ast.to_json() != round1_ast.to_json() {
    fail(
      (
        $| format(\{name}.mbt) changed the AST.
        $|================= source AST =================
        $|\{source_ast.to_json().stringify(indent=2)}
        $|================= round1 AST =================
        $|\{round1_ast.to_json().stringify(indent=2)}
      ),
    )
  }
}

// ///|
// test "compose_case_rhs" (t : @test.T) {
//   t.run()
// }

// ///|
// test "compose_let_rhs" (t : @test.T) {
//   t.run()
// }

// ///|
// test "chained_dot" (t : @test.T) {
//   t.run()
// }

// ///|
// test "mixed_infix" (t : @test.T) {
//   t.run()
// }

// ///|
// test "compose_arrow_rhs" (t : @test.T) {
//   t.run()
// }

// ///|
// test "trailing_block" (t : @test.T) {
//   t.run()
// }

///|
test "cases" (t : @test.T) {
  // TODO: avoid printing trailing marks in the json
  t.run(enable_ast_check=false)
}

///|
test "typedecl_enum" (t : @test.T) {
  t.run()
}

///|
test "typedecl_struct" (t : @test.T) {
  t.run()
}

///|
test "typedecl_derive" (t : @test.T) {
  t.run()
}

///|
test "typedecl_suberror" (t : @test.T) {
  t.run()
}

///|
test "typedecl_type" (t : @test.T) {
  t.run()
}

///|
test "typedecl_tuplestruct" (t : @test.T) {
  t.run()
}

///|
test "typedecl_alias" (t : @test.T) {
  t.run()
}

///|
test "trait_impl_decl" (t : @test.T) {
  t.run()
}

///|
test "top_function" (t : @test.T) {
  // TODO: adapt new parameter syntax in parser
  t.run(enable_ast_check=false)
}

///|
test "attribute" (t : @test.T) {
  // TODO: avoid printing attributes raw in the json
  t.run(enable_ast_check=false)
}

///|
test "ffi" (t : @test.T) {
  t.run()
}

///|
test "arrow_function" (t : @test.T) {
  t.run()
}

///|
test "docstring" (t : @test.T) {
  t.run(enable_ast_check=false)
}
