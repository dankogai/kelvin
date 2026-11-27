// a let's borrow is no element of an Array of a T^ that may change what
// it borrows (#784): a += &x, which kc built
let main():int32 {
    let x:int64 = 1
    var a:$[int64^] = $[]
    a += &x
    return 0
}
// error: an element of Array<i64^> is an i64^, which may change what it borrows, and this is const i64^, a let's: write const in the type taken, or borrow a var
