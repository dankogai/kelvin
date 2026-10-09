// = does not copy an owner into a case (#54, #61): copy it, or move with T.n(x)
enum pair { b: Bytes; n: i32 }
let main():i32 {
    var p:pair
    var bb = Bytes("x")
    p.b = bb
    return 0
}
// error: an owner is not copied by '=' (#54)
