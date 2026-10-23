// a literal's \u{X}, \uXXXX and \UXXXXXXXX are its codepoint's UTF-8 bytes
// (#292), which kelvinc writes to C itself: a control character too,
// which C's universal character names refuse. So the text print gives
// pastes back, ["a\u007f\u001bé"] the value printed; \\u is a backslash
// and a u, and \x41 is C's, next to them
let main():int32 {
    var s = $"a"
    s += (0x7f as u32).uchr
    s += (0x1b as u32).uchr
    s += (0xe9 as u32).uchr
    let printed:$[String] = $["a\u007f\u001bé"]
    println($[s.copy()], " ", printed[0] == s, " ", $"a\u{7f}\u{1b}\u{e9}" == s)
    let t:cstr := "\u{1F600}\U0001F600\u00e9\u0041\x41\u{e9}5\\u{7f}"
    println(t, " ", String(t).count)
    let n = 7
    println(`n\u{3d}${n}\u{2028}end`.count, " ", $"\u{0}x".count)
    return 0
}
// out: ["a\u007f\u001bé"] true true
// out: 😀😀éAAé5\u{7f} 13
// out: 9 2
