// PLEASE READ BEFORE EDITING:
// 
// 1. The syntax2doc is implemented in a divide-and-conquer style
//
// 2. Do not emit trailing space or newline
//   Due to the behavior of the `nest` primitive, **`Hardline` represents the 
//   start of a line**, not its end. Therefore, each piece of code is responsible 
//   for handling its own leading newline or space, and should NOT emit trailing 
//   newlines and spaces (unless they are explicitly optional in the AST).
//
// 3. Consistent printing style is important for a formatter
//   In MoonBit, we do not strictly enforce the "keep your code DRY" principle.
//   Duplicating code is acceptable if abstraction becomes too complex.
//   However, in formatter, maintaining multiple copies makes it difficult to 
//   ensure consistent printing style. Before duplicating code, please consider 
//   reusing existing helper functions.
//

///|
priv struct Fmt {
  mapper : @comment.Mapper?
}

///|
fn fmt_comment(comment : @comment.Comment) -> Doc {
  match comment.kind {
    Blank => @pp.mandatory_line
    Block(_) => panic()
    Line(l) => @pp.mandatory_space + text(l) + @pp.mandatory_line
  }
}

///|
fn fmt_comments(comments : Array[@comment.Comment]) -> Doc {
  comments.map(fmt_comment).fold(init=empty, Doc::op_add)
}

///|
fn Fmt::wrap_comment(fmt : Self, key : @comment.Key?, doc : Doc) -> Doc {
  let (a, b) = fmt.comments(key)
  a + doc + b
}

///|
// fn Fmt::has_comment(fmt : Self, key : @comment.Key?) -> Bool {
//   match (fmt.mapper, key) {
//     (Some(mapper), Some(k)) => mapper.has_comment(key)
//     _ => false
//   }
// }

///|
// fn Fmt::has_trailing_comment(fmt : Self, key : @comment.Key?) -> Bool {
//   match fmt.mapper {
//     None => false
//     Some(m) => m.has_leading_comment(key)
//   }
// }

///|
// fn Fmt::has_leading_comment(fmt : Self, key : @comment.Key?) -> Bool {
//   match fmt.mapper {
//     None => false
//     Some(m) => m.has_trailing_comment(key)
//   }
// }

///|
/// Gets the formatted comments after to the given node's key.
fn Fmt::before_comment(fmt : Self, key : @comment.Key?) -> Doc {
  match (fmt.mapper, key) {
    (Some(mapper), Some(k)) =>
      mapper.consume_comments(key, c => c.start < k.loc().start) |> fmt_comments
    _ => empty
  }
}

///|
/// Gets the formatted comments before to the given node's key.
fn Fmt::after_comment(fmt : Self, key : @comment.Key?) -> Doc {
  match (fmt.mapper, key) {
    (Some(mapper), Some(k)) =>
      mapper.consume_comments(key, c => c.start >= k.loc().start)
      |> fmt_comments
    _ => empty
  }
}

///|
/// Gets the formatted comments attached to the given node's key.
/// 
/// Returns a tuple of two `Doc` values representing the comments before and 
/// after the node.
fn Fmt::comments(fmt : Self, key : @comment.Key?) -> (Doc, Doc) {
  let doc1 = fmt.before_comment(key)
  let doc2 = fmt.after_comment(key)
  (doc1, doc2)
}

///|
/// Gets the token table for the node.
fn Fmt::get_table(fmt : Self, node : Location) -> @comment.NodeTable {
  match fmt.mapper {
    Some(tbl) => tbl.get_table(node)
    None => @comment.NodeTable::empty()
  }
}

///|
fn Fmt::new(mapper? : @comment.Mapper) -> Self {
  { mapper, }
}

///|
fn Fmt::impls(fmt : Self, impls : List[@syntax.Impl]) -> Doc {
  concat_map(impls, x => fmt.impl_(x) + hardline + hardline) //TODO: handle comments between impls
}

