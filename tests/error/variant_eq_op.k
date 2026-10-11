// a Result has == and != only (#79)
let main():i32 {
    var a:i64? = 1
    var b:i64? = 2
    println(a < b)
    return 0
}
// error: i64? has no operator '<': compare with == and !=
