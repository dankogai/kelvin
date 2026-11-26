// Array<T>({1, 2}) (#769): braces are no count and no elements, which
// was C's error of kc's C
let main():int32 {
    var a = Array<int64>({1, 2})
    return 0
}
// error: a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'
