// lex.k - the tokens of the source, for kc (selfhost/kc.k).
// Every file's codepoints go into one Array, `codes`; a token is where
// its text is there, how long, its line and its file. A newline is a
// token where it may end a statement: outside ( ) and [ ].

enum tkind {                    // the kinds of tokens (#210)
    T_EOF,
    T_NL,
    T_ID,
    T_NUM,
    T_STR,      // "...", as written
    T_CHAR,     // '.', as written
    T_PUNCT,
    T_DSTR,     // $"...", the text from its "
    T_IMPORT,   // #import <x>, "x.k" or <x.h> as C, the name with its brackets
    T_TPL,      // `...` with no ${...}: a string, its text as C's literal after the files' (#445)
    T_TPL_HEAD, // `...${ of a template, its text so
    T_TPL_MID,  // }...${
    T_TPL_TAIL  // }...`
}

struct tok {
    kind: tkind
    at: int64
    len: int64
    line: int64
    file: int64
    src: int64      // where it is in its file: at, or a template's and a 123n's place, their text being kc's (#682)
}

var codes:$[uint32]       // every file's text
var toks:$[tok]
var fnames:$[String]      // every file's name
var file_by:$[int64]      // the #import token each file was first read for; -1 the program's own and the prelude's (#550)
var codes_from:$[int64]   // where each file's codes begin and end, for a token's column (#652)
var codes_to:$[int64]
var reading_by:int64 = 0 - 1
var file_with_a:$[int64]  // an overlay's two modules, A and B of A+B.k, as files (#551); -1 of any other file,
var file_with_b:$[int64]  // and an overlay's file_by is -2 until the pass before parsing places it
var reading_a:int64 = 0 - 1
var reading_b:int64 = 0 - 1
var failed:bool
var eof_pos = 0           // the end of the files' tokens: kc's own come after it (#217)

let code_at(i:int64):uint32 {
    if i < codes.count as int64 { return codes[i] }
    return 0
}

// the text of token t is w
let tok_is(t:int64, w:cstr):bool {
    let at:int64 = toks[t].at
    let n:int64 = toks[t].len
    var i = 0
    while i < n {
        if w[i] == 0 { return false }
        if codes[at + i] != w[i] as uint32 { return false }
        i += 1
    }
    return w[n] == 0
}

// the text of token t begins with w
let tok_starts(t:int64, w:cstr):bool {
    let at:int64 = toks[t].at
    var i = 0
    while w[i] != 0 {
        if i >= toks[t].len || codes[at + i] != w[i] as uint32 { return false }
        i += 1
    }
    return true
}

// whether file f is one of the prelude's (#600), as kelvinc's
// prelude_file: UnicodeData, RegExp, BigInt or math, the source or its
// header, by its name. What it declares at its top level is what
// Kelvin.name names
var file_prelude:$[int64] = $[]                          // 1 where it is, 0 where not, each file asked once

let prelude_file(f:int64):bool {
    while file_prelude.count as int64 > fnames.count as int64 { file_prelude.pop() }
    while file_prelude.count as int64 < fnames.count as int64 {
        var base = $""
        for c in fnames[file_prelude.count as int64].codepoints {
            if c == '/' {
                base = $""
            } else {
                base += c
            }
        }
        let yes = base == "UnicodeData.k" || base == "UnicodeData.kh" || base == "RegExp.k" || base == "RegExp.kh" || base == "BigInt.k" || base == "BigInt.kh" || base == "math.k" || base == "math.kh"
        file_prelude += yes ? 1 : 0
    }
    return file_prelude[f] == 1
}

// whether the T_IMPORT token t is of a line written #import, and not of
// another line with a #, which kc reads no further (#611)
let import_line(t:int64):bool {
    var w:int64 = toks[t].at
    while w > 0 && codes[w - 1] != '#' && codes[w - 1] != '\n' { w -= 1 }
    if w == 0 || codes[w - 1] != '#' { return false }
    while codes[w] == ' ' || codes[w] == '\t' { w += 1 }
    return codes[w] == 'i' && codes[w + 1] == 'm' && codes[w + 2] == 'p' && codes[w + 3] == 'o' && codes[w + 4] == 'r' && codes[w + 5] == 't'
}

// tokens a and b have the same text
let same_text(a:int64, b:int64):bool {
    let n:int64 = toks[a].len
    if toks[b].len != n { return false }
    var i = 0
    while i < n {
        if codes[toks[a].at + i] != codes[toks[b].at + i] { return false }
        i += 1
    }
    return true
}

// the text of token t, a String
let tok_text(t:int64):String {
    var s = $""
    let at:int64 = toks[t].at
    for i in 0..<toks[t].len {
        s += codes[at + i]
    }
    return s
}

let is_alpha(c:uint32):bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

let is_digit(c:uint32):bool {
    return c >= '0' && c <= '9'
}

// whether c may begin a name, and go on with one (#385): ASCII's letters
// and _, digits after the first, and past ASCII ident.k's, UAX #31's
// XID_Start and XID_Continue and emoji, as kelvinc's
let name_start(c:uint32):bool {
    return is_alpha(c) || (c >= 128 && ident_start(c as int64))
}

let name_continue(c:uint32):bool {
    return is_alpha(c) || is_digit(c) || (c >= 128 && ident_continue(c as int64))
}

// c as four hex digits or more, upper case, as U+%04X writes it
let hex4(c:uint32):String {
    let digits:cstr := "0123456789ABCDEF"
    var p:uint32 = 268435456
    while p > 4096 && c / p == 0 { p = p / 16 }
    var s = $""
    while p > 0 {
        s += digits[(c / p) % 16]
        p = p / 16
    }
    return s
}

let add_tok(kind:tkind, at:int64, len:int64, line:int64, file:int64) {
    let t:tok = {kind, at, len, line, file, at}
    toks += t
}

// a token kc writes itself, its text s put after the files' codes, for
// a literal that becomes a call, as kelvinc's push_text (#515)
let add_made(kind:tkind, s:cstr, line:int64, file:int64) {
    let at:int64 = codes.count as int64
    var k = 0
    while s[k] != 0 {
        codes += s[k] as uint32
        k += 1
    }
    add_tok(kind, at, codes.count as int64 - at, line, file)
}

// whether what follows the . of a hex number, at i, is the rest of a hex
// float (#556): its fraction's digits, if any, then p or P and the
// exponent's digits, signed or not: 0x1.8p1, 0x1.f4p+9, 0x1.p3. So
// 0xff.cstr and 0xff.pow2() are a member's, the p of a name no exponent
let hex_fraction(i:int64):bool {
    var k:int64 = i
    while is_digit(code_at(k)) || (code_at(k) >= 'a' && code_at(k) <= 'f') || (code_at(k) >= 'A' && code_at(k) <= 'F') { k += 1 }
    if code_at(k) != 'p' && code_at(k) != 'P' { return false }
    k += 1
    if code_at(k) == '+' || code_at(k) == '-' { k += 1 }
    return is_digit(code_at(k))
}

var big_lits:$[int64]     // the BigInt token of each 123n, which names the prelude's BigInt (#508, #515)
var rx_lits:$[int64]      // the RegExp token of each $/.../, the prelude's RegExp (#157, #515)

