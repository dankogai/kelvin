// parse.k - the tree of the program, for kc (selfhost/kc.k).
// A node is an element of `nodes`, its children by index, a list by
// `next`; a type is an element of `types`, made once. Every variable
// says its type, so nothing is inferred but what an expression gives.

enum nkind {                    // the kinds of nodes (#210)
    // expressions
    N_NUM,
    N_CHAR,
    N_STR,
    N_DSTR,
    N_BOOL,
    N_ID,
    N_CALL,     // a(b...)
    N_FIELD,    // a.t
    N_METHOD,   // a.t(b...)
    N_INDEX,    // a[b]
    N_UNARY,    // t a
    N_BIN,      // a t b
    N_CAST,     // a as ty
    N_ADDR,     // &a
    N_DEREF,    // a^
    N_EMPTY,    // $[]
    N_TYPE,     // IO or String called: a type's name as a function
    N_INIT,     // {b...}, a struct's members in order
    N_NULL,     // nullptr
    // statements
    S_VAR,      // t:ty = a
    S_ASSIGN,   // a t b, t an assignment's operator
    S_EXPR,
    S_IF,       // if a { b } else c
    S_WHILE,
    S_FOR,      // for t in a..<b { c }
    S_EACH,     // for t in a { c }
    S_RETURN,
    S_BREAK,
    S_CONTINUE,
    S_BLOCK,    // a, the first statement
    S_SWITCH,   // switch a { b, the first case }
    S_CASE,     // case a...: b...; flag 1 of default
    // declarations
    D_FN,       // t(a...):ty { b }, b -1 for a prototype
    D_STRUCT,   // t { a... }
    D_GLOBAL,   // as S_VAR
    D_IMPORT,
    D_ENUM      // enum t { a... }, each an N_ID, its a a value or -1
}

enum ykind {                    // the kinds of types (#210)
    Y_VOID,
    Y_I64,
    Y_I32,
    Y_U8,
    Y_U32,
    Y_BOOL,
    Y_CSTR,
    Y_STRING,
    Y_IO,
    Y_UCHR,
    Y_ARRAY,
    Y_STRUCT,
    Y_PTR,
    Y_ARGV,     // [cstr], main's argv
    Y_C         // what only C sees: a name of a C header (#207)
}

struct node {
    kind: nkind
    a: int64
    b: int64
    c: int64
    t: int64           // its token: a name, a literal, an operator
    ty: int64          // the type it declares
    next: int64        // the next of a list
    flag: int64        // a let (1) or a var (0); a #import of <IO> (1)
}

struct ty {
    kind: ykind
    elem: int64        // of an Array or a pointer
    name: int64        // the token of a struct's name
}

var nodes:$[node]
var types:$[ty]
var decls:$[int64]         // the top-level declarations, in order
var arrays:$[int64]        // every Array type, in the order they are met
var pos:int64              // the next token
var c_headers:bool         // whether a C header is imported: then a name kc does not know is C's (#207)

// whether token t names a C header: <x.h> or "x.h"
let is_header(t:int64):bool {
    let n:int64 = toks[t].len
    return n > 3 && codes[toks[t].at + n - 3] == '.' && codes[toks[t].at + n - 2] == 'h'
}

// ---------- types ----------

let type_of_kind(kind:ykind, elem:int64, name:int64):int64 {
    var i:int64 = 0
    while i < types.count as int64 {
        let y:ty = types[i]
        if y.kind == kind && y.elem == elem {
            if kind != Y_STRUCT { return i }
            if same_text(y.name, name) { return i }
        }
        i += 1
    }
    let y:ty = {kind, elem, name}
    types += y
    if kind == Y_ARRAY { arrays += types.count as int64 - 1 }
    return types.count as int64 - 1
}

let base_type(kind:ykind):int64 {
    return type_of_kind(kind, -1, -1)
}

// ---------- the cursor ----------

let at_kind(k:tkind):bool {
    return toks[pos].kind == k
}

let at_word(w:cstr):bool {
    let k:tkind = toks[pos].kind
    return (k == T_ID || k == T_PUNCT) && tok_is(pos, w)
}

let parse_error(what:cstr) {
    if !failed {
        let t:tok = toks[pos]
        println(fnames[t.file], ":", t.line, ": error: ", what)
    }
    failed = true
    pos = toks.count as int64 - 1       // the end: every loop stops
}

let advance():int64 {
    let t:int64 = pos
    if pos < toks.count as int64 - 1 { pos += 1 }
    return t
}

let expect(w:cstr) {
    if !at_word(w) {
        parse_error("unexpected token")
        return
    }
    advance()
}

let skip_newlines() {
    while at_kind(T_NL) { advance() }
}

