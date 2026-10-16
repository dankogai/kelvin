// try takes a Result or an Optional (#76)
let f(n:int64):Result<int64, int32> {
    return try n
}
let main():int32 { return 0 }
// error: 'try' takes a Result or an Optional, and this is i64
