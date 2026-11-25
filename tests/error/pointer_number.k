// a number that is no 0 is no pointer (#760): it was C's error,
// incompatible integer to pointer conversion
let main():int32 {
    var p:int64^ := 5
    return 0
}
// error: 'p' is an i64^, and this is a number
