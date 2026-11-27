// a let's borrow is no case of an Optional of a T^ that may change what
// it borrows (#784): kc ended the sentence at const i64^
let main():int32 {
    let x:int64 = 1
    var q:int64^? = &x
    return 0
}
// error: case 'some' of i64^? holds an i64^, which may change what it borrows, and this is const i64^, a let's: write const in the type taken, or borrow a var