// 123n, 0xffn, 0o17n (#562), 0b101n from s up to the n at e (#508), as
// kelvinc's big_literal: BigInt("123", 10), the prelude's; false where
// the text before the n is no integer, which is then a number's error
let big_literal(s:int64, e:int64, ts:int64, te:int64, line:int64, file:int64):bool {
    var base = 10
    var d:int64 = s
    if e - s > 2 && codes[s] == '0' && (codes[s + 1] == 'x' || codes[s + 1] == 'X' || codes[s + 1] == 'b' || codes[s + 1] == 'B' || codes[s + 1] == 'o' || codes[s + 1] == 'O') {
        base = codes[s + 1] == 'x' || codes[s + 1] == 'X' ? 16 : codes[s + 1] == 'o' || codes[s + 1] == 'O' ? 8 : 2
        d = s + 2
    }
    if d == e { return false }
    for q in d..<e {
        let c:uint32 = codes[q]
        let hexd = is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
        if base == 16 && !hexd { return false }
        if base == 8 && (c < '0' || c > '7') { return false }
        if base == 2 && c != '0' && c != '1' { return false }
        if base == 10 && !is_digit(c) { return false }
    }
    if base == 10 && e - s > 1 && codes[s] == '0' {
        var m = $"'"
        for q in ts..<te { m += codes[q] }               // as written, its _ too (#671)
        m += "': a BigInt literal is decimal, 0x hex, 0o octal or 0b binary, with no leading 0: C's octal is none of them"
        lex_error(file, line, m.cstr)
        return true
    }
    let first:int64 = toks.count as int64
    add_made(T_ID, "BigInt", line, file)
    big_lits += toks.count as int64 - 1
    add_made(T_PUNCT, "(", line, file)
    let at:int64 = codes.count as int64
    codes += '"'
    for q in d..<e { codes += codes[q] }
    codes += '"'
    add_tok(T_STR, at, codes.count as int64 - at, line, file)
    add_made(T_PUNCT, ",", line, file)
    add_made(T_NUM, base == 16 ? "16" : base == 8 ? "8" : base == 2 ? "2" : "10", line, file)
    add_made(T_PUNCT, ")", line, file)
    for q in first..<toks.count as int64 { toks[q].src = ts }   // each at the literal, as kelvinc's error there (#682)
    return true
}

// what kelvinc says to use for token t, a keyword of a C compiler's and
// none of Kelvin's, as its foreign_keywords list them (#612): "" of one
// with nothing to use, nowhere of any other word
let foreign_hint(t:int64):cstr {
    if toks[t].len < 5 || codes[toks[t].at] != '_' {
        return tok_is(t, "typeof_unqual") ? "x.type, whose own qualifiers do not come along" : nowhere
    }
    if tok_is(t, "__alignof__") || tok_is(t, "__alignof") { return "alignof(T) or x.align" }
    if tok_is(t, "__typeof__") || tok_is(t, "__typeof") { return "typeof(x) or x.type" }
    if tok_is(t, "__typeof_unqual__") { return "x.type, whose own qualifiers do not come along" }
    if tok_is(t, "__int128") { return "i128 or u128" }
    if tok_is(t, "__complex__") || tok_is(t, "__complex") { return "c64 or c32 of #import <math> (#404)" }
    if tok_is(t, "__asm__") || tok_is(t, "__asm") { return "#inline C { __asm__ __volatile__(\"...\"); }, as C" }
    if tok_is(t, "__volatile__") || tok_is(t, "__volatile") { return "volatile" }
    if tok_is(t, "__extension__") || tok_is(t, "__real__") || tok_is(t, "__real") || tok_is(t, "__imag__") || tok_is(t, "__imag") || tok_is(t, "_BitInt") || tok_is(t, "__auto_type") || tok_is(t, "__label__") || tok_is(t, "_Float16") || tok_is(t, "_Float128") || tok_is(t, "__float128") || tok_is(t, "__fp16") || tok_is(t, "__bf16") || tok_is(t, "_Decimal32") || tok_is(t, "_Decimal64") || tok_is(t, "_Decimal128") || tok_is(t, "__signed__") || tok_is(t, "__signed") { return "" }
    return nowhere
}

// an integer literal from s to e, its _ left out, past u64's greatest,
// which C has no type for, as kelvinc's reject_huge_int says it (#678):
// the text as written, ts to te, and the BigInt literal that holds it,
// 0o's of C's octal
let huge_int(s:int64, e:int64, ts:int64, te:int64, line:int64, file:int64):bool {
    var base:uint64 = 10
    var p:int64 = s
    var c_octal = false
    let x:uint32 = e - s > 1 ? codes[s + 1] : 0
    if e - s > 1 && codes[s] == '0' && (x == 'x' || x == 'X' || x == 'b' || x == 'B' || x == 'o' || x == 'O') {
        base = x == 'x' || x == 'X' ? 16 : x == 'b' || x == 'B' ? 2 : 8
        p = s + 2
    } else if e - s > 1 && codes[s] == '0' {
        base = 8
        c_octal = true
        p = s + 1
    }
    var v:uint64 = 0
    for q in p..<e {
        let c:uint32 = codes[q]
        var d:uint64 = c - 'A' + 10
        if is_digit(c) { d = c - '0' } else if c >= 'a' { d = c - 'a' + 10 }
        if v > (uint64.max - d) / base {
            var m = $"integer literal '"
            for r in ts..<te { m += codes[r] }
            m += "' is too large: u64's greatest is 18446744073709551615; a BigInt is written '"
            if c_octal {
                m += "0o"
                for r in s + 1..<e { m += codes[r] }
            } else {
                for r in ts..<te { m += codes[r] }
            }
            m += "n'"
            lex_error(file, line, m.cstr)
            return true
        }
        v = v * base + d
    }
    return false
}

// a number from s to e is digits, a fraction and an exponent and no more,
// as kelvinc's check_number has it (#612): C's suffixes, 10UL, 1.5f, are
// its error, the type goes on the declaration; and what else follows the
// digits, 12ab, is a malformed number
let check_number(s:int64, e:int64, ts:int64, te:int64, line:int64, file:int64) {
    var p:int64 = s                                      // ts to te: the text as written, its _ too, which a message quotes (#671)
    let hex = e - s > 1 && codes[s] == '0' && (codes[s + 1] == 'x' || codes[s + 1] == 'X')
    let bin = e - s > 1 && codes[s] == '0' && (codes[s + 1] == 'b' || codes[s + 1] == 'B')
    var floating = false
    if hex || bin { p += 2 }
    while p < e && (is_digit(codes[p]) || (hex && ((codes[p] >= 'a' && codes[p] <= 'f') || (codes[p] >= 'A' && codes[p] <= 'F')))) { p += 1 }
    if !bin && p < e && codes[p] == '.' {
        floating = true
        p += 1
        while p < e && (is_digit(codes[p]) || (hex && ((codes[p] >= 'a' && codes[p] <= 'f') || (codes[p] >= 'A' && codes[p] <= 'F')))) { p += 1 }
    }
    if !bin && p < e && (hex ? codes[p] == 'p' || codes[p] == 'P' : codes[p] == 'e' || codes[p] == 'E') {
        floating = true
        p += 1
        if p < e && (codes[p] == '+' || codes[p] == '-') { p += 1 }
        while p < e && is_digit(codes[p]) { p += 1 }
    }
    if p == e {
        if !floating { huge_int(s, e, ts, te, line, file) }     // (#678)
        return
    }
    var text = $""
    for q in ts..<te { text += codes[q] }
    var suffix = true
    var has_f = false
    var has_u = false
    for q in p..<e {
        let c:uint32 = codes[q]
        if c == 'f' || c == 'F' { has_f = true } else if c == 'u' || c == 'U' { has_u = true } else if c != 'l' && c != 'L' { suffix = false }
    }
    var m = $""
    if suffix {
        m = $"'"
        m += &text
        m += "': literals have no suffixes in Kelvin; put the type on the declaration, e.g. 'x:"
        m += floating ? (has_f ? "f32" : "f64") : has_u ? "u64" : "i64"
        m += " = "
        for q in ts..<te - (e - p) { m += codes[q] }
        m += "'"
    } else {
        m = $"malformed number '"
        m += &text
        m += "'"
    }
    lex_error(file, line, m.cstr)
}

