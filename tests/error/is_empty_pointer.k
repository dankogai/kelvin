// x.isEmpty (#434) of a pointer: of what it points to, p^.isEmpty
let main():int32 {
    var xs:$[i64] = $[]
    let p := &xs
    println(p.isEmpty)
    return 0
}
// error: '.isEmpty' is a property of collections and iterators, and this is Array<i64>^, a pointer: write 'p^.isEmpty' of what it points to
