// error: 'refs' is a value ([i32^](2)): assign it with '=', not ':='
let f(p:int32^, q:i32^) { var refs:[i32^](2) := {p, q}; }
