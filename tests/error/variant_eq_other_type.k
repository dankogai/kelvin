// == compares two of the same type (#79)
let main():i32 {
    var a:i64? = 1
    var b:i32? = 1
    println(a == b)
    return 0
}
// error: '==' compares two i64?, and this is i32?
