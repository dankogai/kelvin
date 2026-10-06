// error: 'a' is a reference (i32^): assign it with ':=', not '='
let f(var a:[i32](4), q:i32^):i32 { a = q; return a[0]; }
