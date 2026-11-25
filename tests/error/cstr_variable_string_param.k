// a cstr variable where a String parameter goes is no String (#749),
// where kc said an owner moves in only as a whole variable
let greet(s:String):int64 { s.count as int64 }
let main():int32 {
    let s:cstr := "a"
    println(greet(s))
    return 0
}
// error: 's' of 'greet' is a String, and this is cstr
