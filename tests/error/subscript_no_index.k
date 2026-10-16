// a subscript takes at least one index (#136)
struct pair { a: int64; b: int64 }
let pair[]():int64 { .a }
let main():int32 { return 0 }
// error: a subscript takes at least one index
