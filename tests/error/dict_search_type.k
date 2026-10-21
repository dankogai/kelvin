// error: '.lastKey' of Dictionary<String, i64> looks for an i64, and this is text
let main():int32 {
    var d = ${"a": 1}
    println(d.lastKey("x"))
    return 0
}
