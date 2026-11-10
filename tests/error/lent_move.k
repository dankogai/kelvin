// a lent parameter moves into no function, as its caller keeps it (#510)
let keep(s:String):i64 { s.count as i64 }
let f(s:lent String):i64 { keep(s) }
let main():int32 { return 0 }
// error: 's' is a value its caller keeps, lent to this function: pass a borrow, '&s', or a copy
