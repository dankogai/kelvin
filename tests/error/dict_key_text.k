// a String-keyed Dictionary is read with text (#65)
let main():i32 {
    var d = ${"a": 1}
    var y = d[1]
    return 0
}
// error: a key of Dictionary<String, i64> is text: a cstr, a template, or a String
