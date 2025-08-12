///|
pub fn impls_to_string(impls : @syntax.Impls) -> String {
  impls
  |> RemoveGroup::process
  |> then(x => Fmt::new().impls(x))
  |> @pp.render(width=80)
}

///|
pub fn format(source : String) -> String {
  let { tokens, .. } = @lexer.tokens_from_string(comment=false, source)
  let (impls, diag) = @handrolled_parser.parse(tokens)
  ignore(diag)
  impls
  |> RemoveGroup::process
  |> then(x => Fmt::new().impls(x))
  |> @pp.render(width=80)
}

///|
pub fn debug_comment(source : String) -> (String, String) {
  let { tokens, .. } = @lexer.tokens_from_string(comment=true, source)
  let (impls, _) = @handrolled_parser.parse(tokens)
  let mapper = @comment.Mapper::new(tokens, impls)
  let attach_info = mapper.to_debug_info()
  let ast = impls
    |> RemoveGroup::process
    |> then(x => Fmt::new(mapper~).impls(x))
    |> @pp.render(width=80)
  (attach_info, ast)
}

///|
fn init {
  ignore((format, debug_comment))
}
