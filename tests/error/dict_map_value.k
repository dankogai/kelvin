// error: '.map' calls its function with each value, i64, and this takes String
let main():int32 {
    var a = ${"x": 1}
    var b = a.map { (s:String):int64 in 1 }
    return 0
}
