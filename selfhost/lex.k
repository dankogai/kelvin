// lex.k - the tokens of the source, for kc (selfhost/kc.k).
// Every file's codepoints go into one Array, `codes`; a token is where
// its text is there, how long, its line and its file. A newline is a
// token where it may end a statement: outside ( ) and [ ].

struct tok {
    kind: int64
    at: int64
    len: int64
    line: int64
    file: int64
}

let T_EOF:int64 = 0
let T_NL:int64 = 1
let T_ID:int64 = 2
let T_NUM:int64 = 3
let T_STR:int64 = 4       // "...", as written
let T_CHAR:int64 = 5      // '.', as written
let T_PUNCT:int64 = 6
let T_DSTR:int64 = 7      // $"...", the text from its "
let T_IMPORT:int64 = 8    // #import <x> or "x.k", the name with its brackets

var codes:$[uint32]       // every file's text
var toks:$[tok]
var fnames:$[String]      // every file's name
var failed:bool

let code_at(i:int64):uint32 {
    if i < codes.count as int64 { return codes[i] }
    return 0
}

// the text of token t is w
let tok_is(t:int64, w:cstr):bool {
    let at:int64 = toks[t].at
    let n:int64 = toks[t].len
    var i:int64 = 0
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
    var i:int64 = 0
    while i < n {
        if codes[toks[a].at + i] != codes[toks[b].at + i] { return false }
        i += 1
    }
    return true
}

let is_alpha(c:uint32):bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

let is_digit(c:uint32):bool {
    return c >= '0' && c <= '9'
}

let add_tok(kind:int64, at:int64, len:int64, line:int64, file:int64) {
    let t:tok = {kind, at, len, line, file}
    toks += t
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
    if c == '$' && d == '[' { return 2 }
    if (c == '=' || c == '!' || c == '<' || c == '>' || c == '+' || c == '-' || c == '*' || c == '/' || c == '%') && d == '=' { return 2 }
    if c == '&' && d == '&' { return 2 }
    if c == '|' && d == '|' { return 2 }
    return 1
}

// the tokens of codes[from..<to], the text of file; returns where an
// #import of a Kelvin file begins its own, or -1
let lex_range(from:int64, to:int64, file:int64) {
    var i:int64 = from
    var line:int64 = 1
    var depth:int64 = 0              // ( and [ open
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
        } else if is_alpha(c) {
            let s:int64 = i
            while i < to && (is_alpha(codes[i]) || is_digit(codes[i])) { i += 1 }
            add_tok(T_ID, s, i - s, line, file)
        } else if is_digit(c) {
            let s:int64 = i
            while i < to && (is_digit(codes[i]) || is_alpha(codes[i])) { i += 1 }
            add_tok(T_NUM, s, i - s, line, file)
        } else if c == '"' || (c == '$' && code_at(i + 1) == '"') {
            let s:int64 = i
            var kind:int64 = T_STR
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
            if codes[i] == '\\' { i += 1 }
            i += 2
            add_tok(T_CHAR, s, i - s, line, file)
        } else if c == '#' {
            let s:int64 = i
            while i < to && codes[i] != '\n' { i += 1 }
            var a:int64 = s
            while a < i && codes[a] != '<' && codes[a] != '"' { a += 1 }
            var b:int64 = i
            while b > a && codes[b - 1] != '>' && codes[b - 1] != '"' { b -= 1 }
            if a >= b { lex_error(file, line, "only #import <x> and #import \"x.k\" are known") }
            add_tok(T_IMPORT, a, b - a, line, file)
        } else {
            let n:int64 = punct_len(i)
            if c == '(' || c == '[' { depth += 1 }
            if c == '$' && n == 2 { depth += 1 }
            if c == ')' || c == ']' { depth -= 1 }
            add_tok(T_PUNCT, i, n, line, file)
            i += n
        }
    }
}
