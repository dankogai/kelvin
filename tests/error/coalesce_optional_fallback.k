// error: '??' of i64? falls back to an i64? or an i64, and this is String?
// a ?? b falls back to an Optional of a's type (#252), or to its value's
// type (#251): an Optional of another type is neither
let main():int32 {
    var a:int64? = none
    var b:String? = $"b"
    println(a ?? b)
    return 0
}
