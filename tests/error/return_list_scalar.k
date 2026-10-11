// return {...} takes a struct, union or variant result, not a number (#77)
let f():i64 { return {1} }
let main():i32 { return 0 }
// error: a list is not a value here
