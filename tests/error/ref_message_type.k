// error: 'refs' is a value (i32^[2]): assign it with '=', not ':='
f(p: i32^, q: i32^) { var refs: i32^[2] := {p, q}; }
