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
    N_EMPTY,    // $[], ${:}; ${} flag 1 (#348)
    N_ARRAY,    // $[b...], an Array of its elements (#266)
    N_DICT,     // ${k: v...}, b the first key, each key's next its value (#267)
    N_SET,      // ${a, b}, a Set of its elements, b the first (#274)
    N_TYPE,     // IO or String called: a type's name as a function
    N_INIT,     // {b...}, a struct's members in order
    N_NULL,     // nullptr
    N_SELF,     // self, and the self of .x (#213)
    N_CHAIN,    // a?.rest (#221): b the rest, of the name c bound to what a holds; t the ?
    N_COND,     // a ? b : c (#232); t the ?
    N_ASYNC,    // async a, a call on a thread of its own (#313)
    N_AWAIT,    // await a, a Task's value (#313)
    N_ANON,     // { (a...):ty in b } or { b } of $0, an anonymous function (#324); flag 1 of $0, 2 of { v in b } (#330)
    N_ITER,     // Iterator<ty>(a) b or Iterator(a, b), a state and a function of it (#326)
    N_LIST,     // [b...], a fixed array's elements (#354); flag 1 of [ty](a), a zero elements
    N_MAKE,     // Array<T>(), Dictionary<K, V>(): an empty one of ty (#349); flag 1 of no (), 2 of what kc does not make;
                // of an Array (#350), flag 3 of [b...], the elements, 4 of &a, a copy, 5 of a, a count, 6 of more after [...], 7 of more than one;
                // of a Dictionary (#351), flag 3 of {k: v}, a the literal, 4 of &a, 5 of a, 6 of more, c the token
    N_RANGE,    // a..<b, a...b (flag 1), a... (flag 2, b -1); ..<b and ...b, a -1 of 0 (#373); ty the Range<T> it is
    N_RITER,    // the Iterator<T> of the Range a, which kc makes for its lazy and prefix { ... } (#373)
    // statements
    S_VAR,      // t:ty = a
    S_ASSIGN,   // a t b, t an assignment's operator
    S_EXPR,
    S_IF,       // if a { b } else c
    S_WHILE,
    S_FOR,      // for t in a..<b { c }; flag 1 of a...b, 2 of a... (b -1), a -1 of ..<b and ...b (#373)
    S_EACH,     // for t in a { c }; for t, b in a of a Dictionary, b the value's name (#269)
    S_RETURN,
    S_BREAK,
    S_CONTINUE,
    S_FALL,     // fallthrough, on into the next case's body (#386)
    S_BLOCK,    // a, the first statement
    S_SWITCH,   // switch a { b, the first case }
    S_CASE,     // case a...: b...; flag 1 of default
    S_IFLET,    // if let t(flag) = a { b } else c (#217)
    // declarations
    D_FN,       // t(a...):ty { b }, b -1 for a prototype; of a type c, flag 1 static, 2 a var method (#320)
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
    Y_F64,      // float64 (#262)
    Y_F32,      // float32 (#263)
    Y_BOOL,
    Y_CSTR,
    Y_STRING,
    Y_IO,
    Y_UCHR,
    Y_ARRAY,
    Y_DICT,     // a Dictionary: its value elem, its key name (#211)
    Y_SET,      // a Set: its element elem (#274)
    Y_STRUCT,
    Y_PTR,
    Y_ARGV,     // [cstr], main's argv
    Y_TASK,     // a Task (#313): its value elem, -1 of none
    Y_ITER,     // an Iterator<T> (#326): its value elem
    Y_FIXED,    // [T](N), a fixed array (#354): its element elem, its count name, -1 where its elements give it;
                // -3 of [const T]; a parameter's, a pointer, -2, and -4 of its const elements (#357);
                // -10 - n of a count C computes, node n (#366)
    Y_RANGE,    // a Range<T> (#373): its integers elem
    Y_BITS,     // a Bits (#387): 64 bits in a u64, kv_bits in C
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
    name: int64        // the token of a struct's name; a Dictionary's key type (#211)
}

extend node {                                      // (#213)
    // a node of kind and token t, with nothing under it yet
    static let leaf(kind:nkind, t:int64):Self {
        return {kind, -1, -1, -1, t, -1, -1, 0}
    }
    // whether it leaves a case: a return, a break, a continue, a fallthrough
    let jumps():bool {
        return .kind == S_RETURN || .kind == S_BREAK || .kind == S_CONTINUE || .kind == S_FALL
    }
}

extend ty {
    // whether it is an owner, freed where its block ends
    let owns():bool {
        return .kind == Y_STRING || .kind == Y_ARRAY || .kind == Y_IO || .kind == Y_DICT || .kind == Y_SET || .kind == Y_TASK || .kind == Y_ITER
    }
}

var nodes:$[node]
var types:$[ty]
var decls:$[int64]         // the top-level declarations, in order
var arrays:$[int64]        // every Array type, in the order they are met
var dicts:$[int64]         // every Dictionary type, so (#211)
var sets:$[int64]          // every Set type, so (#274)
var pos:int64              // the next token
var c_headers:bool         // whether a C header is imported: then a name kc does not know is C's (#207)
var self_name:int64 = 0 - 1    // the token of the type whose method is being read, for Self (#213)
var made_enums:Dictionary<String, int64>   // the enums kc makes of T? and Result<T, E>, by name (#217)
var range_values = 0       // the ranges that are values, not a for's (#373): then each Range<T>'s struct is written

// whether token t names a C header: <x.h> or "x.h"
let is_header(t:int64):bool {
    let n:int64 = toks[t].len
    return n > 3 && codes[toks[t].at + n - 3] == '.' && codes[toks[t].at + n - 2] == 'h'
}

// ---------- types ----------

