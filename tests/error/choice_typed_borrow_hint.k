// a choice of two variables of the type a pointer borrows is told how
// to lend (#792), as a variable is: kc ended the sentence at i64
let main():int32 {
    var x:int64 = 1
    var y:int64 = 2
    var a:$[int64^] = $[true ? x : y]
    return 0
}
// error: an element of Array<i64^> is an i64^, and this is i64: give a borrow, '&x'
