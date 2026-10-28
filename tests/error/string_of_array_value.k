// String(x) of an owner an expression gives, not C's error (#412)
let main():int32 {
    let s = String($[1, 2])
    println(s)
    return 0
}
// error: String takes nothing, text, or a borrow of a Bytes, '&b', and this is Array<i64>
