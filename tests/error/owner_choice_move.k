// error: an owner moves into 'eat' only as a whole variable
let eat(x:String):int64 { x.count }
let main():int32 {
    var s = $"a"
    var t = $"b"
    var c = true
    println(eat(c ? s : t))
    return 0
}