///|
fn Fmt::impl_(fmt : Self, toplevel : @syntax.Impl) -> Doc {
  match toplevel {
    TopView(_) => panic() //TODO
    TopImpl(
      self_ty~,
      trait_~,
      method_name~,
      has_error~,
      quantifiers~,
      params~,
      ret_ty~,
      err_ty~,
      body~,
      vis~,
      attrs~,
      doc~,
      loc=_
    ) => {
      ignore(
        (
          self_ty, trait_, method_name, has_error, quantifiers, params, ret_ty, err_ty,
          body, vis, attrs, doc,
        ),
      )
      panic()
    }
    TopTrait({ name, supers, methods, vis, attrs, doc, loc: _ }) => {
      let doc = fmt.docstring(doc)
      let attrs = fmt.attributes(attrs)
      let vis = fmt.visibility(vis)
      let trait_ = text("trait")
      let name = space + fmt.binder(name)
      let supers = match supers {
        Empty => empty
        More(_) =>
          space +
          colon +
          space +
          series1(
            supers.map(x => fmt.type_var_constraint(x)),
            space + char('+'),
          )
      }
      let methods = braces(
        series1(methods.map(x => fmt.trait_method(x)), empty),
        force_newline=true,
      )
      doc + attrs + vis + trait_ + name + supers + methods
    }
    TopLetDef(binder~, ty~, expr~, vis~, is_constant~, attrs~, doc~, loc=_) => {
      let doc = fmt.docstring(doc)
      let attrs = fmt.attributes(attrs)
      let vis = fmt.visibility(vis)
      let let_ = text(if is_constant { "const" } else { "let" })
      let binder = space + fmt.binder(binder)
      let ty = match ty {
        None => empty
        Some(ty) => space + colon + fmt.ty(ty)
      }
      let rhs = space + char('=') + fmt.compose(expr, Expr) // TODO: compose_rhs
      doc + attrs + vis + let_ + binder + ty + rhs
    }
    TopTypeDef(typedecl) => fmt.typedecl(typedecl)
    TopFuncDef(fun_decl~, decl_body~, loc~) => {
      let table = fmt.get_table(loc)
      let {
        type_name,
        name,
        has_error: _,
        is_async,
        decl_params,
        quantifiers,
        return_type,
        error_type,
        vis,
        attrs,
        doc,
        params_loc: _,
      } = fun_decl
      let doc = fmt.docstring(doc)
      let attrs = fmt.attributes(attrs)
      let vis = fmt.visibility(vis)
      let fn_ = fmt.wrap_comment(table.get_token("fn"), text("fn"))
      let async_ = if is_async {
        fmt.wrap_comment(table.get_token("async"), space + text("async"))
      } else {
        empty
      }
      let quantifiers = fmt.type_var_binders(
        quantifiers,
        lbracket=table.get_token("lbracket"),
        commas=table.get_array("commas0"),
        tvar_tables=table.get_table_array("type_var_binders"),
        rbracket=table.get_token("rbracket"),
      )
      let type_name = match type_name {
        None => empty
        Some(n) => fmt.type_name(n) + text("::")
      }
      let binder = space + fmt.binder(name)
      let params = match decl_params {
        None => empty
        Some(xs) =>
          group(
            fmt.parameters(
              xs,
              lparen=table.get_token("lparen"),
              param_tables=table.get_table_array("parameters"),
              commas=table.get_array("commas1"),
              rparen=table.get_token("rparen"),
            ),
          )
      }
      let arrow = space + text("->")
      let return_type = match return_type {
        None => empty
        Some(ty) => space + fmt.ty(ty)
      }
      let error_type = fmt.error_type(error_type)
      let (extern_, body) = match decl_body {
        DeclBody(local_types~, expr~) =>
          (empty, space + fmt.expr_block(expr, local_types~))
        DeclStubs(Import(module_name~, func_name~)) =>
          (
            empty,
            space +
            equal +
            double_quoted(text(module_name)) +
            space +
            double_quoted(text(func_name)),
          )
        DeclStubs(Embedded(language~, code~)) => {
          let extern_ = match language {
            None => empty
            Some(s) => text("extern") + space + double_quoted(text(s)) + space
          }
          let code = fmt.embedded_code(code)
          (extern_, space + code)
        }
      }
      let layout = doc +
        attrs +
        vis +
        extern_ +
        async_ +
        fn_ +
        quantifiers +
        type_name +
        binder +
        params +
        arrow +
        return_type +
        error_type +
        body
      fmt.wrap_comment(Some(Node(loc)), layout)
    }
    TopTest(expr~, name~, params~, local_types~, attrs~, doc~, loc=_) => {
      let doc = fmt.docstring(doc)
      let attrs = fmt.attributes(attrs)
      let test_ = text("test")
      let name = match name {
        None => empty
        Some((s, _)) => space + double_quoted(text(s))
      }
      let params = match params {
        None => empty
        Some(xs) =>
          space +
          group(
            fmt.parameters(
              xs,
              lparen=None,
              param_tables=@comment.NodeTableArray::empty(),
              commas=@comment.NodeArray::empty(),
              rparen=None,
            ),
          )
      }
      let body = fmt.expr_block(expr, local_types~)
      doc + attrs + test_ + name + params + body
    }
    TopExpr(expr~, is_main~, local_types~, loc=_) => {
      let fn_ = text("fn")
      let name = space + text(if is_main { "main" } else { "init" })
      let expr = fmt.expr_block(expr, local_types~)
      fn_ + name + expr
    }
    TopImplRelation(self_ty~, trait_~, quantifiers~, vis~, attrs~, doc~, loc=_) => {
      let doc = fmt.docstring(doc)
      let attrs = fmt.attributes(attrs)
      let vis = fmt.visibility(vis)
      let impl_ = text("impl")
      let quantifiers = fmt.type_var_binders(
        quantifiers,
        lbracket=None,
        commas=@comment.NodeArray::empty(),
        tvar_tables=@comment.NodeTableArray::empty(),
        rbracket=None,
      )
      let self = space + fmt.ty(self_ty)
      let for_ = space + text("for")
      let trait_ = space + fmt.type_name(trait_)
      doc + attrs + vis + impl_ + quantifiers + self + for_ + trait_
    }
    TopBatchTraitAlias(pkg~, targets~, vis~, attrs~, is_list=_, doc~, loc=_) => {
      let doc = fmt.docstring(doc)
      let attrs = fmt.attributes(attrs)
      let vis = fmt.visibility(vis)
      let traitalias_ = text("traitalias") + space
      let pkg = match pkg {
        None => empty
        Some(label) => char('@') + fmt.label(label) + char('.')
      }
      let targets = match targets {
        More(x, tail=Empty) => fmt.alias_target(x)
        xs => group(parens(series1(xs.map(x => fmt.alias_target(x)), comma)))
      }
      doc + attrs + vis + traitalias_ + pkg + targets
    }
    TopBatchTypeAlias(pkg~, targets~, vis~, attrs~, is_list=_, doc~, loc=_) => {
      let doc = fmt.docstring(doc)
      let attrs = fmt.attributes(attrs)
      let vis = fmt.visibility(vis)
      let typealias_ = text("typealias") + space
      let pkg = match pkg {
        None => empty
        Some(label) => char('@') + fmt.label(label) + char('.')
      }
      let targets = match targets {
        More(x, tail=Empty) => fmt.alias_target(x)
        xs => group(parens(series1(xs.map(x => fmt.alias_target(x)), comma)))
      }
      doc + attrs + vis + typealias_ + pkg + targets
    }
    TopFuncAlias(
      pkg~,
      type_name~,
      targets~,
      vis~,
      attrs~,
      is_list=_,
      doc~,
      loc=_
    ) => {
      let doc = fmt.docstring(doc)
      let attrs = fmt.attributes(attrs)
      let vis = fmt.visibility(vis)
      let fnalias_ = text("fnalias") + space
      let type_name = match type_name {
        None => empty
        Some(label) => fmt.label(label) + text("::")
      }
      let pkg = match pkg {
        None => empty
        Some(label) => char('@') + fmt.label(label) + char('.')
      }
      let targets = match targets {
        More(x, tail=Empty) => fmt.alias_target(x)
        xs => group(parens(series1(xs.map(x => fmt.alias_target(x)), comma)))
      }
      doc + attrs + vis + fnalias_ + pkg + type_name + targets
    }
  }
}

///|
fn Fmt::embedded_code(fmt : Fmt, code : @syntax.EmbeddedCode) -> Doc {
  ignore(fmt) //TODO: use fmt to access comments
  match code {
    CodeString(s) => double_quoted(text(s))
    CodeMultilineString(xs) =>
      softline + group(separate_map(xs, hardline, s => text("#|" + s)))
  }
}

///|
fn Fmt::alias_target(fmt : Fmt, target : @syntax.AliasTarget) -> Doc {
  let { binder, target } = target
  let binder = fmt.binder(binder)
  match target {
    None => binder
    Some(target) => fmt.label(target) + space + text("as") + space + binder
  }
}

///|
fn Fmt::type_var_constraint(
  fmt : Fmt,
  constraint : @syntax.TypeVarConstraint,
) -> Doc {
  ignore(fmt) //TODO: use fmt to access comments
  let { trait_, loc: _ } = constraint
  longident(trait_)
}

///|
fn Fmt::type_var_binder(
  env : Fmt,
  binder : @syntax.TypeVarBinder,
  tvar_table~ : @comment.NodeTable,
) -> Doc {
  let colon = tvar_table.get_token("colon")
  let pluses = tvar_table.get_array("pluses")
  let { name, constraints, name_loc: loc } = binder
  let name = env.wrap_comment(Some(Node(loc)), text(name))
  let constraints = match constraints {
    Empty => empty
    More(_) => {
      let colon = space + env.wrap_comment(colon, char(':'))
      let mut traits = space
      for i, constraint in constraints {
        let plus = if i == 0 {
          empty
        } else {
          env.wrap_comment(pluses[i], empty)
        }
        let constraint = env.type_var_constraint(constraint)
        traits = traits + plus + constraint
      }
      colon + traits
    }
  }
  name + constraints
}

///|
// TODO: patch the parser
fn @syntax.TypeVarBinder::loc(self : Self) -> Location {
  match self.constraints {
    More(x, ..) => self.name_loc.merge(x.loc)
    Empty => self.name_loc
  }
}

///|
fn Fmt::type_var_binders(
  fmt : Fmt,
  quants : List[@syntax.TypeVarBinder],
  lbracket~ : @comment.Key?,
  commas~ : @comment.NodeArray,
  tvar_tables~ : @comment.NodeTableArray,
  rbracket~ : @comment.Key?,
) -> Doc {
  guard quants is More(_) else { return empty }
  let sep = comma
  let trailing = switch(empty, sep)
  let mut acc = empty
  for i, quant in quants {
    let binder = fmt.type_var_binder(quant, tvar_table=tvar_tables[i])
    let constraints = if i == quants.length() - 1 {
      let trailing_comment = fmt.after_comment(Some(Node(quant.loc())))
      let around_comments = fmt.wrap_comment(commas[i], empty)
      trailing + trailing_comment + around_comments
    } else {
      let sep = fmt.wrap_comment(commas[i], sep)
      sep + line
    }
    acc = acc + binder + constraints
  }
  let lp = char('[')
  let rp = char(']')
  let (before_l, after_l) = fmt.comments(lbracket)
  let (before_r, after_r) = fmt.comments(rbracket)
  before_l +
  lp +
  nest(after_l + softline + acc + before_r) +
  softline +
  rp +
  after_r
}

