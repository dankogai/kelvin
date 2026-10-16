// two functions may not share a name in C (#41)
let twice(n:int64):int64 { n * 2 }
let twice(x:float64):float64 { x * 2.0 }
let twice__i64(n:int64):int64 { n }
let main():int32 { return 0 }
// error: this function and the one at line 2 would both be named twice__i64 in C: rename one