// 1_000, 0xff_ff, 1_000.000_1, 1e1_0, 1_000n from s to e (#671), as
// kelvinc's without_separators: a _ among a number's digits, as Swift has
// it, after a digit or another _, so that the digits of the integer part,
// of the fraction and of the exponent each begin with a digit, and a 0x,
// 0o or 0b is as written: 0x_ff, 1e_5 and 0_x10 are none. The text without
// them appended to codes, where it starts; -1 after the error
let without_separators(s:int64, e:int64, line:int64, file:int64):int64 {
    let x:uint32 = e - s > 1 ? codes[s + 1] : 0
    let prefixed = codes[s] == '0' && (x == 'x' || x == 'X' || x == 'b' || x == 'B' || x == 'o' || x == 'O')
    let hex = prefixed && (x == 'x' || x == 'X')
    var exponent = false
    var ok = true
    let at:int64 = codes.count as int64
    for q in s..<e {
        let c:uint32 = codes[q]
        if hex && (c == 'p' || c == 'P') { exponent = true }   // a hex float's exponent, decimal digits
        if c != '_' {
            codes += c
            continue
        }
        let prev:uint32 = codes[q - 1]                   // q > s: a number begins with a digit
        let hexd = (prev >= 'a' && prev <= 'f') || (prev >= 'A' && prev <= 'F')
        if prev != '_' && !is_digit(prev) && !(hex && !exponent && hexd) { ok = false }
    }
    let y:uint32 = codes.count as int64 - at > 1 ? codes[at + 1] : 0
    if !prefixed && codes[at] == '0' && (y == 'x' || y == 'X' || y == 'b' || y == 'B' || y == 'o' || y == 'O') { ok = false }
    if ok { return at }
    var m = $"malformed number '"
    for q in s..<e { m += codes[q] }
    m += "': a '_' separates digits and follows one, as in 1_000 or 0xff_ff"
    lex_error(file, line, m.cstr)
    return -1
}

// 0o52 from s to e (#562), as kelvinc reads it (#561): 0o or 0O and
// digits of 0 to 7, the text n.oct writes; from here on C's own octal,
// 052, which gen.k and the C compiler know. What is not one, 0o18, 0o,
// 0o1.5, is the error kelvinc says
let octal_literal(s:int64, e:int64, ts:int64, te:int64, line:int64, file:int64) {
    var ok = e - s > 2
    for q in s + 2..<e {
        if codes[q] < '0' || codes[q] > '7' { ok = false }
    }
    if !ok {
        var m = $"malformed number '"
        for q in ts..<te { m += codes[q] }
        m += "': an octal number is 0o and digits of 0 to 7, as in 0o17"
        lex_error(file, line, m.cstr)
        return
    }
    if huge_int(s, e, ts, te, line, file) { return }    // (#678)
    let at:int64 = codes.count as int64
    codes += '0'
    for q in s + 2..<e { codes += codes[q] }
    add_tok(T_NUM, at, codes.count as int64 - at, line, file)
}

// """text""" from i, at its first quote (#115, #118, #516), as kelvinc's
// lex_triple: the text between runs of three or more quotes as it is, no
// escapes, no ${...}; a closing run as long as the opening one ends it,
// and its extra quotes are text. Written on its own lines, the line break
// after the opening run and the one before the closing run are not text,
// and the closing run's indentation comes off each line that has it. A
// T_STR of C's literal, appended to codes, or a T_DSTR after a $. Where
// it ends, after the closing run
let lex_triple(i:int64, to:int64, line:int64, file:int64, dollar:bool):int64 {
    var k:int64 = i
    var n:int64 = 0
    while k < to && codes[k] == '"' {
        k += 1
        n += 1
    }
    var raw:$[uint32] = $[]
    while true {
        if k >= to {
            var m = $"unterminated \"\"\" string: it ends with "
            m += String(n)
            m += " quotes, as it began"
            lex_error(file, line, m.cstr)
            return k
        }
        if codes[k] == '"' {
            var run:int64 = 0
            while k < to && codes[k] == '"' {
                k += 1
                run += 1
            }
            let text_run:int64 = run >= n ? run - n : run
            for q in 0..<text_run { raw += '"' }
            if run >= n { break }
            continue
        }
        if codes[k] == '\r' && k + 1 < to && codes[k + 1] == '\n' { k += 1 }   // a CRLF line end is a new line
        raw += codes[k]
        k += 1
    }
    var from:int64 = 0
    var len:int64 = raw.count as int64
    var ind:int64 = 0                    // where the indentation is, in raw, and how long
    var ind_len:int64 = 0
    if len > 0 && raw[0] == '\n' {
        from = 1
        var last:int64 = len
        while last > from && (raw[last - 1] == ' ' || raw[last - 1] == '\t') { last -= 1 }
        if last > from && raw[last - 1] == '\n' {
            ind = last
            ind_len = len - last
            len = last - 1
        } else if last == from {
            ind = from
            ind_len = len - from
            len = from
        }
    }
    let at:int64 = codes.count as int64
    if dollar { codes += '$' }
    codes += '"'
    var line_start = true
    var q:int64 = from
    while q < len {
        if line_start && ind_len > 0 && len - q >= ind_len {
            var same = true
            for r in 0..<ind_len {
                if raw[q + r] != raw[ind + r] { same = false }
            }
            if same {
                q += ind_len
                line_start = false
                continue
            }
        }
        let c:uint32 = raw[q]
        line_start = c == '\n'
        if c == '\\' || c == '"' || c == '?' {
            codes += '\\'
            codes += c
        } else if c == '\n' {
            codes += '\\'
            codes += 'n'
        } else if c == '\r' {
            codes += '\\'
            codes += 'r'
        } else {
            codes += c
        }
        q += 1
    }
    codes += '"'
    add_tok(dollar ? T_DSTR : T_STR, at, codes.count as int64 - at, line, file)
    return k
}

