// a lent parameter is its caller's, which it does not change: var asks
// for one of its own, a copy, which lent is not (#510)
let f(var s:lent String):i64 { s.count as i64 }
let main():int32 { return 0 }
// error: 's' is lent, its caller's, and cannot change: 'var' asks for one of its own, a copy, which 'lent' is not
