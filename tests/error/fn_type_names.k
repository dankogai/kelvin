// error: a function type lists its parameters' types without names
let apply(x:int64, f:(a:i64):i64):i64 { return f(x); }
let main():i32 { return 0; }