// $/pattern/flags from i, at its $ (#157), as kelvinc's lex_regexp:
// RegExp.compile("pattern", "flags"), the prelude's; the pattern ends at
// the first / not escaped and not in [...], on its line, and goes into C's
// literal as written, with \, " and ? escaped (?? would start a trigraph);
// the flags are the letters after it. Where it ends, after the flags
let lex_regexp(i:int64, to:int64, line:int64, file:int64):int64 {
    let s:int64 = i + 2
    var k:int64 = s
    var in_class = false
    while true {
        if k >= to || codes[k] == '\n' {
            lex_error(file, line, "unterminated $/.../: a regular expression ends with '/' on its line")
            return k
        }
        let c:uint32 = codes[k]
        if c == '\\' && k + 1 < to && codes[k + 1] != '\n' {
            k += 2
            continue
        }
        if c == '[' {
            in_class = true
        } else if c == ']' {
            in_class = false
        } else if c == '/' && !in_class {
            break
        }
        k += 1
    }
    let e:int64 = k
    k += 1
    let fs:int64 = k
    while k < to && is_alpha(codes[k]) && codes[k] != '_' { k += 1 }
    var pattern = $""                                    // checked now, by the runtime's parser of RegExp, its rx_check,
    for q in s..<e { pattern += codes[q] }               // as kelvinc checks it (#163, #611)
    var flags = $""
    for q in fs..<k { flags += codes[q] }
    var where:size_t = 0
    let wrong:cstr := rx_check(pattern.cstr, flags.cstr, &where) as cstr
    if wrong != nowhere {
        var m = $"a $/.../ literal that is not a regular expression: "
        m += wrong
        var wi:int64 = s                                 // where's bytes into the pattern, as kelvinc's column (#682)
        var wb:int64 = 0
        while wi < e && wb < where as int64 {
            let c:uint32 = codes[wi]
            wb += c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
            wi += 1
        }
        lex_error_at(file, wi, m.cstr)
        return k
    }
    add_made(T_ID, "RegExp", line, file)
    rx_lits += toks.count as int64 - 1
    add_made(T_PUNCT, ".", line, file)
    add_made(T_ID, "compile", line, file)
    add_made(T_PUNCT, "(", line, file)
    var at:int64 = codes.count as int64
    codes += '"'
    for q in s..<e {
        let c:uint32 = codes[q]
        if c == '\\' || c == '"' || c == '?' { codes += '\\' }
        codes += c
    }
    codes += '"'
    add_tok(T_STR, at, codes.count as int64 - at, line, file)
    add_made(T_PUNCT, ",", line, file)
    at = codes.count as int64
    codes += '"'
    for q in fs..<k { codes += codes[q] }
    codes += '"'
    add_tok(T_STR, at, codes.count as int64 - at, line, file)
    add_made(T_PUNCT, ")", line, file)
    return k
}

// a type of the files' own that has the name of one of the prelude's is
// _kv_own_T in the tokens and in C (#600), as kelvinc's: each such name,
// where its text is among the codes
var own_at:$[int64] = $[]
var own_len:$[int64] = $[]

// a message as it is shown, as kelvinc's kv_shown: the files' own type is
// T, and the prelude's of that name Kelvin.T, as the program writes each
let shown_text(what:cstr, prelude:bool):String

let as_shown(what:cstr):String {
    return shown_text(what, true)
}

// what as the files write it: with prelude, the prelude's type of such a
// name is Kelvin.T too; without, as x.typename has it, the files' own is T
let shown_text(what:cstr, prelude:bool):String {
    if own_at.count == 0 { return String(what) }
    var text = String(what)
    var cs:$[uint32] = $[]
    for c in text.codepoints { cs += c }
    let own:cstr := "_kv_own_"
    var s = $""
    let n:int64 = cs.count as int64
    var i:int64 = 0
    while i < n {
        var marked = i + 8 <= n
        for j in 0..<8 {
            if marked && cs[i + j] != own[j] as uint32 { marked = false }
        }
        if marked {                                      // the files' own: its name
            i += 8
            while i < n && name_continue(cs[i]) {
                s += cs[i]
                i += 1
            }
            continue
        }
        var len:int64 = 0
        if prelude && (i == 0 || (!name_continue(cs[i - 1]) && cs[i - 1] != '.')) {
            for k in 0..<own_at.count as int64 {
                let m:int64 = own_len[k]
                if len > 0 || i + m > n { continue }
                var same = true
                for j in 0..<m {
                    if cs[i + j] != codes[own_at[k] + j] { same = false }
                }
                if same && (i + m == n || !name_continue(cs[i + m])) { len = m }
            }
        }
        if len > 0 {                                     // the prelude's of that name
            s += "Kelvin."
            for j in 0..<len { s += cs[i + j] }
            i += len
            continue
        }
        s += cs[i]
        i += 1
    }
    return s
}

// the column of token t, as kelvinc counts it: 1 and the bytes of UTF-8
// before it on its line; 0 of a token kc made, which is in no file (#652)
let tok_col(t:int64):int64 {
    let k:tok = toks[t]
    if k.file < 0 || k.file >= codes_from.count as int64 { return 0 }
    let lo:int64 = codes_from[k.file]
    let src:int64 = k.src                                // (#682)
    if src < lo || src >= codes_to[k.file] { return 0 }
    var i:int64 = src
    while i > lo && codes[i - 1] != '\n' { i -= 1 }
    var at:int64 = src
    if k.kind == T_IMPORT {                              // #import's column is its #, as kelvinc's
        var h:int64 = k.at
        while h > i && codes[h] != '#' { h -= 1 }
        at = h
    }
    var col:int64 = 1
    while i < at {
        let c:uint32 = codes[i]
        col += c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
        i += 1
    }
    return col
}

// where file f ends, as kelvinc says an error there: file:line:col of
// the place after its last character (#652)
let file_end_text(f:int64):String {
    var line:int64 = 1
    var col:int64 = 1
    if f >= 0 && f < codes_from.count as int64 {
        for i in codes_from[f]..<codes_to[f] - 1 {       // its text, without the newline kc puts after it
            let c:uint32 = codes[i]
            if c == '\n' {
                line += 1
                col = 1
            } else {
                col += c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
            }
        }
    }
    var s:String = fnames[f].copy()
    s += ":"
    s += String(line)
    s += ":"
    s += String(col)
    return s
}

// where an error at token t is, as kelvinc writes it: file:line:col
let error_at_text(t0:int64):String {
    var t:int64 = t0
    while t + 1 < toks.count as int64 && toks[t].kind == T_NL { t += 1 }   // kelvinc has no token of a line's end: the one after it (#681)
    if toks[t].kind == T_EOF && toks[t0].kind == T_NL { return file_end_text(toks[t0].file) }
    let k:tok = toks[t]
    var s:String = fnames[k.file].copy()
    s += ":"
    s += String(k.line)
    let col:int64 = tok_col(t)
    if col > 0 {
        s += ":"
        s += String(col)
    }
    return s
}

// whether the innermost { open among the tokens read is a struct's, a
// union's or an enum's body: struct T {, enum {, extend's own aside (#653)
let in_record_body():bool {
    var depth:int64 = 0
    var j:int64 = toks.count as int64 - 1
    while j >= 0 {
        if toks[j].kind == T_PUNCT && tok_is(j, "}") {
            depth += 1
        } else if toks[j].kind == T_PUNCT && tok_is(j, "{") {
            if depth == 0 {
                var k:int64 = j - 1
                if k >= 0 && toks[k].kind == T_ID && !tok_is(k, "struct") && !tok_is(k, "union") && !tok_is(k, "enum") { k -= 1 }
                return k >= 0 && (tok_is(k, "struct") || tok_is(k, "union") || tok_is(k, "enum"))
            }
            depth -= 1
        }
        j -= 1
    }
    return false
}

var lex_start:int64 = 0 - 1   // where the token being read starts, kelvinc's pos of a lexer's error (#682)

// an error of the lexer at line of file: at the token being read, as
// kelvinc's error_at(pos, ...) says it, where that token is on the line
let lex_error(file:int64, line:int64, what:cstr) {
    if lex_start >= 0 && file >= 0 && file < codes_from.count as int64 && lex_start >= codes_from[file] && lex_start < codes_to[file] && line_of(file, lex_start) == line {
        lex_error_at(file, lex_start, what)               // (#682)
        return
    }
    let said:String = as_shown(what)
    println(fnames[file], ":", line, ": error: ", said)
    failed = true
}

// the line of code i of file (#682)
let line_of(file:int64, i:int64):int64 {
    var line:int64 = 1
    for k in codes_from[file]..<i {
        if codes[k] == '\n' { line += 1 }
    }
    return line
}

// an error at code i of file, as kelvinc's error_at says one: its line
// and column, 1 and the bytes of UTF-8 before it on its line (#681)
let lex_error_tok(t:int64, what:cstr) {
    let said:String = as_shown(what)
    let at:String = error_at_text(t)                     // file:line:col, as kelvinc's error_at (#682)
    println(at, ": error: ", said)
    failed = true
}

