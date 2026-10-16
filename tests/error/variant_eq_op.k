// a Result has == and != only (#79)
let main():int32 {
    var a:int64? = 1
    var b:int64? = 2
    println(a < b)
    return 0
}
// error: i64? has no operator '<': compare with == and !=
