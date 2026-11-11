// grapheme(c0, c1, ...) takes codepoints (#526): text is a String
// already, whose s[0] is its first grapheme
let main():int32 {
    println(grapheme("é"))
    return 0
}
// error: grapheme(...) takes codepoints, integers, or one Array<u32>, and this is text: $"..."[0] is its first grapheme, a String
