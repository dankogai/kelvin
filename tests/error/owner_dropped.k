// a struct that owns, given by an expression and not bound, is an error (O4)
let positive(n:i64):Result<i64, String> { return n }
let main():i32 {
    positive(1)
    return 0
}
// error: a struct that owns is given and dropped here: bind it to a variable, which frees it
