// ok(v) holds what the Result's ok holds, in Kelvin's words (#411)
let main():int32 {
    let r:Result<int64, String> = ok($"s")
    println(r)
    return 0
}
// error: case 'ok' of Result<i64, String> holds an i64, and this is String
