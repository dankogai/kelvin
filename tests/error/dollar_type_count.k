// an Array has no count in its type (#64)
let main():i32 {
    var x:$[[i64](3)]
    return 0
}
// error: an Array grows, and has no count in its type: write $[[i64]], and give the elements or a count where it is made
