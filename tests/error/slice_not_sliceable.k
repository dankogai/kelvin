// a slice is of an Array, a String or a Bytes (#68)
let main():i32 {
    var d = ${"a": 1}
    var y = d[0..<1]
    return 0
}
// error: a slice [lo..<hi] is of an Array, a String or a Bytes, and this is Dictionary<String, i64>
