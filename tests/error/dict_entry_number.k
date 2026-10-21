// error: an entry of Dictionary<String, String> is a String, and this is a number
let main():int32 {
    var d:Dictionary<String, String> = ${:}
    d["b"] ??= 3
    return 0
}
