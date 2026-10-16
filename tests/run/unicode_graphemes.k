// UnicodeData's grapheme clusters (#156) against the Unicode Character
// Database's own GraphemeBreakTest.txt in tools/ucd/: each line is
// codepoints with ÷ where a cluster ends and × where it goes on
#import <UnicodeData>
#import <IO>
let main():int32 {
    let f = IO("tools/ucd/GraphemeBreakTest.txt", "r")
    if f.error != 0 { println("cannot open the test file"); return 1 }
    var lines:i64 = 0
    var failed:i64 = 0
    for line in f.lines {
        if line.count == 0 || line.bytes^[0] == '#' { continue }
        var text = $""
        var expected:Array<String> = Array<String>()
        var cluster = $""
        var cp:i64 = 0
        var digits:i64 = 0
        var started = false
        for c in line {
            let n = c.utf32 as i64
            if n == '#' as i64 { break }
            if n == 0xF7 || n == 0xD7 {                     // ÷ or ×
                if digits > 0 { text += uchr(cp); cluster += uchr(cp) }
                cp = 0
                digits = 0
                if n == 0xF7 && started { expected += cluster.copy(); cluster = $"" }
                started = true
            } else if n != ' ' as i64 && n != '\t' as i64 {
                let h:i64 = n >= 'a' as i64 ? n - 'a' as i64 + 10 : n >= 'A' as i64 ? n - 'A' as i64 + 10 : n - '0' as i64
                cp = cp * 16 + h
                digits += 1
            }
        }
        if expected.count == 0 { continue }
        lines += 1
        var got = text.graphemes
        var ok = got.count == expected.count
        if ok {
            for k in 0..<got.count as i64 { if got[k] != expected[k] { ok = false } }
        }
        if !ok {
            failed += 1
            if failed <= 5 { println("failed: ", line) }
        }
    }
    println("graphemes: ", lines, " lines, ", failed, " failed")
    return failed == 0 ? 0 : 1
}
// out: graphemes: 853 lines, 0 failed
