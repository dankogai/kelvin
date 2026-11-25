// braces where a Set's element goes (#764)
let main():int32 {
    var s:${int64} = ${1}
    s.insert({ 1 })
    return 0
}
// error: a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'
