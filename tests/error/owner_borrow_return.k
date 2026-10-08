// a borrow of a local owner cannot be returned (#54, O6)
let g():Bytes^ {
    var a = Bytes("x")
    return &a
}
let main():i32 { return 0 }
// error: a borrow of 'a' is returned, and 'a' is freed when this function returns: return 'a' itself, which moves it out
