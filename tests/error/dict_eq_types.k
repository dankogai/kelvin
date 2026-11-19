// error: '==' compares two Dictionaries of the same key and value types, and these are Dictionary<String, i64> and Dictionary<String, String>
let main():int32 {
    var a = ${"a": 1}
    var b = ${"a": "x"}
    println(a == b)
    return 0
}
