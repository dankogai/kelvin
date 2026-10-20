// parse.k - the tree of the program, for kc (selfhost/kc.k).
// A node is an element of `nodes`, its children by index, a list by
// `next`; a type is an element of `types`, made once. Every variable
// says its type, so nothing is inferred but what an expression gives.

struct node {
    kind: int64
    a: int64
    b: int64
    c: int64
    t: int64           // its token: a name, a literal, an operator
    ty: int64          // the type it declares
    next: int64        // the next of a list
    flag: int64        // a let (1) or a var (0); a #import of <IO> (1)
}

struct ty {
    kind: int64
    elem: int64        // of an Array or a pointer
    name: int64        // the token of a struct's name
}

// expressions
let N_NUM:int64 = 1
let N_CHAR:int64 = 2
let N_STR:int64 = 3
let N_DSTR:int64 = 4
let N_BOOL:int64 = 5
let N_ID:int64 = 6
let N_CALL:int64 = 7       // a(b...)
let N_FIELD:int64 = 8      // a.t
let N_METHOD:int64 = 9     // a.t(b...)
let N_INDEX:int64 = 10     // a[b]
let N_UNARY:int64 = 11     // t a
let N_BIN:int64 = 12       // a t b
let N_CAST:int64 = 13      // a as ty
let N_ADDR:int64 = 14      // &a
let N_DEREF:int64 = 15     // a^
let N_EMPTY:int64 = 16     // $[]
let N_TYPE:int64 = 17      // IO or String called: a type's name as a function
let N_INIT:int64 = 18      // {b...}, a struct's members in order
// statements
let S_VAR:int64 = 20       // t:ty = a
let S_ASSIGN:int64 = 21    // a t b, t an assignment's operator
let S_EXPR:int64 = 22
let S_IF:int64 = 23        // if a { b } else c
let S_WHILE:int64 = 24
let S_FOR:int64 = 25       // for t in a..<b { c }
let S_EACH:int64 = 26      // for t in a { c }
let S_RETURN:int64 = 27
let S_BREAK:int64 = 28
let S_CONTINUE:int64 = 29
let S_BLOCK:int64 = 30     // a, the first statement
// declarations
let D_FN:int64 = 40        // t(a...):ty { b }, b -1 for a prototype
let D_STRUCT:int64 = 41    // t { a... }
let D_GLOBAL:int64 = 42    // as S_VAR
let D_IMPORT:int64 = 43

// types
let Y_VOID:int64 = 0
let Y_I64:int64 = 1
let Y_I32:int64 = 2
let Y_U8:int64 = 3
let Y_U32:int64 = 4
let Y_BOOL:int64 = 5
let Y_CSTR:int64 = 6
let Y_STRING:int64 = 7
let Y_IO:int64 = 8
let Y_UCHR:int64 = 9
let Y_ARRAY:int64 = 10
let Y_STRUCT:int64 = 11
let Y_PTR:int64 = 12
let Y_ARGV:int64 = 13      // [cstr], main's argv

var nodes:$[node]
var types:$[ty]
var decls:$[int64]         // the top-level declarations, in order
var arrays:$[int64]        // every Array type, in the order they are met
var pos:int64              // the next token

// ---------- types ----------

let type_of_kind(kind:int64, elem:int64, name:int64):int64 {
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

let base_type(kind:int64):int64 {
    return type_of_kind(kind, -1, -1)
}

// ---------- the cursor ----------

let at_kind(k:int64):bool {
    return toks[pos].kind == k
}

let at_word(w:cstr):bool {
    let k:int64 = toks[pos].kind
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

let make_node(kind:int64, t:int64):int64 {
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
    let k:int64 = toks[t].kind
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
    if at_word("=") {
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

let parse_statement():int64 {
    let t:int64 = pos
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
        var kind:int64 = S_BREAK
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

// the declarations from the token at pos to the end
let parse_program() {
    skip_newlines()
    while !at_kind(T_EOF) && !failed {
        if at_kind(T_IMPORT) {
            let n:int64 = make_node(D_IMPORT, advance())
            if tok_is(nodes[n].t, "<IO>") { nodes[n].flag = 1 }
            decls += n
        } else if at_word("struct") {
            advance()
            decls += parse_struct()
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
