// a Dictionary in a Dictionary's literal has its values checked (#764)
let main():int32 {
    var d:${String: ${String: int64}} = ${"a": ${"b": "c"}}
    return 0
}
// error: a value of Dictionary<String, i64> is an i64, and this is text
