// a key that is a pointer is said at its ^ (#774), where kelvinc places
// the type
let main():int32 {
    var d:${int64^: int64}
    return 0
}
// error: a key of a Dictionary is an integer or a String, not i64^