// an error at code i of file, as kelvinc's error_at says one: its line
// and column, 1 and the bytes of UTF-8 before it on its line (#681)
let lex_error_at(file:int64, i:int64, what:cstr) {
    let said:String = as_shown(what)
    var line:int64 = 1
    var col:int64 = 1
    if file >= 0 && file < codes_from.count as int64 {
        var k:int64 = codes_from[file]
        while k < i && k < codes_to[file] {
            let c:uint32 = codes[k]
            if c == '\n' {
                line += 1
                col = 1
            } else {
                col += c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
            }
            k += 1
        }
    }
    println(fnames[file], ":", line, ":", col, ": error: ", said)
    failed = true
}

// #inline C { ... } from i, after its word, as kelvinc's lex_inline_c
// reads it: its errors in kelvinc's words; kc writes no C of its own, so
// one that is right is refused after, as before
let inline_c_check(i0:int64, to:int64, file:int64, line:int64) {
    var i:int64 = i0
    while i < to && (codes[i] == ' ' || codes[i] == '\t') { i += 1 }
    if !(i < to && codes[i] == 'C' && !(is_alpha(code_at(i + 1)) || is_digit(code_at(i + 1)))) {
        lex_error_at(file, i, "expected 'C' after '#inline': #inline C { ... }")   // where it reads, as kelvinc's here (#682)
        return
    }
    i += 1
    while i < to && (codes[i] == ' ' || codes[i] == '\t') { i += 1 }
    if !(i < to && codes[i] == '{') {
        lex_error_at(file, i, "expected '{' after '#inline C', on the same line")
        return
    }
    i += 1
    var depth:int64 = 1
    var start = true                             // only blanks since the '{' or a new line
    while true {
        if i >= to {
            lex_error(file, line, "unterminated '#inline C {': it ends with the '}' that matches its '{'")
            return
        }
        let c:uint32 = codes[i]
        if c == '#' && start {
            var w:int64 = i + 1
            while w < to && (codes[w] == ' ' || codes[w] == '\t') { w += 1 }
            var n:int64 = 0
            while w + n < to && is_alpha(codes[w + n]) { n += 1 }
            var word = $""
            for q in 0..<n { word += codes[w + q] }
            var m = $"'#"
            m += &word
            if word == "import" || word == "inline" {
                m += "' does not nest in '#inline C': Kelvin's directives stand at the top level, or among a function's statements (#296)"
            } else {
                m += "' in '#inline C' is C's preprocessor, which Kelvin leaves out (#296): import a header with '#import <x.h> as C' outside it, and write a constant as an enum's or a Kelvin let"
            }
            lex_error_at(file, i, m.cstr)                // at its '#', as kelvinc's (#681)
            return
        }
        if c == '\n' {
            start = true
        } else if c != ' ' && c != '\t' && c != '\r' && !(c == '/' && (code_at(i + 1) == '/' || code_at(i + 1) == '*')) {
            start = false
        }
        if c == '/' && code_at(i + 1) == '/' {
            while i < to && codes[i] != '\n' { i += 1 }
            continue
        }
        if c == '/' && code_at(i + 1) == '*' {
            i += 2
            while i < to && !(codes[i] == '*' && code_at(i + 1) == '/') { i += 1 }
            i += 2
            continue
        }
        if c == '"' || c == '\'' {
            i += 1
            while i < to && codes[i] != c && codes[i] != '\n' {
                if codes[i] == '\\' { i += 1 }
                i += 1
            }
            i += 1
            continue
        }
        if c == '{' { depth += 1 }
        if c == '}' {
            depth -= 1
            if depth == 0 { break }
        }
        if c == '?' && code_at(i + 1) == '?' {
            lex_error_at(file, i, "'??' in '#inline C' is a trigraph of C, which Kelvin does not have (#220): write what it stands for")
            return
        }
        i += 1
    }
    i += 1
    while i < to && (codes[i] == ' ' || codes[i] == '\t' || codes[i] == '\r') { i += 1 }
    if i < to && codes[i] != '\n' && !(codes[i] == '/' && code_at(i + 1) == '/') {
        lex_error_at(file, i, "unexpected text after the '}' of '#inline C'")
    }
}

// ---------- #if os(...) (#643), as kelvinc's lexer reads it ----------

// the directive's word at w: 1 if, 2 elseif, 3 else, 4 endif, 0 another
let cond_word_at(w:int64):int64 {
    let words:$[cstr] = $["if", "elseif", "else", "endif"]
    for k in 0..<4 {
        let x:cstr := words[k]
        var n:int64 = 0
        var same = true
        while x[n] != 0 {
            if code_at(w + n) != x[n] as uint32 { same = false }
            n += 1
        }
        if same && !(is_alpha(code_at(w + n)) || is_digit(code_at(w + n)) || code_at(w + n) == '_') { return k + 1 }
    }
    return 0
}

// the newlines from a to b
let lines_in(a:int64, b:int64):int64 {
    var n:int64 = 0
    for k in a..<b {
        if codes[k] == '\n' { n += 1 }
    }
    return n
}

// past a branch not taken, from i: the # of the #elseif, #else or #endif
// that ends it, an #if in it counted; to, where there is none
let cond_skip(i0:int64, to:int64):int64 {
    var i:int64 = i0
    var depth:int64 = 0
    while i < to {
        while i < to && codes[i] != '\n' { i += 1 }
        if i >= to { return to }
        i += 1
        var k:int64 = i
        while k < to && (codes[k] == ' ' || codes[k] == '\t') { k += 1 }
        if k < to && codes[k] == '#' {
            var w:int64 = k + 1
            while w < to && (codes[w] == ' ' || codes[w] == '\t') { w += 1 }
            let cw:int64 = cond_word_at(w)
            if cw == 1 { depth += 1 }
            if cw > 1 && depth == 0 { return k }
            if cw == 4 { depth -= 1 }
        }
    }
    return to
}

var cond_at:int64 = 0          // where cond_value reads
var cond_end:int64 = 0
var cond_file:int64 = 0
var cond_line:int64 = 0

let cond_blanks() {
    while cond_at < cond_end && (codes[cond_at] == ' ' || codes[cond_at] == '\t' || codes[cond_at] == '\r') { cond_at += 1 }
}

let cond_or():bool    // a prototype: a factor in parentheses is one

let cond_factor():bool {
    cond_blanks()
    if cond_at < cond_end && codes[cond_at] == '!' {
        cond_at += 1
        return !cond_factor()
    }
    if cond_at < cond_end && codes[cond_at] == '(' {
        cond_at += 1
        let v = cond_or()
        cond_blanks()
        if !(cond_at < cond_end && codes[cond_at] == ')') { lex_error_at(cond_file, cond_at, "expected ')' in the condition of '#if'") }
        cond_at += 1
        return v
    }
    let os_at:int64 = cond_at                            // kelvinc's at, of these errors (#682)
    if !(code_at(cond_at) == 'o' && code_at(cond_at + 1) == 's' && !is_alpha(code_at(cond_at + 2))) {
        lex_error_at(cond_file, os_at, "a condition of '#if' is os(name), as in '#if os(macOS)', with !, && and || (#643)")
        return false
    }
    cond_at += 2
    cond_blanks()
    if !(cond_at < cond_end && codes[cond_at] == '(') {
        lex_error_at(cond_file, cond_at, "expected '(' after 'os', as in 'os(Linux)'")
        return false
    }
    cond_at += 1
    cond_blanks()
    var name = $""
    var lower = $""
    while cond_at < cond_end && (is_alpha(codes[cond_at]) || is_digit(codes[cond_at]) || codes[cond_at] == '_') {
        let c:uint32 = codes[cond_at]
        name += c
        lower += c >= 'A' && c <= 'Z' ? c + 32 : c
        cond_at += 1
    }
    if !(name == "macOS" || name == "Linux" || name == "FreeBSD" || name == "Windows") {
        var m = $"os("
        m += &name
        m += "): an os is macOS, Linux, FreeBSD or Windows (#643)"
        lex_error_at(cond_file, os_at, m.cstr)
        return false
    }
    cond_blanks()
    if !(cond_at < cond_end && codes[cond_at] == ')') { lex_error_at(cond_file, cond_at, "expected ')' after the name of the os") }
    cond_at += 1
    var host = $""
    host += SYS.platform
    return lower == host
}

