// err({}) is a list where a value goes, as ok({}) is (#743), of a
// number's case too
let half(n:int64):Result<int64, int64> {
    if n % 2 != 0 { return err({}) }
    return n / 2
}
let main():int32 {
    let r = half(3)
    return 0
}
// error: a list is not a value here: write a compound literal, as in '(i32[3]){1, 2, 3}'; as a function with no parameters and no result, this would do nothing
