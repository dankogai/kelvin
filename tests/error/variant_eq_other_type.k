// == compares two of the same type (#79)
let main():int32 {
    var a:int64? = 1
    var b:int32? = 1
    println(a == b)
    return 0
}
// error: '==' compares two i64?, and this is i32?
