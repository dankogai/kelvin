// Result<T, E>.ok(v) holds a T (#411)
let main():int32 {
    let r = Result<int64, String>.ok($"s")
    println(r)
    return 0
}
// error: case 'ok' of Result<i64, String> holds an i64, and this is String