///|
fn Fmt::trait_method(fmt : Fmt, meth : @syntax.TraitMethodDecl) -> Doc {
  // TODO
  ignore((fmt, meth))
  panic()
}

///|
fn Fmt::visibility(fmt : Fmt, vis : @syntax.Visibility) -> Doc {
  match vis {
    Pub(attr=modifier, loc~) => {
      let table = fmt.get_table(loc)
      let pub_ = fmt.wrap_comment(table.get_token("pub"), text("pub"))
      let modifier = match modifier {
        None => empty
        Some(s) => {
          let lparen = fmt.wrap_comment(table.get_token("("), text("("))
          let id = fmt.wrap_comment(table.get_token("lident"), text(s))
          let rparen = fmt.wrap_comment(table.get_token(")"), text(")"))
          lparen + id + rparen
        }
      }
      fmt.wrap_comment(Some(Node(loc)), pub_ + modifier)
    }
    Priv(loc~) => {
      let table = fmt.get_table(loc)
      let priv_ = fmt.wrap_comment(table.get_token("priv"), text("priv"))
      fmt.wrap_comment(Some(Node(loc)), priv_ + space)
    }
    Default => empty
  }
}

///|
fn Fmt::attributes(fmt : Fmt, attrs : List[Attribute]) -> Doc {
  ignore((fmt, attrs))
  empty //TODO
}

///|
fn Fmt::docstring(fmt : Fmt, doc : @syntax.DocString) -> Doc {
  ignore((fmt, doc))
  empty //TODO
}

///|
fn Fmt::typedecl(fmt : Fmt, typedecl : @syntax.TypeDecl) -> Doc {
  ignore(fmt) //TODO: use fmt to access comments
  let {
    tycon: _,
    tycon_loc: _,
    params: _,
    components: _,
    attrs: _,
    doc: _,
    type_vis: _,
    deriving: _,
    loc: _,
  } = typedecl
  panic()
}

///|
fn Fmt::constant(fmt : Fmt, constant : @syntax.Constant) -> Doc {
  ignore(fmt) //TODO: use fmt to access comments
  match constant {
    String(s) => double_quoted(text(s))
    Char(s) => single_quoted(text(s))
    Bytes(s) => char('b') + double_quoted(text(s))
    Byte(s) => char('b') + single_quoted(text(s))
    Bool(b) => @pp.pretty(b)
    BigInt(s)
    | Double(s)
    | Float(s)
    | UInt64(s)
    | UInt(s)
    | Int64(s)
    | Int(s) => text(s)
  }
}

///|
fn Fmt::interps(fmt : Fmt, interps : List[@syntax.InterpElem]) -> Doc {
  interps.fold(init=empty, fn(acc, x) {
    match x {
      Literal(repr~, ..) => acc + text(repr)
      Expr(expr~, ..) => acc + text("\\{") + fmt.compose(expr, Expr) + char('}')
      Source({ source, .. }) => acc + text("\\{") + text(source) + char('}')
    }
  })
}

///|
fn Fmt::multiline_string(
  env : Fmt,
  elems : List[@syntax.MultilineStringElem],
  parens~ : Bool,
  loc~ : Location,
) -> Doc {
  ignore(parens)
  ignore(loc)
  let elems = separate_map(elems, hardline, elem => match elem {
    String(s) => text(s)
    Interp(xs) => env.interps(xs)
  })
  group(elems)
}

///|
fn Fmt::label(fmt : Fmt, label : @syntax.Label) -> Doc {
  ignore(fmt) //TODO: use fmt to access comments
  let { name, loc: _ } = label
  text(name)
}

///|
fn is_pun_eligible_for_expr(
  label : @syntax.Label,
  value : @syntax.Expr,
) -> Bool {
  value is Ident(id={ name: Ident(name~), .. }, ..) && name == label.name
}

///|
fn is_pun_eligible_for_pat(
  label : @syntax.Label,
  pat : @syntax.Pattern,
) -> Bool {
  pat is Var({ name, .. }) && name == label.name
}

///|
fn Fmt::argument(fmt : Fmt, arg : @syntax.Argument) -> Doc {
  //TODO: print in compact style for short expr 

  let { value, kind } = arg
  match kind {
    Positional => fmt.compose(value, Expr)
    Labelled(label) =>
      if is_pun_eligible_for_expr(label, value) {
        fmt.label(label) + char('~')
      } else {
        fmt.label(label) + char('=') + fmt.compose(value, Expr) //TODO: compose_rhs
      }
    LabelledOption(label~, question_loc=_) =>
      if is_pun_eligible_for_expr(label, value) {
        fmt.label(label) + char('?')
      } else {
        fmt.label(label) + text("?=") + fmt.compose(value, Expr) //TODO: compose_rhs
      }
    LabelledPun(label) => fmt.label(label) + char('~')
    LabelledOptionPun(label~, question_loc=_) => fmt.label(label) + char('?')
  }
}

///|
fn Fmt::arguments(fmt : Fmt, args : List[@syntax.Argument]) -> Doc {
  // TODO: optimize list <-> array conversion and readability
  let arr = args.to_array()
  // Bad case:
  //
  // Before applying the trailing block rules, we should ensure the remaining space 
  // is enough for leading arguments and the head of the trailing function.
  //
  // ```
  // f(arg1, arg2, ..., argN, [ elems ])
  //   ^^^^^^^^^^^^^^^^^^^^^^
  // f(arg1, arg2, ..., argN, (x,y) => e)
  //   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  // f(arg1, arg2, ..., argN, fn(x,y){ e })
  //   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~~~~~~ is this part fits in current remaining space?
  // ```
  // 
  // Consider this bad result:
  // ```
  // long_function(argument1, argument2, argument3, argument4, argument5, fn(
  //   param1, 
  //   param2,
  // ) {
  //   expr
  // })
  // ```
  match arr.pop() {
    Some({ value: trailing_arg_value, kind: Positional } as trailing_arg) => {
      let leading_args = arr.map(x => fmt.argument(x))
      fn trailing_block_style() {
        let leading_doc = series1(
          @list.from_array(leading_args),
          comma,
          trailing=AlwaysPresent,
        )
        let trailing_doc = fmt.argument(trailing_arg)
        let sep = if leading_args.is_empty() { empty } else { space }
        group(char('(') + (group(leading_doc) + sep + trailing_doc) + char(')'))
      }

      fn fallback_style() {
        leading_args.push(fmt.argument(trailing_arg))
        group(parens(series1(@list.from_array(leading_args), comma)))
      }

      fn switch_trailing_block(leading_req, total_req) {
        ignore(total_req) //TODO: use total_req to decide the layout
        dynamic(fn(ctx) {
          if ctx.current_remain() >= leading_req {
            trailing_block_style()
          } else {
            fallback_style()
          }
        })
      }

      let leading_args_req = leading_args.fold(init=Requirement::Space(0), fn(
        acc,
        x,
      ) {
        acc + x.requirement() + Space(2)
      })
      match trailing_arg_value {
        Record(_) | Array(_) => {
          guard fmt.expr(trailing_arg_value) is BlockLike(doc)
          let leading_req = leading_args_req
          let total_req = leading_args_req + doc.requirement()
          switch_trailing_block(leading_req, total_req)
        }
        Function(_) => {
          guard fmt.expr(trailing_arg_value) is Collapsible(head, body)
          let leading_req = leading_args_req + head.requirement()
          let total_req = leading_args_req +
            head.requirement() +
            body.requirement()
          switch_trailing_block(leading_req, total_req)
        }
        _ => fallback_style()
      }
    }
    _ => group(parens(series1(args.map(x => fmt.argument(x)), comma)))
  }
}

