// an owner passed to async f(x) moves into it (#312), as passing it would
let size(s:String):int64 { s.count }
let main():int32 {
    var s = String("x")
    let t = async size(s)
    println(s)
    return 0
}
// error: 's' was moved out and holds nothing now: assign it anew before using it
