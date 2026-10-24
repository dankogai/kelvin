// a built-in type's method has no var to change (#318)
var int64.bump() { }
let main():int32 { return 0 }
// error: a var method changes the caller's var, which a built-in type's method cannot