///|
fn longident(id : @syntax.LongIdent) -> Doc {
  match id {
    Ident(name~) => text(name)
    Dot(pkg~, id~) => text("@" + pkg + "." + id)
  }
}

///|
fn Fmt::var_(fmt : Self, variable : @syntax.Var) -> Doc {
  ignore(fmt) //TODO: use fmt to access comments
  longident(variable.name)
}

///|
fn Fmt::binder(fmt : Self, binder : @syntax.Binder) -> Doc {
  ignore(fmt) //TODO: use fmt to access comments
  let { name, loc: _ } = binder
  text(name)
}

///|
fn Fmt::pattern(fmt : Self, pat : @syntax.Pattern) -> Doc {
  match pat {
    SpecialConstr(_) => abort("unsupported special constr")
    Var(binder) => fmt.binder(binder)
    Any(loc=_) => char('_')
    Tuple(pats~, loc=_) =>
      group(parens(series1(pats.map(x => fmt.pattern(x)), comma)))
    Constr(constr~, args=payload, is_open~, loc=_) => {
      fn constr_pat_arg2doc(arg : @syntax.ConstrPatArg) -> Doc {
        let { pat, kind } = arg
        let pat_doc = fmt.pattern(pat)
        match kind {
          Positional => pat_doc
          Labelled(label) =>
            if is_pun_eligible_for_pat(label, pat) {
              fmt.label(label) + equal + pat_doc
            } else {
              fmt.label(label) + tilde
            }
          LabelledPun(label) => fmt.label(label) + tilde
          LabelledOption(_) | LabelledOptionPun(_) => panic()
        }
      }

      let constr = fmt.constr(constr)
      let payload = match payload {
        None => empty
        Some(args) => {
          let args = args.map(constr_pat_arg2doc)
          let args = if is_open {
            //TODO: improve performance
            args.concat(@list.of([text("..")]))
          } else {
            args
          }
          group(parens(series(args, comma, x => x)))
        }
      }
      group(constr + payload)
    }
    Constant(c~, loc=_) => fmt.constant(c)
    Array(pats~, loc=_) => {
      fn array_pattern2doc(pat : @syntax.ArrayPattern) -> Doc {
        match pat {
          Pattern(pat) => fmt.pattern(pat)
          StringSpread(s) => text("..") + double_quoted(text(s))
          BytesSpread(s) => text("..") + char('b') + double_quoted(text(s))
          ConstSpread(binder~, pkg~, loc=_) => {
            let pkg = match pkg {
              Some(x) => text("@\{x}.")
              None => empty
            }
            let binder = fmt.binder(binder)
            text("..") + pkg + binder
          }
        }
      }

      match pats {
        Closed(elems) =>
          group(brackets(series(elems, comma, array_pattern2doc)))
        Open(left, right, remain) => {
          let elems = left.to_array().map(array_pattern2doc)
          match remain {
            NoBinder => ()
            Binder(b) | BinderAs(b) => elems.push(text("..") + fmt.binder(b))
            Underscore => elems.push(text(".._"))
          }
          elems.push_iter(right.map(array_pattern2doc).iter())
          let elems = @list.from_array(elems)
          group(brackets(series(elems, comma, x => x)))
        }
      }
    }
    Range(lhs~, rhs~, inclusive~, loc=_) => {
      let lhs = fmt.pattern(lhs)
      let op = text(if inclusive { "..=" } else { "..<" })
      let rhs = fmt.pattern(rhs)
      group(lhs + op + rhs)
    }
    Record(fields~, is_closed~, loc=_) => {
      fn field_pat2doc(field : @syntax.FieldPat) -> Doc {
        let { label, pattern, is_pun, loc: _ } = field
        if is_pun || is_pun_eligible_for_pat(label, pattern) {
          fmt.label(label)
        } else {
          fmt.label(label) + colon + space + fmt.pattern(pattern)
        }
      }

      let elems = fields.to_array().map(field_pat2doc)
      if is_closed {
        elems.push(text(".."))
      }
      let elems = @list.from_array(elems)
      group(braces(series(elems, comma, x => x)))
    }
    Map(elems~, is_closed~, loc=_) => {
      fn map_pat2doc(elem : @syntax.MapPatElem) -> Doc {
        let { key, pat, match_absent, key_loc: _, loc: _ } = elem
        let key = fmt.constant(key)
        let absent = if match_absent { char('?') } else { empty }
        let pat = space + fmt.pattern(pat)
        key + absent + colon + pat
      }

      let elems = elems.to_array().map(map_pat2doc)
      if is_closed {
        elems.push(text(".."))
      }
      let elems = @list.from_array(elems)
      group(braces(series(elems, comma, x => x)))
    }
    Constraint(pat~, ty~, loc=_) => {
      let pat = fmt.pattern(pat)
      let colon = space + char(':')
      let ty = space + fmt.ty(ty)
      group(parens(pat + colon + ty))
    }
    Alias(pat~, alias_~, loc=_) => {
      let pat = fmt.pattern(pat)
      let as_ = space + text("as")
      let alias_ = space + fmt.binder(alias_)
      group(pat + as_ + alias_)
    }
    Or(pat1~, pat2~, loc=_) => {
      let sep = line + char('|') + space
      let pats = loop (@list.of([pat1]), pat2) {
        (acc, Or(pat1~, pat2~, loc=_)) => continue (acc.add(pat1), pat2)
        (acc, pat) => acc.add(pat).rev()
      }
      let lparen = switch(empty, char('(') + space)
      let pats = separate(pats.map(x => fmt.pattern(x)), sep)
      let rparen = switch(empty, softline + char(')'))
      lparen + pats + rparen
    }
  }
}

///|
/// Convert ErrorType to Document, the result including the leading space.
/// 
/// for example:
/// `` 
/// ` noraise`
/// ` raise TYPE`
/// ` raise?`
fn Fmt::error_type(fmt : Self, err : @syntax.ErrorType) -> Doc {
  match err {
    NoErrorType => empty
    DefaultErrorType(loc=_) => space + text("raise")
    Noraise(loc=_) => space + text("noraise")
    ErrorType(ty~) => space + text("raise") + space + fmt.ty(ty)
    MaybeError(ty=_) => space + text("raise?")
  }
}

///|
fn Fmt::ty(fmt : Self, ty : @syntax.Type) -> Doc {
  match ty {
    Any(loc=_) => char('_')
    Name(constr_id={ id: constr, loc: _ }, tys~, loc=_) => {
      // If the user writes `Option[Int]`, keep it as is.
      let constr = longident(constr)
      let tys = match tys {
        Empty => empty
        More(_) => group(brackets(series1(tys.map(x => fmt.ty(x)), comma)))
      }
      constr + tys
    }
    Tuple(tys~, loc=_) => group(parens(series1(tys.map(x => fmt.ty(x)), comma)))
    Arrow(args~, res~, err~, is_async~, loc=_) => {
      let async_ = if is_async { text("async") + space } else { empty }
      let args = group(parens(series1(args.map(x => fmt.ty(x)), comma)))
      let arrow = space + text("->")
      let res = space + fmt.ty(res)
      let err = fmt.error_type(err)
      async_ + args + arrow + res + err
    }
    Option(ty~, loc=_, question_loc=_) => {
      let ty = match ty {
        Arrow(_) => parens(fmt.ty(ty))
        Name(_) | Tuple(_) | Any(_) | Option(_) | Object(_) => fmt.ty(ty)
      }
      ty + char('?')
    }
    Object({ id: constr, loc: _ }) => {
      let constr = longident(constr)
      char('&') + constr
    }
  }
}