let cond_and():bool {
    var v = cond_factor()
    while true {
        cond_blanks()
        if !(code_at(cond_at) == '&' && code_at(cond_at + 1) == '&') { return v }
        cond_at += 2
        let w = cond_factor()
        v = v && w
    }
    return v
}

let cond_or():bool {
    var v = cond_and()
    while true {
        cond_blanks()
        if !(code_at(cond_at) == '|' && code_at(cond_at + 1) == '|') { return v }
        cond_at += 2
        let w = cond_and()
        v = v || w
    }
    return v
}

// the condition of #if or #elseif from a to the line's end b
let cond_value(a:int64, b:int64, file:int64, line:int64):bool {
    cond_at = a
    cond_end = b
    cond_file = file
    cond_line = line
    let v = cond_or()
    cond_blanks()
    if cond_at < cond_end && !(codes[cond_at] == '/' && code_at(cond_at + 1) == '/') { lex_error(file, line, "unexpected text after the condition of '#if'") }
    return v
}

// the punctuators of two or three characters, longest first
let punct_len(i:int64):int64 {
    let c:uint32 = code_at(i)
    let d:uint32 = code_at(i + 1)
    if c == '.' && d == '.' && code_at(i + 2) == '<' { return 3 }
    if c == '.' && d == '.' && code_at(i + 2) == '.' { return 3 }      // ... of a range (#373)
    if c == '$' && (d == '[' || d == '{') { return 2 }    // $[ of an Array, ${:} of a Dictionary (#211)
    if c == '*' && d == '*' && code_at(i + 2) == '=' { return 3 }      // **= (#380)
    if c == '*' && d == '*' { return 2 }                   // ** of a power (#380)
    if (c == '<' || c == '>') && d == c && code_at(i + 2) == '=' { return 3 }   // <<= and >>= (#387)
    if (c == '<' || c == '>') && d == c { return 2 }       // << and >>, a type's >> closed by close_angle
    if (c == '=' || c == '!' || c == '<' || c == '>' || c == '+' || c == '-' || c == '*' || c == '/' || c == '%' || c == '|' || c == '&' || c == '~') && d == '=' { return 2 }   // |= &= ~= (#276)
    if c == '&' && d == '&' { return 2 }
    if (c == '+' || c == '-') && d == c { return 2 }       // p++ and p-- (#459)
    if (c == '?' || c == '!') && d == c && code_at(i + 2) == '=' { return 3 }   // ??= and !!= (#460)
    if c == '!' && d == '!' { return 2 }                   // !! (#460), of !!n (#387) too
    if c == '?' && d == '?' { return 2 }                   // ?? (#217)
    if c == ':' && d == '=' { return 2 }
    if c == '|' && d == '|' { return 2 }
    return 1
}

// a template's text from i (after its backquote, or after the } that ends
// a ${...}) up to its closing backquote or the next ${, as kelvinc's
// lex_template (#445): a token of its text as C's string literal, put
// after the files' codes; a new line is \n, \` a backquote, \$ a dollar
// sign, \{ and \} a brace, a backslash before a new line joins the lines,
// and other escapes are C's. head is whether it begins the template, and
// dollar whether that is $`...`, a String, whose $ is the token before;
// where it ends, after the ` or the ${, or -1 where it is unterminated
let lex_template(i:int64, to:int64, file:int64, line:int64, head:bool, dollar:bool):int64 {
    var at:int64 = codes.count as int64
    if dollar { codes += '$' }                   // $`text` is $"text" (#67), a T_DSTR
    codes += '"'
    var k:int64 = i
    var ends = 0                                 // 1 at its backquote, 2 at a ${
    while k < to && ends == 0 {
        let c:uint32 = codes[k]
        let d:uint32 = code_at(k + 1)
        if c == '`' {
            ends = 1
            k += 1
        } else if c == '$' && d == '{' {
            ends = 2
            k += 2
        } else if c == '\\' && (d == '`' || d == '$' || d == '{' || d == '}') {
            codes += d
            k += 2
        } else if c == '\\' && d == '\n' {
            k += 2
        } else if c == '\\' && d == '\r' && code_at(k + 2) == '\n' {
            k += 3
        } else if c == '\\' && k + 1 < to {
            codes += c
            codes += d
            k += 2
        } else if c == '"' {
            codes += '\\'
            codes += '"'
            k += 1
        } else if c == '\n' || (c == '\r' && d == '\n') {   // a CRLF line end is a new line
            codes += '\\'
            codes += 'n'
            k += c == '\r' ? 2 : 1
        } else if c == '\r' {
            codes += '\\'
            codes += 'r'
            k += 1
        } else {
            codes += c
            k += 1
        }
    }
    if ends == 0 {
        lex_error(file, line, "unterminated template literal: it ends with a backquote")
        return to
    }
    codes += '"'
    var kind:tkind = ends == 1 ? (head ? T_TPL : T_TPL_TAIL) : (head ? T_TPL_HEAD : T_TPL_MID)
    if dollar && kind == T_TPL {
        toks.pop()                               // the $ before it
        kind = T_DSTR
    } else if dollar {
        at += 1                                  // its $ is a token of its own
    }
    add_tok(kind, at, codes.count as int64 - at, line, file)
    return k
}

