// a value of a Dictionary's literal is of its kind where the type is
// written (#752), as an entry set is (#246): it was C's error
let main():int32 {
    var d:${String: int64} = ${"a": 1, "b": "x"}
    return 0
}
// error: a value of Dictionary<String, i64> is an i64, and this is text
