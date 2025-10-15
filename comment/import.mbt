///|
using @basic {type Location, type Position}

///|
using @tokens {type TokenKind}

///|
using @pp {trait Pretty, space, text, pretty}

///|
typealias (@tokens.Token, @basic.Position, @basic.Position) as Triple

///|
traitalias @syntax.IterVisitor as Visitor
