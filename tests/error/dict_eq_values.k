// error: compares the values, and pt has no '=='
struct pt { x: int64 }

let main():int32 {
    var a:Dictionary<String, pt> = ${:}
    var b:Dictionary<String, pt> = ${:}
    println(a == b)
    return 0
}
