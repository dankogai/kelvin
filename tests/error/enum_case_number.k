// a case of an enum with values has a name, not a number (#61)
enum e { a = 1; b: int32 }
let main():int32 { return 0 }
// error: a case of an enum with values is known by its name, not by a number