let type_of_kind(kind:ykind, elem:int64, name:int64):int64 {
    var i = 0
    while i < types.count as int64 {
        let y:ty = types[i]
        if y.kind == kind && y.elem == elem {
            if kind == Y_STRUCT {
                if same_text(y.name, name) { return i }
            } else if kind == Y_DICT || kind == Y_PTR || kind == Y_FIXED {
                if y.name == name { return i }   // a pointer's name 1 where what it points to is const (#272); a fixed array's count (#354)
            } else {
                return i
            }
        }
        i += 1
    }
    let y:ty = {kind, elem, name}
    types += y
    if kind == Y_ARRAY { arrays += types.count as int64 - 1 }
    if kind == Y_DICT { dicts += types.count as int64 - 1 }
    if kind == Y_SET { sets += types.count as int64 - 1 }
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

// off while the middle of c ? a : b or a case's values are parsed, where
// a : and a name are ?:'s or the case's, as kelvinc's ident_annotation_ok (#265)
var name_annotation = true

// whether the : at the cursor annotates a value with a type, 0.1:float32,
// as kelvinc's x:T (#264): a type's word follows, and no ( or <, which
// would make the value of the other arm of c ? a : b, or a case's body;
// a struct's name or a C typedef's, p:point, n:size_t (#265), but where
// the : is ?:'s or a case's
let annotation_ahead():bool {
    if !at_word(":") || pos + 2 >= toks.count as int64 || toks[pos + 1].kind != T_ID { return false }
    if tok_is(pos + 2, "(") || tok_is(pos + 2, "<") { return false }
    let t:int64 = pos + 1
    if tok_is(t, "int64") || tok_is(t, "int32") || tok_is(t, "uint8") || tok_is(t, "uint32") || tok_is(t, "float64") || tok_is(t, "float32") || tok_is(t, "bool") || tok_is(t, "cstr") || tok_is(t, "uchr") {
        return true
    }
    return name_annotation
}

let parse_error(what:cstr) {
    if !failed {
        let t:tok = toks[pos]
        println(fnames[t.file], ":", t.line, ": error: ", what)
    }
    failed = true
    pos = eof_pos                       // the end: every loop stops
}

let advance():int64 {
    let t:int64 = pos
    if pos < eof_pos { pos += 1 }
    return t
}

let expect(w:cstr) {
    if !at_word(w) {
        parse_error("unexpected token")
        return
    }
    advance()
}

// the > that closes a type's <...>, the first of a >> too, which the
// lexer reads as a shift (#387): that token is left as its second >
let close_angle() {
    if at_word(">>") {
        toks[pos].at += 1
        toks[pos].len = 1
        return
    }
    expect(">")
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
    let n:node = node.leaf(kind, t)
    nodes += n
    return nodes.count as int64 - 1
}

// ---------- Optional and Result (#217) ----------

// a token of a name kc makes, its codepoints after the files'
let made_token(s:String^):int64 {
    let at = codes.count as int64
    for c in s^ {
        codes += c.utf32
    }
    let t:tok = {T_ID, at, codes.count as int64 - at, 0, 0}
    toks += t
    return toks.count as int64 - 1
}

// the part of a made name a type gives, as kelvinc's: i64, String, Array_i64
let type_word(y:int64):String {
    switch types[y].kind {            // each its own, as gen.k's mangled: f64? and a Dictionary? are two (#267)
    case Y_I64: return $"i64"
    case Y_I32: return $"i32"
    case Y_U8: return $"u8"
    case Y_U32: return $"u32"
    case Y_F64: return $"f64"
    case Y_F32: return $"f32"
    case Y_BOOL: return $"bool"
    case Y_CSTR: return $"cstr"
    case Y_STRING: return $"String"
    case Y_IO: return $"IO"
    case Y_UCHR: return $"uchr"
    case Y_BITS: return $"Bits"
    case Y_PTR:
        var s = type_word(types[y].elem)
        s += "p"
        return s
    case Y_ARRAY:
        var s = $"Array_"
        var e = type_word(types[y].elem)
        s += &e
        return s
    case Y_DICT:
        var s = $"Dictionary_"
        var k = type_word(types[y].name)
        s += &k
        s += "_"
        var e = type_word(types[y].elem)
        s += &e
        return s
    case Y_SET:
        var s = $"Set_"
        var e = type_word(types[y].elem)
        s += &e
        return s
    case Y_STRUCT: return tok_text(types[y].name)
    case Y_ITER:                                   // (#326)
        var s = $"Iterator_"
        var e = type_word(types[y].elem)
        s += &e
        return s
    case Y_RANGE:                                  // (#373)
        var s = $"Range_"
        var e = type_word(types[y].elem)
        s += &e
        return s
    case Y_TASK:                                   // (#313)
        var s = $"Task"
        if types[y].elem >= 0 {
            s += "_"
            var e = type_word(types[y].elem)
            s += &e
        }
        return s
    default: return $"T"
    }
}

// the enum with values kc makes of T? or Result<T, E>, once, as kelvinc
// makes it: _kv_opt_T of none and some, _kv_res_T_E of ok and err; its c
// is 1 of an Optional, whose T a T? takes as some(T)
let made_enum(name:String^, first:cstr, ft:int64, second:cstr, st:int64, optional:bool):int64 {
    if made_enums.has(name^) { return made_enums.get(name^, 0) }
    let d = make_node(D_ENUM, made_token(name))
    nodes[d].flag = 1
    if optional { nodes[d].c = 1 }
    var w1 = String(first)
    let m1 = make_node(N_ID, made_token(&w1))
    nodes[m1].ty = ft
    var w2 = String(second)
    let m2 = make_node(N_ID, made_token(&w2))
    nodes[m2].ty = st
    nodes[d].a = m1
    nodes[m1].next = m2
    decls += d
    let y = type_of_kind(Y_STRUCT, -1, nodes[d].t)
    made_enums[name^] = y
    return y
}

let optional_of(t:int64):int64 {
    var name = $"_kv_opt_"
    var w = type_word(t)
    name += &w
    return made_enum(&name, "none", -1, "some", t, true)
}

let result_of(t:int64, e:int64):int64 {
    var name = $"_kv_res_"
    var w = type_word(t)
    name += &w
    name += "_"
    var v = type_word(e)
    name += &v
    return made_enum(&name, "ok", t, "err", e, false)
}

// ---------- types as written ----------

let parse_expr():int64    // a prototype: the parsers call each other, a type's count too (#366)
let parse_type():int64    // a prototype: a type's parts are types
let parse_bare_type():int64

// T^ of y, its innermost pointer to a const T: const T^, a borrow through
// which T does not change, as C's const T * (#272)
let const_pointee(y:int64):int64 {
    if types[y].kind != Y_PTR { return y }
    let e:int64 = types[y].elem
    if types[e].kind == Y_PTR { return type_of_kind(Y_PTR, const_pointee(e), types[y].name) }
    return type_of_kind(Y_PTR, e, 1)
}

// whether the [ before pos, of [[T](n)](2), closes with ]( : a type's
// array of zeros, not a list of lists (#367)
let bracket_type_ahead():bool {
    var depth = 1
    var k:int64 = pos
    while k < toks.count as int64 {
        if tok_is(k, "[") || tok_is(k, "$[") { depth += 1 }
        if tok_is(k, "]") {
            depth -= 1
            if depth == 0 { return tok_is(k + 1, "(") }
        }
        k += 1
    }
    return false
}

// the value of token t, a number of decimal digits, or -1: a fixed
// array's count (#354)
let tok_count(t:int64):int64 {
    if toks[t].kind != T_NUM { return 0 - 1 }
    var v = 0
    for i in 0..<toks[t].len {
        let c:uint32 = codes[toks[t].at + i]
        if c < '0' || c > '9' { return 0 - 1 }
        v = v * 10 + (c as int64 - 48)
    }
    return v
}

// const T^ and the rest (#272)
let parse_type():int64 {
    if at_word("const") {
        advance()
        let y = parse_bare_type()
        if types[y].kind == Y_ARRAY {               // as kelvinc has it of each spelling, $[T] (#273, #274)
            parse_error("a qualifier of an Array or a Dictionary is the variable's: a let does not change")
        } else if types[y].kind == Y_DICT {
            parse_error("a qualifier of a Dictionary is the variable's: a let does not change")
        } else if types[y].kind == Y_SET {
            parse_error("a qualifier of a Set is the variable's: a let does not change")
        } else if types[y].kind == Y_FIXED || (types[y].kind == Y_PTR && types[types[y].elem].kind == Y_FIXED) {   // as kelvinc says it (#362)
            parse_error("a qualifier of an array is its elements': write it inside the brackets, as in '[const u8]'")
        }
        return const_pointee(y)
    }
    return parse_bare_type()
}

// [T] in $[...], an Array in turn, as kelvinc reads $[[i64]] (#369)
let grown(y:int64):int64 {
    if types[y].kind == Y_FIXED && (types[y].name == 0 - 1 || types[y].name == 0 - 3) {
        return type_of_kind(Y_ARRAY, grown(types[y].elem), -1)
    }
    return y
}

// a list among $[...]'s elements, an Array in turn, its lists too (#369)
let lists_grow(e:int64) {
    if nodes[e].kind != N_LIST || nodes[e].flag != 0 { return }
    nodes[e].kind = N_ARRAY
    var x:int64 = nodes[e].b
    while x >= 0 {
        lists_grow(x)
        x = nodes[x].next
    }
}

let parse_bare_type():int64 {
    if at_word("$[") {
        advance()
        var elem:int64 = parse_type()
        expect("]")
        if types[elem].kind == Y_FIXED && types[elem].name != 0 - 1 && types[elem].name != 0 - 3 {   // as kelvinc says it (#369)
            var b:int64 = elem
            while types[b].kind == Y_FIXED { b = types[b].elem }
            var m = $"an Array grows, and has no count in its type: write $[["
            let w:String = type_word(b)
            m += &w
            m += "]], and give the elements or a count where it is made"
            parse_error(m.cstr)
            return base_type(Y_VOID)
        }
        elem = grown(elem)
        var y:int64 = type_of_kind(Y_ARRAY, elem, -1)
        while at_word("^") || at_word("?") {
            if at_word("?") {
                y = optional_of(y)               // $[T]?, an Optional (#221)
            } else {
                y = type_of_kind(Y_PTR, y, -1)
            }
            advance()
        }
        return y
    }
    if at_word("[") {
        advance()
        if at_word("cstr") && tok_is(pos + 1, "]") && !tok_is(pos + 2, "(") {   // [cstr], main's argv
            advance()
            advance()
            return base_type(Y_ARGV)
        }
        let constant = at_word("const")             // [const T], a parameter's elements read alone (#357)
        if constant { advance() }
        let elem:int64 = parse_type()                // [T](N), [T] of a count its elements give (#354)
        if constant && types[elem].kind == Y_FIXED { // [const [T](N)], as kelvinc says it (#370)
            parse_error("a qualifier of an array is its elements': write it inside the brackets, as in '[const u8]'")
            return base_type(Y_VOID)
        }
        expect("]")
        var count:int64 = constant ? 0 - 3 : 0 - 1
        if constant && at_word("(") {
            parse_error("kc reads [const T] without a count, a parameter's; not yet [const T](N)")
            return base_type(Y_VOID)
        }
        if at_word("(") {
            advance()
            count = tok_is(pos + 1, ")") ? tok_count(pos) : 0 - 1
            if count < 0 {                           // a count C computes, a local's (#366): -10 - its node
                count = 0 - 10 - parse_expr()
            } else {
                advance()
            }
            expect(")")
        }
        var y:int64 = type_of_kind(Y_FIXED, elem, count)
        while at_word("^") || at_word("?") {         // [T](N)^, which gen says is not kc's yet
            y = at_word("?") ? optional_of(y) : type_of_kind(Y_PTR, y, -1)
            advance()
        }
        return y
    }
    if !at_kind(T_ID) {
        parse_error("a type is expected")
        return base_type(Y_VOID)
    }
    let t:int64 = advance()
    var y = -1
    if tok_is(t, "int64") {
        y = base_type(Y_I64)
    } else if tok_is(t, "int32") {
        y = base_type(Y_I32)
    } else if tok_is(t, "uint8") {
        y = base_type(Y_U8)
    } else if tok_is(t, "uint32") {
        y = base_type(Y_U32)
    } else if tok_is(t, "float64") {                 // (#262)
        y = base_type(Y_F64)
    } else if tok_is(t, "float32") {                 // (#263)
        y = base_type(Y_F32)
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
    } else if tok_is(t, "Bits") {                // (#387)
        y = base_type(Y_BITS)
    } else if tok_is(t, "Self") && self_name >= 0 {   // the type of the method (#213)
        y = type_of_kind(Y_STRUCT, -1, self_name)
    } else if tok_is(t, "Optional") {            // Optional<T>, T? (#217)
        expect("<")
        let inner = parse_type()
        close_angle()
        y = optional_of(inner)
    } else if tok_is(t, "Result") {              // Result<T, E> (#217)
        expect("<")
        let value = parse_type()
        expect(",")
        let error = parse_type()
        close_angle()
        y = result_of(value, error)
    } else if tok_is(t, "Iterator") {            // Iterator<T> (#326)
        expect("<")
        let value:int64 = parse_type()
        close_angle()
        y = type_of_kind(Y_ITER, value, -1)
    } else if tok_is(t, "Range") {               // Range<T>, Range of i64 (#373)
        var value:int64 = base_type(Y_I64)
        if at_word("<") {
            advance()
            value = parse_type()
            close_angle()
        }
        let k:ykind = types[value].kind
        if k != Y_I64 && k != Y_I32 && k != Y_U8 && k != Y_U32 {
            var m = $"a Range is of integers, i8 to i64 or u8 to u64, and this is "
            let w:String = type_word(value)
            m += &w
            m += "; convert its bounds, as in 'i64(n)'"
            parse_error(m.cstr)
        }
        y = type_of_kind(Y_RANGE, value, -1)
    } else if tok_is(t, "Task") {                // Task<R>, Task of none (#313)
        var value = -1
        if at_word("<") {
            advance()
            value = parse_type()
            close_angle()
        }
        y = type_of_kind(Y_TASK, value, -1)
    } else if tok_is(t, "Set") {                 // Set<T> (#274)
        expect("<")
        let elem:int64 = parse_type()
        close_angle()
        y = type_of_kind(Y_SET, elem, -1)
    } else if tok_is(t, "Dictionary") {          // Dictionary<K, V> (#211)
        expect("<")
        let key:int64 = parse_type()
        expect(",")
        let value:int64 = parse_type()
        close_angle()
        y = type_of_kind(Y_DICT, value, key)
        optional_of(value)                       // V?, which d[k] read whole is (#219)
    } else {
        y = type_of_kind(Y_STRUCT, -1, t)
    }
    while at_word("^") || at_word("?") || at_word("??") {
        if at_word("??") {                       // T??, which lexes as ?? (#229)
            y = optional_of(optional_of(y))
        } else if at_word("?") {
            y = optional_of(y)                   // T?, an Optional (#217)
        } else {
            y = type_of_kind(Y_PTR, y, -1)
        }
        advance()
    }
    return y
}

// ---------- expressions ----------


// the arguments of a call after its (, up to its ), as a list
let parse_args():int64 {
    var first = -1
    var last = -1
    let saved = name_annotation
    name_annotation = true                       // c ? f(p:point) : q (#265)
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
    name_annotation = saved
    expect(")")
    return first
}

// whether ${ at the cursor's left begins a Set, ${a, b}: no : at the
// first element's level before its , or } (#274)
let set_ahead():bool {
    var i:int64 = pos
    var depth:int64 = 0
    while i < toks.count as int64 {
        let k:tkind = toks[i].kind
        if k == T_PUNCT && (tok_is(i, "(") || tok_is(i, "[") || tok_is(i, "{") || tok_is(i, "$[") || tok_is(i, "${")) {
            depth += 1
        } else if k == T_PUNCT && (tok_is(i, ")") || tok_is(i, "]") || tok_is(i, "}")) {
            if depth == 0 { return true }
            depth -= 1
        } else if depth == 0 && k == T_PUNCT && tok_is(i, ",") {
            return true
        } else if depth == 0 && k == T_PUNCT && tok_is(i, ":") {
            return false
        } else if depth == 0 && k == T_PUNCT && tok_is(i, "?") {
            return false                        // c ? a : b in a key: a Dictionary's, as before
        }
        i += 1
    }
    return true
}

let parse_statement():int64    // prototypes: an anonymous function asks them (#324)
let parse_typed(is_let:int64):int64

// whether the tokens from i are names, by commas, then `in`: the
// parameters of an anonymous function named without their types (#330)
let names_in_ahead(i0:int64):bool {
    var i:int64 = i0
    while toks[i].kind == T_ID {
        if tok_is(i + 1, "in") { return true }
        if !tok_is(i + 1, ",") { return false }
        i += 2
    }
    return false
}

// whether the { at the cursor begins an anonymous function (#324), as
// kelvinc tells one: { (x:T):R in ... }, or a body that names $0
let anon_ahead():bool {
    if !at_word("{") { return false }
    var i:int64 = pos + 1
    while toks[i].kind == T_NL { i += 1 }
    if tok_is(i, "(") && toks[i + 1].kind == T_ID && tok_is(i + 2, ":") { return true }
    if names_in_ahead(i) { return true }                // { v in ... }, { acc, v in ... } (#330)
    var depth:int64 = 0
    while toks[i].kind != T_EOF {
        if tok_is(i, "{") || tok_is(i, "${") { depth += 1 }
        if tok_is(i, "}") {
            if depth == 0 { return false }
            depth -= 1
        }
        if toks[i].kind == T_ID && codes[toks[i].at] == '$' { return true }
        i += 1
    }
    return false
}

// an anonymous function (#324): its parameters and result where written,
// { (x:T):R in ... }, else $0, $1 as the context types them; its body the
// statements to the }
let parse_anon():int64 {
    let n:int64 = make_node(N_ANON, advance())
    skip_newlines()
    if at_word("(") {
        advance()
        var last = -1
        while !at_word(")") && !failed {
            let p:int64 = parse_typed(1)
            if last < 0 {
                nodes[n].a = p
            } else {
                nodes[last].next = p
            }
            last = p
            if at_word(",") { advance() }
        }
        expect(")")
        if at_word(":") {
            advance()
            set_ty(n, parse_type())
        }
        expect("in")
    } else if names_in_ahead(pos) {                      // { v in ... }: named, typed by where it goes (#330)
        nodes[n].flag = 2
        var last = -1
        while !at_word("in") && !failed {
            let p:int64 = make_node(S_VAR, advance())
            nodes[p].flag = 1
            if last < 0 {
                nodes[n].a = p
            } else {
                nodes[last].next = p
            }
            last = p
            if at_word(",") { advance() }
        }
        expect("in")
    } else {
        nodes[n].flag = 1
    }
    let b:int64 = make_node(S_BLOCK, nodes[n].t)
    var last = -1
    skip_newlines()
    while !at_word("}") && !failed {
        let st:int64 = parse_statement()
        if last < 0 {
            nodes[b].a = st
        } else {
            nodes[last].next = st
        }
        last = st
        skip_newlines()
    }
    expect("}")
    nodes[n].b = b
    return n
}

// what follows ${, or { where a Dictionary is written (#351), t the
// opening: ${:}, an empty Dictionary (#211); ${}, an empty Set; ${a, b},
// a Set (#274); ${k: v}, a Dictionary (#267)
let parse_brace_body(t:int64):int64 {
    skip_newlines()
    if at_word(":") {
        advance()
        expect("}")
        return make_node(N_EMPTY, t)
    }
    if at_word("}") {                           // ${}, an empty Set (#274)
        advance()
        let n:int64 = make_node(N_EMPTY, t)
        nodes[n].flag = 1                       // a Set's, not ${:} (#348)
        return n
    }
    if set_ahead() {                            // ${a, b}, a Set (#274)
        let n:int64 = make_node(N_SET, t)
        var last = -1
        while !failed {
            let e:int64 = parse_expr()
            if last < 0 {
                nodes[n].b = e
            } else {
                nodes[last].next = e
            }
            last = e
            skip_newlines()
            if !at_word(",") { break }
            advance()
            skip_newlines()
            if at_word("}") { break }
        }
        expect("}")
        return n
    }
    let n:int64 = make_node(N_DICT, t)          // ${k: v} (#267)
    let saved = name_annotation
    var last = -1
    while !failed {
        name_annotation = false                 // ${k: v}'s :, not k:T
        let k:int64 = parse_expr()
        name_annotation = saved
        expect(":")
        let v:int64 = parse_expr()
        nodes[k].next = v
        if last < 0 {
            nodes[n].b = k
        } else {
            nodes[last].next = k
        }
        last = v
        skip_newlines()
        if !at_word(",") { break }
        advance()
        skip_newlines()
        if at_word("}") { break }                 // a comma after the last
    }
    name_annotation = saved
    expect("}")
    return n
}

// Array<T>() and Dictionary<K, V>(), an empty one, as kelvinc's #57 and
// #65 (#349): ty the type; without (), flag 1, and with what else
// kelvinc takes in them, flag 2, its tokens passed over, for gen's
// errors. Of an Array, Array<T>([a, b]), Array<T>(&a) and Array<T>(n)
// (#350): flags 3, 4 and 5, b the first element, or a the one given;
// flag 6 of more after the elements, 7 of more than one. Of a
// Dictionary, Dictionary<K, V>({k: v}) and (&d) (#351): flag 3, a the
// literal, read as ${...}; 4 of &d, 5 of another; 6 of more, c its token.
// Array(...), ty -1, its T the elements' of Array([a, b]) (#352)
let parse_make():int64 {
    let n:int64 = make_node(N_MAKE, advance())
    if tok_is(nodes[n].t, "Array") && at_word("(") {
        // Array([a, b]), ty -1: T is the elements' (#352)
    } else if tok_is(nodes[n].t, "Array") {
        advance()                                // <
        let elem:int64 = parse_type()
        close_angle()
        set_ty(n, type_of_kind(Y_ARRAY, elem, -1))
    } else {
        advance()                                // <
        let key:int64 = parse_type()
        expect(",")
        let value:int64 = parse_type()
        close_angle()
        set_ty(n, type_of_kind(Y_DICT, value, key))
        optional_of(value)                       // V?, which d[k] read whole is (#219)
    }
    if !at_word("(") {
        nodes[n].flag = 1
        return n
    }
    advance()
    if tok_is(nodes[n].t, "Array") && at_word("[") {      // the elements (#350)
        advance()
        nodes[n].flag = 3
        var last = -1
        while !failed && !at_word("]") {
            let e:int64 = parse_expr()
            lists_grow(e)                            // Array([[1], [2, 3]]), as kelvinc's #58 (#369)
            if last < 0 {
                nodes[n].b = e
            } else {
                nodes[last].next = e
            }
            last = e
            if !at_word(",") { break }
            advance()
        }
        expect("]")
        if !at_word(")") {
            nodes[n].flag = 6
        }
    } else if tok_is(nodes[n].t, "Dictionary") && (at_word("{") || at_word("${")) {   // the entries (#351)
        nodes[n].a = parse_brace_body(advance())
        nodes[n].flag = 3
    } else if tok_is(nodes[n].t, "Dictionary") && !at_word(")") {   // &d, a copy (#351)
        nodes[n].a = parse_expr()
        nodes[n].flag = nodes[nodes[n].a].kind == N_ADDR ? 4 : 5
    } else if tok_is(nodes[n].t, "Array") && !at_word(")") {   // &a, a copy; n, a count (#350)
        nodes[n].a = parse_expr()
        nodes[n].flag = nodes[nodes[n].a].kind == N_ADDR ? 4 : 5
        if !at_word(")") {
            nodes[n].flag = 7
        }
    }
    if tok_is(nodes[n].t, "Dictionary") && nodes[n].flag >= 3 && !at_word(")") {
        nodes[n].flag = 6                        // more, as kelvinc's: expected ')'
        nodes[n].c = pos
    }
    var depth = 0
    while !failed && pos < toks.count as int64 && !(depth == 0 && at_word(")")) {
        if nodes[n].flag < 2 { nodes[n].flag = 2 }
        if at_word("(") || at_word("[") || at_word("{") || at_word("$[") || at_word("${") { depth += 1 }
        if at_word(")") || at_word("]") || at_word("}") { depth -= 1 }
        advance()
    }
    expect(")")
    return n
}

// Iterator(state) { ... }, Iterator(state, f), Iterator<T>(...) (#326), as
// kelvinc's #325: a the state, b the function, ty T where written
let parse_iterator():int64 {
    let n:int64 = make_node(N_ITER, advance())
    if at_word("<") {
        advance()
        set_ty(n, parse_type())
        close_angle()
    }
    expect("(")
    set_a(n, parse_expr())
    if at_word(",") {
        advance()
        if at_word("{") {                                // a function is what goes here, as kelvinc reads it
            set_b(n, parse_anon())
        } else {
            set_b(n, parse_expr())
        }
        expect(")")
    } else {
        expect(")")
        if !at_word("{") {
            parse_error("an Iterator takes a function of its state after it, 'Iterator(0) { ... }', or after a comma, 'Iterator(0, f)'; in a for, write it in the parentheses")
            return n
        }
        set_b(n, parse_anon())
    }
    return n
}

let parse_primary():int64 {
    let t:int64 = pos
    let k:tkind = toks[t].kind
    if k == T_ID && tok_is(t, "Iterator") && (tok_is(t + 1, "(") || tok_is(t + 1, "<")) { return parse_iterator() }   // (#326)
    if k == T_ID && (tok_is(t, "Array") || tok_is(t, "Dictionary")) && tok_is(t + 1, "<") { return parse_make() }   // (#349)
    if k == T_ID && tok_is(t, "Array") && tok_is(t + 1, "(") { return parse_make() }   // Array([a, b]) (#352)
    if k == T_NUM {
        advance()
        return make_node(N_NUM, t)
    }
    if at_word("[") {                                    // a fixed array's elements, or [T](n) (#354)
        advance()
        let n:int64 = make_node(N_LIST, t)
        let word = toks[pos].kind == T_ID                // [T](n) of a type's name: a list is no function (#366)
        if word && tok_is(pos + 1, "]") && tok_is(pos + 2, "(") || at_word("[") && bracket_type_ahead() {   // [T](n), n zero elements; [[T](n)](2) (#367)
            set_ty(n, parse_type())
            expect("]")
            expect("(")
            nodes[n].a = parse_expr()
            expect(")")
            nodes[n].flag = 1
            return n
        }
        var last = -1
        skip_newlines()
        while !failed && !at_word("]") {
            let e:int64 = parse_expr()
            if last < 0 {
                nodes[n].b = e
            } else {
                nodes[last].next = e
            }
            last = e
            skip_newlines()
            if !at_word(",") { break }
            advance()
            skip_newlines()
        }
        expect("]")
        return n
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
        let saved = name_annotation
        name_annotation = true                   // (c ? (p:point) : q) (#265)
        let e:int64 = parse_expr()
        name_annotation = saved
        expect(")")
        return e
    }
    if at_word("$[") {
        advance()
        if at_word("]") {
            advance()
            return make_node(N_EMPTY, t)
        }
        let n:int64 = make_node(N_ARRAY, t)          // $[a, b] (#266)
        var last = -1
        while !failed {
            let e:int64 = parse_expr()
            lists_grow(e)                            // $[[1, 2], [3]], an Array of Arrays, as kelvinc's (#369)
            if last < 0 {
                nodes[n].b = e
            } else {
                nodes[last].next = e
            }
            last = e
            if !at_word(",") { break }
            advance()
            if at_word("]") { break }                 // a comma after the last
        }
        expect("]")
        return n
    }
    if at_word("${") {                          // ${:}, ${}, ${a, b}, ${k: v} (#211, #267, #274)
        advance()
        return parse_brace_body(t)
    }
    if anon_ahead() { return parse_anon() }          // (#324)
    if at_word("{") {
        advance()
        let n:int64 = make_node(N_INIT, t)
        var last = -1
        skip_newlines()                                  // a { ... } of lines of its own, in parentheses too (#326)
        while !at_word("}") && !failed {
            let e:int64 = parse_expr()
            if last < 0 {
                nodes[n].b = e
            } else {
                nodes[last].next = e
            }
            last = e
            skip_newlines()
            if at_word(",") { advance() }
            skip_newlines()
        }
        expect("}")
        return n
    }
    if k == T_ID {
        advance()
        if tok_is(t, "true") || tok_is(t, "false") { return make_node(N_BOOL, t) }
        if tok_is(t, "nullptr") { return make_node(N_NULL, t) }
        if tok_is(t, "self") { return make_node(N_SELF, t) }
        if tok_is(t, "IO") || tok_is(t, "String") || tok_is(t, "Bits") { return make_node(N_TYPE, t) }   // Bits(n) (#387)
        return make_node(N_ID, t)
    }
    if at_word(".") && toks[pos + 1].kind == T_ID {        // .x, self's member x (#213)
        advance()
        let n:int64 = make_node(N_FIELD, advance())
        nodes[n].a = make_node(N_SELF, t)
        return n
    }
    parse_error("an expression is expected")
    return make_node(N_NUM, t)
}

// whether token b follows token a with nothing between them, as x! does (#218)
let adjacent(a:int64, b:int64):bool {
    return toks[a].at + toks[a].len == toks[b].at
}

// whether what follows a[k] makes it a place: kelvinc reads d[k] whole as
// an Optional since #218, and goes into it as a place, as kc does
let place_follows():bool {
    if at_word(".") || at_word("[") || at_word("^") || at_word("=") || at_word(":=") { return true }
    if at_word("+=") || at_word("-=") || at_word("*=") || at_word("/=") || at_word("%=") { return true }
    if at_word("|=") || at_word("&=") || at_word("~=") || at_word("**=") || at_word("<<=") || at_word(">>=") { return true }   // (#276, #380, #387)
    return at_word("!") && adjacent(pos - 1, pos)
}

var chains = 0                                   // the names of chains kc makes (#221)

// the postfix steps after e: calls, members, indexes, x!, x?.m
let parse_steps(first:int64):int64 {
    var e:int64 = first
    while !failed {
        if at_word("?") && adjacent(pos - 1, pos) && pos + 1 < toks.count as int64 && (tok_is(pos + 1, ".") || tok_is(pos + 1, "[")) {
            let n = make_node(N_CHAIN, advance())    // x?.m, x?[i] (#221): the rest of the chain of what x holds
            chains += 1
            var name = $"_kv_chain"
            name += String(chains)
            nodes[n].c = made_token(&name)
            nodes[n].a = e
            nodes[n].b = parse_steps(make_node(N_ID, nodes[n].c))
            return n
        }
        if at_word("!") && adjacent(pos - 1, pos) {       // x! (#218): d[k]! the place, x! of an Optional x.some
            advance()
            if nodes[e].kind != N_INDEX {
                var word = $"some"
                let n = make_node(N_FIELD, made_token(&word))
                nodes[n].a = e
                e = n
            }
            continue
        }
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
            if !place_follows() { nodes[n].flag = 1 }    // read whole: a Dictionary's is an Optional (#218)
            e = n
        } else if at_word(".") {
            advance()
            let t:int64 = advance()
            if at_word("(") {
                advance()
                let n:int64 = make_node(N_METHOD, t)
                nodes[n].a = e
                if tok_is(t, "stride") && toks[pos].kind == T_ID && tok_is(pos + 1, ":") {   // r.stride(by: 2), as kelvinc says it (#379)
                    advance()
                    parse_error("'.stride' takes its step alone, as in 'r.stride(2)': Kelvin has no argument labels")
                }
                set_b(n, parse_args())
                if anon_ahead() {                        // x.m(a) { ... }: a function trailing, the last argument (#328)
                    let an:int64 = parse_anon()
                    if nodes[n].b < 0 {
                        nodes[n].b = an
                    } else {
                        var last:int64 = nodes[n].b
                        while nodes[last].next >= 0 { last = nodes[last].next }
                        nodes[last].next = an
                    }
                }
                e = n
            } else if (tok_is(t, "map") || tok_is(t, "filter") || tok_is(t, "flatMap") || tok_is(t, "mapWithKey") || tok_is(t, "filterWithKey") || tok_is(t, "flatMapWithKey") || tok_is(t, "contains") || tok_is(t, "firstKey") || tok_is(t, "lastKey") || tok_is(t, "containsWithKey") || tok_is(t, "firstKeyWithKey") || tok_is(t, "lastKeyWithKey") || tok_is(t, "firstIndex") || tok_is(t, "lastIndex") || tok_is(t, "prefix")) && anon_ahead() {   // x.map { ... }, its function trailing (#324), d.contains { ... } and the rest (#339), xs.firstIndex { ... } (#342), x.prefix { ... } (#372)
                let n:int64 = make_node(N_METHOD, t)
                nodes[n].a = e
                set_b(n, parse_anon())
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

let parse_postfix():int64 {
    return parse_steps(parse_primary())
}

let parse_unary():int64 {
    if at_word("!") && tok_is(pos + 1, "!") && adjacent(pos, pos + 1) {   // !!n, a bit's bool, flag 1 (#387)
        let t:int64 = advance()
        advance()
        let n:int64 = make_node(N_UNARY, t)
        nodes[n].flag = 1
        set_a(n, parse_unary())
        return n
    }
    if at_word("-") || at_word("!") || at_word("~") {     // ~ of a Bits (#387)
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
    if at_word("async") {                        // async f(x), a call on a thread of its own (#313)
        let t:int64 = advance()
        if at_word("{") {
            parse_error("'async' takes a call, as in 'async f(x)', which passes the function what it needs: a block would take the names around it, which Kelvin does not enclose")
            return -1
        }
        let n:int64 = make_node(N_ASYNC, t)
        set_a(n, parse_postfix())
        return n
    }
    if at_word("await") {                        // await t, its value (#313)
        let t:int64 = advance()
        let n:int64 = make_node(N_AWAIT, t)
        set_a(n, parse_unary())
        return n
    }
    var e:int64 = parse_postfix()
    if at_word("**") {                                   // b ** e (#380): tighter than a prefix on its left, right to left
        let t:int64 = advance()
        let n:int64 = make_node(N_BIN, t)
        nodes[n].a = e
        set_b(n, parse_unary())
        e = n
    }
    while at_word("as") || annotation_ahead() {          // x as T, x:T (#264)
        let t:int64 = advance()
        let n:int64 = make_node(N_CAST, t)
        nodes[n].a = e
        set_ty(n, parse_type())
        e = n
        if at_word("**") {                               // as kelvinc says it (#380)
            if tok_is(t, "as") {
                parse_error("'**' binds tighter than 'as': write '(x as T) ** y'")
            } else {
                parse_error("'**' binds tighter than ':': write '(x:T) ** y'")
            }
            return 0 - 1
        }
    }
    return e
}

// how tightly the operator at pos binds, 0 where it is none
let binding_power():int64 {
    if !at_kind(T_PUNCT) { return 0 }
    if at_word("||") { return 1 }
    if at_word("&&") { return 2 }
    if at_word("|") { return 3 }                 // | ~ &, between && and ==, as C's (#276)
    if at_word("~") { return 4 }
    if at_word("&") { return 5 }
    if at_word("==") || at_word("!=") || at_word("<") || at_word("<=") || at_word(">") || at_word(">=") { return 6 }
    if at_word("??") { return 8 }                // a value, or what an Optional holds (#217)
    if at_word("<<") || at_word(">>") { return 9 }    // between ranges and +, as C's (#387)
    if at_word("+") || at_word("-") { return 10 }
    if at_word("*") || at_word("/") || at_word("%") { return 11 }
    return 0                                     // 7 is a range's, ..< and ... (#373)
}

// whether the range whose ... was just read ends here, as lo... does
// (#373): what follows starts no value, or the next line
let range_ends():bool {
    if at_kind(T_NL) || at_kind(T_EOF) { return true }
    if !at_kind(T_PUNCT) { return false }
    return !(at_word("(") || at_word("-") || at_word("!") || at_word("&") || at_word("$[") || at_word("${") || at_word("[") || at_word("."))
}

let parse_binary(min:int64):int64 {
    var e:int64 = 0 - 1
    if min <= 7 && (at_word("..<") || at_word("...")) {      // ..<hi, ...hi, from 0 (#373)
        let t:int64 = advance()
        if range_ends() {
            var m = $"'"
            m += tok_text(t)
            m += "' before a value is a range from 0, as in '"
            m += tok_text(t)
            m += "10', and this has no end"
            parse_error(m.cstr)
            return 0 - 1
        }
        e = make_node(N_RANGE, t)
        range_values += 1
        if tok_is(t, "...") { nodes[e].flag = 1 }
        set_b(e, parse_binary(8))
    } else {
        e = parse_unary()
    }
    while !failed {
        if min <= 7 && (at_word("..<") || at_word("...")) {  // lo..<hi, lo...hi, lo... (#373)
            if nodes[e].kind == N_RANGE {
                parse_error("a range's bounds are integers, and this would be a range of a range")
                return 0 - 1
            }
            let t:int64 = advance()
            let r:int64 = make_node(N_RANGE, t)
            range_values += 1
            nodes[r].a = e
            if range_ends() {
                if tok_is(t, "..<") {
                    parse_error("'..<' needs an end, as in '0..<10'; a range without one is 'lo...'")
                    return 0 - 1
                }
                nodes[r].flag = 2
            } else {
                if tok_is(t, "...") { nodes[r].flag = 1 }
                set_b(r, parse_binary(8))
            }
            e = r
            continue
        }
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

// c ? a : b (#232), which binds the loosest and groups to the right; a
// ? right after a value and before . or [ is a chain's (#221)
let parse_expr():int64 {
    let e:int64 = parse_binary(1)
    if failed || !at_word("?") { return e }
    let n:int64 = make_node(N_COND, advance())
    nodes[n].a = e
    let saved = name_annotation
    name_annotation = false                      // c ? a : b's : (#265)
    set_b(n, parse_expr())
    name_annotation = saved
    expect(":")
    set_c(n, parse_expr())
    return n
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

// name:Type = value, its let or var read; without :Type, the type is
// what the value gives, found when it is written (#214); c is 1 of :=
let parse_var(is_let:int64):int64 {
    let t:int64 = advance()
    let n:int64 = make_node(S_VAR, t)
    nodes[n].flag = is_let
    if at_word(":") {
        advance()
        set_ty(n, parse_type())
    }
    if at_word("=") || at_word(":=") {          // := of a reference, as a cstr
        if at_word(":=") { nodes[n].c = 1 }
        advance()
        set_a(n, parse_expr())
    }
    return n
}

// a parameter or a member, whose type is written
let parse_typed(is_let:int64):int64 {
    if toks[pos + 1].kind != T_PUNCT || !tok_is(pos + 1, ":") { parse_error("a parameter or a member says its type: name:T") }
    return parse_var(is_let)
}

let parse_if():int64 {
    let n:int64 = make_node(S_IF, advance())
    if at_word("let") {                          // if let c(x) = e { } (#217): t c, flag x
        advance()
        nodes[n].kind = S_IFLET
        nodes[n].t = advance()
        expect("(")
        nodes[n].flag = advance()
        expect(")")
        expect("=")
    }
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
    var last = -1
    while !at_word("}") && !failed {
        let c:int64 = make_node(S_CASE, pos)
        if at_word("default") {
            advance()
            nodes[c].flag = 1
        } else {
            expect("case")
            var lastv = -1
            let saved = name_annotation
            name_annotation = false              // case a: b, the case's : (#265)
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
            name_annotation = saved
        }
        expect(":")
        skip_newlines()
        var lasts = -1
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
        let is_let = 0
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
        var second = -1
        if at_word(",") {                       // for k, v in d (#269)
            advance()
            second = advance()
        }
        expect("in")
        let from:int64 = parse_expr()
        if !failed && nodes[from].kind == N_RANGE {      // for i in a..<b; a...b, a..., ..<b, ...b, flag as the range's (#373)
            let n:int64 = make_node(S_FOR, v)
            nodes[n].a = nodes[from].a
            nodes[n].b = nodes[from].b
            nodes[n].flag = nodes[from].flag
            range_values -= 1
            set_c(n, parse_block())
            return n
        }
        let n:int64 = make_node(S_EACH, v)
        nodes[n].a = from
        if second >= 0 { nodes[n].b = make_node(N_ID, second) }   // for k, v in d (#269)
        set_c(n, parse_block())
        return n
    }
    if at_word("return") {
        let n:int64 = make_node(S_RETURN, advance())
        if !at_kind(T_NL) && !at_word("}") && !at_word(";") { set_a(n, parse_expr()) }
        end_statement()
        return n
    }
    if at_word("break") || at_word("continue") || at_word("fallthrough") {
        var kind:nkind = S_BREAK
        if at_word("continue") { kind = S_CONTINUE }
        if at_word("fallthrough") { kind = S_FALL }       // Swift's (#386)
        let n:int64 = make_node(kind, advance())
        end_statement()
        return n
    }
    if at_word("{") {
        return parse_block()
    }
    let e:int64 = parse_expr()
    if at_word("=") || at_word(":=") || at_word("+=") || at_word("-=") || at_word("*=") || at_word("/=") || at_word("%=") || at_word("|=") || at_word("&=") || at_word("~=") || at_word("**=") || at_word("<<=") || at_word(">>=") {
        let n:int64 = make_node(S_ASSIGN, advance())        // := of a reference (#233)
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
    var last = -1
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
    var last = -1
    while !at_word(")") && !failed {
        var is_let = 1
        if at_word("var") {                     // a var parameter may change (#271)
            advance()
            is_let = 0
        }
        let p:int64 = parse_typed(is_let)
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
    var last = -1
    skip_newlines()
    while !at_word("}") && !failed {
        let f:int64 = parse_typed(0)
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

// enum t { a, b = 3, c }, C's enum (#210); enum t { none; n: int64 },
// an enum with values (#215), where a case says the type of its value:
// then the enum's flag is 1, and each case's ty its value's, or -1
let parse_enum():int64 {
    let n:int64 = make_node(D_ENUM, advance())
    expect("{")
    skip_newlines()
    var last = -1
    while !at_word("}") && !failed {
        let m:int64 = make_node(N_ID, advance())
        if at_word(":") {
            advance()
            set_ty(m, parse_type())
            nodes[n].flag = 1
        } else if at_word("=") {
            advance()
            set_a(m, parse_expr())
        }
        if last < 0 {
            nodes[n].a = m
        } else {
            nodes[last].next = m
        }
        last = m
        if at_word(",") || at_word(";") { advance() }
        skip_newlines()
    }
    expect("}")
    return n
}

// extend T { let m(...) ... static let f(...) ... } (#213): a method takes
// self, a T, first; a function of the type, static, does not; each goes
// into decls as a D_FN whose c is T's token, its flag 1 where static, 2
// for a var method, var m(...), whose self is the caller's var (#320)
let parse_extend() {
    let recv:int64 = advance()
    self_name = recv
    expect("{")
    skip_newlines()
    while !at_word("}") && !failed {
        var is_static = 0
        if at_word("static") {
            advance()
            is_static = 1
        }
        if is_static == 0 && at_word("var") {
            advance()
            is_static = 2
        } else if is_static == 1 && at_word("var") {
            parse_error("a function of the type has no self to change: write 'static let'")
            return
        } else {
            expect("let")
        }
        let n:int64 = parse_function()
        nodes[n].c = recv
        nodes[n].flag = is_static
        decls += n
        skip_newlines()
    }
    expect("}")
    self_name = 0 - 1
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
        } else if (at_word("let") || at_word("var")) && tok_is(pos + 2, ".") && tok_is(pos + 4, "(") {   // let T.m(...) (#213)
            let is_var = at_word("var")                     // var T.m(...), self the caller's var (#320)
            advance()
            let recv:int64 = advance()
            advance()
            self_name = recv
            let n:int64 = parse_function()
            nodes[n].c = recv
            if is_var { nodes[n].flag = 2 }
            self_name = 0 - 1
            decls += n
        } else if at_word("extend") {
            advance()
            parse_extend()
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
