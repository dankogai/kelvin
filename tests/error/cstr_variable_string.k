// a cstr variable is no String (#749): text written becomes one, and a
// cstr is converted, String(s); kc says it too, where it was C's error
let main():int32 {
    let s:cstr := "a"
    var t:String = s
    println(t)
    return 0
}
// error: 't' is a String, and this is cstr
