// braces where an element is appended (#764), which was C's error in kc
let main():int32 {
    var a:$[int64] = $[]
    a.append({ 1 })
    return 0
}
// error: a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'
