// grapheme(c0, c1, ...) and String.fromCodepoints(c0, c1, ...) (#526):
// a String of codepoints, a Result<String, CodepointError>; grapheme is
// the first grapheme alone, the codepoints after it checked but dropped.
// The text is the codepoints as given, e and U+0301, not é made one.
// Of any number of integers, or of one Array<u32>; none at all, a
// surrogate and a number past U+10FFFF or below 0 are errors
let main():int32 {
    println(grapheme(0x65, 0x301, 0x41), " ", String.fromCodepoints(0x65, 0x301, 0x41))
    println(grapheme(0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467, 0x21))
    let n:u8 = 104
    println(grapheme(n), " ", grapheme('a'), " ", String.fromCodepoints(0x48, 'i'))
    println(grapheme(), " ", String.fromCodepoints())
    println(grapheme(0x41, 0xDC00), " ", grapheme(0x110000), " ", String.fromCodepoints(0x41, -1))
    if let g = grapheme(0x1F1EF, 0x1F1F5) { println(g, " ", g.count) }
    if let err(why) = grapheme(0xD800) { println(why) }
    let e = grapheme()
    println(e.is(err), " ", e ?? $"none")
    var cs:$[u32] = $[0x63, 0x327, 0x61]
    println(grapheme(cs), " ", String.fromCodepoints(cs), " ", cs.count)
    var none:$[u32] = $[]
    println(String.fromCodepoints(none))
    var s = $"Kelvin"
    if let t = String.fromCodepoints(0x4B, 0x65, 0x6C, 0x76, 0x69, 0x6E) { println(t == s) }
    return 0
}
// out: ok("é") ok("éA")
// out: ok("👨‍👩‍👧")
// out: ok("h") ok("a") ok("Hi")
// out: err(CodepointError.empty) err(CodepointError.empty)
// out: err(CodepointError.surrogate(56320)) err(CodepointError.outOfRange(1114112)) err(CodepointError.outOfRange(-1))
// out: 🇯🇵 1
// out: CodepointError.surrogate(55296)
// out: true none
// out: ok("ç") ok("ça") 3
// out: err(CodepointError.empty)
// out: true