///|
fn Fmt::type_name(fmt : Self, typename : @syntax.TypeName) -> Doc {
  ignore(fmt) // TODO: use fmt to get comments
  let { name, is_object, loc: _ } = typename
  let object_mark = if is_object { char('&') } else { empty }
  let name = longident(name)
  object_mark + name
}

///|
fn Fmt::constr(fmt : Self, constr : @syntax.Constructor) -> Doc {
  let { extra_info, name: { name, loc: _ }, loc: _ } = constr
  let extra_info = match extra_info {
    NoExtraInfo => empty
    TypeName(n) => fmt.type_name(n) + text("::")
    Package(p) => text("@" + p + ".")
  }
  let name = text(name)
  extra_info + name
}

///|
fn Fmt::parameter(
  fmt : Self,
  parameter : @syntax.Parameter,
  table : @comment.NodeTable,
) -> Doc {
  ignore(table) // TODO: use table for comments
  match parameter {
    Optional(binder~, default~, ty~) => {
      let binder = fmt.binder(binder) + char('?')
      let ty = match ty {
        None => empty
        Some(ty) => space + colon + space + fmt.ty(ty)
      }
      let equal = space + equal
      let default = space + fmt.compose(default, Expr)
      binder + ty + equal + default
    }
    Labelled(binder~, ty~) => {
      let binder = fmt.binder(binder) + char('~')
      let ty = match ty {
        None => empty
        Some(ty) => space + colon + space + fmt.ty(ty)
      }
      binder + ty
    }
    Positional(binder~, ty~) => {
      let binder = fmt.binder(binder)
      let ty = match ty {
        None => empty
        Some(ty) => space + colon + space + fmt.ty(ty)
      }
      binder + ty
    }
    DiscardPositional(ty~, loc=_) => {
      let binder = char('_')
      let ty = match ty {
        None => empty
        Some(ty) => space + colon + space + fmt.ty(ty)
      }
      binder + ty
    }
    QuestionOptional(binder~, ty~) => {
      let binder = fmt.binder(binder) + char('?')
      let ty = match ty {
        None => empty
        Some(ty) => space + colon + space + fmt.ty(ty)
      }
      binder + ty
    }
  }
}

///|
fn Fmt::parameters(
  fmt : Self,
  parameters : List[@syntax.Parameter],
  lparen~ : @comment.Key?,
  param_tables~ : @comment.NodeTableArray,
  commas~ : @comment.NodeArray,
  rparen~ : @comment.Key?,
) -> Doc {
  ignore(rparen) //TODO: use rparen comment
  let sep = comma
  let trailing = switch(empty, sep)
  let mut acc = empty
  for i, param in parameters {
    acc += fmt.parameter(param, param_tables[i])
    if i == parameters.length() - 1 {
      let trailing_comment = fmt.after_comment(Some(Node(param.loc())))
      let around_comments = fmt.wrap_comment(commas[i], empty)
      acc += trailing + trailing_comment + around_comments
    } else {
      let sep = fmt.wrap_comment(commas[i], sep)
      acc += sep + line
    }
  }
  let l = softline
  let lp = fmt.wrap_comment(lparen, char('('))
  let rp = fmt.wrap_comment(lparen, char(')'))
  lp + nest(l + acc) + l + rp
}

///|
fn Fmt::arrow(
  fmt : Self,
  parameters~ : @syntax.Parameters,
  body~ : @syntax.Expr,
) -> RawExprDoc {
  let params = group(
    fmt.parameters(
      parameters,
      lparen=None,
      param_tables=@comment.NodeTableArray::empty(),
      commas=@comment.NodeArray::empty(),
      rparen=None,
    ),
  )
  let arrow = space + text("=>")
  let body = fmt.compose_arrow_rhs(body)
  Collapsible(params + arrow, body)
}

///|
fn Fmt::func(
  fmt : Self,
  func : @syntax.Func,
  binder? : @syntax.Binder,
) -> RawExprDoc {
  let is_annomyous = binder.is_empty()
  match func {
    Lambda(
      parameters~,
      params_loc=_,
      body~,
      return_type~,
      error_type~,
      kind~,
      has_error=_,
      is_async~,
      loc=_
    ) => {
      let async_ = if is_async { text("async") + space } else { empty }
      let fn_ = match kind {
        Arrow => empty
        Lambda => text("fn")
        Matrix => panic()
      }
      let binder = match binder {
        None => empty
        Some(b) => space + fmt.binder(b)
      }
      let params = group(
        fmt.parameters(
          parameters,
          lparen=None,
          param_tables=@comment.NodeTableArray::empty(),
          commas=@comment.NodeArray::empty(),
          rparen=None,
        ),
      )
      let has_error_ty = match error_type {
        NoErrorType => false
        DefaultErrorType(_) | Noraise(_) | ErrorType(_) | MaybeError(_) => true
      }
      let arrow = match kind {
        Arrow => space + text("=>")
        Lambda =>
          if return_type is Some(_) || has_error_ty {
            space + text("->")
          } else {
            empty
          }
        Matrix => panic()
      }
      let ety = fmt.error_type(error_type)
      let rty = match return_type {
        None => empty
        Some(ty) => space + fmt.ty(ty)
      }
      let body = space + fmt.expr_block(body, force_newline=!is_annomyous)
      Collapsible(async_ + fn_ + binder + params + arrow + rty + ety, body)
    }
    Match(_) => panic()
  }
}

///|
fn Fmt::field(fmt : Self, field : @syntax.FieldDef) -> Doc {
  let { label, expr, is_pun, loc: _ } = field
  if is_pun || is_pun_eligible_for_expr(label, expr) {
    fmt.label(label)
  } else {
    fmt.label(label) + colon + space + fmt.compose(expr, Expr)
  }
}

///|
/// in cases `(1).f()`, `(-1L).f()` and `(-1.0).f()`, the parens should be reserved 
fn Fmt::expr_before_dot(fmt : Self, expr : @syntax.Expr) -> Doc {
  let doc = fmt.compose(expr, Prefix)
  match expr {
    Constant(c=Int(_), loc=_) => group(parens(doc))
    Constant(c=Double(str) | Int64(str), loc=_) if str.has_prefix("-") =>
      group(parens(doc))
    _ => doc
  }
}

///|
fn Fmt::accessor(self : Self, accessor : @syntax.Accessor) -> Doc {
  match accessor {
    Label(label) => dot + self.label(label)
    Index(tuple_index~, loc=_) => dot + text(tuple_index.to_string())
    Newtype(loc=_) => text(".inner()")
  }
}

///|
fn Fmt::loop_label(
  self : Self,
  label : @syntax.Label?,
  trailing_colon~ : Bool,
) -> Doc {
  match label {
    None => empty
    Some(label) =>
      space +
      self.label(label) +
      tilde +
      (if trailing_colon { colon } else { empty })
  }
}

///|
fn Fmt::case(fmt : Self, case_ : @syntax.Case) -> Doc {
  let { pattern, guard_, body } = case_
  let pattern = fmt.pattern(pattern)
  let guard_ = match guard_ {
    None => empty
    Some(expr) => space + text("if") + space + fmt.compose(expr, Infix(Other))
  }
  let body = space + text("=>") + fmt.compose_case_rhs(body, ExprStmt) //TODO: compose_rhs
  group(group(pattern) + guard_ + body)
}

///|
fn Fmt::local_type(self : Self, local_type : @syntax.LocalTypeDecl) -> Doc {
  // TODO
  ignore((self, local_type))
  panic()
}

