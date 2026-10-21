// error: '??' of Result<i64, String> falls back to a Result<i64, String> or an i64, and this is Result<String, String>
// r ?? r2 falls back to a Result of r's type (#253), or to its ok value's
// type: a Result of another type is neither
let main():int32 {
    var a:Result<int64, String> = 1
    var b:Result<String, String> = $"b"
    println(a ?? b)
    return 0
}
