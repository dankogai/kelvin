// a value of the type a pointer borrows, given where the pointer is an
// Optional's case, is told how to lend it (#784)
let main():int32 {
    var x:int64 = 1
    var q:int64^? = x
    return 0
}
// error: case 'some' of i64^? holds an i64^, and this is i64: give a borrow, '&x'
