// a borrow of a local owner dies with it (#54, O6)
let main():i32 {
    var r:Bytes^
    {
        var a = Bytes("x")
        r := &a
    }
    return 0
}
// error: a borrow of 'a' outlives it: 'a' is freed when this block ends, and 'r' is of an outer one
