// uchr is no more (#528): a codepoint is a u32 (#527), as s.codepoints
// gives it; n.uchr, uchr(x) and the type say what to write instead
let main():int32 {
    let n:u32 = 0x41
    var s = $""
    s += n.uchr
    return 0
}
// error: uchr is no more (#528): a codepoint is a u32, as s.codepoints[0] gives it; s += n appends one, and grapheme(n) is a String of it