// nodes[n].a = parse_expr() let C find nodes[n] before the parse grew
// nodes, and gcc did, writing where nodes was, until kelvinc made the
// value first (#205): a call takes its arguments first, so the children
// are set through these, which any kelvinc compiles right
let set_a(n:int64, v:int64) { nodes[n].a = v }
let set_b(n:int64, v:int64) { nodes[n].b = v }
let set_c(n:int64, v:int64) { nodes[n].c = v }
let set_ty(n:int64, v:int64) { nodes[n].ty = v }

let make_node(kind:nkind, t:int64):int64 {
    let n:node = {kind, -1, -1, -1, t, -1, -1, 0}
    nodes += n
    return nodes.count as int64 - 1
}

// ---------- types as written ----------

let parse_type():int64 {
    if at_word("$[") {
        advance()
        let elem:int64 = parse_type()
        expect("]")
        var y:int64 = type_of_kind(Y_ARRAY, elem, -1)
        while at_word("^") {
            advance()
            y = type_of_kind(Y_PTR, y, -1)
        }
        return y
    }
    if at_word("[") {
        advance()
        expect("cstr")
        expect("]")
        return base_type(Y_ARGV)
    }
    if !at_kind(T_ID) {
        parse_error("a type is expected")
        return base_type(Y_VOID)
    }
    let t:int64 = advance()
    var y:int64 = -1
    if tok_is(t, "int64") {
        y = base_type(Y_I64)
    } else if tok_is(t, "int32") {
        y = base_type(Y_I32)
    } else if tok_is(t, "uint8") {
        y = base_type(Y_U8)
    } else if tok_is(t, "uint32") {
        y = base_type(Y_U32)
    } else if tok_is(t, "bool") {
        y = base_type(Y_BOOL)
    } else if tok_is(t, "cstr") {
        y = base_type(Y_CSTR)
    } else if tok_is(t, "String") {
        y = base_type(Y_STRING)
    } else if tok_is(t, "IO") {
        y = base_type(Y_IO)
    } else if tok_is(t, "uchr") {
        y = base_type(Y_UCHR)
    } else {
        y = type_of_kind(Y_STRUCT, -1, t)
    }
    while at_word("^") {
        advance()
        y = type_of_kind(Y_PTR, y, -1)
    }
    return y
}

// ---------- expressions ----------

let parse_expr():int64    // a prototype: the parsers call each other

// the arguments of a call after its (, up to its ), as a list
let parse_args():int64 {
    var first:int64 = -1
    var last:int64 = -1
    while !at_word(")") && !failed {
        let e:int64 = parse_expr()
        if first < 0 {
            first = e
        } else {
            nodes[last].next = e
        }
        last = e
        if at_word(",") { advance() }
    }
    expect(")")
    return first
}

let parse_primary():int64 {
    let t:int64 = pos
    let k:tkind = toks[t].kind
    if k == T_NUM {
        advance()
        return make_node(N_NUM, t)
    }
    if k == T_CHAR {
        advance()
        return make_node(N_CHAR, t)
    }
    if k == T_STR {
        advance()
        return make_node(N_STR, t)
    }
    if k == T_DSTR {
        advance()
        return make_node(N_DSTR, t)
    }
    if at_word("(") {
        advance()
        let e:int64 = parse_expr()
        expect(")")
        return e
    }
    if at_word("$[") {
        advance()
        expect("]")
        return make_node(N_EMPTY, t)
    }
    if at_word("{") {
        advance()
        let n:int64 = make_node(N_INIT, t)
        var last:int64 = -1
        while !at_word("}") && !failed {
            let e:int64 = parse_expr()
            if last < 0 {
                nodes[n].b = e
            } else {
                nodes[last].next = e
            }
            last = e
            if at_word(",") { advance() }
        }
        expect("}")
        return n
    }
    if k == T_ID {
        advance()
        if tok_is(t, "true") || tok_is(t, "false") { return make_node(N_BOOL, t) }
        if tok_is(t, "nullptr") { return make_node(N_NULL, t) }
        if tok_is(t, "IO") || tok_is(t, "String") { return make_node(N_TYPE, t) }
        return make_node(N_ID, t)
    }
    parse_error("an expression is expected")
    return make_node(N_NUM, t)
}

let parse_postfix():int64 {
    var e:int64 = parse_primary()
    while !failed {
        if at_word("(") {
            let t:int64 = advance()
            let n:int64 = make_node(N_CALL, t)
            nodes[n].a = e
            set_b(n, parse_args())
            e = n
        } else if at_word("[") {
            let t:int64 = advance()
            let n:int64 = make_node(N_INDEX, t)
            nodes[n].a = e
            set_b(n, parse_expr())
            expect("]")
            e = n
        } else if at_word(".") {
            advance()
            let t:int64 = advance()
            if at_word("(") {
                advance()
                let n:int64 = make_node(N_METHOD, t)
                nodes[n].a = e
                set_b(n, parse_args())
                e = n
            } else {
                let n:int64 = make_node(N_FIELD, t)
                nodes[n].a = e
                e = n
            }
        } else if at_word("^") {
            let t:int64 = advance()
            let n:int64 = make_node(N_DEREF, t)
            nodes[n].a = e
            e = n
        } else {
            return e
        }
    }
    return e
}

