// error: a function type lists its parameters' types without names
let apply(x:int64, f:(a:int64):int64):int64 { return f(x); }
let main():int32 { return 0; }
