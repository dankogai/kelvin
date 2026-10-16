// a struct that owns, given by an expression and not bound, is an error (O4)
let positive(n:int64):Result<int64, String> { return n }
let main():int32 {
    positive(1)
    return 0
}
// error: a struct that owns is given and dropped here: bind it to a variable, which frees it