let parse_unary():int64 {
    if at_word("-") || at_word("!") {
        let t:int64 = advance()
        let n:int64 = make_node(N_UNARY, t)
        set_a(n, parse_unary())
        return n
    }
    if at_word("&") {
        let t:int64 = advance()
        let n:int64 = make_node(N_ADDR, t)
        set_a(n, parse_unary())
        return n
    }
    var e:int64 = parse_postfix()
    while at_word("as") {
        let t:int64 = advance()
        let n:int64 = make_node(N_CAST, t)
        nodes[n].a = e
        set_ty(n, parse_type())
        e = n
    }
    return e
}

// how tightly the operator at pos binds, 0 where it is none
let binding_power():int64 {
    if !at_kind(T_PUNCT) { return 0 }
    if at_word("||") { return 1 }
    if at_word("&&") { return 2 }
    if at_word("==") || at_word("!=") || at_word("<") || at_word("<=") || at_word(">") || at_word(">=") { return 3 }
    if at_word("+") || at_word("-") { return 4 }
    if at_word("*") || at_word("/") || at_word("%") { return 5 }
    return 0
}

let parse_binary(min:int64):int64 {
    var e:int64 = parse_unary()
    while !failed {
        let p:int64 = binding_power()
        if p == 0 || p < min { return e }
        let t:int64 = advance()
        let n:int64 = make_node(N_BIN, t)
        nodes[n].a = e
        set_b(n, parse_binary(p + 1))
        e = n
    }
    return e
}

let parse_expr():int64 {
    return parse_binary(1)
}

// ---------- statements ----------

let parse_block():int64

// the end of a statement: a newline, a ;, or a } or the end after it
let end_statement() {
    if at_kind(T_NL) || at_word(";") {
        advance()
        return
    }
    if at_word("}") || at_kind(T_EOF) { return }
    parse_error("a statement ends with its line")
}

// name:Type = value, its let or var read
let parse_var(is_let:int64):int64 {
    let t:int64 = advance()
    let n:int64 = make_node(S_VAR, t)
    nodes[n].flag = is_let
    expect(":")
    set_ty(n, parse_type())
    if at_word("=") || at_word(":=") {          // := of a reference, as a cstr
        advance()
        set_a(n, parse_expr())
    }
    return n
}

let parse_if():int64 {
    let n:int64 = make_node(S_IF, advance())
    set_a(n, parse_expr())
    set_b(n, parse_block())
    if at_word("else") {
        advance()
        if at_word("if") {
            set_c(n, parse_if())
        } else {
            set_c(n, parse_block())
        }
    }
    return n
}

let parse_statement():int64

// switch e { case a, b: ... default: ... } (#210): its cases a list of
// S_CASE, each with its values and its statements, up to the next case
let parse_switch():int64 {
    let n:int64 = make_node(S_SWITCH, advance())
    set_a(n, parse_expr())
    expect("{")
    skip_newlines()
    var last:int64 = -1
    while !at_word("}") && !failed {
        let c:int64 = make_node(S_CASE, pos)
        if at_word("default") {
            advance()
            nodes[c].flag = 1
        } else {
            expect("case")
            var lastv:int64 = -1
            while !failed {
                let v:int64 = parse_expr()
                if lastv < 0 {
                    nodes[c].a = v
                } else {
                    nodes[lastv].next = v
                }
                lastv = v
                if !at_word(",") { break }
                advance()
            }
        }
        expect(":")
        skip_newlines()
        var lasts:int64 = -1
        while !at_word("case") && !at_word("default") && !at_word("}") && !failed {
            let s:int64 = parse_statement()
            if lasts < 0 {
                nodes[c].b = s
            } else {
                nodes[lasts].next = s
            }
            lasts = s
            skip_newlines()
        }
        if lasts < 0 { parse_error("a case has a statement before the next: write case a, b: for one body") }
        if last < 0 {
            nodes[n].b = c
        } else {
            nodes[last].next = c
        }
        last = c
    }
    expect("}")
    return n
}

