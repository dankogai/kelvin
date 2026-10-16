// error: 'refs' is a value ([i32^](2)): assign it with '=', not ':='
let f(p:int32^, q:int32^) { var refs:[int32^](2) := {p, q}; }
