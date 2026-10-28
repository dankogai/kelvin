// r ?? ok(v) of an ok of another type (#411)
let main():int32 {
    let r:Result<int64, String> = err($"e")
    println(r ?? ok($"s"))
    return 0
}
// error: case 'ok' of Result<i64, String> holds an i64, and this is String