// the tokens of codes[from..<to], the text of file; returns where an
// #import of a Kelvin file begins its own, or -1
let lex_range(from:int64, to:int64, file:int64) {
    var i:int64 = from
    var line = 1
    var depth:int64 = 0              // ( and [ open
    var outer:$[int64] = $[]         // the depth each open { was written at: a body inside parentheses has its lines (#326)
    var tpls:$[int64] = $[]          // the count of outer at each open ${ of a template (#445)
    var tpl_at:$[int64] = $[]        // where each open ${ is, for an error there (#681)
    var conds:$[int64] = $[]         // the lines of the #if open (#643)
    while i < to && !failed {
        let c:uint32 = codes[i]
        lex_start = i                                    // (#682)
        if c == '\n' {
            if depth == 0 && toks.count > 0 && toks[toks.count as int64 - 1].kind != T_NL {
                add_tok(T_NL, i, 1, line, file)
            }
            line += 1
            i += 1
        } else if c == ' ' || c == '\t' || c == '\r' {
            i += 1
        } else if c == '/' && code_at(i + 1) == '/' {
            while i < to && codes[i] != '\n' { i += 1 }
        } else if c == '/' && code_at(i + 1) == '*' {
            i += 2
            while i < to && !(codes[i] == '*' && code_at(i + 1) == '/') {
                if codes[i] == '\n' { line += 1 }
                i += 1
            }
            i += 2
        } else if c == '$' && code_at(i + 1) == '/' {        // $/pattern/flags, the prelude's RegExp (#157, #515)
            i = lex_regexp(i, to, line, file)
        } else if c == '$' && is_digit(code_at(i + 1)) {     // $0, an anonymous function's parameter (#324)
            let s:int64 = i
            i += 1
            while i < to && is_digit(codes[i]) { i += 1 }
            add_tok(T_ID, s, i - s, line, file)
        } else if name_start(c) {                        // a name, of Unicode's letters and emoji too (#385)
            let s:int64 = i
            while i < to && name_continue(codes[i]) { i += 1 }
            let q:uint32 = code_at(i)
            let one = i - s == 1 && (codes[s] == 'L' || codes[s] == 'u' || codes[s] == 'U')
            let wide8 = i - s == 2 && codes[s] == 'u' && codes[s + 1] == '8'
            if (q == '"' || q == '\'') && (one || wide8) {       // C's prefix, as kelvinc refuses it (#295, #298)
                var m = $""
                for k in s..<i { m += codes[k] }
                m += q
                m += "..."
                m += q
                m += " is C's prefixed literal: a Kelvin source is UTF-8, and a literal's one prefix is $, a String's, $\"...\" (#295)"
                lex_error(file, line, m.cstr)
            }
            add_tok(T_ID, s, i - s, line, file)
            if tok_is(toks.count as int64 - 1, "uchr") {       // removed (#528): a codepoint is a u32 (#527), as kelvinc says it
                lex_error(file, line, "uchr is no more (#528): a codepoint is a u32, as s.codepoints[0] gives it; s += n appends one, and grapheme(n) is a String of it")
            }
            if tok_is(toks.count as int64 - 1, "Bits") {       // removed (#532): an integer's and a BigInt's bits are .bits (#530, #531), as kelvinc says it
                lex_error(file, line, "Bits is no more (#532): an integer's bits are x.bits, an Array<bool>, and x.bits[n] its bit n; a BigInt's are b.bits, of any width; and bools that grow are an Array<bool>")
            }
            let hint:cstr := foreign_hint(toks.count as int64 - 1)   // a C compiler's keyword, as kelvinc says it (#612)
            if hint != nowhere {
                var m = $"'"
                m += tok_text(toks.count as int64 - 1)
                if hint[0] != 0 {
                    m += "' is a C compiler keyword; use "
                    m += hint
                } else {
                    m += "' is a C compiler keyword, not available in Kelvin"
                }
                lex_error(file, line, m.cstr)
            }
            if tok_is(toks.count as int64 - 1, "_Complex") {   // C99's, left out on purpose (#404), as kelvinc says it
                lex_error(file, line, "'_Complex' is C99's complex type, left out on purpose: #import <math> and write c64 or c32, Kelvin's own")
            }
        } else if is_digit(c) {
            let s:int64 = i
            let hex = c == '0' && (code_at(i + 1) == 'x' || code_at(i + 1) == 'X')
            var more = true
            while more {
                while i < to && (is_digit(codes[i]) || is_alpha(codes[i])) { i += 1 }
                more = false
                let d:uint32 = code_at(i)
                if !hex && d == '.' && is_digit(code_at(i + 1)) {       // 1.5, not 0..<n (#262)
                    i += 1
                    more = true
                } else if !hex && (d == '+' || d == '-') && (code_at(i - 1) == 'e' || code_at(i - 1) == 'E') && (is_digit(code_at(i + 1)) || code_at(i + 1) == '_') {
                    i += 1                                              // 2.5e-8
                    more = true
                } else if hex && d == '.' && hex_fraction(i + 1) {      // 0x1.8p1, 0x1.p3, not 0xff.cstr (#556)
                    i += 1
                    more = true
                } else if hex && (d == '+' || d == '-') && (code_at(i - 1) == 'p' || code_at(i - 1) == 'P') && (is_digit(code_at(i + 1)) || code_at(i + 1) == '_') {
                    i += 1                                              // 0x1p-1074, a hex float's exponent (#556)
                    more = true
                }
            }
            var b:int64 = s                                     // the number without its _ (#671)
            var f:int64 = i
            for q in s..<i {
                if codes[q] == '_' && b == s {
                    b = without_separators(s, i, line, file)
                    f = codes.count as int64
                }
            }
            if b < 0 {
                // the error said
            } else if f - b >= 2 && codes[f - 1] == 'n' && big_literal(b, f - 1, s, i, line, file) {
                // 123n, the prelude's BigInt (#508, #515)
            } else if codes[b] == '0' && f - b > 1 && (codes[b + 1] == 'o' || codes[b + 1] == 'O') {
                octal_literal(b, f, s, i, line, file)                   // 0o52 (#562)
            } else {
                check_number(b, f, s, i, line, file)                    // 10UL, 12ab (#612)
                add_tok(T_NUM, b, f - b, line, file)
            }
        } else if c == '`' || (c == '$' && code_at(i + 1) == '`') || (c == '}' && tpls.count > 0 && tpls[tpls.count as int64 - 1] == outer.count as int64 - 1) {
            let head = c != '}'                  // a template, `a${x}b`, or the } that ends its ${...} (#445)
            if c == '}' {
                depth = outer.pop()
                tpls.pop()
                tpl_at.pop()
            }
            if c == '$' {
                add_tok(T_PUNCT, i, 1, line, file)
                i += 1
            }
            let s:int64 = i + 1
            i = lex_template(s, to, file, line, head, c == '$')
            if !failed {                         // its place in the file: its ` or the } of a ${...}, $` of a $`...` (#682)
                let tl:int64 = toks.count as int64 - 1
                toks[tl].src = toks[tl].kind == T_DSTR ? s - 2 : s - 1
            }
            for k in s..<i {
                if codes[k] == '\n' { line += 1 }
            }
            let last:tkind = toks[toks.count as int64 - 1].kind
            if !failed && (last == T_TPL_HEAD || last == T_TPL_MID) {   // a ${, as a ( : no new line ends a statement in it
                tpls += outer.count as int64
                tpl_at += i - 2                  // its $, before the { (#681)
                outer += depth
                depth = 1
            }
        } else if (c == '"' && code_at(i + 1) == '"' && code_at(i + 2) == '"') || (c == '$' && code_at(i + 1) == '"' && code_at(i + 2) == '"' && code_at(i + 3) == '"') {
            let s:int64 = i                      // """text""", $"""text""" (#115, #516)
            i = lex_triple(c == '$' ? i + 1 : i, to, line, file, c == '$')
            for k in s..<i {
                if codes[k] == '\n' { line += 1 }
            }
        } else if c == '"' || (c == '$' && code_at(i + 1) == '"') {
            let s:int64 = i
            var kind:tkind = T_STR
            if c == '$' {
                kind = T_DSTR
                i += 1
            }
            i += 1
            while i < to && codes[i] != '"' {
                if codes[i] == '\\' { i += 1 }
                if codes[i] == '\n' { lex_error(file, line, "a string ends on its line") }
                i += 1
            }
            i += 1
            add_tok(kind, s, i - s, line, file)
        } else if c == '\'' {
            let s:int64 = i
            i += 1
            while i < to && codes[i] != '\'' && codes[i] != '\n' {   // up to its ', '\x6b' too (#459)
                if codes[i] == '\\' { i += 1 }
                i += 1
            }
            i += 1
            add_tok(T_CHAR, s, i - s, line, file)
        } else if c == '#' {
            let s:int64 = i
            while i < to && codes[i] != '\n' { i += 1 }
            var a:int64 = s
            while a < i && codes[a] != '<' && codes[a] != '"' { a += 1 }
            var b:int64 = i
            while b > a && codes[b - 1] != '>' && codes[b - 1] != '"' { b -= 1 }
            var w:int64 = s + 1
            while w < i && (codes[w] == ' ' || codes[w] == '\t') { w += 1 }
            let cw:int64 = cond_word_at(w)               // #if os(...), #elseif, #else, #endif (#643)
            if cw > 0 {
                if cw == 1 {
                    conds += line
                    var take = cond_value(w + 2, i, file, line)
                    while !take && !failed {
                        let k:int64 = cond_skip(i, to)
                        line += lines_in(i, k)
                        i = k
                        if k >= to {
                            lex_error(file, conds[conds.count - 1], "'#if' has no '#endif'")
                            break
                        }
                        var e:int64 = k
                        while e < to && codes[e] != '\n' { e += 1 }
                        var kw:int64 = k + 1
                        while kw < e && (codes[kw] == ' ' || codes[kw] == '\t') { kw += 1 }
                        let ww:int64 = cond_word_at(kw)
                        i = e
                        if ww == 2 {
                            take = cond_value(kw + 6, e, file, line)
                        } else if ww == 3 {
                            take = true
                        } else {
                            conds.pop()
                            take = true
                        }
                    }
                } else if cw == 4 {
                    if conds.count == 0 { lex_error(file, line, "'#endif' has no '#if' before it") } else { conds.pop() }
                } else {                                     // the end of a branch read: the rest to #endif are not
                    if conds.count == 0 {
                        lex_error(file, line, cw == 2 ? "'#elseif' has no '#if' before it" : "'#else' has no '#if' before it")
                    }
                    while !failed && conds.count > 0 {
                        let k:int64 = cond_skip(i, to)
                        line += lines_in(i, k)
                        i = k
                        if k >= to {
                            lex_error(file, conds[conds.count - 1], "'#if' has no '#endif'")
                            break
                        }
                        var e:int64 = k
                        while e < to && codes[e] != '\n' { e += 1 }
                        var kw:int64 = k + 1
                        while kw < e && (codes[kw] == ' ' || codes[kw] == '\t') { kw += 1 }
                        i = e
                        if cond_word_at(kw) == 4 {
                            conds.pop()
                            break
                        }
                    }
                }
                continue
            }
            let imports = w + 6 <= i && codes[w] == 'i' && codes[w + 1] == 'm' && codes[w + 2] == 'p' && codes[w + 3] == 'o' && codes[w + 4] == 'r' && codes[w + 5] == 't' && !(is_alpha(code_at(w + 6)) || is_digit(code_at(w + 6)))
            let inlines = w + 6 <= i && codes[w] == 'i' && codes[w + 1] == 'n' && codes[w + 2] == 'l' && codes[w + 3] == 'i' && codes[w + 4] == 'n' && codes[w + 5] == 'e'
            if inlines && !imports && in_record_body() { // as kelvinc says it (#653)
                lex_error(file, line, "#inline C is for the top level of a file and a function's blocks, outside structs, unions and enums")
                continue
            }
            if inlines && !imports {                     // #inline C { ... }, kelvinc's words of what is wrong in it (#629)
                inline_c_check(w + 6, to, file, line)
            }
            if !imports && !inlines {                    // #include, #define: as kelvinc says it (#296, #612)
                lex_error(file, line, "only '#import <header.h> as C', '#inline C { ... }' and '#if os(...)' are supported; C's preprocessor Kelvin leaves out (#296)")
            } else if a >= b {
                lex_error(file, line, "only #import <x>, #import \"x.k\" and #import <x.h> as C are known")
            }
            if a < b && imports {                        // a Kelvin file's line ends at its name, as kelvinc says it (#40, #611)
                var dot = false
                for j in a + 1..<b - 1 {
                    if codes[j] == '.' { dot = true }
                }
                let kelvin = !dot || (b - a > 4 && codes[b - 3] == '.' && codes[b - 2] == 'k') || (b - a > 5 && codes[b - 4] == '.' && codes[b - 3] == 'k' && codes[b - 2] == 'h')
                var r:int64 = b
                while r < i && (codes[r] == ' ' || codes[r] == '\t' || codes[r] == '\r') { r += 1 }
                let ended = r >= i || (codes[r] == '/' && r + 1 < i && codes[r + 1] == '/')
                if kelvin && !ended {
                    var name = $""
                    for j in a..<b { name += codes[j] }
                    var m = $""
                    let as_c = r + 2 <= i && codes[r] == 'a' && codes[r + 1] == 's' && (r + 2 == i || !(is_alpha(codes[r + 2]) || is_digit(codes[r + 2])))
                    if as_c {
                        m = $"a Kelvin file is imported as it is: write '#import "
                        m += &name
                        m += "' without 'as C'"
                    } else {
                        m = $"unexpected text after '#import "
                        m += &name
                        m += "'"
                    }
                    if as_c { lex_error(file, line, m.cstr) } else { lex_error_at(file, r, m.cstr) }   // the rest where it reads, as kelvinc's here (#682)
                }
                if !kelvin && !failed {                  // a C header's line is its name and 'as C', as kelvinc says it (#612)
                    var q:int64 = r
                    let has_as = q + 2 <= i && codes[q] == 'a' && codes[q + 1] == 's' && !(is_alpha(code_at(q + 2)) || is_digit(code_at(q + 2)))
                    if has_as {
                        q += 2
                        while q < i && (codes[q] == ' ' || codes[q] == '\t') { q += 1 }
                    }
                    let has_c = has_as && q < i && codes[q] == 'C' && !(is_alpha(code_at(q + 1)) || is_digit(code_at(q + 1)))
                    if has_c {
                        q += 1
                        while q < i && (codes[q] == ' ' || codes[q] == '\t' || codes[q] == '\r') { q += 1 }
                    }
                    var trigraph = false
                    for j in a..<b - 1 {
                        if codes[j] == '?' && codes[j + 1] == '?' { trigraph = true }
                    }
                    if !has_as {
                        lex_error_at(file, r, "expected 'as C' after the header name")   // where it reads, as kelvinc's here (#682)
                    } else if !has_c {
                        lex_error_at(file, q, "only 'as C' is supported")
                    } else if q < i && !(codes[q] == '/' && code_at(q + 1) == '/') {
                        lex_error_at(file, q, "unexpected text after '#import ... as C'")
                    } else if trigraph {
                        lex_error(file, line, "a header name with '??' is a trigraph of C, which Kelvin does not have (#220)")
                    }
                }
            }
            add_tok(T_IMPORT, a, b - a, line, file)
        } else if c >= 128 {                             // as kelvinc says it (#385)
            var m = $"'"
            m += c
            m += "' (U+"
            let h:String = hex4(c)
            m += &h
            m += ") is neither an operator nor in a name: a name holds letters, digits, _ and emoji"
            lex_error(file, line, m.cstr)
        } else {
            let n:int64 = punct_len(i)
            if c == '(' || c == '[' { depth += 1 }
            if c == '$' && code_at(i + 1) == '[' { depth += 1 }
            if c == ')' || c == ']' { depth -= 1 }
            if c == '{' || (c == '$' && code_at(i + 1) == '{') {
                outer += depth
                depth = 0
            }
            if c == '}' && outer.count > 0 { depth = outer.pop() }
            add_tok(T_PUNCT, i, n, line, file)
            i += n
        }
    }
    if tpls.count > 0 && !failed {
        lex_error_at(file, tpl_at[tpl_at.count as int64 - 1], "unterminated ${...} in a template literal: it ends with '}'")
    }
}
