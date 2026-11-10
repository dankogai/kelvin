// a lent parameter is its caller's, which a function returns as a copy (#510)
let f(s:lent String):String { return s }
let main():int32 { return 0 }
// error: 's' is a value its caller keeps, lent to this function: return a copy, 's.copy()'
