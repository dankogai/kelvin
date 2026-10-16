// a subscript is of a type of the program, not a built-in one (#136)
let Array[](i:int64):i64 { 0 }
let main():i32 { return 0 }
// error: a subscript is of a struct, a union or an enum with values of the program: 'Array' has its own indexing
