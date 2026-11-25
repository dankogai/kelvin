// braces where an entry that is a number goes (#764), which kc built
let main():int32 {
    var d:${String: int64} = ${:}
    d["a"] = { 1 }
    return 0
}
// error: a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'