let parse_statement():int64 {
    let t:int64 = pos
    if at_word("switch") {
        return parse_switch()
    }
    if at_word("var") || at_word("let") {
        let is_let:int64 = 0
        advance()
        let n:int64 = parse_var(is_let)
        if tok_is(t, "let") { nodes[n].flag = 1 }
        end_statement()
        return n
    }
    if at_word("if") {
        return parse_if()
    }
    if at_word("while") {
        let n:int64 = make_node(S_WHILE, advance())
        set_a(n, parse_expr())
        set_b(n, parse_block())
        return n
    }
    if at_word("for") {
        advance()
        let v:int64 = advance()
        expect("in")
        let from:int64 = parse_expr()
        if at_word("..<") {
            advance()
            let n:int64 = make_node(S_FOR, v)
            nodes[n].a = from
            set_b(n, parse_expr())
            set_c(n, parse_block())
            return n
        }
        let n:int64 = make_node(S_EACH, v)
        nodes[n].a = from
        set_c(n, parse_block())
        return n
    }
    if at_word("return") {
        let n:int64 = make_node(S_RETURN, advance())
        if !at_kind(T_NL) && !at_word("}") && !at_word(";") { set_a(n, parse_expr()) }
        end_statement()
        return n
    }
    if at_word("break") || at_word("continue") {
        var kind:nkind = S_BREAK
        if at_word("continue") { kind = S_CONTINUE }
        let n:int64 = make_node(kind, advance())
        end_statement()
        return n
    }
    if at_word("{") {
        return parse_block()
    }
    let e:int64 = parse_expr()
    if at_word("=") || at_word("+=") || at_word("-=") || at_word("*=") || at_word("/=") || at_word("%=") {
        let n:int64 = make_node(S_ASSIGN, advance())
        nodes[n].a = e
        set_b(n, parse_expr())
        end_statement()
        return n
    }
    let n:int64 = make_node(S_EXPR, t)
    nodes[n].a = e
    end_statement()
    return n
}

// { statements }, as a list in an S_BLOCK
let parse_block():int64 {
    let n:int64 = make_node(S_BLOCK, pos)
    expect("{")
    var last:int64 = -1
    skip_newlines()
    while !at_word("}") && !failed {
        let s:int64 = parse_statement()
        if last < 0 {
            nodes[n].a = s
        } else {
            nodes[last].next = s
        }
        last = s
        skip_newlines()
    }
    expect("}")
    return n
}

// ---------- declarations ----------

let parse_function():int64 {
    let n:int64 = make_node(D_FN, advance())
    expect("(")
    var last:int64 = -1
    while !at_word(")") && !failed {
        let p:int64 = parse_var(1)
        if last < 0 {
            nodes[n].a = p
        } else {
            nodes[last].next = p
        }
        last = p
        if at_word(",") { advance() }
    }
    expect(")")
    nodes[n].ty = base_type(Y_VOID)
    if at_word(":") {
        advance()
        set_ty(n, parse_type())
    }
    if at_word("{") { set_b(n, parse_block()) }
    return n
}

let parse_struct():int64 {
    let n:int64 = make_node(D_STRUCT, advance())
    type_of_kind(Y_STRUCT, -1, nodes[n].t)
    expect("{")
    var last:int64 = -1
    skip_newlines()
    while !at_word("}") && !failed {
        let f:int64 = parse_var(0)
        if last < 0 {
            nodes[n].a = f
        } else {
            nodes[last].next = f
        }
        last = f
        if at_word(";") { advance() }
        skip_newlines()
    }
    expect("}")
    return n
}

// enum t { a, b = 3, c }, C's enum (#210)
let parse_enum():int64 {
    let n:int64 = make_node(D_ENUM, advance())
    expect("{")
    skip_newlines()
    var last:int64 = -1
    while !at_word("}") && !failed {
        let m:int64 = make_node(N_ID, advance())
        if at_word("=") {
            advance()
            set_a(m, parse_expr())
        }
        if last < 0 {
            nodes[n].a = m
        } else {
            nodes[last].next = m
        }
        last = m
        if at_word(",") { advance() }
        skip_newlines()
    }
    expect("}")
    return n
}

// the declarations from the token at pos to the end
let parse_program() {
    skip_newlines()
    while !at_kind(T_EOF) && !failed {
        if at_kind(T_IMPORT) {
            let n:int64 = make_node(D_IMPORT, advance())
            if tok_is(nodes[n].t, "<IO>") { nodes[n].flag = 1 }
            if is_header(nodes[n].t) {
                nodes[n].flag = 2                   // a C header, as C (#207)
                c_headers = true
            }
            decls += n
        } else if at_word("struct") {
            advance()
            decls += parse_struct()
        } else if at_word("enum") {
            advance()
            decls += parse_enum()
        } else if at_word("let") && toks[pos + 2].kind == T_PUNCT && tok_is(pos + 2, "(") {
            advance()
            decls += parse_function()
        } else if at_word("let") || at_word("var") {
            let is_let:bool = at_word("let")
            advance()
            let n:int64 = parse_var(0)
            nodes[n].kind = D_GLOBAL
            if is_let { nodes[n].flag = 1 }
            decls += n
        } else {
            parse_error("a declaration is expected")
        }
        skip_newlines()
    }
}
