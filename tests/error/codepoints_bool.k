// String.fromCodepoints(c0, c1, ...) takes integers (#526): a bool is
// none
let main():int32 {
    let yes = true
    println(String.fromCodepoints(0x41, yes))
    return 0
}
// error: String.fromCodepoints(...) takes codepoints, integers, or one Array<u32>, and this is a bool
