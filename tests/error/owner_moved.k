// an owner passed by value moves, and is dead afterwards (#54, O5)
let take(d:Bytes) {}
let main():i32 {
    var a = Bytes("x")
    take(a)
    println(a.count)
    return 0
}
// error: 'a' was moved out and holds nothing now: assign it anew before using it
