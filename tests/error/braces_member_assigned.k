// braces are an initializer's: a member is assigned a value (#725, #736)
struct point { x: int64; y: int64 }
let main():int32 {
    var p:point = {0, 0}
    p.x = {1}
    return 0
}
// error: a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'; an anonymous function here writes its parameters, as in '{ (a:i64):i64 in a + 1 }'
