// s.bytes is a read-only borrow: the bytes change only as a String (#55)
let main():i32 {
    var s = String("x")
    s.bytes^.append("y")
    return 0
}
// error: '.append' through a read-only borrow: a String's bytes change only as a String
