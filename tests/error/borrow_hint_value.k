// a value of the type a pointer borrows, given where the pointer is a
// Dictionary's value, is told how to lend it (#784), as an Array's
// element given by += was
let main():int32 {
    var x:int64 = 1
    var d:${String: int64^} = ${"k": x}
    return 0
}
// error: a value of Dictionary<String, i64^> is an i64^, and this is i64: give a borrow, '&x'
