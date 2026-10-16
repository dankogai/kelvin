// error: 'a' is a reference (i32^): assign it with ':=', not '='
let f(var a:[int32](4), q:int32^):int32 { a = q; return a[0]; }
