// for c:uchr in s is no more (#528): for c:u32 in s, or for c in
// s.codepoints, walks the codepoints, each a u32 (#527)
let main():int32 {
    var s = $"Kelvin"
    for c:uchr in s { println(c) }
    return 0
}
// error: uchr is no more (#528): a codepoint is a u32, as s.codepoints[0] gives it; s += n appends one, and grapheme(n) is a String of it
