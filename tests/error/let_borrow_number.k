// error: 'q' is an i64^, which may change what it borrows, and this is const i64^, a let's: write const in the type taken, or borrow a var
// &x of a let number is a const borrow too, in Kelvin's words (#273)
let main():int32 {
    let x = 1
    var q:int64^ := &x
    return 0
}
