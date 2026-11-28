// arithmetic where a pointer's Optional goes is a number (#787): kc
// named its type, i64
let main():int32 {
    var x:int64 = 1
    var q:int64^? = x + 1
    return 0
}
// error: case 'some' of i64^? holds an i64^, and this is a number
