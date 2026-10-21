// error: '.mapWithKey' calls its function with each key, cstr, and this takes String
let main():int32 {
    var a = ${"x": 1}
    var b = a.mapWithKey { (k:String, v:int64):int64 in v }
    return 0
}