///|
fn Fmt::expr_block(
  fmt : Self,
  expr : @syntax.Expr,
  force_newline? : Bool = true,
  local_types? : List[@syntax.LocalTypeDecl],
  grouped? : Bool = true,
) -> Doc {
  let local_types = match local_types {
    None => empty
    Some(xs) =>
      series1(
        xs.map(x => fmt.local_type(x)),
        empty,
        trailing=PresentInNormalStyle,
      )
  }
  let doc = braces(local_types + fmt.compose(expr, Stmt), force_newline~)
  if grouped {
    group(doc)
  } else {
    doc
  }
}

///|
fn Fmt::case_block(
  self : Self,
  cases : List[@syntax.Case],
  force_newline? : Bool = true,
) -> Doc {
  group(braces(series1(cases.map(x => self.case(x)), empty), force_newline~))
}

///|
fn Fmt::expr(fmt : Self, expr : @syntax.Expr) -> RawExprDoc {
  match expr {
    Apply(func~, args~, attr=_, loc~) => {
      let func = match func {
        // (self.label)(args) 
        // (self.0)(args)
        Field(accessor=Label(_) | Index(_), ..) =>
          parens(fmt.compose(func, Simple))
        _ => fmt.compose(func, Simple)
      }
      let args = fmt.arguments(args)
      let before_comment = fmt.before_comment(Some(Node(loc)))
      let after_comment = fmt.after_comment(Some(Node(loc)))
      Collapsible(before_comment + func, args + after_comment)
    }
    Infix(op~, lhs~, rhs~, loc=_) => {
      let op_str = match op.name {
        Ident(name~) => name
        _ => panic()
      }
      let op = longident(op.name)
      let layout = if op_str is ("..<" | "..=") {
        let lhs = fmt.compose(lhs, Range)
        let rhs = fmt.compose(rhs, Range)
        group(lhs + op + rhs)
      } else {
        let lhs = fmt.compose(
          lhs,
          Infix(InfixOperand(op=op_str, pos=LeftOperand)),
        )
        let rhs = fmt.compose(
          rhs,
          Infix(InfixOperand(op=op_str, pos=RightOperand)),
        )
        lhs + space + op + rhs
      }
      Normal(layout)
    }
    Unary(op~, expr~, loc=_) => {
      let op = fmt.var_(op)
      let expr = match expr {
        // -(_) or +(_)
        Hole(kind=_, loc=_) => parens(fmt.compose(expr, Simple))
        _ => fmt.compose(expr, Simple)
      }
      let layout = group(op + expr)
      Normal(layout)
    }
    Array(exprs~, loc~) => {
      let before_comment = fmt.before_comment(Some(Node(loc)))
      let doc = group(brackets(series(exprs, comma, e => fmt.compose(e, Expr))))
      let after_comment = fmt.after_comment(Some(Node(loc)))
      BlockLike(before_comment + doc + after_comment)
    }
    ArraySpread(elems~, loc=_) => {
      fn spreadable2doc(elem : @syntax.SpreadableElem) -> Doc {
        match elem {
          Regular(expr) => fmt.compose(expr, Expr)
          Spread(expr~, loc=_) => text("..") + fmt.compose(expr, Expr)
        }
      }

      let doc = group(brackets(series(elems, comma, spreadable2doc)))
      Normal(doc)
    }
    ArrayGet(array~, index~, loc=_) => {
      let array = fmt.compose(array, Simple)
      let index = fmt.compose(index, Expr)
      let doc = group(array + group(brackets(index)))
      Normal(doc)
    }
    ArrayGetSlice(array~, start_index~, end_index~, loc=_, index_loc=_) => {
      let array = fmt.compose(array, Simple)
      let start_index = optional(start_index, empty, e => fmt.compose(e, Expr))
      let end_index = optional(end_index, empty, e => fmt.compose(e, Expr))
      let doc = group(array + group(brackets(start_index + colon + end_index)))
      Normal(doc)
    }
    ArraySet(array~, index~, value~, loc=_) => {
      let op = equal
      let array = fmt.compose(array, Simple)
      let index = fmt.compose(index, Expr)
      let value = fmt.compose_assign_rhs(value, Expr) // TODO: compose_rhs
      let doc = group(
        array + group(brackets(index)) + space + op + space + value,
      )
      Normal(doc)
    }
    ArrayAugmentedSet(op~, array~, index~, value~, loc=_) => {
      let op = fmt.var_(op)
      let array = fmt.compose(array, Simple)
      let index = fmt.compose(index, Expr)
      let value = fmt.compose_assign_rhs(value, Expr) // TODO: compose_rhs
      let doc = group(
        array + group(brackets(index)) + space + op + space + value,
      )
      Normal(doc)
    }
    Constant(c~, loc=_) => {
      let doc = fmt.constant(c)
      Normal(doc)
    }
    MultilineString(elems~, loc~) => {
      let doc = fmt.multiline_string(parens=true, loc~, elems)
      Normal(doc)
    }
    Interp(elems~, loc=_) => {
      fn elem2doc(elem : @syntax.InterpElem) -> Doc {
        match elem {
          Literal(repr~, loc=_) => text(repr)
          Expr(expr~, loc=_) => fmt.compose(expr, Expr)
          Source({ source, loc: _ }) => text(source)
        }
      }

      let elems = concat_map(elems, elem2doc)
      let doc = double_quoted(elems)
      Normal(doc)
    }
    Constraint(expr~, ty~, loc=_) => {
      let expr = fmt.compose(expr, Expr)
      let ty = fmt.ty(ty)
      let doc = group(parens(expr + line + colon + space + ty))
      BlockLike(doc)
    }
    Constr(constr~, loc=_) => {
      let doc = fmt.constr(constr)
      Normal(doc)
    }
    While(loop_cond~, loop_body~, while_else~, label~, loc=_) => {
      let label = match label {
        None => empty
        Some(x) => fmt.label(x) + colon
      }
      let while_ = text("while")
      let cond = space + fmt.compose(loop_cond, Infix(Other))
      let body = space + fmt.expr_block(loop_body)
      let else_ = match while_else {
        None => empty
        Some(e) => space + fmt.expr_block(e)
      }
      let doc = while_ + label + cond + body + else_
      Normal(doc)
    }
    Function(func~, loc=_) =>
      match func {
        Lambda(parameters~, body~, kind~, ..) =>
          match kind {
            Arrow => fmt.arrow(parameters~, body~)
            Lambda => fmt.func(func)
            Matrix => panic()
          }
        Match(_) => panic()
      }
    Ident(id~, loc~) => {
      let before_comment = fmt.before_comment(Some(Node(loc)))
      let doc = fmt.var_(id)
      let after_comment = fmt.after_comment(Some(Node(loc)))
      Normal(before_comment + doc + after_comment)
    }
    If(cond~, ifso~, ifnot~, loc=_) => {
      let if_ = text("if")
      let cond = space + fmt.compose(cond, Infix(Other))
      let ifso = space +
        fmt.expr_block(ifso, force_newline=false, grouped=false)
      let ifnot = match ifnot {
        None => empty
        Some(If(_) as e) => space + text("else") + space + fmt.compose(e, Stmt)
        Some(e) =>
          space +
          text("else") +
          space +
          fmt.expr_block(e, force_newline=false, grouped=false)
      }
      Collapsible(if_ + cond, ifso + ifnot)
    }
    Guard(cond~, otherwise~, body~, loc=_) => {
      let guard_ = text("guard")
      let cond = space + fmt.compose(cond, Infix(Other))
      let otherwise = match otherwise {
        None => empty
        Some(e) => space + text("else") + space + fmt.expr_block(e)
      }
      let body = hardline + fmt.compose(body, Stmt)
      let doc = guard_ + cond + otherwise + body
      Normal(doc)
    }
    Is(expr~, pat~, loc=_) => {
      // The right-hand side of the `is` expression is a simple pattern.
      // Parentheses should be added around complex patterns.
      let expr = fmt.compose(expr, Expr)
      let is_ = space + text("is")
      let pat = match pat {
        Constant(_)
        | Any(_)
        | Var(_)
        | Constr(_)
        | SpecialConstr(_)
        | Tuple(_)
        | Constraint(_)
        | Array(_)
        | Record(_)
        | Map(_) => fmt.pattern(pat)
        Range(_) | Or(_) | Alias(_) => parens(fmt.pattern(pat))
      }
      let pat = space + pat
      let doc = group(expr + is_ + pat)
      Normal(doc)
    }
    Defer(expr~, body~, loc=_) => {
      let defer_ = text("defer")
      let expr = space + fmt.compose(expr, Pipeline) // TODO: compose_rhs
      let body = hardline + fmt.compose(body, Stmt)
      let doc = defer_ + expr + body
      Normal(doc)
    }
    LetFn(name=_, func~, body~, loc=_) => { //TODO: fixme
      guard fmt.func(func) is Collapsible(a, b)
      let func = a + b
      let body = hardline + fmt.compose(body, Stmt)
      Normal(func + body)
    }
    LetRec(bindings~, body~, loc=_) => {
      fn binding2doc(pair) {
        let (binder, func) = pair
        guard fmt.func(func, binder~) is Collapsible(a, b)
        a + b
      }

      let bindings = separate_map(bindings, hardline, binding2doc)
      let body = hardline + fmt.compose(body, Stmt)
      let doc = bindings + body
      Normal(doc)
    }
    LetAnd(bindings~, body~, loc=_) => {
      fn rec_binding2doc(triple) {
        let (binder, ty, func) = triple
        let binder = fmt.binder(binder)
        let ty = match ty {
          None => empty
          Some(ty) => space + colon + space + fmt.ty(ty)
        }
        guard func
          is @syntax.Func::Lambda(
            parameters~,
            params_loc=_,
            body~,
            return_type=_,
            error_type=_,
            kind=_,
            has_error=_,
            is_async=_,
            loc=_
          ) else {
          panic()
        }
        let params = space +
          group(
            fmt.parameters(
              parameters,
              lparen=None,
              param_tables=@comment.NodeTableArray::empty(),
              commas=@comment.NodeArray::empty(),
              rparen=None,
            ),
          )
        let body = space + fmt.expr_block(body)
        binder + ty + space + equal + params + text("=>") + body
      }

      let letrec_ = text("letrec")
      let bindings = space +
        separate_map(bindings, hardline + text("and") + space, rec_binding2doc)
      let body = hardline + fmt.compose(body, Stmt)
      let doc = letrec_ + bindings + body
      Normal(doc)
    }
    Let(pattern~, expr~, body~, loc=_) => {
      let lhs = if pattern is Constraint(pat~, ty~, loc=_) {
        let pattern = fmt.pattern(pat)
        let ty = fmt.ty(ty)
        pattern + space + colon + ty
      } else {
        fmt.pattern(pattern)
      }
      let expr = fmt.compose_assign_rhs(expr, Expr) //TODO: compose_rhs
      let doc = group(text("let") + space + lhs + space + equal + expr) +
        hardline +
        fmt.compose(body, Stmt)
      Normal(doc)
    }
    Sequence(exprs~, last_expr~, loc~) => {
      let before_comment = fmt.before_comment(Some(Node(loc)))
      let exprs = separate(exprs.map(e => fmt.compose(e, ExprStmt)), hardline)
      let last_expr = hardline + fmt.compose(last_expr, Stmt)
      let after_comment = fmt.after_comment(Some(Node(loc)))
      let doc = before_comment + exprs + last_expr + after_comment
      Normal(doc)
    }
    Tuple(exprs~, loc=_) => {
      let doc = group(parens(series(exprs, comma, e => fmt.compose(e, Expr))))
      Normal(doc)
    }
    Record(type_name~, fields~, trailing=_, loc=_) =>
      // Bad case: if type_name is empty and the record is initialized with 
      // one punning field, a comma should be added for disambiguation.
      //
      // ```
      // { ident }           // block with one expression
      // { field, }          // record with one field
      // TypeName::{ field } 
      // ```
      if type_name is None {
        let record = group(
          if fields is More(_, tail=Empty) {
            braces(
              series1(
                fields.map(x => fmt.field(x)),
                comma,
                trailing=AlwaysPresent,
              ),
            )
          } else {
            braces(series1(fields.map(x => fmt.field(x)), comma))
          },
        )
        BlockLike(record)
      } else {
        let type_name = match type_name {
          None => empty
          Some(type_name) => fmt.type_name(type_name) + text("::")
        }
        let record = group(
          braces(series1(fields.map(x => fmt.field(x)), comma)),
        )
        Collapsible(type_name, record)
      }
    RecordUpdate(type_name~, record~, fields~, loc=_) => {
      let type_name = match type_name {
        None => empty
        Some(x) => fmt.type_name(x)
      }
      let dotdot_record = text("..") + fmt.compose(record, Simple)
      let fields = fields.map(x => fmt.field(x))
      let record = group(
        braces(series(fields.add(dotdot_record), comma, x => x)),
      )
      let doc = group(type_name + text("::") + record)
      Normal(doc)
    }
    Field(record~, accessor~, loc=_) => {
      let record = fmt.expr_before_dot(record)
      let accessor = fmt.accessor(accessor)
      let doc = record + accessor
      Normal(doc)
    }
    Method(type_name~, method_name~, loc=_) => {
      let type_name = fmt.type_name(type_name)
      let method_name = fmt.label(method_name)
      let doc = type_name + text("::") + method_name
      Normal(doc)
    }
    DotApply(self=_, method_name=_, args=_, return_self=_, attr=_, loc=_) as e => {
      let xs = loop (@list.empty(), e) {
        (acc, DotApply(self~, ..) as apply) => continue (acc.add(apply), self)
        (acc, expr) => acc.add(expr)
      }
      guard xs is More(s, tail=chained)
      let lhs = fmt.expr_before_dot(s)
      let chained = separate_map(chained, softline, fn(expr) {
        guard expr
          is DotApply(self=_, method_name~, args~, return_self~, attr=_, loc=_)
        let dot = if return_self { text("..") } else { text(".") }
        let method_name = fmt.label(method_name)
        let args = fmt.arguments(args)
        dot + method_name + args
      })
      let apps = group(
        current_column_without_indent(fn(column) {
          if lhs.requirement() < Space(3) { // single line lhs
            nest(chained)
          } else if column < 3 { // multiline line lhs but (next indent) - (current indent) < 3
            softline + nest(chained)
          } else {
            nest(softline + chained)
          }
        }),
      )
      Collapsible(lhs, apps)
    }
    As(expr~, trait_~, loc=_) => {
      let expr = fmt.compose(expr, Simple)
      let as_ = space + text("as")
      let trait_ = space + fmt.type_name(trait_)
      let doc = group(expr + as_ + trait_)
      Normal(doc)
    }
    Mutate(record~, accessor~, field~, augmented_by~, loc=_) => {
      let record = fmt.expr_before_dot(record)
      let accessor = fmt.accessor(accessor)
      let op = match augmented_by {
        None => space + text("=")
        Some(op) => space + fmt.var_(op)
      }
      let field = space + fmt.compose(field, Expr) //TODO: compose_rhs
      let doc = record + accessor + op + field
      Normal(doc)
    }
    Match(expr~, cases~, match_loc=_, using_=_, loc=_) => {
      let match_ = text("match")
      let cond = space + fmt.compose(expr, Infix(Other))
      let cases = space +
        group(
          braces(
            series1(cases.map(x => fmt.case(x)), empty),
            force_newline=true,
          ),
        )
      Collapsible(match_ + cond, cases)
    }
    LetMut(binder~, ty~, expr~, body~, loc=_) => {
      let let_ = text("let")
      let binder = space + fmt.binder(binder)
      let ty = match ty {
        None => empty
        Some(ty) => space + fmt.ty(ty)
      }
      let assign = space + equal
      // TODO: handle multiline string
      let expr = space + fmt.compose(expr, Expr) // TODO: compose_rhs
      let body = hardline + fmt.compose(body, Stmt)
      let doc = let_ + binder + ty + assign + expr + body
      Normal(doc)
    }
    Pipe(lhs~, rhs~, loc=_) => {
      fn pipe2doc(lhs : @syntax.Expr, rhs) {
        let lhs = match lhs {
          Pipe(lhs~, rhs~, loc=_) => pipe2doc(lhs, rhs)
          _ => fmt.compose(lhs, Simple)
        }
        let pipe = line + text("|>")
        let rhs = space + fmt.compose(rhs, Infix(Other))
        lhs + pipe + rhs
      }

      Normal(group(pipe2doc(lhs, rhs)))
    }
    Assign(var_~, expr~, augmented_by~, loc=_) => {
      let var_ = fmt.var_(var_)
      let op = match augmented_by {
        None => space + text("=")
        Some(op) => space + fmt.var_(op)
      }
      let expr = fmt.compose_assign_rhs(expr, Expr) //TODO: compose_rhs
      let doc = var_ + op + expr
      Normal(doc)
    }
    Hole(loc=_, kind=hole) => {
      let doc = match hole {
        Incomplete => text("_")
        Synthesized => text("_") //TODO: sus
        Todo => text("...")
      }
      Normal(doc)
    }
    Return(return_value~, loc=_) => {
      let return_ = text("return")
      let value = space +
        optional(return_value, empty, e => fmt.compose_return_break_continue_rhs(
          e,
          Expr,
        )) //TODO: compose_rhs
      let doc = return_ + value
      Normal(doc)
    }
    Raise(err_value~, loc=_) => {
      let raise_ = text("raise")
      let value = space + fmt.compose_assign_rhs(err_value, Expr) //TODO: compose_rhs
      let doc = raise_ + value
      Normal(doc)
    }
    Unit(faked~, loc=_) => {
      let doc = if faked { empty } else { text("()") }
      Normal(doc)
    }
    Break(arg~, label~, loc=_) => {
      let break_ = text("break")
      let label = fmt.loop_label(label, trailing_colon=false)
      let arg = space + optional(arg, empty, e => fmt.compose(e, Expr)) //TODO: compose_rhs
      let doc = break_ + label + arg
      Normal(doc)
    }
    Continue(args~, label~, loc=_) => {
      let continue_ = text("continue")
      let label = fmt.loop_label(label, trailing_colon=false)
      let args = if args.is_empty() {
        empty
      } else {
        space + series(args, comma, e => fmt.compose(e, Expr))
      }
      let doc = continue_ + label + args
      Normal(doc)
    }
    Loop(args~, body~, label~, loop_loc=_, loc=_) => {
      // deprecated multi-args syntax is not supported
      guard args is More(arg, tail=Empty) else { panic() }
      let label = fmt.loop_label(label, trailing_colon=true)
      let loop_ = text("loop")
      let arg = space + fmt.compose(arg, Expr)
      let cases : List[@syntax.Case] = body.map(case_ => {
        // deprecated multi-args syntax is not supported
        guard case_.patterns is More(pattern, tail=Empty) else { panic() }
        { pattern, guard_: case_.guard_, body: case_.body }
      })
      let body = space + fmt.case_block(cases)
      let doc = label + loop_ + arg + body
      Normal(doc)
    }
    For(binders~, condition~, continue_block~, body~, for_else~, label~, loc=_) => {
      fn binder_expr2doc(pair : (@syntax.Binder, @syntax.Expr)) -> Doc {
        let (binder, expr) = pair
        let binder = fmt.binder(binder)
        let assign = space + equal
        let expr = space + fmt.compose(expr, Infix(Other))
        binder + assign + expr
      }

      let label = fmt.loop_label(label, trailing_colon=true)
      let for_ = text("for")
      let binders_doc = space +
        series(binders, comma, binder_expr2doc, trailing=AlwaysHidden)
      let condition = match condition {
        None => None
        Some(e) => Some(fmt.compose(e, Infix(Other)))
      }
      let continue_block = match continue_block {
        Empty => None
        More(_) =>
          Some(
            space +
            series(
              continue_block,
              comma,
              binder_expr2doc,
              trailing=AlwaysHidden,
            ),
          )
      }
      let body = space + fmt.expr_block(body)
      let for_else = match for_else {
        None => empty
        Some(e) => space + text("else") + space + fmt.expr_block(e)
      }
      let semi_or_newline = switch(semi + space, softline)
      let header = match (condition, continue_block) {
        (None, None) =>
          if binders.is_empty() {
            empty
          } else {
            space + binders_doc
          }
        (_, _) =>
          binders_doc +
          semi_or_newline +
          condition.unwrap_or(empty) +
          semi_or_newline +
          continue_block.unwrap_or(empty)
      }
      let doc = label + for_ + group(nest(softline + header)) + body + for_else
      Normal(doc)
    }
    ForEach(binders~, expr~, body~, else_block~, label~, loc=_) => {
      let label = fmt.loop_label(label, trailing_colon=true)
      fn foreach_binder2doc(binder : @syntax.Binder?) -> Doc {
        match binder {
          None => empty
          Some(x) => fmt.binder(x)
        }
      }

      let binders = series(
        binders,
        comma,
        foreach_binder2doc,
        trailing=AlwaysHidden,
      )
      let in_ = space + text("in")
      let expr = fmt.compose(expr, Infix(Other))
      let body = space + fmt.expr_block(body)
      let else_block = match else_block {
        None => empty
        Some(e) => fmt.expr_block(e)
      }
      let doc = label + binders + in_ + expr + body + else_block
      Normal(doc)
    }
    Try(
      body~,
      catch_=catch_cases,
      catch_all=_,
      try_else~,
      has_try=_,
      try_loc=_,
      catch_loc=_,
      else_loc=_,
      loc=_
    ) => {
      let try_ = text("try")
      let body = space + fmt.expr_block(body)
      let catch_ = space + text("catch") + fmt.case_block(catch_cases)
      let noraise_ = match try_else {
        None => empty
        Some(cases) => space + text("noraise") + space + fmt.case_block(cases)
      }
      let doc = try_ + body + catch_ + noraise_
      Normal(doc)
    }
    TryOperator(body~, kind=op, try_loc=_, loc=_) => {
      let try_ = match op {
        Question => text("try?")
        Exclamation => text("try!")
      }
      let body = space + fmt.compose(body, Simple)
      let doc = try_ + body
      Normal(doc)
    }
    Map(elems~, loc=_) => {
      fn map_expr_elem2doc(elem : @syntax.MapExprElem) -> Doc {
        let { key, expr, key_loc: _, loc: _ } = elem
        fmt.constant(key) + colon + space + fmt.compose(expr, Expr)
      }

      let doc = group(braces(series(elems, comma, map_expr_elem2doc)))
      Normal(doc)
    }
    Group(expr~, ..) => {
      expr.loc() |> println
      fmt.expr(expr).to_doc() |> @pp.render() |> println
      panic()
    }
    StaticAssert(_) => panic()
  }
}
