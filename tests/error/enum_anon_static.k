// a function of a type is called by its name, which a type with no tag has not (#121)
enum { nothing; just: i64 }
static let enum{nothing, just: i64}.make():enum{nothing, just: i64} { nothing }
let main():i32 { return 0 }
// error: a function of a type is called by the type's name, and a type with no tag has none
