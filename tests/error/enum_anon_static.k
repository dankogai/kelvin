// a function of a type is called by its name, which a type with no tag has not (#121)
enum { nothing; just: int64 }
static let enum{nothing, just: int64}.make():enum{nothing, just: int64} { nothing }
let main():int32 { return 0 }
// error: a function of a type is called by the type's name, and a type with no tag has none
