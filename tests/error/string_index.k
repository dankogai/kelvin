// a String is not indexed by codepoint (#55)
let main():i32 {
    var s = String("héllo")
    println(s[1])
    return 0
}
// error: a String is not indexed by codepoint, which would walk it: walk it with 'for c in s', or index its bytes, 's.bytes^[i]'
