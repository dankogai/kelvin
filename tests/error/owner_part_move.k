// a part of an owner does not move alone (#54, O5)
struct m { b: Bytes }
let take(d:Bytes) {}
let main():i32 {
    var v:m = {Bytes("x")}
    take(v.b)
    return 0
}
// error: an owner moves into 'take' only as a whole variable: pass a borrow, '&...', or a copy
