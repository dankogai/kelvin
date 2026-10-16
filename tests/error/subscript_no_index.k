// a subscript takes at least one index (#136)
struct pair { a: int64; b: i64 }
let pair[]():i64 { .a }
let main():i32 { return 0 }
// error: a subscript takes at least one index
