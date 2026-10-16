// numbers keep C's operators (#42)
let +(a:int64, b:int64):int64 { a - b }
let main():int32 { return 0 }
// error: an operator is for a Kelvin struct or union: at least one of its values must be one
