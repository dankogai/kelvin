// a value where a T? goes is a T, which becomes some(v) (#411)
let main():int32 {
    let o:int64? = $"s"
    println(o)
    return 0
}
// error: case 'some' of i64? holds an i64, and this is String
