// a let's borrow is no value of a Dictionary of a T^ that may change
// what it borrows (#784): kc ended the sentence at const i64^
let main():int32 {
    let x:int64 = 1
    var d:${String: int64^} = ${"k": &x}
    return 0
}
// error: a value of Dictionary<String, i64^> is an i64^, which may change what it borrows, and this is const i64^, a let's: write const in the type taken, or borrow a var
