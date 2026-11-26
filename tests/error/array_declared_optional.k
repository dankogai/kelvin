// an Optional where an array is declared (#772): where [i64](2) goes,
// as written, and kc's an array is not assigned no more
let main():int32 {
    var q:int64? = 1
    var a:[int64](2) = q
    return 0
}
// error: this is i64?, an Optional, where [i64](2) goes: unwrap it with '!', or give a default with '??'
