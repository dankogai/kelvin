// x.isEmpty (#434) is a collection's or an iterator's
let main():int32 {
    let n:i64 = 3
    println(n.isEmpty)
    return 0
}
// error: '.isEmpty' is a property of collections and iterators, and this is i64
