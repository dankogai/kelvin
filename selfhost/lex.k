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
}

var codes:$[uint32]       // every file's text
var toks:$[tok]
var fnames:$[String]      // every file's name
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
        s += codes[at + i].uchr
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
        s += digits[(c / p) % 16].uchr
        p = p / 16
    }
    return s
}

let add_tok(kind:tkind, at:int64, len:int64, line:int64, file:int64) {
    let t:tok = {kind, at, len, line, file}
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

var big_lits:$[int64]     // the BigInt token of each 123n, which names the prelude's BigInt (#508, #515)
var rx_lits:$[int64]      // the RegExp token of each $/.../, the prelude's RegExp (#157, #515)

// 123n, 0xffn, 0b101n from s up to the n at e (#508), as kelvinc's
// big_literal: BigInt("123", 10), the prelude's; false where the text
// before the n is no integer, which is then a number's error
let big_literal(s:int64, e:int64, line:int64, file:int64):bool {
    var base = 10
    var d:int64 = s
    if e - s > 2 && codes[s] == '0' && (codes[s + 1] == 'x' || codes[s + 1] == 'X' || codes[s + 1] == 'b' || codes[s + 1] == 'B') {
        base = codes[s + 1] == 'x' || codes[s + 1] == 'X' ? 16 : 2
        d = s + 2
    }
    if d == e { return false }
    for q in d..<e {
        let c:uint32 = codes[q]
        let hexd = is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
        if base == 16 && !hexd { return false }
        if base == 2 && c != '0' && c != '1' { return false }
        if base == 10 && !is_digit(c) { return false }
    }
    if base == 10 && e - s > 1 && codes[s] == '0' {
        var m = $"'"
        for q in s..<e { m += codes[q].uchr }
        m += "n': a BigInt literal is decimal, 0x hex or 0b binary, with no leading 0: C's octal is none of them"
        lex_error(file, line, m.cstr)
        return true
    }
    add_made(T_ID, "BigInt", line, file)
    big_lits += toks.count as int64 - 1
    add_made(T_PUNCT, "(", line, file)
    let at:int64 = codes.count as int64
    codes += '"'
    for q in d..<e { codes += codes[q] }
    codes += '"'
    add_tok(T_STR, at, codes.count as int64 - at, line, file)
    add_made(T_PUNCT, ",", line, file)
    add_made(T_NUM, base == 16 ? "16" : base == 2 ? "2" : "10", line, file)
    add_made(T_PUNCT, ")", line, file)
    return true
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

let lex_error(file:int64, line:int64, what:cstr) {
    println(fnames[file], ":", line, ": error: ", what)
    failed = true
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
    while i < to && !failed {
        let c:uint32 = codes[i]
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
                for k in s..<i { m += codes[k].uchr }
                m += q.uchr
                m += "..."
                m += q.uchr
                m += " is C's prefixed literal: a Kelvin source is UTF-8, and a literal's one prefix is $, a String's, $\"...\" (#295)"
                lex_error(file, line, m.cstr)
            }
            add_tok(T_ID, s, i - s, line, file)
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
                } else if !hex && (d == '+' || d == '-') && (code_at(i - 1) == 'e' || code_at(i - 1) == 'E') && is_digit(code_at(i + 1)) {
                    i += 1                                              // 2.5e-8
                    more = true
                }
            }
            if !(i - s >= 2 && codes[i - 1] == 'n' && big_literal(s, i - 1, line, file)) {   // 123n, the prelude's BigInt (#508, #515)
                add_tok(T_NUM, s, i - s, line, file)
            }
        } else if c == '`' || (c == '$' && code_at(i + 1) == '`') || (c == '}' && tpls.count > 0 && tpls[tpls.count as int64 - 1] == outer.count as int64 - 1) {
            let head = c != '}'                  // a template, `a${x}b`, or the } that ends its ${...} (#445)
            if c == '}' {
                depth = outer.pop()
                tpls.pop()
            }
            if c == '$' {
                add_tok(T_PUNCT, i, 1, line, file)
                i += 1
            }
            let s:int64 = i + 1
            i = lex_template(s, to, file, line, head, c == '$')
            for k in s..<i {
                if codes[k] == '\n' { line += 1 }
            }
            let last:tkind = toks[toks.count as int64 - 1].kind
            if !failed && (last == T_TPL_HEAD || last == T_TPL_MID) {   // a ${, as a ( : no new line ends a statement in it
                tpls += outer.count as int64
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
            if a >= b { lex_error(file, line, "only #import <x>, #import \"x.k\" and #import <x.h> as C are known") }
            add_tok(T_IMPORT, a, b - a, line, file)
        } else if c >= 128 {                             // as kelvinc says it (#385)
            var m = $"'"
            m += c.uchr
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
        lex_error(file, line, "unterminated ${...} in a template literal: it ends with '}'")
    }
}
