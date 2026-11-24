// braces are an initializer's: an assignment takes a value, (T?){} or none (#725)
let main():int32 {
    var c:int64? = 4
    c = {}
    return 0
}
// error: a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'; an anonymous function here writes its parameters, as in '{ (a:i64):i64 in a + 1 }'
