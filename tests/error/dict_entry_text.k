// error: an entry of Dictionary<String, i64> is an i64, and this is text
let main():int32 {
    var d = ${"a": 1}
    d["a"] = "text"
    return 0
}
