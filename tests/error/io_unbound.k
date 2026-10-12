// a Result an expression gives is an owner: its IO is not taken by = (#82)
let main():i32 {
    var f = IO("x", "r").ok
    return 0
}
// error: an owner is not copied by '=' (#54)
