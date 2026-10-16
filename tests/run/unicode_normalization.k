// UnicodeData's normalization (#156) against the Unicode Character
// Database's own NormalizationTest.txt in tools/ucd/: for each line of
// five columns, c2 is NFC of c1, c2 and c3, c4 of c4 and c5; c3 is NFD of
// c1 to c3, c5 of c4 and c5; c4 is NFKC and c5 NFKD of all five
#import <UnicodeData>
#import <IO>
// the hex codepoints of a column, as a String
let column(line:const String^, from:i64, to:i64):String {
    var s = $""
    var cp:i64 = 0
    var digits:i64 = 0
    for i in from..<to {
        let c = line^.bytes^[i]
        if c == ' ' {
            if digits > 0 { s += uchr(cp) }
            cp = 0
            digits = 0
        } else {
            cp = cp * 16 + (c >= 'a' ? (c - 'a') as i64 + 10 : c >= 'A' ? (c - 'A') as i64 + 10 : (c - '0') as i64)
            digits += 1
        }
    }
    if digits > 0 { s += uchr(cp) }
    return s
}
let main():int32 {
    let f = IO("tools/ucd/NormalizationTest.txt", "r")
    if f.error != 0 { println("cannot open the test file"); return 1 }
    var lines:i64 = 0
    var failed:i64 = 0
    for line in f.lines {
        if line.count == 0 || line.bytes^[0] == '#' || line.bytes^[0] == '@' { continue }
        var cols:Array<String> = Array<String>()
        var start:i64 = 0
        var i:i64 = 0
        let n = line.bytes^.count as i64
        while i < n && cols.count < 5 {
            if line.bytes^[i] == ';' {
                cols += column(&line, start, i)
                start = i + 1
            }
            i += 1
        }
        if cols.count != 5 { continue }
        lines += 1
        var ok = true
        for k in 0..<5 {
            var composed = cols[k].normalize(nfc)
            var decomposed = cols[k].normalize(nfd)
            var kcomposed = cols[k].normalize(nfkc)
            var kdecomposed = cols[k].normalize(nfkd)
            let c:i64 = k < 3 ? 1 : 3
            let d:i64 = k < 3 ? 2 : 4
            if composed != cols[c] || decomposed != cols[d] || kcomposed != cols[3] || kdecomposed != cols[4] { ok = false }
        }
        if !ok {
            failed += 1
            if failed <= 5 { println("failed: ", line) }
        }
    }
    println("normalization: ", lines, " lines, ", failed, " failed")
    return failed == 0 ? 0 : 1
}
// out: normalization: 20171 lines, 0 failed
