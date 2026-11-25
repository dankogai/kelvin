// a cstr variable is no String as a Dictionary's value either (#749,
// #752): text written becomes one
let main():int32 {
    let c:cstr := "s"
    var d:${String: String} = ${"k": c}
    return 0
}
// error: a value of Dictionary<String, String> is a String, and this is cstr
