// a row that is a string gives no count: write it in the type (#49)
let main():i32 {
    var m:[[u8]] = ["ab", "cd"]
    return 0
}
// error: the rows of an array of arrays are written [...], or their count is written in the type, as in '[[T](n)]'
