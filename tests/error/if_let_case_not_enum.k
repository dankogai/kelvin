// if let of a case takes an enum with values, a Result or an Optional (#78)
let main():int32 {
    var n:int64 = 1
    if let err(e) = n { }
    return 0
}
// error: 'if let err(e)' takes an enum with values, a Result or an Optional, and this is i64
