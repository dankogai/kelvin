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
    N_TYPE,     // IO, String or Bytes called: a type's name as a function
    N_INIT,     // {b...}, a struct's members in order; ty of (T){b...}, C's compound literal (#418)
    N_NULL,     // nowhere (#446)
    N_SELF,     // self, and the self of .x (#213)
    N_CHAIN,    // a?.rest (#221): b the rest, of the name c bound to what a holds; t the ?
    N_COND,     // a ? b : c (#232); t the ?
    N_ASYNC,    // async a, a call on a thread of its own (#313)
    N_AWAIT,    // await a, a Task's value (#313)
    N_ANON,     // { (a...):ty in b } or { b } of $0, an anonymous function (#324); flag 1 of $0, 2 of { v in b } (#330)
    N_ITER,     // Iterator<ty>(a) b or Iterator(a, b), a state and a function of it (#326)
    N_LIST,     // [b...], a fixed array's elements (#354); flag 1 of [ty](a), a zero elements; ty of ([T](N))[b...], C's compound literal (#419)
    N_MAKE,     // Array<T>(), Dictionary<K, V>(): an empty one of ty (#349); flag 1 of no (), 2 of what kc does not make;
                // of an Array (#350), flag 3 of [b...], the elements, 4 of &a, a copy, 5 of a, a count, 6 of more after [...], 7 of more than one;
                // of a Dictionary (#351), flag 3 of {k: v}, a the literal, 4 of &a, 5 of a, 6 of more, c the token
    N_RANGE,    // a..<b, a...b (flag 1), a... (flag 2, b -1); ..<b and ...b, a -1 of 0 (#373); ty the Range<T> it is
    N_RITER,    // the Iterator<T> of the Range a, which kc makes for its lazy and prefix { ... } (#373)
    N_ALIGN,    // alignof(ty) (#395), C's _Alignof
    N_DESIG,    // .t = a in {...}, C's designator (#418)
    N_ADESIG,   // [c] = a in [...], C's designator of an element (#715)
    N_SIZEOF,   // sizeof(ty), or sizeof a of a value (#420), C's sizeof; flag 1 of sizeof ty, an error, 2 of sizeof(x.type) (#421)
    N_TRY,      // try a (#449): a's ok (some), or a return of its err (none)
    N_TPL,      // `a${x}b` (#445): b the first of its parts, N_STR, and values in turn; flag 1 of $`...`, a String
    N_COMMA,    // (a, b), C's comma operator: b's value, after a (#652)
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
    S_ASSERT,   // static_assert(a, b...) (#394): c the condition's first token, flag the token after it, b the message's first or -1
    S_BLOCK,    // a, the first statement
    S_SWITCH,   // switch a { b, the first case }
    S_CASE,     // case a...: b...; flag 1 of default
    S_IFLET,    // if let t(flag) = a { b } else c (#217); if let flag = a, t flag too (#442)
    S_CFOR,     // for (a...; b; flag...) c, C's (#458): a its first init statement, flag its first step, each -1 where none
    S_DO,       // do { b } while a, C's (#459)
    S_LABEL,    // t: a label, C's (#715)
    S_GOTO,     // goto t, C's (#715)
    // declarations
    D_FN,       // t(a...):ty { b }, b -1 for a prototype; of a type c, flag 1 static, 2 a var method (#320)
    D_STRUCT,   // t { a... }
    D_GLOBAL,   // as S_VAR
    D_IMPORT,
    D_ENUM,     // enum t { a... }, each an N_ID, its a a value or -1
    D_ASSERT    // as S_ASSERT, at the top level (#394)
}

enum ykind {                    // the kinds of types (#210)
    Y_VOID,
    Y_I64,
    Y_I32,
    Y_U8,
    Y_U32,
    Y_I8,       // the rest of kelvinc's integers (#472)
    Y_I16,
    Y_U16,
    Y_U64,
    Y_I128,     // C's __int128, where the C compiler has it
    Y_U128,
    Y_F64,      // float64 (#262)
    Y_F32,      // float32 (#263)
    Y_BOOL,
    Y_CSTR,
    Y_STRING,
    Y_BYTES,    // a Bytes (#439): kv_bytes in C
    Y_IO,
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
    Y_TYPEOF,   // x.type of a local whose type is inferred (#423): its name x's node, whose type gen tells
    Y_FN,       // a function type (#428), (T, U):R: its result elem, -1 of none; its parameters name, a Y_PARAM or -1
    Y_PARAM,    // a parameter of a function type (#428): its type elem; the next name, a Y_PARAM or -1
    Y_C         // what only C sees: a name of a C header (#207)
}

// whether k is an integer's kind; signed; unsigned (#472)
let is_signed_kind(k:ykind):bool {
    return k == Y_I8 || k == Y_I16 || k == Y_I32 || k == Y_I64 || k == Y_I128
}

let is_unsigned_kind(k:ykind):bool {
    return k == Y_U8 || k == Y_U16 || k == Y_U32 || k == Y_U64 || k == Y_U128
}

let is_int_kind(k:ykind):bool {
    return is_signed_kind(k) || is_unsigned_kind(k)
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
    konst: int64       // 1 of [const T](N), a fixed array of const elements (#425)
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
        return .kind == Y_STRING || .kind == Y_BYTES || .kind == Y_ARRAY || .kind == Y_IO || .kind == Y_DICT || .kind == Y_SET || .kind == Y_TASK || .kind == Y_ITER
    }
}

var nodes:$[node]
var types:$[ty]
var decls:$[int64]         // the top-level declarations, in order
var arrays:$[int64]        // every Array type, in the order they are met
var dicts:$[int64]         // every Dictionary type, so (#211)
var sets:$[int64]          // every Set type, so (#274)
var fn_types:$[int64]      // every function type, so (#428)
var pos:int64              // the next token
var c_headers:bool         // whether a C header is imported: then a name kc does not know is C's (#207)
var self_name:int64 = 0 - 1    // the token of the type whose method is being read, for Self (#213)
var nested_of:Dictionary<String, int64>    // a type defined in a struct (#389), by its C name, point__kind: its token, of that name
var outer_of:Dictionary<String, int64>     // and the token of the struct it is defined in
var own_of:Dictionary<String, int64>       // and its own name's token, kind
var records_seen:Dictionary<String, int64> // every struct and enum read so far, by its C name (#389)
var fn_aliases:Dictionary<String, int64>   // typealias op = (i64):i64, by the alias's name (#403, #550)
var body_struct:int64 = 0 - 1  // the token of the struct whose body is being read, which names its nested types bare (#389)
var nest_outer:int64 = 0 - 1   // the token of the struct a nested definition is read in (#389)
var late_seen = false          // whether the program has an x.type gen tells (#423)
var brace_ends = false         // whether a { at the cursor ends a condition, its body's: as kelvinc's brace_ends_condition (#470)
var anon_depth:int64 = 0       // how many anonymous functions the cursor is in, whose $0.type gen tells (#424)
var anon_head:int64 = 0        // how many anonymous functions' parameters and result the cursor is in (#654)
var anon_head_from:int64 = 0   // locals_seen's count where the head began: those before are the function's around it
var anon_named:$[int64]        // the names of { v in ... }'s parameters the cursor is among (#424)
var literal_brace = false      // whether the { at the cursor is a compound literal's, (T){$0.y, $0.x} (#424)
var locals_seen:$[int64]       // the names declared in the function being read, which a nested type's bare name yields to (#389)
var local_types:$[int64]       // the types defined in the blocks being read (#391): the tokens kc names them by, _kv_main_point
var local_type_depths:$[int64] // and the depth of the block each is in
var local_enums:$[int64]       // the enumerators of the enums so defined, by their tokens, _kv_main_red
var local_fns:$[int64]         // the functions defined inside a function, by their tokens, _kv_main_fib (#180, #697)
var local_fn_depths:$[int64]   // and the depth of the block each is in
var local_enum_depths:$[int64]
var local_own_of:Dictionary<String, int64>   // each one's own name's token, by its C name
var ended_types:$[int64]       // the types of the function whose blocks have ended
var hidden_seen:Dictionary<String, int64>    // the C names given so, each once
var block_depth:int64 = 0
var fn_tok:int64 = 0 - 1       // the token of the function being read, which names them
var local_next = false         // the struct or enum parse_struct or parse_enum reads is defined in a block (#391)
var inline_fns:$[int64]        // the functions written inline (#392), C's static inline
var static_decls:$[int64]      // the functions, globals and locals written static, C's (#459)
var extern_decls:$[int64]      // and those written extern, declared for C's
var thread_decls:$[int64]      // and those written thread_local, each thread's own, C's _Thread_local (#641)
var variadic_fns:$[int64]      // the functions whose parameters end in ..., C's variadic ones (#453)
var c_tags:Dictionary<String, int64>   // struct T; and union T;, C's, -2 or -3 by T (#453)
var c_tag_types:$[int64]       // and their types, which gen declares so
var align_expr:int64 = 0 - 1   // alignas(N) before the declaration being read (#396): N
var align_type:int64 = 0 - 1   // or alignas(T): T
var align_tok:int64 = 0 - 1
var aligned:$[int64]           // the variables and members so declared, and their N or T in turn
var aligned_exprs:$[int64]
var aligned_types:$[int64]
var made_enums:Dictionary<String, int64>   // the enums kc makes of T? and Result<T, E>, by name (#217)
var anon_keys:Dictionary<String, int64>    // the types with no tag (#476), {x:f64, y:f64}, by their members' names and types
var anon_decls:Dictionary<String, int64>   // and each one's declaration by its C name, _kv_anonN
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
        if y.kind == kind && y.elem == elem && y.konst == 0 {
            if kind == Y_STRUCT {
                if same_text(y.name, name) { return i }
            } else if kind == Y_DICT || kind == Y_PTR || kind == Y_FIXED || kind == Y_TYPEOF || kind == Y_FN || kind == Y_PARAM || kind == Y_CSTR {
                if y.name == name { return i }   // a pointer's name 1 where what it points to is const (#272); a fixed array's count (#354)
            } else {
                return i
            }
        }
        i += 1
    }
    let y:ty = {kind, elem, name, 0}
    types += y
    if kind == Y_ARRAY { arrays += types.count as int64 - 1 }
    if kind == Y_DICT { dicts += types.count as int64 - 1 }
    if kind == Y_SET { sets += types.count as int64 - 1 }
    if kind == Y_FN { fn_types += types.count as int64 - 1 }
    return types.count as int64 - 1
}

// [const T](N) of the fixed array y, its elements const (#425): a type
// of its own, as type_of_kind makes none
let const_fixed(y:int64):int64 {
    if types[y].konst == 1 { return y }
    for i in 0..<types.count as int64 {
        if types[i].konst == 1 && types[i].elem == types[y].elem && types[i].name == types[y].name { return i }
    }
    let c:ty = {Y_FIXED, types[y].elem, types[y].name, 1}
    types += c
    return types.count as int64 - 1
}

// const T of the number or bool y, konst 1, as [const T](N) is: what
// typeof(x) of a let gives, its const kept, as C23's typeof keeps it and
// kelvinc's (#398, #708)
let const_number(y:int64):int64 {
    if types[y].konst == 1 { return y }
    for i in 0..<types.count as int64 {
        if types[i].konst == 1 && types[i].kind == types[y].kind && types[i].elem == types[y].elem && types[i].name == types[y].name { return i }
    }
    let c:ty = {types[y].kind, types[y].elem, types[y].name, 1}
    types += c
    return types.count as int64 - 1
}

// whether the variable that token t names is a let, its latest
// declaration's (#708)
let written_let(t:int64):bool {
    var i:int64 = nodes.count as int64 - 1
    while i >= 0 {
        let k = nodes[i].kind
        if (k == S_VAR || k == D_GLOBAL) && same_text(nodes[i].t, t) { return nodes[i].flag == 1 }
        i -= 1
    }
    return false
}

// the fixed array y without const elements, [T](N) of [const T](N) (#425)
let plain_fixed(y:int64):int64 {
    if y < 0 || types[y].konst == 0 { return y }
    return type_of_kind(Y_FIXED, types[y].elem, types[y].name)
}

let base_type(kind:ykind):int64 {
    return type_of_kind(kind, -1, -1)
}

// the function type of the parameters ps and the result r, -1 of none
// (#428): its parameters a chain of Y_PARAMs, made from the last, so that
// one type is one index
let fn_type_of(ps:const $[int64]^, r:int64):int64 {
    var chain:int64 = 0 - 1
    var k:int64 = ps^.count as int64 - 1
    while k >= 0 {
        chain = type_of_kind(Y_PARAM, ps^[k], chain)
        k -= 1
    }
    return type_of_kind(Y_FN, r, chain)
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

// the number type the word t names, kelvinc's full name or its short one,
// int64 or i64 (#151, #430), or -1
// a number type's word at t in its short spelling: int32 is i32, float64 f64
let kelvin_type_text(y:int64):String    // a prototype: gen.k's, a type in kelvinc's words
let is_number_kind(k:ykind):bool    // a prototype: gen.k's, of atomic's types (#642)

let short_number(t:int64):String {
    if tok_is(t, "float64") { return $"f64" }
    if tok_is(t, "float32") { return $"f32" }
    var s = codes[toks[t].at] == 'u' ? $"u" : $"i"
    var k:int64 = 0
    while k < toks[t].len && !is_digit(codes[toks[t].at + k]) { k += 1 }
    if k == toks[t].len { return tok_text(t) }
    while k < toks[t].len {
        s += codes[toks[t].at + k]
        k += 1
    }
    return s
}

let number_word(t:int64):int64 {
    if tok_is(t, "int64") || tok_is(t, "i64") { return base_type(Y_I64) }
    if tok_is(t, "int32") || tok_is(t, "i32") { return base_type(Y_I32) }
    if tok_is(t, "uint8") || tok_is(t, "u8") { return base_type(Y_U8) }
    if tok_is(t, "uint32") || tok_is(t, "u32") { return base_type(Y_U32) }
    if tok_is(t, "int8") || tok_is(t, "i8") { return base_type(Y_I8) }   // (#472)
    if tok_is(t, "int16") || tok_is(t, "i16") { return base_type(Y_I16) }
    if tok_is(t, "uint16") || tok_is(t, "u16") { return base_type(Y_U16) }
    if tok_is(t, "uint64") || tok_is(t, "u64") { return base_type(Y_U64) }
    if tok_is(t, "int128") || tok_is(t, "i128") { return base_type(Y_I128) }
    if tok_is(t, "uint128") || tok_is(t, "u128") { return base_type(Y_U128) }
    if tok_is(t, "float64") || tok_is(t, "f64") { return base_type(Y_F64) }
    if tok_is(t, "float32") || tok_is(t, "f32") { return base_type(Y_F32) }
    return 0 - 1
}

// whether the : at the cursor annotates a value with a type, 0.1:float32,
// as kelvinc's x:T (#264): a type's word follows, and no ( or <, which
// would make the value of the other arm of c ? a : b, or a case's body,
// nor in those a ., which reads the type's attribute, f64.infinity (#578);
// a struct's name or a C typedef's, p:point, n:size_t (#265), but where
// the : is ?:'s or a case's
let annotation_ahead():bool {
    if !at_word(":") || pos + 2 >= toks.count as int64 || toks[pos + 1].kind != T_ID { return false }
    if tok_is(pos + 2, "(") || tok_is(pos + 2, "<") { return false }
    if !name_annotation && tok_is(pos + 2, ".") { return false }   // c ? x : f64.infinity, the type's attribute (#578)
    let t:int64 = pos + 1
    if number_word(t) >= 0 || tok_is(t, "bool") || tok_is(t, "cstr") {
        return true
    }
    if tok_is(t, "struct") || tok_is(t, "union") || tok_is(t, "enum") { return true }   // p:struct node^, as kelvinc's (#453)
    return name_annotation
}

// an error at the end of file f, as kelvinc says one there (#652)
let parse_error_at_end(f:int64, what:cstr) {
    if !failed {
        let said:String = as_shown(what)
        let at:String = file_end_text(f)
        println(at, ": error: ", said)
    }
    failed = true
    pos = eof_pos
}

// whether token t is past the file of token from: the end, or another file's
let past_file(t:int64, from:int64):bool {
    return toks[t].kind == T_EOF || toks[t].file != toks[from].file
}

// what is found at token t, in kelvinc's words: the end of the program's
// file, or of an imported one, or the token
let found_text(t:int64, from:int64):String {
    if past_file(t, from) {
        if toks[from].file == 0 { return $"end of file" }
        var s = $"the end of "
        s += &fnames[toks[from].file]
        return s
    }
    if toks[t].kind == T_TPL_HEAD { return $"a template literal" }
    if toks[t].kind == T_TPL_MID || toks[t].kind == T_TPL_TAIL { return $"'}', the end of ${...}" }
    var s = $"'"
    let w:String = tok_text(t)
    s += &w
    s += "'"
    return s
}

let parse_error(what:cstr) {
    if !failed {
        let said:String = as_shown(what)                    // (#600)
        let at:String = error_at_text(pos)                  // file:line:col, as kelvinc's (#652)
        println(at, ": error: ", said)
    }
    failed = true
    pos = eof_pos                       // the end: every loop stops
}

let parse_error_at(t:int64, what:cstr)    // a prototype

// whether token t is a word kelvinc keeps, C11's and Kelvin's own, as
// src/lexer.c lists them: it names no variable (#611)
var kept_words:Dictionary<String, bool>

let kept_word(t:int64):bool {
    if toks[t].kind != T_ID { return false }
    if kept_words.count == 0 {
        let all:cstr := "as i8 i16 i32 i64 i128 u8 u16 u32 u64 u128 f32 f64 bool true false String any nowhere nullptr cstr Bytes Array Dictionary Set Optional Result IO OS SYS try let var Task async await Iterator Range fallthrough static_assert alignof alignas typeof auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while _Alignas _Alignof _Atomic _Bool _Generic _Imaginary _Noreturn _Static_assert _Thread_local"
        var w = $""
        var i = 0
        while all[i] != 0 {
            if all[i] as uint32 == ' ' {
                kept_words[w] = true
                w = $""
            } else {
                w += all[i] as uint32
            }
            i += 1
        }
        kept_words[w] = true
    }
    return kept_words.get(tok_text(t), false)
}

// a name declared at token t that starts with _kv_ is kelvinc's own, in
// the C it writes, and one with kv_ or KV_ its runtime's, as kelvinc's
// reject_kv_name says them (#611); the prelude's files name the runtime's
let reject_kv_name(t:int64) {
    if failed || toks[t].kind != T_ID || t >= eof_pos { return }
    if tok_starts(t, "_kv_own_") { return }              // the files' own type of a prelude's name (#600)
    var m = $""
    if tok_starts(t, "_kv_") {
        m = $"names starting with _kv_ are kelvinc's own, in the C it writes: rename '"
    } else if (tok_starts(t, "kv_") || tok_starts(t, "KV_") || tok_is(t, "KELVIN_PRELUDE_H")) && !prelude_file(toks[t].file) {
        m = $"names starting with kv_ or KV_ are kelvinc's runtime's: rename '"
    } else {
        return
    }
    m += tok_text(t)
    m += "'"
    parse_error_at(t, m.cstr)
}

// a let needs a value, as kelvinc says it (#27, #611): n is one declared
// with none
let let_needs_value(n:int64) {
    if !at_kind(T_NL) && !at_kind(T_EOF) && !at_word(";") && !at_word(",") && !at_word("}") && !at_word(")") { return }   // what kc does not read is its own error
    var m = $"a let needs a value: write 'let "
    m += tok_text(nodes[n].t)
    m += " = ...', or 'var "
    m += tok_text(nodes[n].t)
    m += "' if it changes later"
    parse_error_at(nodes[n].t, m.cstr)
}

// an error at token t, not at the cursor (#611)
let parse_error_at(t:int64, what:cstr) {
    if !failed {
        let said:String = as_shown(what)
        let at:String = error_at_text(t)                    // file:line:col, as kelvinc's (#652)
        println(at, ": error: ", said)
    }
    failed = true
    pos = eof_pos
}

let advance():int64 {
    let t:int64 = pos
    if pos < eof_pos { pos += 1 }
    return t
}

let expect(w:cstr) {
    if !at_word(w) {
        if at_assign() {                                 // (c = getchar()), a[i += 1], as kelvinc says it
            parse_error("assignment is a statement in Kelvin, not a value: assign on a line of its own")
            return
        }
        var m = $"expected '"                            // as kelvinc's expect_p says it
        m += w
        m += "', found "
        let d:String = tok_desc(pos)
        m += &d
        parse_error(m.cstr)
        return
    }
    advance()
}

// a token as kelvinc's desc names it in a message: 'x', a template
// literal, end of file; past a line's end, the token after it
let tok_desc(t0:int64):String {
    var t:int64 = t0
    while t < eof_pos && toks[t].kind == T_NL { t += 1 }
    if t >= eof_pos || toks[t].kind == T_EOF { return $"end of file" }
    if toks[t].kind == T_TPL_HEAD { return $"a template literal" }
    var s = $"'"
    s += tok_text(t)
    s += "'"
    return s
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
    for c in s^.codepoints {
        codes += c
    }
    let t:tok = {T_ID, at, codes.count as int64 - at, 0, 0}
    toks += t
    return toks.count as int64 - 1
}

// ---------- types nested in a struct (#389) ----------

// the token of the type nested in the one named by token o as token w's
// text names, o.w, or -1
let nested_tok(o:int64, w:int64):int64 {
    var name:String = tok_text(o)
    name += "__"
    let own:String = tok_text(w)
    name += &own
    return nested_of.get(name, -1)
}

// whether token t is a type kc names, point__kind, for one nested (#389)
let is_nested(t:int64):bool {
    let name:String = tok_text(t)
    return nested_of.get(name, -1) == t
}

// the type a bare name w names where it is written, as kelvinc's, Swift's:
// one nested in the struct whose body or method this is, or in one around
// it, else w itself
let scoped_type(w:int64):int64 {
    var s:int64 = body_struct
    while s >= 0 {
        let n:int64 = nested_tok(s, w)
        if n >= 0 { return n }
        let name:String = tok_text(s)
        s = outer_of.get(name, -1)
    }
    var i:int64 = local_types.count as int64 - 1
    while i >= 0 {                                       // one defined in a block around it (#391)
        let u:int64 = local_types[i]
        if same_text(local_own_of.get(tok_text(u), -1), w) { return u }
        i -= 1
    }
    s = body_struct >= 0 ? 0 - 1 : self_name
    while s >= 0 {
        let n:int64 = nested_tok(s, w)
        if n >= 0 { return n }
        let name:String = tok_text(s)
        s = outer_of.get(name, -1)
    }
    return w
}

// the token kc names a type or an enumerator defined in a block by (#391),
// _kv_main_point, then _kv_main_point1, 2, ..., as kelvinc names it
let hidden_token(t:int64):int64 {
    var k:int64 = 0
    while true {
        var name = $"_kv_"
        let f:String = fn_tok >= 0 && toks[fn_tok].kind != T_PUNCT ? tok_text(fn_tok) : fn_tok >= 0 ? $"op" : $"local"   // of an operator, no name C reads (#471)
        name += &f
        name += "_"
        let own:String = tok_text(t)
        name += &own
        if k > 0 { name += String(k) }
        if hidden_seen.get(name, -1) < 0 {
            let u:int64 = made_token(&name)
            toks[u].line = toks[t].line
            toks[u].file = toks[t].file
            hidden_seen[name] = u
            local_own_of[name] = t
            return u
        }
        k += 1
    }
    return t
}

// the enumerator of an enum defined in a block that token t names (#391),
// its token, or -1
let local_enum_named(t:int64):int64 {
    var i:int64 = local_enums.count as int64 - 1
    while i >= 0 {
        let u:int64 = local_enums[i]
        if same_text(local_own_of.get(tok_text(u), -1), t) { return u }
        i -= 1
    }
    return 0 - 1
}

// the function defined inside a function that token t names in its
// block (#180, #697), its hidden token, or -1
let local_fn_named(t:int64):int64 {
    var i:int64 = local_fns.count as int64 - 1
    while i >= 0 {
        let u:int64 = local_fns[i]
        if same_text(local_own_of.get(tok_text(u), -1), t) { return u }
        i -= 1
    }
    return 0 - 1
}

// the type written for the variable that token t names (#398): its
// latest declaration's, -1 where its type is inferred, -2 where none is
let written_type(t:int64):int64 {
    var i:int64 = nodes.count as int64 - 1
    while i >= 0 {
        let k = nodes[i].kind
        if (k == S_VAR || k == D_GLOBAL) && same_text(nodes[i].t, t) { return nodes[i].ty }
        i -= 1
    }
    return 0 - 2
}

// whether the function being read declares a name as token t's
let local_named(t:int64):bool {
    for l in locals_seen {
        if same_text(l, t) { return true }
    }
    return false
}

// whether token t is an anonymous function's $0, $1, ..., whose type gen
// knows alone (#424)
let dollar_named(t:int64):bool {
    return toks[t].kind == T_ID && toks[t].len > 1 && codes[toks[t].at] == '$'
}

// whether token t names a parameter of { v in ... } the cursor is in
// (#424), typed where the function goes
let anon_param(t:int64):bool {
    for v in anon_named {
        if same_text(v, t) { return true }
    }
    return false
}

// whether the program declares, so far, a global, a function, a struct or
// an enum named as token t's (#416)
let program_named(t:int64):bool {
    for d in nodes {
        if (d.kind == D_GLOBAL || d.kind == D_FN || d.kind == D_STRUCT || d.kind == D_ENUM) && same_text(d.t, t) { return true }
    }
    return false
}

// whether struct T, union T or enum T starts at token t, C's spelling of
// a type (#453)
let tagged_word(t:int64):bool {
    return (tok_is(t, "struct") || tok_is(t, "union") || tok_is(t, "enum")) && toks[t + 1].kind == T_ID
}

// whether the program's struct, union or enum named by token t is one of
// C's word tag, -2 struct, -3 union, -4 enum (#453)
let record_tagged(t:int64, tag:int64):bool {
    if records_seen.get(tok_text(t), -1) < 0 { return false }
    for d in nodes {
        if d.kind == D_STRUCT && same_text(d.t, t) { return tag == (d.flag == 1 || d.flag == 3 ? 0 - 3 : 0 - 2) }
        if d.kind == D_ENUM && same_text(d.t, t) { return tag == (d.flag == 1 ? 0 - 2 : 0 - 4) }
    }
    return false
}

// the structs, unions and enums at the top of every file, by name, the
// token of each one's word (#550): kc parses the program's file before
// the files it imports, so a type of one of them, c64 of <math>, is not
// declared so far where the program writes (c64){...} or sizeof(c64), as
// it is to kelvinc, which reads an imported file where its #import stands
var far_records:Dictionary<String, int64>

let scan_records() {
    var depth = 0
    for k in 0..<eof_pos {
        if toks[k].kind == T_PUNCT {
            if tok_is(k, "{") || tok_is(k, "${") { depth += 1 }
            if tok_is(k, "}") { depth -= 1 }
        } else if toks[k].kind == T_ID && depth == 0 && toks[k + 1].kind == T_ID && tok_is(k + 2, "{") && (tok_is(k, "struct") || tok_is(k, "union") || tok_is(k, "enum")) {
            if k == 0 || toks[k - 1].kind == T_NL || tok_is(k - 1, ";") || toks[k - 1].file != toks[k].file { far_records[tok_text(k + 1)] = k }
        }
    }
}

// whether token t names a struct or a union, or an enum where enums is,
// at the top of another file than its own
let far_record(t:int64, enums:bool):bool {
    if far_records.count == 0 { return false }
    let w:int64 = far_records.get(tok_text(t), 0 - 1)
    if w < 0 || toks[w].file == toks[t].file { return false }
    return enums || !tok_is(w, "enum")
}

// whether token t names the type of a compound literal, (T){...} (#418):
// Self in a method, or a struct declared so far, a block's and a nested
// one's too, which a variable or a function of the name leaves the type
// before {, as kelvinc reads it
let literal_type(t:int64):bool {
    if tok_is(t, "Self") { return self_name >= 0 }
    let u:int64 = scoped_type(t)
    for d in nodes {
        if (d.kind == D_STRUCT || (d.kind == D_ENUM && d.flag == 1)) && same_text(d.t, u) { return true }   // an enum with values' too, (shape){.rect = ...} (#714)
    }
    return far_record(t, false)                          // one of a file imported (#550)
}

// whether ([T](N))[ or ([T])[ starts here, an array's compound literal
// (#419), as kelvinc tells it from (p)[i]: parentheses that open with [,
// and a [ right after them
let value_type_end():int64    // a prototype: (xs.type)[a, b] is one too (#696)

let array_literal_ahead():bool {
    if !at_word("(") { return false }
    if !tok_is(pos + 1, "[") {                           // (xs.type)[7, 8, 9], of a variable's type, as kelvinc's (#696)
        let e:int64 = value_type_end()
        return e >= 0 && tok_is(e + 1, "[") && (local_named(pos + 1) || written_type(pos + 1) != 0 - 2)
    }
    var depth = 0
    var k:int64 = pos
    while k < toks.count as int64 {
        if tok_is(k, "(") || tok_is(k, "[") || tok_is(k, "$[") || tok_is(k, "{") || tok_is(k, "${") { depth += 1 }
        if tok_is(k, ")") || tok_is(k, "]") || tok_is(k, "}") {
            depth -= 1
            if depth == 0 { return tok_is(k, ")") && tok_is(k + 1, "[") }
        }
        k += 1
    }
    return false
}

let value_type_end():int64    // a prototype: (x.type){...} is a compound literal (#422)

// whether (T){ starts here, its { on the line of the (T) (#418), or
// (x.type){ of a variable's type (#422)
let compound_ahead():bool    // a prototype: (T){ at the cursor, written so (#715)

// whether (T){ starts a compound literal here: in a condition only where
// the expression goes on after its }, as kelvinc's brace_is_compound, so
// that 'if n > sizeof(int64) {' opens the body (#715)
let literal_ahead():bool {
    if !compound_ahead() { return false }
    if !brace_ends { return true }
    var k:int64 = pos
    var depth:int64 = 0
    while toks[k].kind != T_EOF {                        // past the (T)
        if tok_is(k, "(") { depth += 1 }
        if tok_is(k, ")") {
            depth -= 1
            if depth == 0 { break }
        }
        k += 1
    }
    k += 1                                               // its {
    depth = 0
    while toks[k].kind != T_EOF {
        if tok_is(k, "{") || tok_is(k, "${") { depth += 1 }
        if tok_is(k, "}") {
            depth -= 1
            if depth == 0 { break }
        }
        k += 1
    }
    let nx:int64 = k + 1
    if tok_is(nx, ".") || tok_is(nx, "[") || tok_is(nx, "^") || tok_is(nx, "?") || tok_is(nx, "as") || tok_is(nx, "..<") || tok_is(nx, "...") { return true }   // a range's too, for i in (i64){1}..<3 {
    let back:int64 = pos
    pos = nx
    let p:int64 = binding_power()                        // a binary operator after it goes on too
    pos = back
    return p > 0
}

let compound_ahead():bool {
    if at_word("(") && (tok_is(pos + 1, "{") || ((tok_is(pos + 1, "struct") || tok_is(pos + 1, "union") || tok_is(pos + 1, "enum")) && tok_is(pos + 2, "{"))) {
        var k:int64 = tok_is(pos + 1, "{") ? pos + 1 : pos + 2   // ({x:f64, y:f64}){...}, of a type with no tag (#476)
        var depth = 0
        while k < toks.count as int64 {
            if tok_is(k, "{") || tok_is(k, "${") || tok_is(k, "(") || tok_is(k, "[") || tok_is(k, "$[") { depth += 1 }
            if tok_is(k, "}") || tok_is(k, ")") || tok_is(k, "]") {
                depth -= 1
                if depth == 0 { return tok_is(k, "}") && tok_is(k + 1, ")") && tok_is(k + 2, "{") }
            }
            k += 1
        }
        return false
    }
    if at_word("(") && toks[pos + 1].kind == T_ID && tok_is(pos + 2, ")") && tok_is(pos + 3, "{") && literal_type(pos + 1) { return true }
    if at_word("(") && (number_word(pos + 1) >= 0 || tok_is(pos + 1, "bool")) && tok_is(pos + 2, ")") && tok_is(pos + 3, "{") { return true }   // (int64){1}, a number's, as kelvinc's (#524)
    if at_word("(") && tagged_word(pos + 1) && tok_is(pos + 3, ")") && tok_is(pos + 4, "{") { return true }   // (struct T){...} (#453)
    if at_word("(") && tok_is(pos + 1, "typeof") && tok_is(pos + 2, "(") {   // (typeof(p)){...}, as kelvinc's (#696)
        var k:int64 = pos + 2
        var depth:int64 = 0
        while toks[k].kind != T_EOF {
            if tok_is(k, "(") { depth += 1 }
            if tok_is(k, ")") {
                depth -= 1
                if depth == 0 { return tok_is(k + 1, ")") && tok_is(k + 2, "{") }
            }
            k += 1
        }
        return false
    }
    if at_word("(") && tok_is(pos + 1, "const") {        // (const errno.type){6}, as kelvinc's (#696)
        var k:int64 = pos
        var depth:int64 = 0
        while toks[k].kind != T_EOF {
            if tok_is(k, "(") { depth += 1 }
            if tok_is(k, ")") {
                depth -= 1
                if depth == 0 { return tok_is(k + 1, "{") }
            }
            k += 1
        }
        return false
    }
    let e:int64 = value_type_end()
    return e >= 0 && tok_is(e + 1, "{") && (local_named(pos + 1) || dollar_named(pos + 1) || written_type(pos + 1) != 0 - 2 || c_headers)   // a C header's name's too (#696)
}

// whether sizeof's ( opens a value's type, (x.type) or (p.x.type^)
// (#421), as kelvinc's typeof_at: a name, then .member, ^ or [...] steps,
// .type last, ^ after it, and the )
let value_type_ahead():bool { return value_type_end() >= 0 }

// the ) of value_type_ahead's (x.type), or -1 (#422)
let value_type_end():int64 {
    if !at_word("(") || toks[pos + 1].kind != T_ID { return 0 - 1 }
    var j:int64 = pos + 2
    var typed = false
    while j < toks.count as int64 {
        if tok_is(j, ".") && toks[j + 1].kind == T_ID {
            typed = tok_is(j + 1, "type")
            j += 2
        } else if tok_is(j, "^") {
            j += 1
        } else if tok_is(j, "[") {
            var depth = 0
            while j < toks.count as int64 {
                if tok_is(j, "[") || tok_is(j, "$[") { depth += 1 }
                if tok_is(j, "]") { depth -= 1 }
                j += 1
                if depth == 0 { break }
            }
            typed = false
        } else {
            break
        }
    }
    return typed && tok_is(j, ")") ? j : 0 - 1
}

// whether token t starts a type in sizeof(...) (#420), as kelvinc's: a
// built-in type's word, const, [ or $[, Self in a method, or a struct's
// or an enum's name, which gen reads as a variable's where one hides it
let sizeof_type_at(t:int64):bool {
    if tok_is(t, "const") || tok_is(t, "[") || tok_is(t, "$[") || tok_is(t, "${") || tagged_word(t) { return true }
    if toks[t].kind != T_ID { return false }
    if number_word(t) >= 0 || tok_is(t, "bool") || tok_is(t, "cstr") || tok_is(t, "String") || tok_is(t, "IO") {
        return !tok_is(t + 1, "(")                       // String(x), a converter's value
    }
    if tok_is(t, "typeof") { return tok_is(t + 1, "(") }
    if tok_is(t, "any") { return tok_is(t + 1, "^") }    // sizeof(any^), C's void * (#696)
    if tok_is(t, "Optional") || tok_is(t, "Result") || tok_is(t, "Iterator") || tok_is(t, "Range") || tok_is(t, "Task") || tok_is(t, "Set") || tok_is(t, "Dictionary") || tok_is(t, "Array") {
        return tok_is(t + 1, "<")
    }
    if tok_is(t, "Self") { return self_name >= 0 }
    let u:int64 = scoped_type(t)
    for d in nodes {
        if (d.kind == D_STRUCT || d.kind == D_ENUM) && same_text(d.t, u) {
            return tok_is(t + 1, ")") || tok_is(t + 1, "^") || tok_is(t + 1, ".")
        }
    }
    if far_record(t, true) { return tok_is(t + 1, ")") || tok_is(t + 1, "^") || tok_is(t + 1, ".") }   // one of a file imported (#550)
    return false
}

let anon_spelling(d:int64):String    // a prototype: a type with no tag is named by its spelling (#476)

// the path Kelvin writes of the type named by token t: point.kind of
// point__kind (#389), else its name
let kelvin_name(t:int64):String {
    let anon:int64 = anon_decls.get(tok_text(t), -1)
    if anon >= 0 { return anon_spelling(anon) }          // {x: f64, y: f64}, as kelvinc spells it (#476)
    let block_own:int64 = local_own_of.get(tok_text(t), -1)
    if block_own >= 0 && !is_nested(t) { return tok_text(block_own) }   // a block's (#391)
    if !is_nested(t) { return tok_text(t) }
    let name:String = tok_text(t)
    var s:String = kelvin_name(outer_of.get(name, -1))
    s += "."
    let own:String = tok_text(own_of.get(name, -1))
    s += &own
    return s
}

// the name token of a struct or an enum at the cursor, which a nested one
// (#389) makes of its outer's, point__kind, as kelvinc names it, with
// kelvinc's errors
let record_name():int64 {
    reject_kv_name(pos)                                  // (#611)
    let t:int64 = advance()
    if nest_outer < 0 && local_next {                    // struct point { } in a block (#391): the block's
        local_next = false
        var i:int64 = local_types.count as int64 - 1
        while i >= 0 && local_type_depths[i] == block_depth {
            if same_text(local_own_of.get(tok_text(local_types[i]), -1), t) {
                var m = $"'"
                m += tok_text(t)
                m += "' is defined in this block already"
                parse_error_at(t, m.cstr)                // at its name, as kelvinc's (#685)
            }
            i -= 1
        }
        let u:int64 = hidden_token(t)
        let name:String = tok_text(u)
        records_seen[name] = u
        local_types += u
        local_type_depths += block_depth
        return u
    }
    if nest_outer < 0 {
        let name:String = tok_text(t)
        let same:int64 = nested_of.get(name, -1)
        if same >= 0 {
            var m:String = kelvin_name(same)
            m += " is "
            m += &name
            m += " in C, the name of this type: rename one of them"
            parse_error_at(t > 0 ? t - 1 : t, m.cstr)    // at its struct, as kelvinc's (#684)
        }
        records_seen[name] = t
        return t
    }
    if nested_tok(nest_outer, t) >= 0 {
        var m = $"'"
        m += tok_text(t)
        m += "' is defined in "
        let o:String = kelvin_name(nest_outer)
        m += &o
        m += " already"
        parse_error_at(t, m.cstr)                        // at its name, as kelvinc's (#685)
    }
    var name:String = tok_text(nest_outer)
    name += "__"
    let own:String = tok_text(t)
    name += &own
    let u:int64 = made_token(&name)
    toks[u].line = toks[t].line
    toks[u].file = toks[t].file
    if records_seen.get(name, -1) >= 0 {
        var m:String = kelvin_name(nest_outer)
        m += "."
        m += &own
        m += " is "
        m += &name
        m += " in C, the name of a type declared already: rename one of them"
        parse_error_at(t, m.cstr)                        // (#685)
    }
    nested_of[name] = u
    outer_of[name] = nest_outer
    own_of[name] = t
    records_seen[name] = u
    return u
}

// the token after a path of nested types from token i (#389)
var path_end:int64 = 0

// the type a path of names from token i names, point.kind, its first a
// bare name as scoped_type has it; path_end the token after it
let type_path(i:int64):int64 {
    var t:int64 = scoped_type(i)
    var k:int64 = i + 1
    while tok_is(k, ".") && toks[k + 1].kind == T_ID {
        let n:int64 = nested_tok(t, k + 1)
        if n < 0 { break }
        t = n
        k += 2
    }
    path_end = k
    return t
}

// the part of a made name a type gives, as kelvinc's: i64, String, Array_i64
let type_word(y:int64):String {
    switch types[y].kind {            // each its own, as gen.k's mangled: f64? and a Dictionary? are two (#267)
    case Y_I64: return $"i64"
    case Y_I32: return $"i32"
    case Y_U8: return $"u8"
    case Y_U32: return $"u32"
    case Y_I8: return $"i8"
    case Y_I16: return $"i16"
    case Y_U16: return $"u16"
    case Y_U64: return $"u64"
    case Y_I128: return $"i128"
    case Y_U128: return $"u128"
    case Y_F64: return $"f64"
    case Y_F32: return $"f32"
    case Y_BOOL: return $"bool"
    case Y_CSTR: return types[y].name == 2 ? $"cstr restrict" : $"cstr"
    case Y_STRING: return $"String"
    case Y_BYTES: return $"Bytes"
    case Y_IO: return $"IO"
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

let late_refused(t:int64):bool    // a prototype: T? and Result<T, E> of x.type are not kc's yet (#423)

let optional_of(t:int64):int64 {
    if late_refused(t) { return t }
    var name = $"_kv_opt_"
    var w = type_word(t)
    name += &w
    return made_enum(&name, "none", -1, "some", t, true)
}

let result_of(t:int64, e:int64):int64 {
    if late_refused(t) { return t }
    if late_refused(e) { return e }
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

// whether pointer type y points to a const T, const T^ (#272): its name 1,
// or 3 where it is restrict too (#393)
let ptr_const(y:int64):bool {
    return types[y].name == 1 || types[y].name == 3
}

// whether pointer type y is restrict, T^ restrict (#393): its name 2, or 3
let ptr_restrict(y:int64):bool {
    return types[y].name == 2 || types[y].name == 3
}

// the pointer type y after its ^, restrict where that follows (#393), as
// C's T *restrict
let restrict_of(y:int64):int64 {
    if !at_word("restrict") { return y }
    advance()
    return type_of_kind(Y_PTR, types[y].elem, types[y].name == 1 ? 3 : 2)
}

// restrict anywhere but after a ^, as kelvinc says it (#393)
let refuse_restrict() {
    if at_word("restrict") { parse_error("'restrict' is a pointer's: write it after the ^, as in 'u8^ restrict'") }
}

// T^ of y, its innermost pointer to a const T: const T^, a borrow through
// which T does not change, as C's const T * (#272)
let const_pointee(y:int64):int64 {
    if types[y].kind != Y_PTR { return y }
    let e:int64 = types[y].elem
    if types[e].kind == Y_PTR { return type_of_kind(Y_PTR, const_pointee(e), types[y].name) }
    return type_of_kind(Y_PTR, e, ptr_restrict(y) ? 3 : 1)
}

// whether [i] = v starts here, an element's designator in [...] (#715):
// the [ closed by a ] that a = follows
let element_designator_ahead():bool {
    var depth:int64 = 0
    var k:int64 = pos
    while toks[k].kind != T_EOF {
        if tok_is(k, "[") || tok_is(k, "$[") || tok_is(k, "(") || tok_is(k, "{") || tok_is(k, "${") { depth += 1 }
        if tok_is(k, "]") || tok_is(k, ")") || tok_is(k, "}") {
            depth -= 1
            if depth == 0 { return tok_is(k, "]") && tok_is(k + 1, "=") }
        }
        k += 1
    }
    return false
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

// whether a value's .type follows token t (#422), as kelvinc's #34:
// .member, ^ and [i] steps, then .type
let type_follows(t:int64):bool {
    var j:int64 = t + 1
    while j < toks.count as int64 {
        if tok_is(j, ".") && tok_is(j + 1, "type") { return true }
        if tok_is(j, ".") && toks[j + 1].kind == T_ID {
            j += 2
        } else if tok_is(j, "^") {
            j += 1
        } else if tok_is(j, "[") {
            var depth = 0
            while j < toks.count as int64 {
                if tok_is(j, "[") || tok_is(j, "$[") { depth += 1 }
                if tok_is(j, "]") { depth -= 1 }
                j += 1
                if depth == 0 { break }
            }
        } else {
            return false
        }
    }
    return false
}

// whether x.type starts at token t, x a variable (#422), $0 (#424)
let value_type_at(t:int64):bool {
    return (local_named(t) || dollar_named(t) || written_type(t) != 0 - 2) && type_follows(t)
}

// the type of the member at token m of the struct y, or -1 (#422)
let member_ty(y:int64, m:int64):int64 {
    for d in nodes {
        if d.kind == D_STRUCT && same_text(d.t, types[y].name) {
            var f:int64 = d.a
            while f >= 0 {
                if same_text(nodes[f].t, m) { return nodes[f].ty }
                f = nodes[f].next
            }
        }
    }
    return 0 - 1
}

let late_type(t:int64):int64    // a prototype: x.type of an inferred local (#423)

// the type x.type names (#422), as kelvinc's #34, x at token t, the
// cursor after it: x's written type, as typeof(x)'s (#398), then each
// .member's, ^'s and [i]'s, up to the .type, which it reads
let value_type(t:int64):int64 {
    var y:int64 = written_type(t)
    if dollar_named(t) && anon_depth == 0 {             // as kelvinc says it (#424)
        var e = $"'"
        e += tok_text(t)
        e += "' is a parameter of an anonymous function, and this is not in one"
        parse_error(e.cstr)
        return base_type(Y_VOID)
    }
    if dollar_named(t) || (y < 0 && (local_named(t) || anon_param(t))) || y == 0 - 1 { return late_type(t) }
    if y >= 0 && (types[y].kind == Y_TYPEOF || types[y].kind == Y_C || (types[y].kind == Y_STRUCT && types[y].elem == 0 - 1 && records_seen.get(tok_text(types[y].name), -1) < 0)) && tok_is(pos, ".") && tok_is(pos + 1, "type") { return late_type(t) }   // a.type of a.type's own __typeof__(a), a parameter's a pointer in C, as kelvinc's (#696)   // $0.type, v.type of { v in ... } (#424); a global's whose type is inferred, which gen tells (#696)
    if y < 0 {
        parse_error("kc reads x.type of a local or a parameter; not yet of a global whose type is inferred")
        return base_type(Y_VOID)
    }
    while !failed {
        if at_word(".") && tok_is(pos + 1, "type") && types[y].kind == Y_FIXED && types[y].name <= 0 - 10 {   // an array of a count no number gives: __typeof__ of it, which keeps its count as it was, as kelvinc's (#696)
            pos = t + 1
            return late_type(t)
        }
        if at_word(".") && tok_is(pos + 1, "type") {
            if types[y].kind == Y_VOID && !tok_is(pos + 2, "^") {   // as kelvinc says it (#612)
                var e = $"'"
                for k in t..<pos { e += tok_text(k) }
                e += ".type' is any, which exists only as 'any^', C's void *"
                parse_error_at(t, e.cstr)
                return y
            }
            advance()
            advance()
            return y
        }
        if at_word(".") {
            advance()
            let m:int64 = advance()
            if types[y].kind == Y_PTR { y = types[y].elem }
            if (types[y].kind == Y_STRUCT && records_seen.get(tok_text(types[y].name), -1) < 0) || types[y].kind == Y_C {   // a member of what only C sees: __typeof__ of it, as kelvinc's (#696)
                pos = t + 1
                return late_type(t)
            }
            let f:int64 = types[y].kind == Y_STRUCT ? member_ty(y, m) : 0 - 1
            if f < 0 {
                var e = $"'"
                e += tok_text(m)
                e += "' is no member of "
                let w:String = type_word(y)
                e += &w
                parse_error(e.cstr)
                return base_type(Y_VOID)
            }
            y = f
        } else if at_word("^") {
            advance()
            if types[y].kind != Y_PTR {
                parse_error("'^' reads through a pointer, and this is none")
                return base_type(Y_VOID)
            }
            y = types[y].elem
        } else {
            advance()                                    // [i], an element's
            var depth = 1
            while depth > 0 && !at_kind(T_EOF) {
                if at_word("[") || at_word("$[") { depth += 1 }
                if at_word("]") { depth -= 1 }
                advance()
            }
            let k:ykind = types[y].kind
            if k == Y_FIXED || k == Y_ARRAY || k == Y_PTR {
                y = types[y].elem
            } else if k == Y_ARGV {
                y = base_type(Y_CSTR)
            } else {
                parse_error("'[i]' reads an array's element, and this is none")
                return base_type(Y_VOID)
            }
        }
    }
    return base_type(Y_VOID)
}

// x.type of a local whose type is inferred (#423), x at token t, the
// cursor after it: a Y_TYPEOF of x's path read as a value, its .member,
// ^ and [i] steps, whose type gen tells where it writes the statement
let late_type(t:int64):int64 {
    var e:int64 = make_node(N_ID, t)
    while !failed {
        if at_word(".") && tok_is(pos + 1, "type") {
            advance()
            advance()
            late_seen = true                     // gen tells it, statement by statement
            return type_of_kind(Y_TYPEOF, -1, e)
        }
        if at_word(".") {
            advance()
            let n:int64 = make_node(N_FIELD, advance())
            nodes[n].a = e
            e = n
        } else if at_word("^") {
            let n:int64 = make_node(N_DEREF, advance())
            nodes[n].a = e
            e = n
        } else {
            let n:int64 = make_node(N_INDEX, advance())
            nodes[n].a = e
            set_b(n, parse_expr())
            expect("]")
            nodes[n].flag = 1
            e = n
        }
    }
    return base_type(Y_VOID)
}

// whether y holds an x.type gen tells (#423)
let late(y:int64):bool {
    if y < 0 { return false }
    let k:ykind = types[y].kind
    if k == Y_TYPEOF { return true }
    if k == Y_DICT && late(types[y].name) { return true }
    if k == Y_FN {                                       // a parameter's too, (struct cpt, s.x.type) (#696)
        var p:int64 = types[y].name
        while p >= 0 {
            if late(types[p].elem) { return true }
            p = types[p].name
        }
    }
    return k != Y_STRUCT && late(types[y].elem)
}

// whether T? or Result<T, E> holds an x.type gen tells, kc's error (#423):
// kc makes those types as it parses, a Dictionary's V? too
let late_refused(t:int64):bool {
    if !late(t) { return false }
    parse_error("kc reads T?, Result<T, E> and a Dictionary's value, whose d[k] is a V?, of x.type where x's type is written; not yet where it is inferred")
    return true
}

// const T^ and the rest (#272)
var lent_at:int64 = 0 - 1             // the lent of a parameter b:lent T, which parse_type steps over (#510)
var lent_params:Dictionary<int64, bool>  // the parameters written b:lent T, an owner their caller keeps (#510)

// the source text of tokens a up to b, as written (#652)
let span_text(a:int64, b:int64):String {
    var s = $""
    if b <= a { return s }
    for i in toks[a].at..<toks[b - 1].at + toks[b - 1].len { s += codes[i] }
    return s
}

// C's T[N] after a type, from token from, as kelvinc says it, with the
// hint that spells it as [T](N) (#49, #652)
let c_order_error(from:int64) {
    if anon_head > 0 {                                   // a name in the count, read first, as kelvinc reads it (#654)
        var q:int64 = pos
        while tok_is(q, "[") {
            q += 1
            while !at_kind(T_EOF) && toks[q].kind != T_EOF && !tok_is(q, "]") {
                if codes[toks[q].at] == '$' && toks[q].len > 1 && is_digit(codes[toks[q].at + 1]) {
                    var m = $"'"
                    m += tok_text(q)
                    m += "' cannot be used in the parameters or result of the function it names"
                    parse_error_at(q, m.cstr)
                    return
                }
                if toks[q].kind == T_ID {
                    var outer = false
                    for i in 0..<anon_head_from {
                        if same_text(locals_seen[i], q) { outer = true }
                    }
                    if outer {
                        var m = $"an anonymous function cannot use '"
                        m += tok_text(q)
                        m += "' of the function around it: C has no closures, so pass it as an argument, or make it a global"
                        parse_error_at(q, m.cstr)
                        return
                    }
                }
                q += 1
            }
            if tok_is(q, "]") { q += 1 }
        }
    }
    var spelled:String = span_text(from, pos)
    var dims:$[String] = $[]
    while at_word("[") && !failed {
        advance()
        let at:int64 = pos
        var depth:int64 = 0
        while !at_kind(T_EOF) && !(depth == 0 && at_word("]")) {
            if at_word("[") || at_word("(") { depth += 1 }
            if at_word("]") || at_word(")") { depth -= 1 }
            advance()
        }
        dims += span_text(at, pos)
        if at_word("]") { advance() }
    }
    var i:int64 = dims.count as int64 - 1
    while i >= 0 {
        var w = $"["
        w += &spelled
        w += "]"
        if dims[i].count > 0 {
            w += "("
            w += &dims[i]
            w += ")"
        }
        spelled = w.copy()
        i -= 1
    }
    let rest:int64 = pos
    while at_word("^") || at_word("const") || at_word("volatile") || at_word("restrict") { advance() }
    var m = $"an array type is written '[T]', or '[T](N)' with its count (#49): write '"
    m += &spelled
    let after:String = span_text(rest, pos)
    m += &after
    m += "' for '"
    let all:String = span_text(from, pos)
    m += &all
    m += "'"
    parse_error_at(from, m.cstr)
}

// a type, and C's T[N] after it, kelvinc's error (#652)
var type_depth:int64 = 0      // the types being read, one inside another (#710)
var cast_depth:int64 = 0 - 1  // the depth of a type of x as T or x:T, whose own ? is no Optional's (#710)

let parse_type():int64 {
    let from:int64 = pos
    type_depth += 1
    let y:int64 = parse_type_core()
    type_depth -= 1
    if at_word("[") && !failed {
        if tok_is(from, "(") && types[y].kind == Y_FN {
            parse_error("an array of functions is written [T](N), as any array: [(i64):i64](4) (#403)")
        } else {
            c_order_error(from)
        }
    }
    return y
}

let parse_type_core():int64 {
    if pos == lent_at {
        advance()
        lent_at = 0 - 1
    }
    if at_word("_Atomic") {                              // as kelvinc says it (#642)
        parse_error("'_Atomic' is C's spelling: Kelvin writes 'atomic', as const is, 'var n:atomic i64' (#642)")
        return base_type(Y_VOID)
    }
    if at_word("atomic") && toks[pos + 1].kind == T_ID && !tok_is(pos + 1, "=") {   // atomic i64, C's _Atomic (#642)
        let at:int64 = advance()
        let y = parse_bare_type()
        return atomic_base(y, at)
    }
    if at_word("const") {
        let const_at:int64 = advance()                   // where kelvinc says an array's qualifier (#688)
        let typed = value_type_at(pos)
        let y = parse_bare_type()
        if typed && types[y].kind == Y_FIXED { return const_fixed(y) }   // const xs.type, const on its elements, as kelvinc's #34 (#425)
        if typed && types[y].kind == Y_TYPEOF { return type_of_kind(Y_TYPEOF, 1, types[y].name) }   // told so (#425)
        if types[y].kind == Y_ARRAY {               // as kelvinc has it of each spelling, $[T] (#273, #274)
            parse_error("a qualifier of an Array or a Dictionary is the variable's: a let does not change")
        } else if types[y].kind == Y_DICT {
            parse_error("a qualifier of a Dictionary is the variable's: a let does not change")
        } else if types[y].kind == Y_SET {
            parse_error("a qualifier of a Set is the variable's: a let does not change")
        } else if types[y].kind == Y_FIXED || (types[y].kind == Y_PTR && types[types[y].elem].kind == Y_FIXED) {   // as kelvinc says it (#362)
            parse_error_at(const_at, "a qualifier of an array is its elements': write it inside the brackets, as in '[const u8]'")
        }
        return const_pointee(y)
    }
    return parse_bare_type()
}

// atomic T of a number or a bool, C's _Atomic (#642): a type of its own,
// konst 2, as [const T](N) is of 1; a pointer's base atomic too, of
// atomic i64^; another is kelvinc's error, at the token at
let atomic_base(y:int64, at:int64):int64 {
    if failed { return y }
    let k:ykind = types[y].kind
    if k == Y_PTR { return type_of_kind(Y_PTR, atomic_base(types[y].elem, at), types[y].name) }
    if is_number_kind(k) || k == Y_BOOL {
        if types[y].konst == 2 { return y }
        for i in 0..<types.count as int64 {
            if types[i].konst == 2 && types[i].kind == k { return i }
        }
        let c:ty = {k, types[y].elem, types[y].name, 2}
        types += c
        return types.count as int64 - 1
    }
    var m = $"'atomic' is of a number, a bool or a pointer, which C's atomic operations change at once (#642), and this is "
    let w:String = kelvin_type_text(y)
    m += &w
    parse_error_at(at, m.cstr)
    return y
}

// T^ atomic of the pointer y, konst 2 as an atomic number's, the
// pointer itself C's _Atomic (#701)
let atomic_pointer(y:int64):int64 {
    for i in 0..<types.count as int64 {
        if types[i].konst == 2 && types[i].kind == Y_PTR && types[i].elem == types[y].elem && types[i].name == types[y].name { return i }
    }
    let c:ty = {Y_PTR, types[y].elem, types[y].name, 2}
    types += c
    return types.count as int64 - 1
}

// [T] in $[...], an Array in turn, as kelvinc reads $[[i64]] (#369)
let grown(y:int64):int64 {
    if types[y].kind == Y_ARGV { return type_of_kind(Y_ARRAY, base_type(Y_CSTR), -1) }   // $[[cstr]], as kelvinc's (#616)
    if types[y].kind == Y_FIXED && (types[y].name == 0 - 1 || types[y].name == 0 - 3) {
        return type_of_kind(Y_ARRAY, grown(types[y].elem), -1)
    }
    return y
}

// a list among $[...]'s elements, an Array in turn, its lists too (#369)
let lists_grow(e:int64) {
    if nodes[e].kind != N_LIST || nodes[e].flag != 0 { return }
    if nodes[e].b < 0 {                                  // [], an empty one, as $[] is, where kc had crashed (#451)
        nodes[e].kind = N_EMPTY
        return
    }
    nodes[e].kind = N_ARRAY
    var x:int64 = nodes[e].b
    while x >= 0 {
        lists_grow(x)
        x = nodes[x].next
    }
}

// the text of $[...] and ${...} at any depth (#616): a String, as $"..."
// is, c 1 of a literal, a template's flag 1 and c 1, where the $ made
// it so; gen takes it back where the type written has a cstr. In an
// Array its elements, in a Dictionary its values; a key is a String
// already, and a Set's elements
let dollar_mark(e:int64) {
    let k:nkind = nodes[e].kind
    if k == N_STR {
        nodes[e].c = 1
    } else if k == N_TPL && nodes[e].flag == 0 {
        nodes[e].flag = 1
        nodes[e].c = 1
    } else if k == N_ARRAY {
        var x:int64 = nodes[e].b
        while x >= 0 {
            dollar_mark(x)
            x = nodes[x].next
        }
    } else if k == N_DICT {
        var x:int64 = nodes[e].b
        while x >= 0 && nodes[x].next >= 0 {
            dollar_mark(nodes[x].next)
            x = nodes[nodes[x].next].next
        }
    }
}

// the Array of elem, $[T] or Array<T> (#451); an element of a count
// is kelvinc's error
// the ( of a count after the [...] that starts at token t, $[[i64](3)]'s,
// where kelvinc says an Array has no count; t itself where there is none
let count_paren(t:int64):int64 {
    if !tok_is(t, "[") { return t }
    var depth:int64 = 0
    var k:int64 = t
    while k < eof_pos {
        if tok_is(k, "[") || tok_is(k, "$[") { depth += 1 }
        if tok_is(k, "]") {
            depth -= 1
            if depth == 0 { return tok_is(k + 1, "(") ? k + 1 : t }
        }
        k += 1
    }
    return t
}

let array_type(elem:int64):int64 { return array_type_at(elem, pos) }

// array_type, its error at token at (#681)
let array_type_at(elem:int64, at:int64):int64 {
    if types[elem].kind == Y_FIXED && types[elem].name != 0 - 1 && types[elem].name != 0 - 3 {   // as kelvinc says it (#369)
        var b:int64 = elem
        while types[b].kind == Y_FIXED { b = types[b].elem }
        var m = $"an Array grows, and has no count in its type: write $[["
        let w:String = type_word(b)
        m += &w
        m += "]], and give the elements or a count where it is made"
        parse_error_at(at, m.cstr)                       // at the count's (, as kelvinc's (#681)
        return base_type(Y_VOID)
    }
    return type_of_kind(Y_ARRAY, grown(elem), -1)
}

let parse_anon_record():int64    // a prototype: {x:f64, y:f64} where a type goes (#476)
let anon_record_type(first:int64, is_union:bool, is_enum:bool, open:int64):int64    // and its type's declaration (#694)

// the suffixes after a type: T^, T?, T?? (#217, #229), T^ restrict (#393)
let type_suffixes(y0:int64):int64 {
    var y:int64 = y0
    let cast_type = type_depth == cast_depth             // x as T ? a : b: the ? a choice's, as kelvinc's TYPE_AS (#710)
    while at_word("^") || ((at_word("?") || at_word("??")) && !cast_type) {
        if at_word("??") {                       // T??, which lexes as ?? (#229)
            y = optional_of(optional_of(y))
            advance()
        } else if at_word("?") {
            y = optional_of(y)                   // T?, an Optional (#217)
            advance()
        } else {
            y = type_of_kind(Y_PTR, y, -1)
            advance()
            y = restrict_of(y)                   // T^ restrict (#393)
            if at_word("atomic") {               // T^ atomic, the pointer itself atomic, kelvinc's (#642, #701)
                advance()
                y = atomic_pointer(y)
            }
        }
    }
    if types[y].kind == Y_CSTR && at_word("restrict") {   // cstr restrict, a pointer in C, as kelvinc's (#718)
        advance()
        y = type_of_kind(Y_CSTR, -1, 2)
    }
    refuse_restrict()
    return y
}

// what kelvinc says to use for token t, a type word of C's that is none
// of Kelvin's, as its dead_words have it (#611, #612); "" of any other
let c_word_hint(t:int64):cstr {
    return tok_is(t, "char") ? "u8 (or i8)" : tok_is(t, "short") ? "i16 or u16" : tok_is(t, "int") ? "i32 or u32" : tok_is(t, "long") && tok_is(t + 1, "double") ? "f64 (long double has no Kelvin type yet)" : tok_is(t, "long") ? "i64 or u64 (or i128/u128)" : tok_is(t, "signed") ? "i8, i16, i32, i64 or i128" : tok_is(t, "unsigned") ? "u8, u16, u32, u64 or u128" : tok_is(t, "float") ? "f32" : tok_is(t, "double") ? "f64" : tok_is(t, "_Bool") ? "bool" : tok_is(t, "void") ? "any^ for C's void *; a function without a result omits ': type'" : ""
}

// IO is a module, which a program imports (#144, #612): its name at token
// t where no file has #import <IO> is kelvinc's error
var io_imported:int64 = 0 - 1      // whether a file imports it: 1, 0, or not asked yet

let io_required(t:int64) {
    if io_imported < 0 {
        io_imported = 0
        for k in 0..<eof_pos {
            if toks[k].kind == T_IMPORT && tok_is(k, "<IO>") { io_imported = 1 }
        }
    }
    if io_imported == 0 && t < eof_pos && !failed {
        parse_error_at(t, "IO is a module: write '#import <IO>' at the top of the file")
    }
}

// a Dictionary's key is no cstr, as kelvinc says it (#65, #611): it keeps
// a copy of the text, a String
let cstr_key(key:int64, at:int64) {
    if key >= 0 && types[key].kind == Y_CSTR && !failed {
        parse_error_at(at, "a key of a Dictionary is a String, not a cstr: the Dictionary keeps a copy of the text, and is read with a cstr or a String")
        return
    }
    if key < 0 || failed { return }                      // an integer of 8 to 64 bits or a String, and no other, a Set's element too, as kelvinc's check_dict_key (#705)
    let k:ykind = types[key].kind
    if k == Y_STRING || ((is_int_kind(k) && k != Y_I128 && k != Y_U128) && types[key].konst == 0) { return }
    var m = $"a key of a Dictionary is an integer or a String, not "
    let w:String = kelvin_type_text(key)
    m += &w
    parse_error_at(at, m.cstr)
}

// a fixed array where an Array's element or a Dictionary's value goes,
// kelvinc's error at token at, the type's start (#705)
let fixed_element(elem:int64, at:int64) {
    if elem < 0 || failed || types[elem].kind != Y_FIXED { return }
    var m = $"an Array of "
    let w:String = kelvin_type_text(elem)
    m += &w
    m += " is not here yet: an element is a value C returns"
    parse_error_at(at, m.cstr)
}

let parse_bare_type():int64 {
    if at_kind(T_DSTR) {                         // $"" is String, the type (#616), as kelvinc's
        let at:int64 = toks[pos].at
        let len:int64 = toks[pos].len
        if !(len == 2 || (len == 3 && codes[at] == '$')) {   // its text, from its " or its $
            parse_error("$\"\" is the type String; a type has no text: write $\"\" or String")
            advance()
            return base_type(Y_VOID)
        }
        advance()
        return type_suffixes(base_type(Y_STRING))
    }
    if at_word("$[") || at_word("${") {
        let brace:bool = at_word("${")
        advance()
        let elem_at:int64 = pos                  // where the element's type, or the key's, starts (#681)
        let elem:int64 = parse_type()
        var y:int64 = 0
        if !brace && at_word(":") {              // $[String: i64], as kelvinc says it
            var m = $"a Dictionary's type is written in braces: ${"
            let w:String = kelvin_type_text(elem)
            m += &w
            m += ": V}, as its entries are"
            parse_error(m.cstr)
            return elem
        }
        if !brace {
            expect("]")
            y = array_type_at(elem, count_paren(elem_at))
        } else if at_word(":") {                 // ${K: V}, a Dictionary<K, V> (#460)
            advance()
            let value_at:int64 = pos
            let value:int64 = parse_type()
            expect("}")
            cstr_key(elem, elem_at)              // (#611, #681)
            fixed_element(value, value_at)       // (#705)
            y = type_of_kind(Y_DICT, value, elem)
            optional_of(value)
        } else {                                 // ${T}, a Set<T> (#460)
            expect("}")
            cstr_key(elem, elem_at)              // its element a key, as kelvinc's (#705)
            y = type_of_kind(Y_SET, elem, -1)
        }
        if failed { return y }
        while at_word("^") || at_word("?") {
            if at_word("?") {
                y = optional_of(y)               // $[T]?, an Optional (#221)
                advance()
            } else {
                y = type_of_kind(Y_PTR, y, -1)
                advance()
                y = restrict_of(y)
            }
        }
        refuse_restrict()
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
        let counted = at_word("(")
        if counted {
            advance()
            count = tok_is(pos + 1, ")") ? tok_count(pos) : 0 - 1
            var q:int64 = pos                        // a template with ${...} in it, as kelvinc says it (#653)
            var qd:int64 = 0
            while !failed && toks[q].kind != T_EOF && !(qd == 0 && tok_is(q, ")")) {
                if tok_is(q, "(") { qd += 1 }
                if tok_is(q, ")") { qd -= 1 }
                if toks[q].kind == T_TPL_HEAD {
                    parse_error_at(q, "a template literal with ${...} is made at run time, so it cannot be part of a type")
                }
                q += 1
            }
            if count < 0 {                           // a count C computes, a local's (#366): -10 - its node
                count = 0 - 10 - parse_expr()
            } else {
                advance()
            }
            expect(")")
        }
        var y:int64 = type_of_kind(Y_FIXED, elem, count)
        if constant && counted { y = const_fixed(y) }   // [const T](N), its elements const (#425)
        while at_word("^") || at_word("?") {         // [T](N)^, which gen says is not kc's yet
            y = at_word("?") ? optional_of(y) : type_of_kind(Y_PTR, y, -1)
            advance()
        }
        return y
    }
    if at_word("(") {                            // (T, U):R, a function type (#428)
        advance()
        var ps:$[int64] = $[]
        while !at_word(")") && !failed {
            if at_word("...") {
                parse_error("kc's function types take no '...' yet: C's variadic functions are called by name")
                return base_type(Y_VOID)
            }
            if at_kind(T_ID) && tok_is(pos + 1, ":") {   // (a:i64):i64, as kelvinc says it
                parse_error("a function type lists its parameters' types without names")
                return base_type(Y_VOID)
            }
            ps += parse_type()
            if !at_word(",") { break }
            advance()
        }
        expect(")")
        if at_word("^") {                                // (i64)^, as kelvinc says it
            parse_error("a pointer to a function type groups the type in parentheses: ((i64):i64)^ (#403)")
            return base_type(Y_VOID)
        }
        var r:int64 = 0 - 1
        if at_word(":") {
            advance()
            if at_word("(") && tok_is(pos + 1, ")") && !tok_is(pos + 2, ":") {   // :(), no result (#141)
                advance()
                advance()
            } else {
                r = parse_type()
            }
        }
        return fn_type_of(&ps, r)
    }
    if at_word("{") || ((at_word("struct") || at_word("union") || at_word("enum")) && tok_is(pos + 1, "{")) {
        return type_suffixes(parse_anon_record())   // {x:f64, y:f64}, union{...}, enum{...}, with no tag (#476)
    }
    var tag:int64 = 0 - 1                        // struct T, union T, enum T, as C spells them (#453)
    if (at_word("struct") || at_word("union") || at_word("enum")) && toks[pos + 1].kind == T_ID {
        tag = at_word("union") ? 0 - 3 : at_word("enum") ? 0 - 4 : 0 - 2
        advance()
    }
    if !at_kind(T_ID) {
        if tok_is(pos, "$") {                    // $int64, as kelvinc says it
            parse_error("'$' before a type: $[T] is Array<T> and ${K: V} Dictionary<K, V>, as $[a, b] and ${k: v} are the values; a String is written String")
            return base_type(Y_VOID)
        }
        parse_error("a type is expected")
        return base_type(Y_VOID)
    }
    refuse_restrict()                            // restrict T^ (#393)
    reject_kv_name(pos)                          // _kv_anon1, as kelvinc says it (#476), and kv_s, the runtime's (#611)
    if failed { return base_type(Y_VOID) }
    if tag == 0 - 1 && pos < eof_pos {           // C's type words are no types of Kelvin's, as kelvinc says it (#611)
        let ws:cstr := c_word_hint(pos)
        if ws[0] != 0 {
            var m = $"'"
            m += tok_text(pos)
            m += "' is not a Kelvin type; use "
            m += ws
            parse_error(m.cstr)
            return base_type(Y_VOID)
        }
    }
    let t:int64 = advance()
    var y = -1
    if tag != 0 - 1 && !record_tagged(scoped_type(t), tag) {
        y = type_of_kind(Y_STRUCT, tag, t)               // a C header's, which keeps its word, as one of another word: C's error
    } else if value_type_at(t) {                         // x.type, a value's type (#422), $0.type (#424)
        y = value_type(t)
    } else if fn_aliases.count > 0 && fn_aliases.has(tok_text(t)) {   // an alias of a function type (#403, #550)
        y = fn_aliases.get(tok_text(t), -1)
    } else if number_word(t) >= 0 {                  // int64 or i64 (#430), float64 (#262), float32 (#263)
        y = number_word(t)
    } else if tok_is(t, "bool") {
        y = base_type(Y_BOOL)
    } else if tok_is(t, "cstr") {
        y = base_type(Y_CSTR)
    } else if tok_is(t, "any") {                 // any^, C's void * (#470)
        y = base_type(Y_VOID)
        if !at_word("^") && t < eof_pos {        // and nothing else, as kelvinc says it (#612)
            parse_error_at(t, "'any' exists only as 'any^', C's void *")
            return y
        }
    } else if tok_is(t, "String") {
        y = base_type(Y_STRING)
    } else if tok_is(t, "Bytes") {               // (#439)
        y = base_type(Y_BYTES)
    } else if tok_is(t, "IO") {
        io_required(t)                           // (#612)
        y = base_type(Y_IO)
    } else if tok_is(t, "typeof") {             // typeof(T), typeof(x) (#398), C23's
        if !at_word("(") {
            parse_error_at(t, "typeof takes a value or a type in parentheses, as C23's: typeof(x)")   // at its word, as kelvinc's (#685)
            return base_type(Y_VOID)
        }
        advance()
        let v:int64 = pos
        let named = toks[v].kind == T_ID && (local_named(v) || written_type(v) != 0 - 2)
        if named && tok_is(v + 1, ")") && written_type(v) >= 0 {
            y = written_type(v)
            let yk:ykind = types[y].kind
            if written_let(v) && (is_int_kind(yk) || yk == Y_F64 || yk == Y_F32 || yk == Y_BOOL) && types[y].konst == 0 { y = const_number(y) }   // a let's const kept, as kelvinc's (#708)
            advance()
        } else if named || toks[v].kind == T_NUM || at_word("(") || at_word("-") || at_word("!") || at_word("&") {   // of an expression, or of a variable whose type is inferred: as gen tells it, else __typeof__ of it, as kelvinc's (#696)
            let saved = brace_ends
            brace_ends = false
            let e:int64 = parse_expr()
            brace_ends = saved
            late_seen = true
            y = type_of_kind(Y_TYPEOF, -1, e)
        } else {
            y = parse_type()
        }
        expect(")")
    } else if tok_is(t, "Self") && self_name >= 0 && number_word(self_name) >= 0 {   // of a number's method (#542)
        y = number_word(self_name)
    } else if tok_is(t, "Self") && self_name >= 0 && (tok_is(self_name, "String") || tok_is(self_name, "Bytes")) {
        y = base_type(tok_is(self_name, "String") ? Y_STRING : Y_BYTES)
    } else if tok_is(t, "Self") && self_name >= 0 {   // the type of the method (#213)
        y = type_of_kind(Y_STRUCT, -1, self_name)
    } else if tok_is(t, "Self") && t < eof_pos && !far_records.has(tok_text(t)) {   // a plain function has no T, as kelvinc says it (#140, #612)
        parse_error_at(t, "'Self' is the type's name inside 'extend T { }' and in a method, an attribute or a subscript of T: here there is no T")
        return base_type(Y_VOID)
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
        if !is_int_kind(k) || k == Y_I128 || k == Y_U128 {
            var m = $"a Range is of integers, i8 to i64 or u8 to u64, and this is "
            let w:String = type_word(value)
            m += &w
            m += "; convert its bounds, as in 'i64(n)'"
            parse_error_at(t, m.cstr)                    // at Range, as kelvinc's (#687)
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
    } else if tok_is(t, "Array") && at_word("<") {     // Array<T>, $[T] as it is spelled out (#451)
        advance()
        let elem_at:int64 = pos
        let elem:int64 = parse_type()
        close_angle()
        fixed_element(elem, elem_at)                     // as kelvinc says it (#705)
        if failed { return y }
        y = array_type(elem)
    } else if tok_is(t, "Set") {                 // Set<T> (#274)
        expect("<")
        let elem_at:int64 = pos
        let elem:int64 = parse_type()
        close_angle()
        cstr_key(elem, elem_at)                          // its element a key, as kelvinc's (#705)
        y = type_of_kind(Y_SET, elem, -1)
    } else if tok_is(t, "Dictionary") {          // Dictionary<K, V> (#211)
        expect("<")
        let key_at:int64 = pos
        let key:int64 = parse_type()
        expect(",")
        let value_at:int64 = pos
        let value:int64 = parse_type()
        close_angle()
        cstr_key(key, key_at)                            // (#611, #681)
        fixed_element(value, value_at)                   // (#705)
        y = type_of_kind(Y_DICT, value, key)
        optional_of(value)                       // V?, which d[k] read whole is (#219)
    } else {
        let nt:int64 = type_path(t)                  // point.kind, or kind in point (#389)
        while pos < path_end { advance() }
        let name:String = tok_text(nt)
        let c_tag:int64 = nt == t && records_seen.get(name, -1) < 0 ? c_tags.get(name, -1) : 0 - 1   // timespec of struct timespec; (#453)
        if nt == t && records_seen.get(name, -1) < 0 && c_tag < 0 && local_own_of.get(name, -1) < 0 && tok_is(pos, ".") && tok_is(pos + 1, "type") && c_headers {
            return type_suffixes(late_type(t))           // errno.type, of what only C sees: __typeof__(errno), as kelvinc's (#696)
        }
        if tok_is(pos, ".") && toks[pos + 1].kind == T_ID && !tok_is(pos + 1, "type") && records_seen.get(name, -1) >= 0 {
            var m:String = kelvin_name(nt)
            m += " has no type '"
            m += tok_text(pos + 1)
            m += "' defined in it"
            parse_error_at(pos + 1, m.cstr)              // at the name it lacks (#685)
        } else if nt == t && records_seen.get(name, -1) < 0 {
            for e in ended_types {                       // (#391)
                if same_text(local_own_of.get(tok_text(e), -1), t) {
                    var m = $"'"
                    m += &name
                    m += "' is defined in a block that has ended: a type defined inside a function is known to the end of its block"
                    parse_error_at(t, m.cstr)            // (#685)
                    break
                }
            }
            for c, own in own_of {                       // as kelvinc says it of the first
                if same_text(own, t) {
                    var m = $"'"
                    m += &name
                    m += "' is defined in "
                    let o:String = kelvin_name(outer_of.get(c, -1))
                    m += &o
                    m += ", and named "
                    let k:String = kelvin_name(nested_of.get(c, -1))
                    m += &k
                    m += " outside it"
                    parse_error_at(t, m.cstr)            // (#685)
                    break
                }
            }
        }
        y = type_of_kind(Y_STRUCT, c_tag, nt)
    }
    if at_word(".") && tok_is(pos + 1, "type") && tok_is(pos + 2, "[") && toks[pos - 1].kind == T_ID {   // f.type[2], C's order, as kelvinc says it (#652)
        let from:int64 = pos - 1
        pos += 2
        c_order_error(from)
        return base_type(Y_VOID)
    }
    if at_word(".") && tok_is(pos + 1, "type") {         // as kelvinc says it (#422)
        let w:String = types[y].kind == Y_STRUCT ? kelvin_name(types[y].name) : type_word(y)
        var m = $"'"
        m += &w
        m += "' is a type already: write '"
        m += &w
        m += "', not '"
        m += &w
        m += ".type'"
        parse_error_at(pos - 1, m.cstr)                  // at the type's name, as kelvinc's (#685)
        return base_type(Y_VOID)
    }
    return type_suffixes(y)
}

// ---------- expressions ----------


// the arguments of a call after its (, up to its ), as a list
let parse_args():int64 {
    var first = -1
    var last = -1
    let saved = name_annotation
    let saved_ends = brace_ends
    name_annotation = true                       // c ? f(p:point) : q (#265)
    brace_ends = false
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
    brace_ends = saved_ends
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
let unnamed_param(p:int64, k:int64, anon:bool)

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
    if tok_is(i, "(") && tok_is(i + 1, "var") && toks[i + 2].kind == T_ID && tok_is(i + 3, ":") { return true }   // { (var s:T):R in ... } (#470)
    if tok_is(i, "(") && tok_is(i + 1, ")") && (tok_is(i + 2, "in") || tok_is(i + 2, ":")) { return true }   // { () in ... } (#428)
    if names_in_ahead(i) { return true }                // { v in ... }, { acc, v in ... } (#330)
    var depth:int64 = 0
    var inner:int64 = 0                                  // in ( ) and [ ]
    while toks[i].kind != T_EOF {
        if tok_is(i, "{") || tok_is(i, "${") { depth += 1 }
        if tok_is(i, "}") {
            if depth == 0 { return false }
            depth -= 1
        }
        if tok_is(i, "(") || tok_is(i, "[") || tok_is(i, "$[") { inner += 1 }
        if tok_is(i, ")") || tok_is(i, "]") { inner -= 1 }
        if (tok_is(i, "Dictionary") || tok_is(i, "Result")) && tok_is(i + 1, "<") {   // { Dictionary<K, V>(...) }, its , no list's (#460)
            var angle:int64 = 0
            i += 1
            while toks[i].kind != T_EOF {
                if tok_is(i, "<") { angle += 1 }
                if tok_is(i, ">") { angle -= 1 }
                if tok_is(i, ">>") { angle -= 2 }
                if angle <= 0 { break }
                i += 1
            }
        }
        if depth == 0 && inner == 0 && tok_is(i, ",") { return false }   // {a, { $0 }}, a list that holds one (#428)
        if toks[i].kind == T_ID && codes[toks[i].at] == '$' { return true }
        if tok_is(i, "$[") && toks[i + 1].kind == T_NUM && tok_is(i + 2, "]") { return true }   // $[0], as $0 (#612)
        i += 1
    }
    return false
}

// whether the { at the cursor is a function trailing a call: not a
// condition's body, as kelvinc's (#32, #470). After map, filter and
// their kin a { that no condition ends is their function whatever it
// holds, { true }, { bool.random() }, with no $0 in it (#549)
let trailing_ahead():bool {
    return !brace_ends && anon_ahead()
}

// the expression of a condition, whose { ends it (#470)
let parse_cond():int64 {
    let saved = brace_ends
    brace_ends = true
    let e:int64 = parse_comma_expr()                     // if f(), ok { }, C's comma, as kelvinc reads it (#715)
    brace_ends = saved
    return e
}

// a, b, C's comma, its value the last's, as kelvinc reads it (#652, #715)
let parse_comma_expr():int64 {
    var e:int64 = parse_expr()
    while at_word(",") && !failed {
        let c:int64 = make_node(N_COMMA, advance())
        nodes[c].a = e
        nodes[c].b = parse_expr()
        e = c
    }
    return e
}

// an anonymous function (#324): its parameters and result where written,
// { (x:T):R in ... }, else $0, $1 as the context types them; its body the
// statements to the }
let parse_anon():int64 {
    let n:int64 = make_node(N_ANON, advance())
    let saved_ends = brace_ends
    brace_ends = false
    skip_newlines()
    if at_word("(") && (tok_is(pos + 1, ")") || tok_is(pos + 1, "var") || (toks[pos + 1].kind == T_ID && !dollar_named(pos + 1) && tok_is(pos + 2, ":"))) {   // not { ($0 as T) ... } (#424), nor { ($0:$0.type) * 3 } (#696)
        advance()
        var last = -1
        var k:int64 = 0
        let saved_from:int64 = anon_head_from
        anon_head += 1
        anon_head_from = locals_seen.count as int64
        while !at_word(")") && !failed {
            let is_var = at_word("var")                  // { (var s:T):R in ... } may change s, its own (#470)
            if is_var { advance() }
            if at_kind(T_ID) && tok_is(pos + 1, ":") && tok_is(pos + 2, "lent") {   // as kelvinc says it
                parse_error_at(pos, "'lent' is for a function's or a method's parameter: an anonymous function is lent the elements .map and .sort give it (#244), and owns what else it takes")
                return n
            }
            let p:int64 = parse_typed(is_var ? 0 : 1)
            unnamed_param(p, k, true)
            k += 1
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
            if at_word("(") && tok_is(pos + 1, ")") && !tok_is(pos + 2, ":") {   // :(), no result, as a function type's (#141, #718)
                advance()
                advance()
            } else {
                set_ty(n, parse_type())
            }
        }
        anon_head -= 1
        anon_head_from = saved_from
        if !at_word("in") {                              // as kelvinc says it
            parse_error("expected 'in' after the parameters, as in '{ (a:i32):i32 in a * 2 }'")
            return n
        }
        expect("in")
    } else if names_in_ahead(pos) {                      // { v in ... }: named, typed by where it goes (#330)
        nodes[n].flag = 2
        var last = -1
        var k:int64 = 0
        while !at_word("in") && !failed {
            reject_kv_name(pos)                          // (#611)
            let p:int64 = make_node(S_VAR, advance())
            nodes[p].flag = 1
            anon_named += nodes[p].t                     // v.type, which gen tells (#424)
            unnamed_param(p, k, true)                    // { _, b in ... } (#388)
            k += 1
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
    anon_depth += 1
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
    anon_depth -= 1
    if nodes[n].flag == 2 {                              // its names, out of sight (#424)
        var p:int64 = nodes[n].a
        while p >= 0 {
            anon_named.pop()
            p = nodes[p].next
        }
    }
    nodes[n].b = b
    brace_ends = saved_ends
    return n
}

let parse_entries(n:int64, k0:int64):int64   // a prototype: {k: v} (#460)

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
            if at_word(":") {                        // ${"a", "b": 1}, as kelvinc says it
                parse_error("a Set holds elements, not entries: ${a, b, c}; a Dictionary's are ${k: v}")
                return n
            }
            if !at_word(",") { break }
            advance()
            skip_newlines()
            if at_word("}") { break }
        }
        expect("}")
        return n
    }
    return parse_entries(make_node(N_DICT, t), 0 - 1)   // ${k: v} (#267)
}

// the entries of the Dictionary literal n, the first key k0 where it is
// read already, -1 where not: {k: v} where a Dictionary is written (#460)
let parse_entries(n:int64, k0:int64):int64 {
    let saved = name_annotation
    var last = -1
    var first = k0
    while !failed {
        name_annotation = false                 // ${k: v}'s :, not k:T
        let k:int64 = first >= 0 ? first : parse_expr()
        first = 0 - 1
        name_annotation = saved
        expect(":")
        let v:int64 = parse_expr()
        lists_grow(v)                           // ${k: [1, 2]}, an Array, as kelvinc's (#460)
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
        let elem_at:int64 = pos
        let elem:int64 = parse_type()
        close_angle()
        fixed_element(elem, elem_at)                     // (#705)
        set_ty(n, type_of_kind(Y_ARRAY, elem, -1))
    } else if tok_is(nodes[n].t, "Set") {        // Set<T>() (#460)
        advance()                                // <
        let elem_at:int64 = pos
        let elem:int64 = parse_type()
        close_angle()
        cstr_key(elem, elem_at)                          // (#705)
        set_ty(n, type_of_kind(Y_SET, elem, -1))
    } else {
        advance()                                // <
        let key_at:int64 = pos
        let key:int64 = parse_type()
        expect(",")
        let value_at:int64 = pos
        let value:int64 = parse_type()
        close_angle()
        cstr_key(key, key_at)                            // (#611, #681)
        fixed_element(value, value_at)                   // (#705)
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
    } else if !tok_is(nodes[n].t, "Array") && (at_word("{") || at_word("${")) {   // the entries (#351), a Set's elements (#460)
        nodes[n].a = parse_brace_body(advance())
        nodes[n].flag = 3
    } else if !tok_is(nodes[n].t, "Array") && !at_word(")") {   // &d, a copy (#351), &s (#460)
        nodes[n].a = parse_expr()
        nodes[n].flag = nodes[nodes[n].a].kind == N_ADDR ? 4 : 5
    } else if tok_is(nodes[n].t, "Array") && !at_word(")") {   // &a, a copy; n, a count (#350)
        nodes[n].a = parse_expr()
        nodes[n].flag = nodes[nodes[n].a].kind == N_ADDR ? 4 : 5
        if !at_word(")") {
            nodes[n].flag = 7
        }
    }
    if !tok_is(nodes[n].t, "Array") && nodes[n].flag >= 3 && !at_word(")") {
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

// the function trailing the call n, x.m(a) { ... } (#328) or f(a) { ... }
// (#470), its last argument
var body_after_call:int64 = 0 - 1   // the { after a call's ) in the head of if, while or for, which starts the body (#612)
var block_after_call:int64 = 0 - 1  // the { on the line after a call's ), which starts a block
var next_blocks:Dictionary<int64, int64>   // and that {, by the call's node, which gen asks of a call that lacks its function

// whether token t is in the braces that open at token o
let in_braces(o:int64, t:int64):bool {
    if o < 0 || t <= o { return false }
    var depth = 0
    var k:int64 = o
    while k < eof_pos {
        if tok_is(k, "{") || tok_is(k, "${") { depth += 1 }
        if tok_is(k, "}") {
            depth -= 1
            if depth == 0 { return t < k }
        }
        k += 1
    }
    return false
}

let take_trailing(n:int64) {
    if brace_ends && at_word("{") { body_after_call = pos }   // (#612)
    if at_kind(T_NL) {
        var k:int64 = pos
        while toks[k].kind == T_NL { k += 1 }
        if tok_is(k, "{") {
            block_after_call = k
            next_blocks[n] = k
        }
    }
    if brace_ends || !at_word("{") { return }            // any { after a call, on its line, as kelvinc's (#32)
    let told = anon_ahead()
    let an:int64 = parse_anon()
    if !told { nodes[an].c = 1 }                         // its body names no $0: atexit() { ... }, of no parameters where nothing types it
    if nodes[n].b < 0 {
        nodes[n].b = an
    } else {
        var last:int64 = nodes[n].b
        while nodes[last].next >= 0 { last = nodes[last].next }
        nodes[last].next = an
    }
}

// e.t(a...) from its '(': a method call, a function trailing it the last
// argument; of e, or of self where .t(a) is written (#444)
var static_parsing = false                       // a function of a type, static let, is parsed (#718)

let parse_method_call(e:int64, t:int64):int64 {
    advance()
    let n:int64 = make_node(N_METHOD, t)
    nodes[n].a = e
    if tok_is(t, "stride") && toks[pos].kind == T_ID && tok_is(pos + 1, ":") {   // r.stride(by: 2), as kelvinc says it (#379)
        advance()
        parse_error("'.stride' takes its step alone, as in 'r.stride(2)': Kelvin has no argument labels")
    }
    set_b(n, parse_args())
    take_trailing(n)
    return n
}

// `a${x}b` from its head (#445), as kelvinc's parse_template: its parts,
// each an N_STR of its text, and its values in turn; dollar of $`...`
var static_init = false            // the cursor is in a static's initializer, which C wants constant (#612)

let parse_template(dollar:bool):int64 {
    if static_init || (block_depth == 0 && fn_tok < 0) {   // as kelvinc says it (#39, #612)
        parse_error(static_init ? "a template literal with ${...} is made at run time, and a static's initializer must be constant: make it in a function" : "a template literal with ${...} is made at run time, and a global's initializer must be constant: make it in a function")
        return make_node(N_NULL, pos)
    }
    let n:int64 = make_node(N_TPL, pos)
    if dollar { nodes[n].flag = 1 }
    var last:int64 = -1
    while !failed {
        let k:tkind = toks[pos].kind
        let part:int64 = make_node(N_STR, advance())
        if last < 0 { nodes[n].b = part } else { nodes[last].next = part }
        last = part
        if k == T_TPL_TAIL { break }
        if at_kind(T_TPL_MID) || at_kind(T_TPL_TAIL) {
            parse_error("${} is empty: write an expression in it, as in ${x}")
            break
        }
        let saved = name_annotation
        name_annotation = true
        let v:int64 = parse_expr()
        name_annotation = saved
        nodes[last].next = v
        last = v
        if !at_kind(T_TPL_MID) && !at_kind(T_TPL_TAIL) {
            var m = $"expected '}' to end ${...} in the template literal, found "   // as kelvinc says it
            let d:String = tok_desc(pos)
            m += &d
            parse_error(m.cstr)
            break
        }
    }
    return n
}

let parse_primary():int64 {
    let t:int64 = pos
    let k:tkind = toks[t].kind
    let braced = literal_brace
    literal_brace = false
    if k == T_ID && tok_is(t, "Iterator") && (tok_is(t + 1, "(") || tok_is(t + 1, "<")) { return parse_iterator() }   // (#326)
    if k == T_ID && (tok_is(t, "Result") || tok_is(t, "Optional")) && tok_is(t + 1, "<") {   // Result<T, E>.err(e), Optional<T>.none, as kelvinc's #75 (#449)
        let y:int64 = parse_type()
        if tok_is(t, "Optional") && at_word("(") {       // Optional<T>(), its none, and Optional<T>(v), some(v), as kelvinc's #222 (#711)
            let open:int64 = advance()
            if at_word(")") {
                advance()
                var w = $"none"
                let e:int64 = make_node(N_ID, made_token(&w))
                toks[nodes[e].t].line = toks[open].line
                toks[nodes[e].t].file = toks[open].file
                set_ty(e, y)
                return e
            }
            var w = $"some"
            let sw:int64 = made_token(&w)
            toks[sw].line = toks[open].line
            toks[sw].file = toks[open].file
            let c:int64 = make_node(N_CALL, open)
            nodes[c].a = make_node(N_ID, sw)
            set_b(c, parse_expr())
            expect(")")
            set_ty(c, y)
            return c
        }
        expect(".")
        let w:int64 = advance()
        var n:int64 = make_node(N_ID, w)                 // the case's word, of its own type
        if at_word("(") {
            let c:int64 = make_node(N_CALL, advance())
            nodes[c].a = n
            set_b(c, parse_args())
            n = c
        }
        set_ty(n, y)
        return n
    }
    if k == T_ID && (tok_is(t, "Array") || tok_is(t, "Dictionary") || tok_is(t, "Set")) && tok_is(t + 1, "<") { return parse_make() }   // (#349), Set<T>() (#460)
    if k == T_ID && (tok_is(t, "__asm__") || tok_is(t, "__asm")) {   // assembly, left out on purpose (#399), as kelvinc says it
        var m = $"'"
        m += tok_text(t)
        m += "' is a C compiler keyword; use #inline C { __asm__ __volatile__(\"...\"); }, as C"
        parse_error(m.cstr)
        return make_node(N_NULL, advance())
    }
    if k == T_ID && tok_is(t, "asm") && tok_is(t + 1, "(") && !local_named(t) {
        parse_error("assembly is C's, a GNU extension, left out on purpose: write it in #inline C { __asm__ __volatile__(\"...\"); }")
        return make_node(N_NULL, advance())
    }
    if k == T_ID && tok_is(t, "C") && tok_is(t + 1, ".") && toks[t + 2].kind == T_ID && !local_named(t) && !program_named(t) {
        var m = $"'C."                                   // as C names no namespace (#416), as kelvinc says it
        m += tok_text(t + 2)
        m += "' names nothing: '#import <x.h> as C' brings a header's names in bare, so write '"
        m += tok_text(t + 2)
        m += "'"
        parse_error(m.cstr)
        return make_node(N_NULL, advance())
    }
    if k == T_ID && tok_is(t, "_Generic") {              // left out on purpose (#397), as kelvinc says it
        parse_error("'_Generic' is C11's, left out on purpose: a function of one name takes several types by overloads, 'let f(x:i64)' and 'let f(x:f64)', and kelvinc chooses, or has C choose (#41)")
        return make_node(N_NULL, advance())
    }
    if k == T_ID && (tok_is(t, "alignof") || tok_is(t, "_Alignof")) {   // alignof(T) (#395), C23's name
        advance()
        let n:int64 = make_node(N_ALIGN, t)
        if tok_is(t, "_Alignof") {
            parse_error_at(t, "'_Alignof' is C11's spelling: Kelvin writes alignof(T), and a value's is x.align")
            return n
        }
        if !at_word("(") {
            parse_error_at(t, "alignof takes a type, as C's does: alignof(T); a value's alignment is x.align")
            return n
        }
        advance()
        set_ty(n, parse_type())
        expect(")")
        return n
    }
    if k == T_ID && tok_is(t, "Array") && tok_is(t + 1, "(") { return parse_make() }   // Array([a, b]) (#352)
    if k == T_NUM {
        advance()
        return make_node(N_NUM, t)
    }
    if at_word("[") {                                    // a fixed array's elements, or [T](n) (#354)
        advance()
        let n:int64 = make_node(N_LIST, t)
        let word = toks[pos].kind == T_ID                // [T](n) of a type's name: a list is no function (#366)
        if word && tok_is(pos + 1, "]") && tok_is(pos + 2, "(") || word && tok_is(pos + 1, "?") && tok_is(pos + 2, "]") && tok_is(pos + 3, "(") || at_word("[") && bracket_type_ahead() {   // [T](n), n zero elements; [[T](n)](2) (#367); [i32?](2), of Optionals (#699)
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
            var e:int64 = 0 - 1
            if at_word("[") && element_designator_ahead() {   // [2] = 9, C's designator of an element, as kelvinc's (#715)
                let open:int64 = advance()
                e = make_node(N_ADESIG, open)
                nodes[e].c = parse_expr()
                expect("]")
                expect("=")
                set_a(e, parse_expr())
            } else {
                e = parse_expr()
            }
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
    if k == T_STR || k == T_TPL {                       // `text`, a template with no ${...}, is a string (#445)
        advance()
        let n:int64 = make_node(N_STR, t)
        while at_kind(T_STR) || at_kind(T_TPL) {         // "a" "b", C's adjacent literals, one: flag the others (#459)
            advance()
            nodes[n].flag += 1
        }
        return n
    }
    if k == T_TPL_HEAD { return parse_template(false) }  // (#445)
    if k == T_PUNCT && tok_is(t, "$") && toks[t + 1].kind == T_TPL_HEAD {   // $`a${x}b`, a String (#445)
        advance()
        return parse_template(true)
    }
    if k == T_DSTR {
        advance()
        let n:int64 = make_node(N_DSTR, t)
        while at_kind(T_STR) || at_kind(T_TPL) {         // $"a" "b", one String of both, as kelvinc's adjacent literals (#459, #715)
            advance()
            nodes[n].flag += 1
        }
        return n
    }
    if array_literal_ahead() {                           // ([T](N))[a, b], ([T])[a, b], an array's (#419)
        advance()
        var y:int64 = parse_type()
        if types[y].kind == Y_ARGV { y = type_of_kind(Y_FIXED, base_type(Y_CSTR), -1) }   // ([cstr])["a"]
        expect(")")
        let n:int64 = parse_primary()                    // [a, b]
        if nodes[n].kind != N_LIST || nodes[n].flag != 0 {
            parse_error("an array's compound literal takes its elements in brackets: ([T])[a, b]")
            return n
        }
        set_ty(n, y)
        return n
    }
    if literal_ahead() {                                 // (T){...}, C's compound literal (#418)
        advance()
        let y:int64 = parse_type()
        expect(")")
        literal_brace = true                             // its { ... } names $0, and is no function (#424)
        let n:int64 = parse_primary()
        set_ty(n, y)
        return n
    }
    if at_word("(") && toks[pos + 1].kind == T_ID && tok_is(pos + 2, ")") && toks[pos + 3].kind == T_NL && tok_is(pos + 4, "{") && literal_type(pos + 1) {
        pos += 4                                         // as kelvinc says it
        parse_error("a compound literal's '{' starts on the line of its '(type)': on the next line, '{' starts a block")
        return make_node(N_NULL, t)
    }
    if at_word("(") && c_cast_ahead(t) { return make_node(N_NULL, t) }   // (T)x, C's, as kelvinc says it
    if at_word("(") {
        advance()
        if at_word("{") {                        // ({ $0 + 1 }): no type says its parameters, as kelvinc says it (#32, #611)
            var i:int64 = pos + 1
            while toks[i].kind == T_NL { i += 1 }
            let written = (tok_is(i, "(") && toks[i + 1].kind == T_ID && tok_is(i + 2, ":")) || (tok_is(i, "(") && tok_is(i + 1, "var") && toks[i + 2].kind == T_ID && tok_is(i + 3, ":")) || (tok_is(i, "(") && tok_is(i + 1, ")") && (tok_is(i + 2, "in") || tok_is(i + 2, ":"))) || names_in_ahead(i)
            if !written {
                parse_error("a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'; an anonymous function here writes its parameters, as in '{ (a:i64):i64 in a + 1 }'")
                return make_node(N_NULL, t)
            }
        }
        let saved = name_annotation
        let saved_ends = brace_ends
        name_annotation = true                   // (c ? (p:point) : q) (#265)
        brace_ends = false                       // if (f(1) { $0 }) > 0 { ... } (#470)
        var e:int64 = parse_expr()
        while at_word(",") && !failed {                  // (a, b), C's comma, as kelvinc reads it (#652)
            let c:int64 = make_node(N_COMMA, advance())
            nodes[c].a = e
            nodes[c].b = parse_expr()
            e = c
        }
        name_annotation = saved
        brace_ends = saved_ends
        expect(")")
        return e
    }
    if at_word("$[") {
        advance()
        if at_word("]") {
            advance()
            return make_node(N_EMPTY, t)
        }
        if anon_depth > 0 && tok_is(pos + 1, "]") {      // $[k] of one token, in an anonymous function: its parameter k (#32, #612)
            var digits = toks[pos].kind == T_NUM
            for q in 0..<toks[pos].len {
                if !is_digit(codes[toks[pos].at + q]) { digits = false }
            }
            if !digits {
                parse_error("$[...] takes a number, as in $[0]: each parameter may have a type of its own")
                return make_node(N_NULL, t)
            }
            if toks[pos].len > 1 && codes[toks[pos].at] == '0' {
                var m = $"'$["
                m += tok_text(pos)
                m += "]' has a leading zero: write $["
                var z:int64 = 0
                while z < toks[pos].len - 1 && codes[toks[pos].at + z] == '0' { z += 1 }
                for q in z..<toks[pos].len { m += codes[toks[pos].at + q] }
                m += "]"
                parse_error_at(t, m.cstr)
                return make_node(N_NULL, t)
            }
            var name = $"$"
            name += tok_text(pos)
            let u:int64 = made_token(&name)
            toks[u].line = toks[t].line
            toks[u].file = toks[t].file
            advance()
            advance()
            return make_node(N_ID, u)
        }
        let n:int64 = make_node(N_ARRAY, t)          // $[a, b] (#266)
        var last = -1
        while !failed {
            let e:int64 = parse_expr()
            lists_grow(e)                            // $[[1, 2], [3]], an Array of Arrays, as kelvinc's (#369)
            dollar_mark(e)                           // $["a"], of Strings (#616)
            if last < 0 {
                nodes[n].b = e
            } else {
                nodes[last].next = e
            }
            last = e
            if at_word(":") {                        // $["a": 1], as kelvinc says it, at its [ (#685)
                if !failed { println(error_at_shift(nodes[n].t, toks[nodes[n].t].len == 2 ? 1 : 0), ": error: a Dictionary's entries are written in braces: ${k: v, ...}, and ${:} for none") }
                failed = true
                pos = eof_pos
                return n
            }
            if !at_word(",") { break }
            advance()
            if at_word("]") { break }                 // a comma after the last
        }
        expect("]")
        return n
    }
    if at_word("${") {                          // ${:}, ${}, ${a, b}, ${k: v} (#211, #267, #274)
        advance()
        let n:int64 = parse_brace_body(t)
        dollar_mark(n)                          // ${"k": "v"}, of Strings (#616)
        return n
    }
    if !braced && anon_ahead() { return parse_anon() }          // (#324)
    if at_word("{") {
        advance()
        let n:int64 = make_node(N_INIT, t)
        var last = -1
        skip_newlines()                                  // a { ... } of lines of its own, in parentheses too (#326)
        while !at_word("}") && !failed {
            var e:int64 = 0 - 1
            if at_word(".") && toks[pos + 1].kind == T_ID && tok_is(pos + 2, "=") {   // .name = v, C's designator (#418)
                advance()
                e = make_node(N_DESIG, advance())
                advance()
                set_a(e, parse_expr())
            } else if last < 0 {
                let saved = name_annotation
                name_annotation = false                  // {k: v}'s :, not k:T
                e = parse_expr()
                name_annotation = saved
                if at_word(":") && !failed {             // {k: v}, a Dictionary where one is written (#460)
                    nodes[n].kind = N_DICT
                    return parse_entries(n, e)
                }
            } else {
                e = parse_expr()
            }
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
        if tok_is(t, "nowhere") { return make_node(N_NULL, t) }
        if tok_is(t, "nullptr") {                        // renamed (#446), as kelvinc says it
            pos = t
            parse_error("'nullptr' is 'nowhere' in Kelvin (#446), a pointer to nothing, as 'none' is an Optional with nothing: write 'nowhere'")
            return make_node(N_NULL, t)
        }
        if tok_is(t, "self") { return make_node(N_SELF, t) }
        if codes[toks[t].at] == '$' && t < eof_pos {     // $k, an anonymous function's parameter, as kelvinc's parse_dollar (#32, #612)
            if toks[t].len > 2 && codes[toks[t].at + 1] == '0' {
                var m = $"'"
                m += tok_text(t)
                m += "' has a leading zero: write $"
                var z:int64 = 1
                while z < toks[t].len - 1 && codes[toks[t].at + z] == '0' { z += 1 }
                for q in z..<toks[t].len { m += codes[toks[t].at + q] }
                parse_error_at(t, m.cstr)
                return make_node(N_NULL, t)
            }
            if anon_depth == 0 {
                var m = $"'"
                m += tok_text(t)
                m += "' is a parameter of an anonymous function, and this is not in one"
                if in_braces(body_after_call, t) {
                    m += "; in the head of if, while or for, a '{' after a call starts the body, so pass the function inside the parentheses"
                } else if in_braces(block_after_call, t) {
                    m += "; a trailing function starts on the line of the call's ')': on the next line, '{' starts a block"
                    let held:int64 = make_node(N_NULL, t)    // said where it is written, after the call above is checked: a call that
                    held_dollars[held] = m.copy()            // lacks a function says so at the '{' first, as kelvinc's (#689)
                    return held
                }
                parse_error_at(t, m.cstr)
                return make_node(N_NULL, t)
            }
        }
        if tok_is(t, "Self") && self_name >= 0 && at_word(".") { return make_node(N_ID, self_name) }   // Self.f(), Self.x (#140)
        if tok_is(t, "Self") && self_name >= 0 && at_word("(") {   // Self(x), the type's own maker, c64(x), or a number's converter (#550)
            return make_node(tok_is(self_name, "String") || tok_is(self_name, "Bytes") ? N_TYPE : N_ID, self_name)
        }
        if tok_is(t, "IO") { io_required(t) }            // (#612)
        if tok_is(t, "IO") || tok_is(t, "String") || tok_is(t, "Bytes") { return make_node(N_TYPE, t) }   // Bytes(x) (#439)
        let le:int64 = local_named(t) ? 0 - 1 : local_enum_named(t)
        if le >= 0 { return make_node(N_ID, le) }        // an enumerator of the block's enum (#391)
        let lf:int64 = local_named(t) ? 0 - 1 : local_fn_named(t)
        if lf >= 0 { return make_node(N_ID, lf) }        // a function defined in this block or one around it (#180, #697)
        if at_word(".") && toks[pos + 1].kind == T_ID && !local_named(t) {
            let nt:int64 = type_path(t)                  // point.kind.none, kind.none in point's method (#389)
            while pos < path_end { advance() }
            return make_node(N_ID, nt)
        }
        return make_node(N_ID, t)
    }
    if at_word(".") && toks[pos + 1].kind == T_ID {        // .x, self's member x (#213)
        advance()
        let m:int64 = advance()
        if at_word("(") { return parse_method_call(make_node(N_SELF, t), m) }   // .m(a), self.m(a) (#444)
        let n:int64 = make_node(N_FIELD, m)
        nodes[n].a = make_node(N_SELF, t)
        return n
    }
    if at_word("*") && (toks[pos + 1].kind == T_ID || tok_is(pos + 1, "(")) {   // *p, as kelvinc says it
        parse_error("dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'")
        return make_node(N_NUM, t)
    }
    if k == T_PUNCT && tok_is(t, "$") && tok_is(pos + 1, "(") && adjacent(pos, pos + 1) && fn_parsing >= 0 {   // $(...), the function being written (#181), as kelvinc reads it
        if self_name >= 0 && !static_parsing {
            var m = $"'$(...)' calls the function around it, and this is a method of "
            m += tok_text(self_name)
            m += ": write 'self."
            m += tok_text(nodes[fn_parsing].t)
            m += "(...)'"
            parse_error(m.cstr)
            return make_node(N_NUM, t)
        }
        advance()
        var call:int64 = 0 - 1
        if self_name >= 0 {                              // a function of the type, T.f(...), as kelvinc's (#718)
            call = parse_method_call(make_node(N_ID, self_name), nodes[fn_parsing].t)
        } else {
            let ct:int64 = advance()
            call = make_node(N_CALL, ct)
            nodes[call].a = make_node(N_ID, nodes[fn_parsing].t)
            set_b(call, parse_args())                    // its ) too
        }
        var given:int64 = 0
        var a:int64 = nodes[call].b
        while a >= 0 {
            given += 1
            a = nodes[a].next
        }
        var takes:int64 = 0
        var p:int64 = nodes[fn_parsing].a
        while p >= 0 {
            takes += 1
            p = nodes[p].next
        }
        if given != takes && !failed {
            var m = $"'$(...)' calls "
            m += tok_text(nodes[fn_parsing].t)
            m += ", which takes "
            m += String(takes)
            m += takes == 1 ? " argument, and this gives " : " arguments, and this gives "
            m += String(given)
            parse_error_at(tok_is(t + 1, "(") ? t + 1 : t, m.cstr)   // at its (, as kelvinc's (#687)
        }
        return call
    }
    if k == T_PUNCT && tok_is(t, "$") {                  // as kelvinc says it
        parse_error("'$' alone is not a value: $\"text\" is a String, $[a, b] an Array, ${k: v} a Dictionary, and an anonymous function's parameters are $[0], $[1], ..., or $0, $1, ...")
        return make_node(N_NUM, t)
    }
    if at_word(">") && tok_is(pos - 1, "-") && toks[pos - 1].at + 1 == toks[pos].at {   // p->x, as kelvinc says it
        parse_error_at(pos - 1, "write 'p^.member' instead of 'p->member'")
        return make_node(N_NUM, t)
    }
    var q:int64 = pos                                    // as kelvinc says it, which reads past a newline (#652)
    while toks[q].kind == T_NL && !past_file(q + 1, pos) { q += 1 }
    if toks[q].kind == T_NL { q += 1 }
    var m = $"expected an expression, found "
    let found:String = found_text(q, pos)
    m += &found
    if past_file(q, pos) {
        parse_error_at_end(toks[pos].file, m.cstr)
    } else {
        parse_error_at(q, m.cstr)
    }
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
    if at_word("??=") || at_word("!!=") { return true }   // (#460)
    return at_word("!") && adjacent(pos - 1, pos)
}

var chains = 0                                   // the names of chains kc makes (#221)

// the postfix steps after e: calls, members, indexes, x!, x?.m
let parse_steps(first:int64):int64 {
    var e:int64 = first
    while !failed {
        if at_kind(T_NL) && self_name < 0 {              // .m on the next line goes on with the expression before it where there is no self, as kelvinc's #35 (#694)
            var q:int64 = pos
            while toks[q].kind == T_NL { q += 1 }
            if tok_is(q, ".") && toks[q + 1].kind == T_ID { skip_newlines() }
        }
        if (at_word("++") || at_word("--")) && !(toks[pos + 1].kind == T_NL || tok_is(pos + 1, ";") || tok_is(pos + 1, "}") || toks[pos + 1].kind == T_EOF) {   // p--^, as kelvinc says it
            var m = $"'"
            m += tok_text(pos)
            m += "' is a statement in Kelvin, not a value: step the pointer on a line of its own"
            parse_error(m.cstr)
            return e
        }
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
            let bang:int64 = advance()
            if nodes[e].kind != N_INDEX {
                var word = $"some"
                let n = make_node(N_FIELD, made_token(&word))
                nodes[n].a = e
                unwrap_nodes[n] = bang                   // x!, as kelvinc names it where x is no Optional (#629), at its '!' (#681)
                e = n
            }
            continue
        }
        if at_word("(") {
            let t:int64 = advance()
            let n:int64 = make_node(N_CALL, t)
            nodes[n].a = e
            set_b(n, parse_args())
            take_trailing(n)                             // f(a) { ... } (#470)
            e = n
        } else if at_word("[") {
            let t:int64 = advance()
            let n:int64 = make_node(N_INDEX, t)
            nodes[n].a = e
            let saved_ends = brace_ends
            brace_ends = false
            set_b(n, parse_expr())
            var last_i:int64 = nodes[n].b                // v[r, c], a subscript's indices (#136)
            while at_word(",") && !failed {
                advance()
                let more:int64 = parse_expr()
                nodes[last_i].next = more
                last_i = more
            }
            brace_ends = saved_ends
            expect("]")
            if !place_follows() { nodes[n].flag = 1 }    // read whole: a Dictionary's is an Optional (#218)
            e = n
        } else if at_word(".") {
            advance()
            let t:int64 = advance()
            if tok_is(t, "reduce") && at_word("{") {     // xs.reduce { ... }, as kelvinc says it
                parse_error_at(t, "'.reduce' takes the value to start from: write '.reduce(init) { ... }' or '.reduce(init, f)'")
                return e
            }
            if at_word("(") {
                e = parse_method_call(e, t)
            } else if (tok_is(t, "sort") || tok_is(t, "sorted")) && trailing_ahead() {   // xs.sort { ... }, its comparator trailing (#470)
                let n:int64 = make_node(N_METHOD, t)
                nodes[n].a = e
                set_b(n, parse_anon())
                e = n
            } else if (tok_is(t, "map") || tok_is(t, "filter") || tok_is(t, "flatMap") || tok_is(t, "mapWithKey") || tok_is(t, "filterWithKey") || tok_is(t, "flatMapWithKey") || tok_is(t, "contains") || tok_is(t, "firstKey") || tok_is(t, "lastKey") || tok_is(t, "containsWithKey") || tok_is(t, "firstKeyWithKey") || tok_is(t, "lastKeyWithKey") || tok_is(t, "firstIndex") || tok_is(t, "lastIndex") || tok_is(t, "prefix")) && (anon_ahead() || (at_word("{") && !brace_ends)) {   // x.map { ... }, its function trailing (#324), d.contains { ... } and the rest (#339), xs.firstIndex { ... } (#342), x.prefix { ... } (#372)
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
    if at_word("++") || at_word("--") {                  // as kelvinc says it (#459)
        var m = $"Kelvin has no prefix '"
        m += tok_text(pos)
        m += "': a pointer steps with 'p"
        m += tok_text(pos)
        m += "' as a statement (#51), and a number with 'x "
        m += tok_is(pos, "++") ? "+" : "-"
        m += "= 1'"
        parse_error(m.cstr)
        return 0 - 1
    }
    if at_word("!!") {                           // !!n, a bit's bool, flag 1 (#387), a token of its own (#460)
        let t:int64 = advance()
        let n:int64 = make_node(N_UNARY, t)
        nodes[n].flag = 1
        set_a(n, parse_unary())
        return n
    }
    if at_word("-") || at_word("!") || at_word("~") {
        let t:int64 = advance()
        let n:int64 = make_node(N_UNARY, t)
        set_a(n, parse_unary())
        return n
    }
    if at_word("+") {                            // +x (#560), as kelvinc's: C's, the value itself, a small integer's an int
        let t:int64 = advance()
        let a:int64 = parse_unary()
        if a < 0 { return a }
        if nodes[a].kind == N_NUM { return a }           // +1, +1.5: the number, which fits what 1 fits
        if nodes[a].kind == N_UNARY && tok_is(nodes[a].t, "-") && nodes[nodes[a].a].kind == N_NUM { return a }   // +-1, as -1
        let n:int64 = make_node(N_UNARY, t)
        set_a(n, a)
        return n
    }
    if at_word("&") {
        let t:int64 = advance()
        let n:int64 = make_node(N_ADDR, t)
        set_a(n, parse_unary())
        if nodes[nodes[n].a].kind == N_INDEX { nodes[nodes[n].a].flag = 0 }   // &d[k], the entry's place, as kelvinc's (#516)
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
    if at_word("try") {                          // try r, a prefix as -x is (#449), as kelvinc's #76
        let t:int64 = advance()
        let n:int64 = make_node(N_TRY, t)
        set_a(n, parse_unary())
        return n
    }
    if at_word("await") {                        // await t, its value (#313)
        let t:int64 = advance()
        let n:int64 = make_node(N_AWAIT, t)
        set_a(n, parse_unary())
        return n
    }
    if at_word("sizeof") {                       // sizeof(T), sizeof x (#420), as kelvinc's
        let t:int64 = advance()
        let n:int64 = make_node(N_SIZEOF, t)
        if at_word("(") && c_word_hint(pos + 1)[0] != 0 && pos + 1 < eof_pos {   // sizeof(int), as kelvinc says it (#612)
            var m = $"'"
            m += tok_text(pos + 1)
            m += "' is not a Kelvin type; use "
            m += c_word_hint(pos + 1)
            parse_error_at(pos + 1, m.cstr)
            return n
        }
        if at_word("(") && !literal_ahead() && !array_literal_ahead() && sizeof_type_at(pos + 1) {
            advance()                            // a compound literal's size is a value's, sizeof (T){...}
            set_ty(n, parse_type())
            expect(")")
            return n
        }
        if value_type_ahead() { nodes[n].flag = 2 }   // sizeof(x.type), gen's to tell from a member named type
        if at_kind(T_ID) && tok_is(pos + 1, "const") && sizeof_type_at(pos) {   // sizeof i32 const^, as kelvinc says it
            var m = $"sizeof a type needs parentheses: sizeof("
            let w:String = number_word(pos) >= 0 ? short_number(pos) : tok_text(pos)
            m += &w
            m += " const"
            var q:int64 = pos + 2
            while tok_is(q, "^") {
                m += "^"
                q += 1
            }
            m += ")"
            parse_error(m.cstr)
            return n
        }
        if at_kind(T_ID) && sizeof_type_at(pos) && !local_named(pos) {
            nodes[n].flag = 1                    // sizeof T, gen's error in Kelvin's words
            set_ty(n, parse_type())
            return n
        }
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
    return e
}

// x as T and x:T (#264), looser than a prefix, as kelvinc's cast: -x as u8
// is (-x) as u8, &b as T^ (&b) as T^ (#453), where kc had read &(b as T^)
let parse_cast():int64 {
    var e:int64 = parse_unary()
    while at_word("as") || annotation_ahead() {          // x as T, x:T (#264)
        let t:int64 = advance()
        let n:int64 = make_node(N_CAST, t)
        nodes[n].a = e
        let saved_cast:int64 = cast_depth
        cast_depth = type_depth + 1
        set_ty(n, parse_type())
        cast_depth = saved_cast
        e = n
        if tok_is(t, "as") && at_word("*") && (tok_is(pos + 1, ";") || tok_is(pos + 1, ":") || tok_is(pos + 1, ")") || tok_is(pos + 1, ",") || tok_is(pos + 1, "]") || toks[pos + 1].kind == T_NL || toks[pos + 1].kind == T_EOF) {
            parse_error("pointer types are written with a postfix '^', as in 'i32^'")   // x as T*, as kelvinc says it
            return e
        }
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
    if at_word("??") || at_word("!!") { return 8 }    // a value, or what an Optional holds (#217); d0 !! d1 (#460)
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
    return !(at_word("(") || at_word("-") || at_word("+") || at_word("!") || at_word("&") || at_word("$[") || at_word("${") || at_word("[") || at_word("."))
}

// whether a binary operator starts the next line, which goes on with the
// expression before it, as kelvinc's continues_expression
let operator_on_next_line():bool {
    if !at_kind(T_NL) { return false }
    let back:int64 = pos
    skip_newlines()
    let found = binding_power() > 0
    pos = back
    return found
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
        e = parse_cast()
    }
    while !failed {
        if operator_on_next_line() {
            skip_newlines()
            if at_word("*") && toks[pos + 1].kind == T_ID && adjacent(pos, pos + 1) {   // a line of *p = 1, as kelvinc says it
                parse_error("dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'")
                return e
            }
        }
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
                if tok_is(t, "..<") && at_word("]") {    // xs[1..<], as kelvinc says it of a slice
                    parse_error("a slice to the end is written [lo...]; '..<' needs an end")
                    return 0 - 1
                }
                if tok_is(t, "..<") {
                    parse_error_at(t, "'..<' needs an end, as in '0..<10'; a range without one is 'lo...'")   // at the ..<, as kelvinc's (#681)
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
        var q:int64 = pos                                 // an operator at a line's end goes on on the next, as kelvinc has no line there, in its own file (#715)
        while toks[q].kind == T_NL { q += 1 }
        if toks[q].file == toks[t].file && toks[q].kind != T_EOF { skip_newlines() }
        set_b(n, parse_binary(p == 8 ? p : p + 1))     // ?? and !! bind right to left, as kelvinc's #251 (#460)
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

// (T)x, (T *)p, (void)x, (int){1}: C's cast or compound literal of a
// type in C's words at the ( at t, kelvinc's error of it; whether one was
let c_cast_ahead(t:int64):bool {
    var i:int64 = t + 1
    var star = false
    var marks = false
    if tok_is(i, "const") {
        i += 1
        marks = true
    }
    if toks[i].kind != T_ID { return false }
    let word:int64 = i
    if tok_is(i, "long") && tok_is(i + 1, "double") && tok_is(i + 2, ")") {   // (long double)d
        parse_error_at(t, "'long' is not a Kelvin type, use f64 (long double has no Kelvin type yet)")
        return true
    }
    i += 1
    while tok_is(i, "*") || tok_is(i, "^") || tok_is(i, "const") {
        if tok_is(i, "*") { star = true }
        marks = true
        i += 1
    }
    if !tok_is(i, ")") { return false }
    let after:int64 = i + 1
    if toks[after].line != toks[i].line && toks[after].kind != T_NL { return false }
    let typed = marks || number_word(word) >= 0 || tok_is(word, "bool") || tok_is(word, "void") || c_word_hint(word)[0] != 0 || tok_ends_t(word)
    let cword = c_word_hint(word)[0] != 0 && !tok_is(word, "void")
    if tok_is(after, "{") {                              // (int){1}, (size_t*){0}: C's words in a compound literal
        if c_word_hint(word)[0] != 0 && !marks {
            var m = $"'"
            m += tok_text(word)
            m += "' is not a Kelvin type; use "
            m += c_word_hint(word)
            parse_error_at(word, m.cstr)
            return true
        }
        if star {
            parse_error_at(t, "pointer types are written with a postfix '^', as in '(i32^){0}'")   // at its (, as kelvinc's (#685)
            return true
        }
        return false
    }
    let operand = toks[after].kind == T_ID || toks[after].kind == T_NUM || toks[after].kind == T_STR || tok_is(after, "!") || tok_is(after, "++") || tok_is(after, "--") || tok_is(after, "sizeof")
    let maybe = tok_is(after, "(") || tok_is(after, "*") || tok_is(after, "&") || tok_is(after, "-") || tok_is(after, "~")
    if tok_is(word, "void") && !marks && (operand || maybe || toks[after].kind == T_NL || tok_is(after, ";")) {
        parse_error_at(t, "C casts are not Kelvin: to discard a value, write it as a statement of its own")
        return true
    }
    if !(operand || (maybe && typed)) { return false }
    if !typed && !operand { return false }
    if star {
        parse_error_at(t, "C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type; pointer types are written with a postfix '^', as in 'i32^'")
    } else if cword {                                    // (double)1: and the word's hint, as kelvinc says it
        var m = $"C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type; '"
        m += tok_text(word)
        m += "' is not a Kelvin type, use "
        m += c_word_hint(word)
        parse_error_at(t, m.cstr)
    } else {
        parse_error_at(t, "C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type")
    }
    return true
}

// whether the name at t ends in _t, as C's typedefs do: size_t, int32_t
let tok_ends_t(t:int64):bool {
    let n:int64 = toks[t].len
    return n > 2 && codes[toks[t].at + n - 2] == '_' && codes[toks[t].at + n - 1] == 't'
}

// ---------- statements ----------

let parse_block():int64

// whether the line before token t ends in a call's ')'
let prev_line_ends_call(t:int64):bool {
    var q:int64 = t - 1
    while q > 0 && toks[q].kind == T_NL { q -= 1 }
    return q > 0 && tok_is(q, ")") && toks[q].line < toks[t].line
}

// whether the token at pos is an assignment's operator
var switch_level:int64                       // the switches being read (#629)
var fn_parsing:int64 = 0 - 1                 // the function whose body is being read, which $(...) calls (#629)
var held_dollars:Dictionary<int64, String>   // $0 in a block after a call, and its error, which gen says (#689)
var unwrap_nodes:Dictionary<int64, int64>    // the x.some that x! makes (#629), and its '!' (#681)

let at_assign():bool {
    return at_word("=") || at_word(":=") || at_word("+=") || at_word("-=") || at_word("*=") || at_word("/=") || at_word("%=") || at_word("|=") || at_word("&=") || at_word("~=") || at_word("**=") || at_word("<<=") || at_word(">>=") || at_word("??=") || at_word("!!=")
}

// the end of a statement: a newline, a ;, or a } or the end after it
let end_statement() {
    if at_kind(T_NL) || at_word(";") {
        advance()
        return
    }
    if at_word("}") || at_kind(T_EOF) { return }
    if at_assign() {                                     // a = b = 1, as kelvinc says it
        parse_error("assignment is a statement in Kelvin, not a value: assign on a line of its own")
        return
    }
    if at_word("]") || at_word(")") {                    // a[0]] + 1, as kelvinc says it, of one that closes nothing open
        var m = $"'"
        m += tok_text(pos)
        m += "' closes nothing: no '"
        m += at_word("]") ? "[" : "("
        m += "' is open here"
        parse_error(m.cstr)
        return
    }
    if tok_is(pos - 1, "}") {                            // f(x) { ... } g(y), as kelvinc says it
        parse_error("expected ';' or a new line after the trailing function, before what follows")
        return
    }
    var m = $"expected ';' or a new line before "       // as kelvinc says it
    let d:String = tok_desc(pos)
    m += &d
    parse_error(m.cstr)
}

// name:Type = value, its let or var read; without :Type, the type is
// what the value gives, found when it is written (#214); c is 1 of :=
var decl_ops:Dictionary<int64, int64>   // a declaration's = or :=, by its node (#683)

let parse_var(is_let:int64):int64 {
    if fnptr_decl(pos, true) { return make_node(S_VAR, pos) }   // var T (*f)(...), as kelvinc says it
    reject_kv_name(pos)
    if kept_word(pos) {                                  // var typeof = 1, as kelvinc says it (#611)
        var m = $"expected a name, found '"
        m += tok_text(pos)
        m += "'"
        parse_error(m.cstr)
    }
    let t:int64 = advance()
    locals_seen += t                                     // a name a nested type's bare one yields to (#389)
    let n:int64 = make_node(S_VAR, t)
    nodes[n].flag = is_let
    if at_word(":") && toks[pos + 1].kind == T_ID && tok_is(pos + 2, "*") && !tok_is(pos + 3, "*") && (tok_is(pos + 3, "=") || tok_is(pos + 3, ":=") || toks[pos + 3].kind == T_NL || tok_is(pos + 3, ";")) {   // var q:int32* = p, as kelvinc says it
        parse_error_at(pos + 2, "pointer types are written with a postfix '^', as in 'i32^'")
        return n
    }
    if at_word(":") {
        advance()
        set_ty(n, parse_type())
    }
    if at_word("=") || at_word(":=") {          // := of a reference, as a cstr
        if at_word(":=") { nodes[n].c = 1 }
        decl_ops[n] = advance()                  // its = or :=, where kelvinc says an error of it (#683)
        set_a(n, parse_expr())
    }
    return n
}

// a parameter written `_`, unnamed as C's f(int) (#388): _kv_argk, the
// k-th, as kelvinc names it, so that `_` stands for several and the body
// reads none by `_`; an anonymous function's is $k, which kc writes so
// and its body may read
let unnamed_param(p:int64, k:int64, anon:bool) {
    let t:int64 = nodes[p].t
    if !tok_is(t, "_") { return }
    var name = anon ? $"$" : $"_kv_arg"
    name += String(k)
    let u:int64 = made_token(&name)
    toks[u].line = toks[t].line
    toks[u].file = toks[t].file
    nodes[p].t = u
}

// T (*f)(...) at t, C's declaration of a pointer to a function, kelvinc's
// error of it (#31): of a variable, var f:(...):T, of a member or a
// parameter f:(...):T; whether it was one
let fnptr_decl(t:int64, var_word:bool):bool {
    if toks[t].kind != T_ID || !tok_is(t + 1, "(") || !tok_is(t + 2, "*") || toks[t + 3].kind != T_ID || !tok_is(t + 4, ")") || !tok_is(t + 5, "(") { return false }
    var m = $"'"
    m += tok_text(t + 3)
    m += "' looks like a C function-pointer declaration: write '"
    if var_word { m += "var " }
    m += tok_text(t + 3)
    m += ":(...):"
    let w:String = number_word(t) >= 0 ? short_number(t) : tok_text(t)
    m += &w
    m += "' (#31)"
    parse_error_at(t, m.cstr)
    return true
}

// a parameter or a member, whose type is written
let parse_typed(is_let:int64):int64 {
    if fnptr_decl(pos, false) { return make_node(S_VAR, pos) }   // T (*f)(...), as kelvinc says it
    if at_kind(T_IMPORT) {                               // as kelvinc says it
        parse_error("#import is for the top level of a file, outside functions, structs and blocks")
        return make_node(S_VAR, pos)
    }
    if toks[pos + 1].kind != T_PUNCT || !tok_is(pos + 1, ":") { parse_error("a parameter or a member says its type: name:T") }
    return parse_var(is_let)
}

let parse_if():int64 {
    let n:int64 = make_node(S_IF, advance())
    if at_word("let") {                          // if let c(x) = e { } (#217): t c, flag x
        advance()
        nodes[n].kind = S_IFLET
        reject_kv_name(pos)                              // (#611)
        nodes[n].t = advance()
        if at_word("(") {
            advance()
            reject_kv_name(pos)
            nodes[n].flag = advance()
            expect(")")
        } else {
            nodes[n].flag = nodes[n].t                // if let x = e, of the value case: t and flag x (#442)
        }
        if !at_word("=") {                           // as kelvinc says it
            var m = $"expected '=' after the name of 'if let "
            m += tok_text(nodes[n].flag)
            m += "'"
            parse_error(m.cstr)
            return n
        }
        advance()
    }
    set_a(n, parse_cond())
    if !at_word("{") && !failed {                        // if (n > 0) n = 0, as kelvinc says it
        parse_error("the body of 'if' is a block: write 'if cond { ... }'")
        return n
    }
    set_b(n, parse_block())
    if at_word("else") {
        advance()
        if at_word("if") {
            set_c(n, parse_if())
        } else if !at_word("{") {                        // as kelvinc says it
            parse_error("expected '{' or 'if' after 'else': the body of 'else' is a block")
        } else {
            set_c(n, parse_block())
        }
    }
    return n
}

let parse_statement():int64
let parse_vars():int64    // prototypes: C's for and several declarators (#458)
let parse_cfor():int64
let parse_simple():int64
let parse_simples():int64
let reject_c_declaration()    // and C's declaration where a statement starts (#612)

// switch e { case a, b: ... default: ... } (#210): its cases a list of
// S_CASE, each with its values and its statements, up to the next case
let parse_switch():int64 {
    switch_level += 1                                    // a case inside a statement of it is said so (#629)
    let n:int64 = parse_switch_body()
    switch_level -= 1
    return n
}

let parse_switch_body():int64 {
    let n:int64 = make_node(S_SWITCH, advance())
    set_a(n, parse_cond())
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
            while nodes[lasts].next >= 0 { lasts = nodes[lasts].next }   // (#458)
            skip_newlines()
        }
        if lasts < 0 && !at_word("}") { parse_error("a case ends at the next case, and the one before this has no body: write 'case a, b:' to share a body, or 'break' to do nothing") }   // as kelvinc says it, of one another case follows: the last may be empty, default: (#714)
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

// alignas(N) or alignas(T) before a declaration (#396), as kelvinc's: a
// number, a power of two where it is a literal, or a type
let parse_alignas() {
    if at_word("_Alignas") {
        parse_error("'_Alignas' is C11's spelling: Kelvin writes alignas(N) or alignas(T) before the declaration")
        return
    }
    if !at_word("alignas") { return }
    if align_expr >= 0 || align_type >= 0 {
        parse_error("'alignas' is written once")
        return
    }
    align_tok = advance()
    expect("(")
    if at_kind(T_NUM) {
        let t:int64 = pos
        align_expr = parse_expr()
        var v:int64 = 0
        for i in 0..<toks[t].len {
            let c:uint32 = codes[toks[t].at + i]
            if c >= '0' && c <= '9' { v = v * 10 + (c - '0') as int64 }
        }
        if nodes[align_expr].kind == N_NUM && (v == 0 || (v & (v - 1)) != 0) {
            parse_error_at(t, "an alignment is a power of two, as C's: 1, 2, 4, 8, 16, ...")   // at the number (#685)
        }
    } else {
        align_type = parse_type()
    }
    expect(")")
}

// the alignas before it, if any, given to the variable or member n (#396)
let take_alignas(n:int64) {
    if align_expr < 0 && align_type < 0 { return }
    aligned += n
    aligned_exprs += align_expr
    aligned_types += align_type
}

// the alignas, spent where a declaration took it (#396)
let end_alignas() {
    align_expr = 0 - 1
    align_type = 0 - 1
}

// an alignas that no variable or member follows (#396), as kelvinc says it
let refuse_alignas() {
    if align_expr >= 0 || align_type >= 0 {
        parse_error_at(align_tok, "'alignas' is for a variable or a member: 'alignas(16) var buf:[u8](64)'")   // (#681)
        end_alignas()
    }
}

// static_assert(cond) or static_assert(cond, "message") (#394), as
// kelvinc's: C's _Static_assert, which C judges as it compiles
let parse_assert(kind:nkind):int64 {
    let n:int64 = make_node(kind, advance())
    nodes[n].b = 0 - 1
    if tok_is(nodes[n].t, "_Static_assert") {
        parse_error_at(nodes[n].t, "'_Static_assert' is C11's spelling: Kelvin writes static_assert(cond, \"message\"), its message optional")
        return n
    }
    expect("(")
    nodes[n].c = pos
    set_a(n, parse_expr())
    nodes[n].flag = pos
    if at_word(",") {
        advance()
        if !at_kind(T_STR) {
            parse_error("a static_assert's message is a string literal: static_assert(cond, \"message\")")
            return n
        }
        nodes[n].b = pos
        while at_kind(T_STR) { advance() }
    }
    expect(")")
    return n
}

let parse_struct():int64    // prototypes: a block defines types too (#391)
let parse_enum():int64

// let f(...) { } inside a function (#180): what kelvinc says of a local
// of the function around it used in its body (#654); whether it said it
// (#697)
let nested_function_error():bool {
    let open:int64 = pos + 2
    let close:int64 = group_end(open)                    // the ) of its parameters
    var own:$[int64] = $[]                               // its parameters and the names its body declares
    var q:int64 = open + 1
    while q < close {
        if toks[q].kind == T_ID && tok_is(q + 1, ":") && (tok_is(q - 1, "(") || tok_is(q - 1, ",") || tok_is(q - 1, "var")) { own += q }
        q += 1
    }
    var b:int64 = close
    while toks[b].kind != T_EOF && !tok_is(b, "{") { b += 1 }
    var depth:int64 = 0
    var e:int64 = b
    while toks[e].kind != T_EOF {
        if tok_is(e, "{") { depth += 1 }
        if tok_is(e, "}") {
            depth -= 1
            if depth == 0 { break }
        }
        if (tok_is(e, "let") || tok_is(e, "var")) && toks[e + 1].kind == T_ID { own += e + 1 }
        e += 1
    }
    for k in b..<e {
        if toks[k].kind != T_ID || tok_is(k - 1, ".") { continue }
        var mine = false
        for o in own { if same_text(o, k) { mine = true } }
        if mine { continue }
        var outer = false
        for l in locals_seen { if same_text(l, k) { outer = true } }
        if outer {
            var m = $"a function defined inside a function cannot use '"
            m += tok_text(k)
            m += "' of the function around it: C has no closures, so pass it as an argument, or make it a global"
            parse_error_at(k, m.cstr)
            return true
        }
    }
    return false
}

let parse_statement():int64 {
    let t:int64 = pos
    if at_word("case") || (at_word("default") && tok_is(pos + 1, ":")) {   // a switch reads its own, as kelvinc says it
        if switch_level > 0 {
            parse_error("a case is written at the top of the switch's block, not inside a statement of it")
        } else {
            parse_error(at_word("case") ? "'case' outside a switch" : "'default' outside a switch")
        }
        return make_node(S_BLOCK, t)
    }
    if at_word("{") && tok_is(pos + 1, "(") && ((toks[pos + 2].kind == T_ID && tok_is(pos + 3, ":")) || (tok_is(pos + 2, ")") && tok_is(pos + 3, "in"))) && prev_line_ends_call(pos) {   // f(x)\n{ (a:T) in ... }, as kelvinc says it
        parse_error("a trailing function starts on the line of the call's ')': on the next line, '{' starts a block")
        return make_node(S_BLOCK, t)
    }
    if at_word("let") && toks[pos + 1].kind == T_ID && tok_is(pos + 2, "(") && fn_parsing >= 0 && anon_depth == 0 {   // a function inside a function (#180, #654)
        if nested_function_error() { return make_node(S_BLOCK, t) }
        advance()                                        // a function of the program, _kv_outer_name in C, its block's, as kelvinc's (#697)
        let name:int64 = pos
        let hidden:int64 = hidden_token(name)
        local_fns += hidden
        local_fn_depths += block_depth
        var saved_locals:$[int64] = $[]
        for l in locals_seen { saved_locals += l }
        var saved_ended:$[int64] = $[]
        for e in ended_types { saved_ended += e }
        let saved_tok:int64 = fn_tok
        let f:int64 = parse_function()
        while locals_seen.count > 0 { locals_seen.pop() }
        for l in saved_locals { locals_seen += l }
        while ended_types.count > 0 { ended_types.pop() }
        for e in saved_ended { ended_types += e }
        fn_tok = saved_tok
        nodes[f].t = hidden
        decls += f
        return make_node(S_BLOCK, t)
    }
    if at_word("register") && (tok_is(pos + 1, "var") || tok_is(pos + 1, "let")) {   // left out on purpose, as kelvinc says it (#640)
        parse_error("'register' is C's hint to keep a variable in a register, which compilers decide for themselves: Kelvin leaves it out on purpose (#640); write 'var' alone")
        return make_node(S_BLOCK, t)
    }
    if at_word("typedef") {                              // as kelvinc says it
        parse_error("'typedef' is C's: Kelvin names a type anew with typealias, 'typealias A = T', at the top level (#294)")
        return make_node(S_BLOCK, t)
    }
    if at_kind(T_ID) && tok_is(pos + 1, ":") && tok_is(pos + 2, "(") {   // f:(i64):i64 := g, as kelvinc says it
        var m = $"declarations start with let or var: write 'var "
        m += tok_text(pos)
        m += ":...', or 'let "
        m += tok_text(pos)
        m += ":...' if it never changes"
        parse_error(m.cstr)
        return make_node(S_BLOCK, t)
    }
    if at_word("*") && toks[pos + 1].kind == T_ID {      // *p = 1, as kelvinc says it
        parse_error("dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'")
        return make_node(S_BLOCK, t)
    }
    if at_kind(T_ID) && tok_is(pos + 1, ":") && toks[pos + 2].line == toks[pos].line && codes[toks[pos].at] != '$' {   // a label of a kv_ name, as kelvinc says it
        reject_kv_name(pos)
        if failed { return make_node(S_BLOCK, t) }
        if tok_is(pos + 2, "var") || tok_is(pos + 2, "let") {   // again: var n = 0, as kelvinc says it
            parse_error_at(pos + 2, "a declaration cannot be the body of a statement or follow a label")   // at its var, as kelvinc's (#686)
            return make_node(S_BLOCK, t)
        }
    }
    if at_kind(T_ID) && tok_is(pos + 1, ":") && codes[toks[pos].at] != '$' && (toks[pos + 2].kind == T_NL || tok_is(pos + 2, ";") || tok_is(pos + 2, "}")) {   // again:, a label, C's, on its own, as kelvinc's; x:i32 is no label (#715)
        reject_kv_name(pos)
        let n:int64 = make_node(S_LABEL, advance())
        advance()                                        // its :
        if at_word(";") { advance() }
        return n
    }
    if at_word("goto") && toks[pos + 1].kind == T_ID {   // goto again, C's, as kelvinc's (#715)
        advance()
        let n:int64 = make_node(S_GOTO, advance())
        if at_word(";") { advance() }
        return n
    }
    if at_word("var") && toks[pos + 1].kind == T_ID && tok_is(pos + 2, "(") && !tok_is(pos + 3, "*") {   // var twice(...) { } in a body, as kelvinc says it; var T (*f)(...) is C's pointer
        var m = $"a function defined inside a function is written 'let "
        m += tok_text(pos + 1)
        m += "(...)', in a function's body"
        parse_error_at(pos + 1, m.cstr)                  // at its name, as kelvinc's (#686)
        return make_node(S_BLOCK, t)
    }
    if at_kind(T_ID) && tok_is(pos + 1, "^") && toks[pos + 2].kind == T_ID && (tok_is(pos + 3, ";") || toks[pos + 3].kind == T_NL) && toks[pos + 2].line == toks[pos].line {   // point^ p; as kelvinc says it
        var m = $"declarations are written 'var name:type', as in 'var x:"
        m += tok_text(pos)
        m += "'"
        parse_error(m.cstr)
        return make_node(S_BLOCK, t)
    }
    if at_word("do") {                                   // do { } while c, C's (#459)
        let n:int64 = make_node(S_DO, advance())
        if !at_word("{") {                               // as kelvinc says it
            parse_error("expected '{': the body of 'do' is a block")
            return n
        }
        set_b(n, parse_block())
        if !at_word("while") {
            parse_error("expected 'while' after the body of 'do'")
            return n
        }
        advance()
        set_a(n, parse_expr())
        end_statement()
        return n
    }
    if at_word("thread_local") && (tok_is(pos + 1, "var") || tok_is(pos + 1, "let") || tok_is(pos + 1, "static")) {   // each thread's own, static in a block (#641)
        advance()
        if at_word("static") { advance() }
        static_init = true
        let n:int64 = parse_vars()
        static_init = false
        var v:int64 = n
        while v >= 0 {
            static_decls += v
            thread_decls += v
            v = nodes[v].next
        }
        end_statement()
        return n
    }
    if at_word("_Thread_local") {                        // as kelvinc says it (#641)
        parse_error("'_Thread_local' is C's spelling: Kelvin writes 'thread_local var x' (#641)")
        return make_node(S_BLOCK, t)
    }
    if at_word("static") && (tok_is(pos + 1, "var") || tok_is(pos + 1, "let")) {   // a local that lives on, C's (#459)
        advance()
        static_init = true                               // (#612)
        let n:int64 = parse_vars()
        static_init = false
        var v:int64 = n
        while v >= 0 {
            static_decls += v
            v = nodes[v].next
        }
        end_statement()
        return n
    }
    if at_word("switch") {
        return parse_switch()
    }
    if at_word("static_assert") || at_word("_Static_assert") { return parse_assert(S_ASSERT) }   // (#394)
    if at_word("alignas") || at_word("_Alignas") {       // alignas(16) var buf:[u8](48) (#396)
        parse_alignas()
        if !at_word("var") && !at_word("let") { refuse_alignas() }
    }
    if (at_word("struct") || at_word("union") || at_word("enum")) && tok_is(pos + 1, "{") {   // one with no name, which kelvinc has not in a block, as it says it (#702)
        parse_error("declarations are written 'var name:type', as in 'var x:T'")
        return make_node(S_BLOCK, t)
    }
    if (at_word("struct") || at_word("union") || at_word("enum")) && toks[pos + 1].kind == T_ID && tok_is(pos + 2, "{") {
        let is_struct = !at_word("enum")                 // a type defined in a block (#391): the block's from here
        let is_union = at_word("union")                  // on, written before the function in C; a union too (#453)
        advance()
        local_next = true
        decls += is_struct ? parse_struct() : parse_enum()
        if is_union { nodes[decls[decls.count - 1]].flag = 1 }
        local_next = false
        return make_node(S_BLOCK, t)
    }
    if (at_word("var") || at_word("let")) && toks[pos + 1].kind == T_ID && tok_is(pos + 2, ".") {
        var r:int64 = type_path(pos + 1)                 // let pair.m() of a block's pair (#391)
        while is_nested(r) { r = outer_of.get(tok_text(r), -1) }
        if r != pos + 1 && local_own_of.get(tok_text(r), -1) >= 0 {
            var m = $"a method of a type defined inside a function is not available yet: define "
            let k:String = kelvin_name(type_path(pos + 1))
            m += &k
            m += " at the top level, or write a function that takes it"
            parse_error_at(pos + 1, m.cstr)              // at the type's name, as kelvinc's (#686)
            return make_node(S_BLOCK, t)
        }
    }
    if at_word("var") || at_word("let") {
        let n:int64 = parse_vars()
        var d:int64 = n
        while d >= 0 {                                   // (#396), each name of the declaration (#462)
            take_alignas(d)
            d = nodes[d].next
        }
        end_alignas()
        end_statement()
        return n
    }
    if at_word("if") {
        return parse_if()
    }
    if at_word("while") {
        let n:int64 = make_node(S_WHILE, advance())
        set_a(n, parse_cond())
        if !at_word("{") && !failed {                    // as kelvinc says it
            parse_error("the body of 'while' is a block: write 'while cond { ... }'")
            return n
        }
        set_b(n, parse_block())
        return n
    }
    if at_word("for") && tok_is(pos + 1, "(") { return parse_cfor() }   // C's for (init; cond; step) (#458)
    if at_word("for") {
        advance()
        reject_kv_name(pos)                              // (#611)
        let v:int64 = advance()
        var second = -1
        if at_word(",") {                       // for k, v in d (#269)
            advance()
            reject_kv_name(pos)
            second = advance()
        }
        var written:int64 = 0 - 1
        if at_word(":") {                       // for c:u32 in s, for i:u8 in 0..<n: a type written (#523), as kelvinc's #480
            advance()
            written = parse_type()
        }
        if !at_word("in") {
            var m = $"expected 'in', as in 'for "
            m += tok_text(v)
            m += " in 0..<n { ... }', or 'for (...)'"
            parse_error(m.cstr)
            return make_node(S_BREAK, v)
        }
        expect("in")
        var q:int64 = pos                                // 0..n, as kelvinc says it
        while q < eof_pos && !tok_is(q, "{") && toks[q].kind != T_NL {
            let two = tok_is(q, ".") && tok_is(q + 1, ".") && toks[q].at + 1 == toks[q + 1].at
            let num_dot = toks[q].kind == T_NUM && codes[toks[q].at + toks[q].len - 1] == '.' && tok_is(q + 1, ".")
            if (two && !tok_is(q + 2, "<") && !tok_is(q + 2, ".")) || num_dot {
                if !failed { println(error_at_shift(q, num_dot ? toks[q].len - 1 : 0), ": error: expected '..<' or '...' in a range, as in '0..<n' or '1...n'") }   // at its first ., as kelvinc's (#687)
                failed = true
                pos = eof_pos
                return make_node(S_BREAK, v)
            }
            q += 1
        }
        let from:int64 = parse_cond()
        if !failed && at_word(".") && tok_is(pos + 1, ".") {   // 0..n, as kelvinc says it
            parse_error("expected '..<' or '...' in a range, as in '0..<n' or '1...n'")
            return make_node(S_BREAK, v)
        }
        if !failed && !at_word("{") {                    // as kelvinc says it
            parse_error("expected '{': the body of 'for' is a block, as in 'for i in a..<b { ... }'")
            return make_node(S_BREAK, v)
        }
        if !failed && nodes[from].kind == N_RANGE {      // for i in a..<b; a...b, a..., ..<b, ...b, flag as the range's (#373)
            let n:int64 = make_node(S_FOR, v)
            nodes[n].a = nodes[from].a
            nodes[n].b = nodes[from].b
            nodes[n].flag = nodes[from].flag
            nodes[n].ty = written
            range_values -= 1
            set_c(n, parse_block())
            return n
        }
        let n:int64 = make_node(S_EACH, v)
        nodes[n].a = from
        nodes[n].ty = written
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
    reject_c_declaration()                               // size_t * b[3]; (#612)
    if failed { return make_node(S_BLOCK, t) }
    let n:int64 = parse_simples()                        // x = 1, y = 2, C's comma, each a statement (#458)
    end_statement()
    return n
}

// an expression or an assignment, a statement's or a C for's step (#458)
let parse_simple():int64 {
    let t:int64 = pos
    let e:int64 = parse_expr()
    if at_word("++") || at_word("--") {                  // p++ and p-- step a pointer, as statements (#51, #459)
        let n:int64 = make_node(S_ASSIGN, advance())
        nodes[n].a = e
        nodes[n].b = 0 - 1
        return n
    }
    if at_word("=") || at_word(":=") || at_word("+=") || at_word("-=") || at_word("*=") || at_word("/=") || at_word("%=") || at_word("|=") || at_word("&=") || at_word("~=") || at_word("**=") || at_word("<<=") || at_word(">>=") || at_word("??=") || at_word("!!=") {
        let n:int64 = make_node(S_ASSIGN, advance())        // := of a reference (#233)
        nodes[n].a = e
        set_b(n, parse_expr())
        return n
    }
    let n:int64 = make_node(S_EXPR, t)
    nodes[n].a = e
    return n
}

// var a:T = x, b:T = y, as kelvinc reads several declarators (#458): each
// an S_VAR, of the first's let or var, the rest along its next
let parse_vars():int64 {
    let is_let = at_word("let")
    advance()
    let first:int64 = parse_var(0)
    if is_let { nodes[first].flag = 1 }
    if is_let && nodes[first].a < 0 && !failed { let_needs_value(first) }   // (#611)
    var last:int64 = first
    while at_word(",") && !failed {
        advance()
        let m:int64 = parse_var(0)
        if is_let { nodes[m].flag = 1 }
        if is_let && nodes[m].a < 0 && !failed { let_needs_value(m) }
        nodes[last].next = m
        last = m
    }
    return first
}

// for (init; cond; step) body, C's (#458), as kelvinc's #10: the init
// declarations or assignments, each part optional, the steps a list,
// the body a block or one statement; the init's names the loop's alone
let parse_cfor():int64 {
    let n:int64 = make_node(S_CFOR, advance())
    nodes[n].flag = 0 - 1
    expect("(")
    if at_word("var") || at_word("let") {
        nodes[n].a = parse_vars()
    } else if !at_word(";") {
        reject_c_declaration()                           // for (size_t * r = &n; ; ), as kelvinc says it
        if failed { return n }
        nodes[n].a = parse_simples()
    }
    expect(";")
    if !at_word(";") { set_b(n, parse_comma_expr()) }   // f(), i < 4, C's comma (#715)
    expect(";")
    if !at_word(")") { nodes[n].flag = parse_simples() }
    expect(")")
    skip_newlines()
    if at_word("{") {
        set_c(n, parse_block())
    } else {
        let b:int64 = make_node(S_BLOCK, pos)
        if at_word("var") || at_word("let") || (at_word("static") && (tok_is(pos + 1, "var") || tok_is(pos + 1, "let"))) {   // as kelvinc says it (#612)
            parse_error("a declaration cannot be the body of a statement or follow a label; put it in a block, or write 'label: ;' before it")
            return n
        }
        nodes[b].a = parse_statement()
        set_c(n, b)
    }
    return n
}

// the token after the group that opens at token i, ( ) or [ ]
let group_end(i:int64):int64 {
    var depth = 0
    var k:int64 = i
    while k < eof_pos {
        if tok_is(k, "(") || tok_is(k, "[") || tok_is(k, "$[") { depth += 1 }
        if tok_is(k, ")") || tok_is(k, "]") {
            depth -= 1
            if depth == 0 { return k + 1 }
        }
        k += 1
    }
    return k
}

// whether token t is const or volatile
let qualifier_tok(t:int64):bool {
    return tok_is(t, "const") || tok_is(t, "volatile")
}

// whether token t names a value so far: a local, a parameter, a global
// or a function, as kelvinc's binding of it (#612)
let value_named(t:int64):bool {
    if toks[t].kind != T_ID { return false }
    if codes[toks[t].at] == '$' || local_named(t) || anon_param(t) { return true }
    for d in nodes {
        if (d.kind == D_GLOBAL || d.kind == D_FN) && same_text(d.t, t) { return true }
    }
    return false
}

// C's declaration where a statement starts, `size_t * b[3];`, `FILE *fp`,
// `T (*f)(int)`, as kelvinc's reject_c_declaration finds one (#27, #31,
// #612): a type's name, stars, a name and its (...) and [...], then the
// statement's end, = or a comma; kelvinc's error says how Kelvin writes
// it. `a * b` of a value a is an expression, and so is a body's one
let reject_c_declaration() {
    if failed { return }
    var i:int64 = pos
    var storage:int64 = 0 - 1
    if tok_is(i, "static") || tok_is(i, "extern") || tok_is(i, "register") || tok_is(i, "auto") {
        storage = i
        i += 1
    }
    var base_const = false
    var base_volatile = false
    while qualifier_tok(i) {
        if tok_is(i, "const") { base_const = true } else { base_volatile = true }
        i += 1
    }
    var type = $""
    var spaced = false
    let type_at:int64 = i
    if tok_is(i, "struct") || tok_is(i, "union") || tok_is(i, "enum") {
        if toks[i + 1].kind != T_ID { return }
        type = tok_text(i)
        type += " "
        type += tok_text(i + 1)
        spaced = true
        i += 2
    } else if toks[i].kind == T_ID && i < eof_pos {
        let base = number_word(i) >= 0 || tok_is(i, "bool") || tok_is(i, "any") || tok_is(i, "cstr") || tok_is(i, "String") || tok_is(i, "Bytes") || tok_is(i, "IO")
        if (kept_word(i) && !base) || tok_is(i, "__attribute__") || tok_is(i, "_Pragma") || tok_is(i, "self") || tok_is(i, "Self") { return }
        if tok_is(i + 1, "(") && !tok_is(i + 2, "*") { return }   // a converter's call, i64(x), but T (*f)(...)
        type = number_word(i) >= 0 ? short_number(i) : tok_text(i)   // int32 is i32 in the hint, as kelvinc writes it
        i += 1
    } else {
        return
    }
    while qualifier_tok(i) {
        if tok_is(i, "const") { base_const = true } else { base_volatile = true }
        i += 1
    }
    var suffix = $""
    var block = false
    while tok_is(i, "*") || tok_is(i, "**") {            // **, a power's token since #380, is two here
        suffix += tok_is(i, "**") ? "^^" : "^"
        i += 1
        while qualifier_tok(i) {
            suffix += " "
            suffix += tok_text(i)
            i += 1
        }
    }
    if suffix.count == 0 && tok_is(i, "~") {
        block = true
        i += 1
    }
    var quals = base_const ? $"const " : $""
    if base_volatile { quals += "volatile " }
    var name_at:int64 = i
    if tok_is(i, "(") && tok_is(i + 1, "*") && toks[i + 2].kind == T_ID && tok_is(i + 3, ")") && tok_is(i + 4, "(") {
        let end:int64 = group_end(i + 4)                 // T (*f)(...): a pointer to a function (#31)
        if tok_is(end, ";") || tok_is(end, ",") || tok_is(end, "=") {
            var m = $"'"
            m += tok_text(i + 2)
            m += "' looks like a C function-pointer declaration: write 'var "
            m += tok_text(i + 2)
            m += ":(...):"
            m += &quals
            m += &type
            m += &suffix
            m += "' (#31)"
            parse_error(m.cstr)
            return
        }
    }
    if tok_is(i, "(") && (suffix.count > 0 || block) {
        let end:int64 = group_end(i)
        name_at = i
        while name_at < end && toks[name_at].kind != T_ID { name_at += 1 }
        if name_at >= end { return }
        i = end
    } else if toks[i].kind == T_ID && !kept_word(i) {
        i += 1
    } else {
        return
    }
    var function = false
    var function_pointer = false
    var dims:$[String] = $[]
    while tok_is(i, "(") || tok_is(i, "[") || tok_is(i, "^") {   // a ( on the next line is after a T_NL, and no part of it
        if tok_is(i, "^") { suffix += "^" }
        if tok_is(i, "(") {
            if tok_is(i - 1, "^") { function_pointer = true }
            function = true
        }
        let end:int64 = tok_is(i, "^") ? i + 1 : group_end(i)
        if tok_is(i, "[") {
            var d = $""
            for k in i + 1..<end - 1 { d += tok_text(k) }
            dims += d.copy()
        }
        i = end
    }
    var after:int64 = i
    while toks[after].kind == T_NL { after += 1 }
    let ends = toks[i].kind == T_NL || toks[i].kind == T_EOF || tok_is(i, "}")
    if !tok_is(i, ";") && !tok_is(i, ",") && !tok_is(i, "=") && !ends { return }
    var before:int64 = pos - 1
    while before > 0 && toks[before].kind == T_NL { before -= 1 }
    let alone = tok_is(before, "{") && tok_is(after, "}") && !tok_is(i, "=") && (block_depth == 1 || anon_depth > 0)   // a body's one expression, which it returns
    if (suffix.count > 0 || block) && storage < 0 && !base_const && !base_volatile && !spaced && ((value_named(type_at) && !tok_is(i, "=")) || alone || value_named(name_at)) { return }
    let name:String = tok_text(name_at)
    var m = $""
    if block {
        m = $"'"
        m += &type
        m += " ~ "
        m += &name
        m += "' as a statement would be read by C as a block-pointer declaration; declarations are written 'var name:type'"
    } else if function_pointer {
        m = $"'"
        m += &name
        m += "' looks like a C function-pointer declaration: write 'var "
        m += &name
        m += ":(...):"
        m += &quals
        m += &type
        m += "' (#31)"
    } else if function {
        m = $"functions are declared at the top level as 'let "
        m += &name
        m += "(...):"
        m += &quals
        m += &type
        m += &suffix
        m += "'"
    } else {
        var spelled:String = quals.copy()
        spelled += &type
        spelled += &suffix
        var k:int64 = dims.count as int64 - 1
        while k >= 0 {                                   // int a[2][3] is [[i32](3)](2) (#49)
            var outer = $"["
            outer += &spelled
            outer += "]"
            if dims[k].count > 0 {
                outer += "("
                outer += &dims[k]
                outer += ")"
            }
            spelled = outer.copy()
            k -= 1
        }
        m = $"declarations are written 'var name:type', as in '"
        if storage >= 0 {
            m += tok_text(storage)
            m += " "
        }
        m += "var "
        m += &name
        m += ":"
        m += &spelled
        m += "'"
    }
    parse_error(m.cstr)
}

// a, b, ...: expressions or assignments, a C for's init or steps (#458)
let parse_simples():int64 {
    let first:int64 = parse_simple()
    var last:int64 = first
    while at_word(",") && !failed {
        advance()
        let m:int64 = parse_simple()
        nodes[last].next = m
        last = m
    }
    return first
}

// { statements }, as a list in an S_BLOCK
let parse_block():int64 {
    let n:int64 = make_node(S_BLOCK, pos)
    expect("{")
    block_depth += 1
    var last = -1
    skip_newlines()
    while !at_word("}") && !failed {
        if past_file(pos, nodes[n].t) {                  // as kelvinc says it, at the { (#652)
            parse_error_at(nodes[n].t, "unterminated block")
            break
        }
        if at_kind(T_IMPORT) {                           // as kelvinc says it (#652)
            parse_error("#import is for the top level of a file, outside functions, structs and blocks")
            break
        }
        if at_word(";") {                                // an empty statement, as `for ... { ... };` ends one (#451)
            advance()
            skip_newlines()
            continue
        }
        let s:int64 = parse_statement()
        if last < 0 {
            nodes[n].a = s
        } else {
            nodes[last].next = s
        }
        last = s
        while nodes[last].next >= 0 { last = nodes[last].next }   // var a = 1, b = 2, two (#458)
        skip_newlines()
    }
    expect("}")
    block_depth -= 1
    while local_types.count > 0 && local_type_depths[local_type_depths.count - 1] > block_depth {   // the block's own end (#391)
        ended_types += local_types.pop()
        local_type_depths.pop()
    }
    while local_enums.count > 0 && local_enum_depths[local_enum_depths.count - 1] > block_depth {
        local_enums.pop()
        local_enum_depths.pop()
    }
    while local_fns.count > 0 && local_fn_depths[local_fn_depths.count - 1] > block_depth {   // (#697)
        local_fns.pop()
        local_fn_depths.pop()
    }
    return n
}

// ---------- declarations ----------

// whether token t is an operator a struct may define (#42), ** too (#380)
let overloadable_tok(t:int64):bool {
    return tok_is(t, "+") || tok_is(t, "-") || tok_is(t, "*") || tok_is(t, "/") || tok_is(t, "%") || tok_is(t, "==") || tok_is(t, "!=") || tok_is(t, "<") || tok_is(t, "<=") || tok_is(t, ">") || tok_is(t, ">=") || tok_is(t, "**") || tok_is(t, "&") || tok_is(t, "|") || tok_is(t, "~") || tok_is(t, "<<") || tok_is(t, ">>")   // bitwise (#502)
}

// whether token t is x op= y that a type may define (#518)
let compound_tok(t:int64):bool {
    return tok_is(t, "+=") || tok_is(t, "-=") || tok_is(t, "*=") || tok_is(t, "/=") || tok_is(t, "%=") || tok_is(t, "**=") || tok_is(t, "&=") || tok_is(t, "|=") || tok_is(t, "~=") || tok_is(t, "<<=") || tok_is(t, ">>=")
}

// whether a method's head is at token i, T.m( or point.kind.m( (#389)
let head_method(i:int64):bool {
    type_path(i)
    return tok_is(path_end, ".") && tok_is(path_end + 2, "(")
}

// a function's names begin anew at its head
let begin_function(n:int64) {
    while locals_seen.count > 0 { locals_seen.pop() }    // (#389)
    while ended_types.count > 0 { ended_types.pop() }    // (#391)
    fn_tok = nodes[n].t
}

// (a:T, b:U), the parameters of the function n
let parse_params(n:int64) {
    expect("(")
    var last = -1
    var k:int64 = 0
    while !at_word(")") && !failed {
        if at_word("...") {                     // C's variadic function, printf(fmt:cstr, ...) (#453)
            if k == 0 { parse_error("a variadic function needs at least one named parameter") }
            advance()
            variadic_fns += n
            break
        }
        var is_let = 1
        if at_word("var") {                     // a var parameter may change (#271)
            advance()
            is_let = 0
        }
        let lent = tok_is(pos + 1, ":") && tok_is(pos + 2, "lent") && (toks[pos + 3].kind == T_ID || tok_is(pos + 3, "$") || tok_is(pos + 3, "$[") || tok_is(pos + 3, "${"))   // b:lent T (#510), b:lent $[T] (#531)
        if lent { lent_at = pos + 2 }
        let p:int64 = parse_typed(is_let)
        if lent { lent_params[p] = true }
        unnamed_param(p, k, false)
        k += 1
        if last < 0 {
            nodes[n].a = p
        } else {
            nodes[last].next = p
        }
        last = p
        if at_word(",") { advance() }
    }
    expect(")")
}

let parse_function():int64 {
    reject_kv_name(pos)                                  // (#611)
    let w:int64 = self_name < 0 ? anon_case_enum(pos) : 0 - 1
    if w >= 0 {                                          // a case's name, a word of the program, as kelvinc says it (#655)
        var e = $"'"
        e += tok_text(pos)
        e += "' is a case of "
        let sp:String = anon_enum_spelling(w)
        e += &sp
        e += ", a word of the program: name the function otherwise, or give the enum a tag"
        parse_error(e.cstr)
        return make_node(D_FN, pos)
    }
    let n:int64 = make_node(D_FN, advance())
    begin_function(n)
    parse_params(n)
    nodes[n].ty = base_type(Y_VOID)
    if at_word(":") && tok_is(pos + 1, "(") && tok_is(pos + 2, ")") && !tok_is(pos + 3, ":") {
        advance()                                        // :(), none, as a module's header writes it (#515)
        advance()
        advance()
    } else if at_word(":") {
        advance()
        if toks[pos].kind == T_ID && tok_is(pos + 1, ".") {   // p.x.type of a parameter, as kelvinc says it (#653)
            var q:int64 = pos
            while tok_is(q + 1, ".") && toks[q + 2].kind == T_ID && !tok_is(q, "type") { q += 2 }
            var named = false
            var p:int64 = nodes[n].a
            while p >= 0 {
                if same_text(nodes[p].t, pos) { named = true }
                p = nodes[p].next
            }
            if named && tok_is(q, "type") {
                var m = $"the result type, "
                let w:String = span_text(pos, q + 1)
                m += &w
                m += ", names a parameter, which C has not seen where it writes the result: write the type itself"
                parse_error_at(pos, m.cstr)
                return n
            }
        }
        set_ty(n, parse_type())
    }
    let outer_fn:int64 = fn_parsing
    fn_parsing = n                                       // what $(...) calls (#181, #629)
    if at_word("{") { set_b(n, parse_block()) }
    fn_parsing = outer_fn
    return n
}

// what a computed attribute's function is (#131, #132): 1 a let
// attribute's getter, 2 a var attribute's, 3 its setter
var attributes:Dictionary<int64, int64>
var attribute_names:Dictionary<String, bool>   // the names any attribute has

// whether token t is of a module's header, M.kh, whose declarations have
// no bodies: libkelvin defines them (#515)
let in_kh(t:int64):bool {
    let name:String = fnames[toks[t].file].copy()
    var cs:$[uint32] = $[]
    for c in name.codepoints { cs += c }
    let n = cs.count as int64
    return n > 3 && cs[n - 3] == '.' && cs[n - 2] == 'k' && cs[n - 1] == 'h'
}

// the function of an attribute of the type at token recv, its body next
let attribute_fn(t:int64, recv:int64, ty:int64, what:int64, inl:bool):int64 {
    let n:int64 = make_node(D_FN, t)
    begin_function(n)
    nodes[n].c = recv
    nodes[n].flag = what == 3 ? 2 : 0                  // a setter changes the caller's var, as a var method (#320)
    set_ty(n, what == 3 ? base_type(Y_VOID) : ty)
    attributes[n] = what
    if inl { inline_fns += n }
    return n
}

// let T.x:R { }, var T.x:R { get { } set(v) { } }, at the name, as
// kelvinc's #131 and #132: T__x(self), and T__set_x(&var, v)
let parse_attribute(recv:int64, is_var:bool, inl:bool) {
    reject_kv_name(pos)                                  // (#611)
    let t:int64 = advance()
    let nm:String = tok_text(t)
    attribute_names[nm] = true
    expect(":")
    let ty:int64 = parse_type()
    if !is_var {
        let g:int64 = attribute_fn(t, recv, ty, 1, inl)
        if !in_kh(t) || at_word("{") { set_b(g, parse_block()) }   // a module's header has none (#515)
        decls += g
        return
    }
    expect("{")
    skip_newlines()
    if !at_word("get") {
        parse_error("a var attribute starts with its getter, 'get { ... }', then its setter, 'set(v) { ... }'")
        return
    }
    advance()
    let g:int64 = attribute_fn(t, recv, ty, 2, inl)
    set_b(g, parse_block())
    decls += g
    skip_newlines()
    if !at_word("set") {
        var m = $"after the getter comes the setter, 'set(v) { ... }', with v the new value; a let attribute, 'let "
        m += tok_text(recv)
        m += "."
        m += &nm
        m += ":R { ... }', has none"
        parse_error(m.cstr)
        return
    }
    advance()
    expect("(")
    var word = $"set_"
    word += &nm
    let st:int64 = made_token(&word)
    toks[st].line = toks[t].line
    toks[st].file = toks[t].file
    let s:int64 = attribute_fn(st, recv, ty, 3, inl)
    let p:int64 = make_node(S_VAR, advance())
    locals_seen += nodes[p].t
    nodes[p].flag = 1
    set_ty(p, ty)
    nodes[s].a = p
    expect(")")
    set_b(s, parse_block())
    decls += s
    skip_newlines()
    expect("}")
}

// what a subscript's function is (#136): 1 a getter, 2 a setter
var subscripts:Dictionary<int64, int64>
var sub_getters:$[int64]
var sub_setters:$[int64]

// let T[](i:I, ...):R { }, var T[](i:I, ...):R { get { } set(v) { } }, at
// the [, as kelvinc's #136: a getter whose self is a const pointer to the
// receiver, so nothing is copied or moved, flag 3, and a setter whose self
// is the caller's var, a var method to C
let parse_subscript(recv:int64, is_var:bool, inl:bool) {
    let at:int64 = advance()
    expect("]")
    var gw = $"subscript"
    let gt:int64 = made_token(&gw)
    toks[gt].line = toks[at].line
    toks[gt].file = toks[at].file
    let g:int64 = make_node(D_FN, gt)
    begin_function(g)
    nodes[g].c = recv
    nodes[g].flag = 3
    subscripts[g] = 1
    sub_getters += g
    if inl { inline_fns += g }
    parse_params(g)
    if nodes[g].a < 0 {
        parse_error_at(at, "a subscript takes at least one index, as in 'let [](i:i64):R { ... }'")   // at its [, as kelvinc's (#686)
        return
    }
    if !at_word(":") {
        parse_error("a subscript gives a value: write its type, as in 'let [](i:i64):R { ... }'")
        return
    }
    advance()
    set_ty(g, parse_type())
    if !is_var {
        if !in_kh(at) || at_word("{") { set_b(g, parse_block()) }  // a module's header has none (#515)
        decls += g
        return
    }
    expect("{")
    skip_newlines()
    if !at_word("get") {
        parse_error("a var subscript starts with its getter, 'get { ... }', then its setter, 'set(v) { ... }'")
        return
    }
    advance()
    set_b(g, parse_block())
    decls += g
    skip_newlines()
    if !at_word("set") {
        parse_error("after the getter comes the setter, 'set(v) { ... }', with v the new value")
        return
    }
    advance()
    expect("(")
    var sw = $"subscript_set"
    let st:int64 = made_token(&sw)
    toks[st].line = toks[at].line
    toks[st].file = toks[at].file
    let s:int64 = make_node(D_FN, st)
    begin_function(s)
    nodes[s].c = recv
    nodes[s].flag = 2
    set_ty(s, base_type(Y_VOID))
    subscripts[s] = 2
    sub_setters += s
    if inl { inline_fns += s }
    var last:int64 = 0 - 1
    var q:int64 = nodes[g].a
    while q >= 0 {                                      // its indices, and the new value last
        let c:int64 = make_node(S_VAR, nodes[q].t)
        nodes[c].flag = 1
        set_ty(c, nodes[q].ty)
        locals_seen += nodes[c].t
        if last < 0 { nodes[s].a = c } else { nodes[last].next = c }
        last = c
        q = nodes[q].next
    }
    let v:int64 = make_node(S_VAR, advance())
    nodes[v].flag = 1
    set_ty(v, nodes[g].ty)
    locals_seen += nodes[v].t
    nodes[last].next = v
    expect(")")
    set_b(s, parse_block())
    decls += s
    skip_newlines()
    expect("}")
}

// whether a subscript's head is at token i, T[]( or point.kind[](
let head_subscript(i:int64):bool {
    type_path(i)
    return tok_is(path_end, "[") && tok_is(path_end + 1, "]") && tok_is(path_end + 2, "(")
}

var type_attrs:Dictionary<String, int64>   // T.x by its text: the token of T__x, a type attribute's global (#133)

// static let T.x:R = v, static var T.x = v, at the name, as kelvinc's #133:
// a global of the type, named T__x in C
let parse_type_attribute(recv:int64, is_let:bool) {
    if static_named(recv, pos) >= 0 {                    // as kelvinc says it (#595)
        var m = $"'"
        m += tok_text(pos)
        m += "' is a computed attribute or a function of "
        m += tok_text(recv)
        m += " already: an attribute of a type is stored or computed, not both"
        parse_error(m.cstr)
        return
    }
    let nm:String = tok_text(pos)
    attribute_names[nm] = true
    let t:int64 = pos
    let n:int64 = parse_var(0)
    let declared = nodes[n].a < 0 && in_kh(t)            // a module's, in its header, as math's f64.tau (#590): extern in C, as kelvinc's (#146)
    if is_let && nodes[n].a < 0 && !declared {
        var m = $"a static let needs a value: write 'static let "
        m += tok_text(recv)
        m += "."
        m += &nm
        m += " = ...', or 'static var' if it changes"
        parse_error_at(t, m.cstr)                        // at its name, as kelvinc's (#681)
        return
    }
    var word:String = number_word(recv) >= 0 ? type_word(number_word(recv)) : tok_text(recv)   // int64 is i64 (#545)
    var key:String = word.copy()
    word += "__"
    word += &nm
    key += "."
    key += &nm
    let g:int64 = made_token(&word)
    toks[g].line = toks[t].line
    toks[g].file = toks[t].file
    type_attrs[key] = g
    nodes[n].t = g
    nodes[n].kind = D_GLOBAL
    if is_let { nodes[n].flag = 1 }
    if declared { extern_decls += n }
    decls += n
}

var static_attrs:Dictionary<int64, bool>   // the functions that are a type's computed attributes, static let T.x:R { } (#595)

// whether the static member named at token i is a computed attribute of
// the type, static let x:R { } (#595), as kelvinc's static_computed: a
// type and then a body, where a stored one, static let x:R = v, has a
// value; a { after a : or a word of a type is the type's
let static_computed(i:int64):bool {
    if toks[i].kind != T_ID || !tok_is(i + 1, ":") { return false }
    var j:int64 = i + 2
    var depth = 0
    while toks[j].kind != T_EOF {
        if tok_is(j, "(") || tok_is(j, "[") {
            depth += 1
        } else if tok_is(j, ")") || tok_is(j, "]") || tok_is(j, "}") {
            depth -= 1
        } else if tok_is(j, "{") {
            let typed = tok_is(j - 1, ":") || tok_is(j - 1, "enum") || tok_is(j - 1, "struct") || tok_is(j - 1, "union") || tok_is(j - 1, "$")
            if depth == 0 && !typed { return true }
            depth += 1
        } else if depth == 0 && (tok_is(j, "=") || tok_is(j, ":=") || tok_is(j, ";") || toks[j].kind == T_NL) {
            return false
        }
        if depth < 0 { return false }
        j += 1
    }
    return false
}

// the function of the type at token recv that token nm names, static let
// T.nm(...) or a computed attribute, static let T.nm:R { }, declared so
// far; or -1 (#595)
let static_named(recv:int64, nm:int64):int64 {
    for d in decls {
        if nodes[d].kind == D_FN && nodes[d].c >= 0 && nodes[d].flag == 1 && same_text(nodes[d].c, recv) && same_text(nodes[d].t, nm) { return d }
    }
    return -1
}

// one name is an attribute of a type or a function of it, as kelvinc
// says it (#595): whether f, of the name at nm, is the other kind
let static_clash(recv:int64, nm:int64, f:int64, computed:bool):bool {
    if f < 0 || static_attrs.has(f) == computed { return false }
    var m = $"'"
    m += tok_text(nm)
    m += static_attrs.has(f) ? "' is a computed attribute of " : "' is a function of "
    m += tok_text(recv)
    m += " already: one name is an attribute of a type, read as "
    m += tok_text(recv)
    m += "."
    m += tok_text(nm)
    m += ", or a function of it, called"
    parse_error(m.cstr)
    return true
}

// static let T.x:R { ... }, at the name (#595), as kelvinc's: a function
// of the type with no parameters, T__x(), which each read of T.x calls;
// in a module's header it is said so, { get }, with no body
let parse_static_attribute(recv:int64, inl:bool) {
    if static_clash(recv, pos, static_named(recv, pos), true) { return }
    var key:String = tok_text(recv)
    key += "."
    key += tok_text(pos)
    if type_attrs.has(key) {                             // as kelvinc says it
        var m = $"'"
        m += tok_text(pos)
        m += "' is a stored attribute of "
        m += tok_text(recv)
        m += " already, 'static let "
        m += &key
        m += " = ...': an attribute of a type is stored or computed, not both"
        parse_error(m.cstr)
        return
    }
    let t:int64 = advance()
    let nm:String = tok_text(t)
    attribute_names[nm] = true
    expect(":")
    let ty:int64 = parse_type()
    let n:int64 = make_node(D_FN, t)
    begin_function(n)
    nodes[n].c = recv
    nodes[n].flag = 1
    set_ty(n, ty)
    static_attrs[n] = true
    if in_kh(t) && at_word("{") && tok_is(pos + 1, "get") && tok_is(pos + 2, "}") {
        advance()
        advance()
        advance()
    } else {
        set_b(n, parse_block())
    }
    if inl { inline_fns += n }
    decls += n
}

// whether an attribute's head is at token i, T.x: or point.kind.x:
let head_attribute(i:int64):bool {
    type_path(i)
    return tok_is(path_end, ".") && toks[path_end + 1].kind == T_ID && (tok_is(path_end + 2, ":") || tok_is(path_end + 2, "="))
}

let parse_struct():int64 {
    let n:int64 = make_node(D_STRUCT, record_name())
    type_of_kind(Y_STRUCT, -1, nodes[n].t)
    expect("{")
    let saved_body:int64 = body_struct
    let saved_outer:int64 = nest_outer
    body_struct = nodes[n].t                         // its members name its nested types bare (#389)
    nest_outer = 0 - 1
    var last = -1
    skip_newlines()
    while !at_word("}") && !failed {
        if (at_word("struct") || at_word("union") || at_word("enum")) && tok_is(pos + 1, "{") {   // one with no name, which kelvinc has not in a type, as it says it (#702)
            var m = $"expected a name, found '"
            m += tok_text(pos)
            m += "'"
            parse_error(m.cstr)
            break
        }
        if (at_word("struct") || at_word("union") || at_word("enum")) && toks[pos + 1].kind == T_ID && tok_is(pos + 2, "{") {
            let is_struct = !at_word("enum")             // a type of its own, defined inside (#389): point.kind,
            let is_union = at_word("union")              // written before this one in C; a union too (#453)
            advance()
            nest_outer = nodes[n].t
            decls += is_struct ? parse_struct() : parse_enum()
            if is_union { nodes[decls[decls.count - 1]].flag = 1 }
            nest_outer = 0 - 1
            if at_word(",") || at_word(";") { advance() }
            skip_newlines()
            continue
        }
        let outer_e:int64 = align_expr                  // a member's own alignas(16) data: [u8](32) (#396),
        let outer_t:int64 = align_type                  // not one written before the struct
        end_alignas()
        parse_alignas()
        let f:int64 = parse_typed(0)
        take_alignas(f)
        align_expr = outer_e
        align_type = outer_t
        if last < 0 {
            nodes[n].a = f
        } else {
            nodes[last].next = f
        }
        last = f
        if at_word(";") || at_word(",") { advance() }
        skip_newlines()
    }
    expect("}")
    body_struct = saved_body
    nest_outer = saved_outer
    return n
}

// enum t { a, b = 3, c }, C's enum (#210); enum t { none; n: int64 },
// an enum with values (#215), where a case says the type of its value:
// then the enum's flag is 1, and each case's ty its value's, or -1
// the enums with no name whose cases have values, read for their words (#655)
var anon_tagged:$[int64]
// those at the top level, each the declaration of its spelling's type,
// _kv_anonN, whose cases are words of the program, as kelvinc's #120 (#694)
var anon_words:$[int64]

// the enum with no name of a case named as token t, or -1
let anon_case_enum(t:int64):int64 {
    for n in anon_words {
        var m:int64 = nodes[n].a
        while m >= 0 {
            if same_text(nodes[m].t, t) { return n }
            m = nodes[m].next
        }
    }
    for n in anon_tagged {
        var m:int64 = nodes[n].a
        while m >= 0 {
            if same_text(nodes[m].t, t) { return n }
            m = nodes[m].next
        }
    }
    return 0 - 1
}

// its spelling, as kelvinc's: enum{red, rgb: {r: u8, g: u8, b: u8}}
let anon_enum_spelling(n:int64):String {
    var s = $"enum{"
    var m:int64 = nodes[n].a
    while m >= 0 {
        if m != nodes[n].a { s += ", " }
        let w:String = tok_text(nodes[m].t)
        s += &w
        if nodes[m].ty >= 0 {
            s += ": "
            let ty:String = kelvin_type_text(nodes[m].ty)
            s += &ty
        }
        m = nodes[m].next
    }
    s += "}"
    return s
}

let parse_enum():int64 {
    let local:bool = local_next || block_depth > 0       // its enumerators the block's (#391)
    if at_word("{") && local {
        parse_error("declarations are written 'var name:type', as in 'var x:T'")   // as kelvinc says it (#702)
        return make_node(D_ENUM, pos)
    }
    let n:int64 = at_word("{") ? make_node(D_ENUM, pos - 1) : make_node(D_ENUM, record_name())   // enum { LIMIT = 100 }: named by its word, C's anonymous enum (#451)
    expect("{")
    skip_newlines()
    var last = -1
    var hidden:int64 = 0
    while !at_word("}") && !failed {
        reject_kv_name(pos)                              // an enumerator, a case's name (#611)
        let m:int64 = make_node(N_ID, advance())
        if at_word(":") {
            advance()
            set_ty(m, parse_type())
            nodes[n].flag = 1
        } else {
            if local {                                   // _kv_main_red, the block's (#391)
                nodes[m].t = hidden_token(nodes[m].t)
                local_enums += nodes[m].t
                local_enum_depths += block_depth
                hidden += 1
            }
            if at_word("=") {
                advance()
                set_a(m, parse_expr())
            }
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
    if nodes[n].flag == 1 && !failed {                   // a case has a name, and no number, as kelvinc says it (#61, #611)
        var m:int64 = nodes[n].a
        while m >= 0 {
            if nodes[m].a >= 0 {
                parse_error_at(tok_is(nodes[m].t + 1, "=") ? nodes[m].t + 1 : nodes[m].t, "a case of an enum with values is known by its name, not by a number")   // at its =, as kelvinc's (#687)
                return n
            }
            m = nodes[m].next
        }
    }
    if nodes[n].flag == 1 && tok_is(nodes[n].t, "enum") {   // as kelvinc's #120, its cases words of the program
        var m:int64 = nodes[n].a
        while m >= 0 {
            if tok_is(nodes[m].t, "ok") || tok_is(nodes[m].t, "err") || tok_is(nodes[m].t, "none") || tok_is(nodes[m].t, "some") {
                var e = $"'"
                e += tok_text(nodes[m].t)
                e += "' is a word of Result and Optional (#72, #75): a case of an enum with no tag is a word of the program, so name it otherwise, or give the enum a tag"
                parse_error_at(nodes[m].t, e.cstr)
                return n
            }
            m = nodes[m].next
        }
        if nest_outer < 0 && !local {                    // the type of its spelling, its cases words of the program, as kelvinc's #120 (#694)
            let y:int64 = anon_record_type(nodes[n].a, false, true, nodes[n].t)
            let d:int64 = anon_decls.get(tok_text(types[y].name), 0 - 1)
            var known = false
            for w in anon_words {
                if w == d { known = true }
            }
            if !known { anon_words += d }
            return 0 - 1                                 // no declaration of its own: the type's is made
        }
        anon_tagged += n                                 // read on, its words the program's; kc builds it not yet (#655)
        return n
    }
    if nodes[n].flag != 1 {                              // an enumerator named as such a case, as kelvinc says it (#655)
        var m:int64 = nodes[n].a
        while m >= 0 {
            let w:int64 = anon_case_enum(nodes[m].t)
            if w >= 0 {
                var e = $"'"
                e += tok_text(nodes[m].t)
                e += "' is a case of "
                let sp:String = anon_enum_spelling(w)
                e += &sp
                e += ", a word of the program: name the enumerator otherwise"
                parse_error_at(nodes[m].t, e.cstr)
                return n
            }
            m = nodes[m].next
        }
    }
    if nodes[n].flag == 1 && hidden > 0 {                // an enum with values: its cases keep their names
        var m:int64 = nodes[n].a
        while m >= 0 {
            let own:int64 = local_own_of.get(tok_text(nodes[m].t), -1)
            if own >= 0 && nodes[m].ty < 0 { nodes[m].t = own }
            m = nodes[m].next
        }
        while hidden > 0 {
            local_enums.pop()
            local_enum_depths.pop()
            hidden -= 1
        }
    }
    return n
}

// {x:f64, y:f64}, a struct with no tag (#59); union{i:i32, f:f32} (#60);
// enum{i:i32, f:f32}, an enum with values (#61), where a type goes (#476):
// as kelvinc's parse_anon_record, one type of each spelling, so that two
// written alike are one, a declaration of its own named _kv_anonN in
// order of first use, before the declaration that first writes it
let parse_anon_record():int64 {
    let is_union = at_word("union")
    let is_enum = at_word("enum")
    if !at_word("{") { advance() }
    let open:int64 = pos
    expect("{")
    let saved_ends = brace_ends
    brace_ends = false
    var first:int64 = 0 - 1
    var last:int64 = 0 - 1
    skip_newlines()
    while !at_word("}") && !failed {
        var m:int64 = 0 - 1
        if is_enum {                                     // a case, its value's type after a colon
            if !at_kind(T_ID) {
                parse_error("a case of an enum is a name")
                break
            }
            m = make_node(N_ID, advance())
            if at_word(":") {
                advance()
                set_ty(m, parse_type())
            }
        } else {
            m = parse_typed(0)
        }
        if last < 0 { first = m } else { nodes[last].next = m }
        last = m
        if at_word(";") || at_word(",") { advance() }
        skip_newlines()
    }
    brace_ends = saved_ends
    if failed { return base_type(Y_VOID) }
    if first < 0 {                                       // as kelvinc says it
        pos = open
        parse_error(is_enum ? "an enum with no tag names its cases: enum{i:i32, f:f32}" : is_union ? "a union with no tag names its members: union{i:i32, f:f32}" : "a struct with no tag names its members: {x:f64, y:f64}")
        return base_type(Y_VOID)
    }
    expect("}")
    return anon_record_type(first, is_union, is_enum, open)
}

// the type of the record with no tag whose members or cases are first
// and on, one of each spelling: its declaration made, _kv_anonN, before
// the one that writes it first, where none is yet (#476); of
// parse_anon_record, and of a top-level enum with no name (#694)
let anon_record_type(first:int64, is_union:bool, is_enum:bool, open:int64):int64 {
    var key = is_enum ? $"enum{" : is_union ? $"union{" : $"{"
    var m:int64 = first
    while m >= 0 {
        key += tok_text(nodes[m].t)
        key += ":"
        key += String(nodes[m].ty)
        key += ","
        m = nodes[m].next
    }
    let seen:int64 = anon_keys.get(key, -1)
    if seen >= 0 { return seen }
    var name = $"_kv_anon"
    name += String(anon_keys.count as int64 + 1)
    let d = make_node(is_enum ? D_ENUM : D_STRUCT, made_token(&name))
    toks[nodes[d].t].line = toks[open].line
    toks[nodes[d].t].file = toks[open].file
    nodes[d].a = first
    if is_union || is_enum { nodes[d].flag = 1 }         // a union's (#453), an enum with values (#215)
    decls += d
    let y:int64 = type_of_kind(Y_STRUCT, -1, nodes[d].t)
    anon_keys[key] = y
    anon_decls[name] = d
    return y
}

// an inline before a declaration (#392), as kelvinc reads it: whether one
// was written, and its errors where once is not all, or no function follows
var inline_tok:int64 = 0 - 1   // the word inline of the declaration being read, for an error there (#681)

let parse_inline(seen:bool):bool {
    if !at_word("inline") { return seen }
    if seen {
        parse_error("'inline' is written once")
        return true
    }
    inline_tok = advance()
    if at_word("inline") {
        parse_error("'inline' is written once")
    } else if !at_word("let") && !at_word("var") && !at_word("static") {
        parse_error_at(inline_tok, "'inline' is for a function, a method or an operator: 'inline let f(...) { ... }'")   // (#684)
    }
    return true
}

// whether function d is written inline (#392)
let is_inline(d:int64):bool {
    for f in inline_fns {
        if f == d { return true }
    }
    return false
}

// whether w names an integer type, i8 to u128, whose computed attributes a
// program may declare (#668)
let int_word_named(w:const String^):bool {
    return w^ == "i8" || w^ == "i16" || w^ == "i32" || w^ == "i64" || w^ == "i128" || w^ == "u8" || w^ == "u16" || w^ == "u32" || w^ == "u64" || w^ == "u128"
}

// whether recv, the type of static let T.f() or of static let T.x:R { }
// whose name is at the cursor, is built in, with kelvinc's error (#111,
// #595, #611): a function and a computed attribute of a type are of a
// struct, union or enum of the program, or of Bytes or String
let builtin_static(recv:int64, computed:bool):bool {
    let ny:int64 = number_word(recv)
    if ny < 0 && !tok_is(recv, "bool") && !tok_is(recv, "cstr") && !tok_is(recv, "any") && !tok_is(recv, "IO") { return false }
    let w:String = ny >= 0 ? type_word(ny) : tok_text(recv)
    if computed && int_word_named(&w) { return false }   // an integer type's, i64.primes (#668)
    var m = $""
    if computed {
        m = $"a computed attribute of a type is declared on a struct, union or enum of the program, on Bytes or String, or on an integer type: of '"
        m += &w
        m += "', which is built in, write a stored one, 'static let "
        m += &w
        m += "."
        m += tok_text(pos)
        m += " = ...'"
    } else {
        m = $"a function of a type is declared on a struct, union or enum of the program, or on Bytes or String: '"
        m += &w
        m += "' is built in"
    }
    parse_error_at(recv, m.cstr)
    return true
}

// whether recv, the type a method, or an extend, is of, written from
// token at, is one of the program's, with kelvinc's error (#130, #612):
// any and cstr have no methods, nor a plain enum outside extend, which C
// cannot tell from its integer; and a name of no struct, union or enum
// names none. kc reads every file's types before any (#550), so a type
// declared after its method is not told from one before it
let receiver_wrong(recv:int64, at:int64, extends:bool):bool {
    if failed || recv >= eof_pos || is_nested(recv) { return failed }
    if !extends && (tok_is(recv, "any") || tok_is(recv, "cstr")) {
        var m = $"'"
        m += tok_text(recv)
        m += "' cannot have methods"
        parse_error_at(at, m.cstr)
        return true
    }
    if number_word(recv) >= 0 || tok_is(recv, "bool") || tok_is(recv, "any") || tok_is(recv, "cstr") || tok_is(recv, "String") || tok_is(recv, "Bytes") || tok_is(recv, "IO") { return false }
    if tok_is(recv, "{") || tok_is(recv, "struct") || tok_is(recv, "union") || tok_is(recv, "enum") { return false }   // a type with no tag
    let name:String = tok_text(recv)
    let word:int64 = far_records.get(name, 0 - 1)
    if word < 0 && records_seen.get(name, 0 - 1) < 0 && !c_tags.has(name) && local_own_of.get(name, 0 - 1) < 0 {
        var m = $"'"
        m += &name
        m += extends ? "' is not a struct, union or enum declared before this extend" : "' is not a struct or union declared before this method"
        parse_error_at(at, m.cstr)
        return true
    }
    if !extends && word >= 0 && tok_is(word, "enum") {
        var k:int64 = word + 3                           // past enum name {
        var depth = 1
        var values = false
        while depth > 0 && k < eof_pos {
            if tok_is(k, "{") { depth += 1 }
            if tok_is(k, "}") { depth -= 1 }
            if depth == 1 && tok_is(k, ":") { values = true }
            k += 1
        }
        if !values {
            parse_error_at(at, "enums cannot have methods: C cannot tell an enum from its integer type")
            return true
        }
    }
    return false
}

// extend T { let m(...) ... static let f(...) ... } (#213): a method takes
// self, a T, first; a function of the type, static, does not; each goes
// into decls as a D_FN whose c is T's token, its flag 1 where static, 2
// for a var method, var m(...), whose self is the caller's var (#320)
// extend enum{...} { }, of a type with no tag (#121): what kelvinc says
// of what it holds, a type's attribute or function, and Self called
// (#655); whether it said one (#694)
let extend_spelled():bool {
    var q:int64 = pos + 1
    var depth:int64 = 0
    while toks[q].kind != T_EOF {                        // past the spelled type
        if tok_is(q, "{") { depth += 1 }
        if tok_is(q, "}") {
            depth -= 1
            if depth == 0 { break }
        }
        q += 1
    }
    q += 1
    while toks[q].kind == T_NL { q += 1 }
    if !tok_is(q, "{") {
        parse_error_at(q, "expected '{' after the type extend names")
        return true
    }
    depth = 0
    while toks[q].kind != T_EOF {
        if tok_is(q, "{") { depth += 1 }
        if tok_is(q, "}") {
            depth -= 1
            if depth == 0 { break }
        }
        if depth == 1 && tok_is(q, "static") && (tok_is(q + 1, "let") || tok_is(q + 1, "var")) && toks[q + 2].kind == T_ID {
            if tok_is(q + 3, "(") {
                parse_error_at(q, "a function of a type is called by the type's name, and a type with no tag has none")
            } else {
                parse_error_at(q + 2, "a type attribute is read by the type's name, as T.x, and a type with no tag has none")   // at its name (#686)
            }
            return true
        }
        if tok_is(q, "Self") && tok_is(q + 1, ".") && toks[q + 2].kind == T_ID && tok_is(q + 3, "(") {
            parse_error_at(q, "'Self' here is a type with no tag, which has no name to call a function by")
            return true
        }
        q += 1
    }
    return false
}

// whether a method of a type with no tag starts at token q, its
// spelling, enum{...}, union{...}, struct{...} or {...}, then .m( (#694)
let spelled_method(q:int64):bool {
    var i:int64 = q
    if tok_is(i, "enum") || tok_is(i, "struct") || tok_is(i, "union") { i += 1 }
    if !tok_is(i, "{") { return false }
    var depth:int64 = 0
    while toks[i].kind != T_EOF {
        if tok_is(i, "{") { depth += 1 }
        if tok_is(i, "}") {
            depth -= 1
            if depth == 0 { break }
        }
        i += 1
    }
    return tok_is(i + 1, ".") && toks[i + 2].kind == T_ID && tok_is(i + 3, "(")
}

let parse_extend() {
    var recv:int64 = 0 - 1
    if (at_word("enum") || at_word("struct") || at_word("union")) && tok_is(pos + 1, "{") {   // a type with no tag (#655): of its spelling's type, _kv_anonN, as kelvinc's #121 (#694)
        if extend_spelled() { return }
        let y:int64 = parse_anon_record()
        if failed { return }
        recv = types[y].name
    } else {
        let recv_at:int64 = pos
        recv = type_path(pos)                            // extend point.kind { } (#389)
        if toks[recv_at].kind == T_ID && receiver_wrong(recv, recv_at, true) { return }   // (#612)
        while pos < path_end { advance() }
    }
    self_name = recv
    expect("{")
    skip_newlines()
    while !at_word("}") && !failed {
        var inl:bool = parse_inline(false)              // (#392)
        var is_static = 0
        if at_word("static") {
            advance()
            is_static = 1
        }
        inl = parse_inline(inl)
        if is_static == 0 && at_word("var") {
            advance()
            is_static = 2
        } else if is_static == 1 && at_word("var") && toks[pos + 1].kind == T_ID && (tok_is(pos + 2, ":") || tok_is(pos + 2, "=")) {
            advance()                                    // static var x = v (#133)
            if static_computed(pos) {                    // as kelvinc says it (#595)
                var m = $"a computed attribute of a type is read and never set: write 'static let "
                m += tok_text(pos)
                m += ":R { ... }', or 'static var "
                m += tok_text(pos)
                m += " = v' for a stored one"
                parse_error(m.cstr)
                return
            }
            parse_type_attribute(recv, false)
            skip_newlines()
            continue
        } else if is_static == 1 && at_word("var") {
            parse_error("a function of the type has no self to change: write 'static let'")
            return
        } else if !at_word("let") {                      // as kelvinc says it
            var m = $"extend holds let f() { }, static let f() { }, let x:R { }, var x:R { get { } set(v) { } }, static let x = v, static var x = v and static let +(a:T, b:T):T { }; found "
            let d:String = tok_desc(pos)
            m += &d
            parse_error(m.cstr)
            return
        } else {
            expect("let")
        }
        if at_word("[") && tok_is(pos + 1, "]") {        // let [](i:I):R { } (#136)
            if is_static == 1 {
                parse_error_at(pos - 2, "a subscript has self, so it is not static: write 'let [](i:I):R { ... }'")   // at its static, as kelvinc's (#686)
                return
            }
            parse_subscript(recv, is_static == 2, inl)
            skip_newlines()
            continue
        }
        if at_kind(T_PUNCT) {                            // static let +(a:T, b:T):T { } (#135): the top level's let +
            if (!overloadable_tok(pos) && !compound_tok(pos)) || !tok_is(pos + 1, "(") {
                var m = $"'"
                m += tok_text(pos)
                m += "' cannot be defined: an operator is one of + - * / % ** == != < <= > >= & | ~ << >>, unary - and ~, or x op= y of one of them (#518)"
                parse_error(m.cstr)
                return
            }
            if is_static != 1 {
                var m = $"an operator in extend is a function of the type, as Swift's static func: write 'static let "
                let w:String = tok_text(recv)
                m += tok_text(pos)
                m += "(a:"
                m += &w
                m += ", b:"
                m += &w
                m += "):"
                m += &w
                m += " { ... }'"
                parse_error_at(pos - 1, m.cstr)          // at its let, as kelvinc's (#686)
                return
            }
            let at:int64 = pos
            let compound = compound_tok(pos)
            let f:int64 = parse_function()
            var takes = false
            var p:int64 = nodes[f].a
            while p >= 0 {
                let py:int64 = nodes[p].ty
                if !compound && py >= 0 && types[py].kind == Y_STRUCT && same_text(types[py].name, recv) { takes = true }
                p = nodes[p].next
            }
            p = nodes[f].a                               // x op= y changes a Self, through a Self^ (#518)
            if compound && p >= 0 {
                let py:int64 = nodes[p].ty
                if py >= 0 && types[py].kind == Y_PTR {
                    let e:int64 = types[py].elem
                    if e >= 0 && types[e].kind == Y_STRUCT && same_text(types[e].name, recv) { takes = true }
                }
            }
            if !takes && compound && nodes[f].a >= 0 && nodes[nodes[f].a].ty >= 0 && types[nodes[nodes[f].a].ty].kind != Y_PTR {   // a value, not a pointer: kelvinc's parse_fn says it first
                var m = $"'"
                m += tok_text(at)
                m += "' changes the value its first parameter points to: write 'static let "
                m += tok_text(at)
                m += "(a:T^, b:U)', T a Kelvin struct or union (#518)"
                let back:int64 = pos
                pos = at
                parse_error(m.cstr)
                pos = back
                return
            }
            if !takes && compound {
                var m = $"'"
                let w:String = tok_text(recv)
                m += tok_text(at)
                m += "' in extend "
                m += &w
                m += " changes a "
                m += &w
                m += ": write 'static let "
                m += tok_text(at)
                m += "(a:Self^, b:U)'"
                let back:int64 = pos
                pos = at
                parse_error(m.cstr)
                pos = back
                return
            }
            if !takes {
                var m = $"an operator in extend "
                let w:String = tok_text(recv)
                m += &w
                m += " takes a "
                m += &w
                m += ", as one of its values"
                let back:int64 = pos
                pos = at
                parse_error(m.cstr)
                pos = back
                return
            }
            if inl { inline_fns += f }
            decls += f
            skip_newlines()
            continue
        }
        if toks[pos].kind == T_ID && (tok_is(pos + 1, ":") || tok_is(pos + 1, "=")) {
            let nm:String = tok_text(pos)
            if is_static == 1 && static_computed(pos) {  // static let x:R { }, computed (#595)
                if builtin_static(recv, true) { return }
                parse_static_attribute(recv, inl)
                skip_newlines()
                continue
            }
            if is_static == 1 {
                parse_type_attribute(recv, true)
                skip_newlines()
                continue
            }
            if tok_is(pos + 1, "=") {
                var m = $"an instance attribute is computed, 'let "
                m += &nm
                m += ":R { ... }': a stored one is a member of the struct; a value of the type is 'static let "
                m += &nm
                m += " = ...'"
                advance()
                parse_error(m.cstr)
                return
            }
            parse_attribute(recv, is_static == 2, inl)
            skip_newlines()
            continue
        }
        if is_static == 1 && builtin_static(recv, false) { return }   // (#611)
        if is_static == 1 && static_clash(recv, pos, static_named(recv, pos), false) { return }   // (#595)
        static_parsing = is_static == 1                  // $(...) of it a call of it (#718)
        let n:int64 = parse_function()
        static_parsing = false
        nodes[n].c = recv
        nodes[n].flag = is_static
        if inl { inline_fns += n }
        decls += n
        skip_newlines()
    }
    expect("}")
    self_name = 0 - 1
}

// whether the struct or union named by token t has its body after it
let body_ahead(t:int64):bool {
    var i:int64 = t + 1
    while toks[i].kind != T_EOF {
        if (tok_is(i, "struct") || tok_is(i, "union")) && same_text(i + 1, t) && tok_is(i + 2, "{") { return true }
        i += 1
    }
    return false
}

// typealias A = T (#149, #550), Swift's, as kelvinc reads it: from there
// on A is T wherever a name is read, each later token A made T's, a
// struct, union or enum read before it or a built-in type. kelvinc reads
// an imported file where its #import stands; kc reads the files one after
// another, the program's first, so a pass before any is parsed walks them
// as kelvinc reads them, each file at the #import it was first read for,
// and an alias reaches what follows it there: the rest of its file, the
// files read for the imports in that rest, and what follows the #import
// its own file was read for. An alias of a function type, typealias op =
// (i64):i64 (#403), no one token another may stand for, is kept by its
// name, which parse_bare_type asks. An overlay, A+B.k (#551), kelvinc
// reads right after the later of its two modules: the pass finds that
// place first, alias_order, the #import after whose files both are read,
// and the overlay is the next file read there
var alias_errs:Dictionary<int64, int64>      // a typealias the pass refused, by its token: 1 a type already, 2 declared already, 3 no type
var alias_records:Dictionary<String, int64>  // the structs, unions and enums at the top of the files walked so far
var file_from:$[int64]                       // each file's first token, and the one after its last
var file_to:$[int64]
var import_reads:Dictionary<int64, int64>    // the file a #import token was first read for
var file_next:$[int64]                       // the file read next at the same #import, an overlay's (#551), or -1
var file_walked:$[bool]                      // the files alias_order has passed
var alias_roots:$[int64]                     // the files no #import reads, as kelvinc reads them: the prelude's, then the program

let alias_builtin(t:int64):bool {
    return number_word(t) >= 0 || tok_is(t, "bool") || tok_is(t, "cstr") || tok_is(t, "String") || tok_is(t, "Bytes") || tok_is(t, "IO")
}

// the tokens of file f from token from on, and of the files read for the
// imports among them, that are name's text: each made target's
let alias_reach(f:int64, from:int64, at:int64, len:int64, target:int64) {
    var k:int64 = from
    while k < file_to[f] {
        if toks[k].kind == T_ID && toks[k].len == len {
            var same = true
            for j in 0..<len {
                if codes[toks[k].at + j] != codes[at + j] { same = false }
            }
            if same {
                toks[k].at = toks[target].at
                toks[k].len = toks[target].len
            }
        } else if toks[k].kind == T_IMPORT && import_reads.has(k) {
            var h:int64 = import_reads.get(k, 0)
            while h >= 0 {                               // the module, and the overlays read after it (#551)
                alias_reach(h, file_from[h], at, len, target)
                h = file_next[h]
            }
        }
        k += 1
    }
}

// typealias at token k of file f, as the pass reads it
let alias_at(f:int64, k:int64) {
    let name:int64 = k + 1
    if toks[name].kind != T_ID || !tok_is(k + 2, "=") { return }   // parse_typealias says what is wrong
    let target:int64 = k + 3
    if alias_builtin(name) {
        alias_errs[k] = 1
        return
    }
    if alias_records.has(tok_text(name)) || fn_aliases.has(tok_text(name)) {
        alias_errs[k] = 2
        return
    }
    if tok_is(target, "(") {                             // typealias op = (i64):i64 (#403)
        let saved:int64 = pos
        pos = target
        let y:int64 = parse_type()
        pos = saved
        if !failed { fn_aliases[tok_text(name)] = y }
        return
    }
    if !alias_builtin(target) && !(toks[target].kind == T_ID && alias_records.has(tok_text(target))) {
        alias_errs[k] = 3
        return
    }
    let at:int64 = toks[name].at
    let len:int64 = toks[name].len
    var j:int64 = k - 1                                  // before it too, back to an #import of its file, as kelvinc moves it up (#626)
    while j >= file_from[f] && toks[j].kind != T_IMPORT { j -= 1 }
    j += 1
    while j < k {
        if toks[j].kind == T_ID && toks[j].len == len {
            var same = true
            for c in 0..<len {
                if codes[toks[j].at + c] != codes[at + c] { same = false }
            }
            if same {
                toks[j].at = toks[target].at
                toks[j].len = toks[target].len
            }
        }
        j += 1
    }
    var g:int64 = f
    var from:int64 = k + 4
    while true {
        alias_reach(g, from, at, len, target)
        var sib:int64 = file_next[g]
        while sib >= 0 {                                 // the overlays read after it at its #import (#551)
            alias_reach(sib, file_from[sib], at, len, target)
            sib = file_next[sib]
        }
        let b:int64 = file_by[g]
        if b < 0 {                                       // a file no #import reads, as math of the prelude (#590):
            var after = false                            // kelvinc reads the rest after it, the program too
            for r in alias_roots {
                if after { alias_reach(r, file_from[r], at, len, target) }
                if r == g { after = true }
            }
            break
        }
        from = b + 1
        g = toks[b].file
    }
}

// file f walked as kelvinc reads it: a file where its #import stands
let alias_walk(f:int64) {
    var depth = 0
    var k:int64 = file_from[f]
    while k < file_to[f] && !failed {
        let kind:tkind = toks[k].kind
        if kind == T_IMPORT && import_reads.has(k) {
            var h:int64 = import_reads.get(k, 0)
            while h >= 0 {
                alias_walk(h)
                h = file_next[h]
            }
        } else if kind == T_PUNCT && (tok_is(k, "{") || tok_is(k, "${")) {
            depth += 1
        } else if kind == T_PUNCT && tok_is(k, "}") {
            depth -= 1
        } else if kind == T_ID && depth == 0 && (k == file_from[f] || toks[k - 1].kind == T_NL || tok_is(k - 1, ";")) {
            if (tok_is(k, "struct") || tok_is(k, "union") || tok_is(k, "enum")) && toks[k + 1].kind == T_ID {
                alias_records[tok_text(k + 1)] = k + 1
            } else if tok_is(k, "typealias") {
                alias_at(f, k)
            }
        }
        k += 1
    }
}

// the overlays whose two modules are both passed, and which have no
// place yet, read next after file last, at #import token by, or as roots
// where by is -1: the last file read there
let alias_order(f:int64)    // a prototype: an overlay is passed in turn

let alias_overlays(last0:int64, by:int64) {
    var last:int64 = last0
    var found = true
    while found {
        found = false
        for o in 0..<file_by.count as int64 {
            if file_by[o] != 0 - 2 || !file_walked[file_with_a[o]] || !file_walked[file_with_b[o]] { continue }
            file_by[o] = by
            if by >= 0 {
                file_next[last] = o
            } else {
                alias_roots += o
            }
            last = o
            alias_order(o)
            file_walked[o] = true
            found = true
        }
    }
}

// file f passed as kelvinc reads it, to place the overlays (#551)
let alias_order(f:int64) {
    var k:int64 = file_from[f]
    while k < file_to[f] {
        if toks[k].kind == T_IMPORT && import_reads.has(k) {
            let h:int64 = import_reads.get(k, 0)
            alias_order(h)
            file_walked[h] = true
            alias_overlays(h, k)
        }
        k += 1
    }
}

let alias_pass() {
    var some = false
    for t in 0..<eof_pos {
        if toks[t].kind == T_ID && tok_is(t, "typealias") { some = true }
    }
    if !some { return }
    for _ in 0..<file_by.count as int64 {
        file_from += eof_pos
        file_to += eof_pos
    }
    var k:int64 = eof_pos - 1
    while k >= 0 {
        let f:int64 = toks[k].file
        if file_to[f] == eof_pos && file_from[f] == eof_pos { file_to[f] = k + 1 }
        file_from[f] = k
        k -= 1
    }
    for h in 0..<file_by.count as int64 {
        if file_by[h] >= 0 { import_reads[file_by[h]] = h }
        file_next += 0 - 1
        file_walked += false
    }
    var root:int64 = file_by.count as int64 - 1
    while root >= 0 {                                    // the prelude's first, as kelvinc reads them, then the program
        if file_by[root] == 0 - 1 && !file_walked[root] {
            alias_roots += root
            alias_order(root)
            file_walked[root] = true
            alias_overlays(root, 0 - 1)
        }
        root -= 1
    }
    for r in alias_roots { alias_walk(r) }
}

let parse_typealias() {
    let kw:int64 = advance()
    let name:int64 = pos
    let why:int64 = alias_errs.get(kw, 0)
    if why == 1 {
        var m = $"'"
        m += tok_text(name)
        m += "' is a type already: an alias is a new name, as in 'typealias real = f64'"
        parse_error(m.cstr)
        return
    }
    if !at_kind(T_ID) {
        parse_error("typealias names the alias, then its type: 'typealias A = T'")
        return
    }
    var taken = why == 2
    for d in decls {
        if (nodes[d].kind == D_FN || nodes[d].kind == D_GLOBAL) && nodes[d].c < 0 && same_text(nodes[d].t, name) { taken = true }
    }
    if taken {
        var m = $"'"
        m += tok_text(name)
        m += "' is declared already: an alias is a new name"
        parse_error(m.cstr)
        return
    }
    advance()
    if !at_word("=") {
        var m = $"expected '=' after the alias's name: 'typealias "
        m += tok_text(name)
        m += " = T'"
        parse_error(m.cstr)
        return
    }
    advance()
    let target:int64 = pos
    if at_word("(") {                                    // typealias op = (i64):i64 (#403), which the pass kept
        let y:int64 = parse_type()
        var f:int64 = y
        while f >= 0 && (types[f].kind == Y_PTR || types[f].kind == Y_FIXED) { f = types[f].elem }
        if !failed && (f < 0 || types[f].kind != Y_FN) {
            pos = target
            parse_error("an alias in parentheses is of a function type, as in 'typealias op = (i64):i64'")
            return
        }
        if at_word(";") { advance() }
        return
    }
    if why == 3 {
        var m = $"'"
        m += tok_text(target)
        m += "' is not a type kelvinc sees: an alias is of a struct, union or enum with values declared before it, or of a built-in type"
        parse_error(m.cstr)
        return
    }
    advance()
    if at_word(";") { advance() }
}

// the declarations from the token at pos to the end
let parse_program() {
    scan_records()                                       // the types of every file, and
    alias_pass()                                         // the aliases, before any file is parsed (#550)
    skip_newlines()
    while !at_kind(T_EOF) && !failed {
        var storage:int64 = 0                            // static 1, extern 2, as C's (#459)
        var thread = false                               // thread_local, before or after it (#641)
        let thread_at:int64 = pos
        if at_word("_Thread_local") {                    // as kelvinc says it
            parse_error("'_Thread_local' is C's spelling: Kelvin writes 'thread_local var x' (#641)")
            return
        }
        if at_word("thread_local") && (tok_is(pos + 1, "var") || tok_is(pos + 1, "let") || tok_is(pos + 1, "static") || tok_is(pos + 1, "extern")) {
            thread = true
            advance()
        }
        if (at_word("static") || at_word("extern")) && !at_word("static_assert") {
            storage = at_word("static") ? 1 : 2
            advance()
        }
        if at_word("thread_local") && (tok_is(pos + 1, "var") || tok_is(pos + 1, "let")) {
            thread = true
            advance()
        }
        if thread && !((at_word("var") || at_word("let")) && toks[pos + 1].kind == T_ID && !tok_is(pos + 2, "(") && !tok_is(pos + 2, ".")) {
            parse_error_at(thread_at, "'thread_local' is of a variable, each thread's own: a function is every thread's already (#641)")
            return
        }
        parse_alignas()                                  // alignas(64) var line:[u8](64) (#396)
        parse_alignas()                                  // a second, kelvinc's error
        let inline_at:int64 = pos
        var inl:bool = parse_inline(false)              // inline let f(...) (#392)
        if inl && storage == 2 && !failed {             // as kelvinc says it (#612)
            parse_error_at(inline_at, "an extern function is defined elsewhere: 'inline' is for one defined here")
        }
        if storage == 0 && at_word("static") {          // inline static let f(...)
            storage = 1
            advance()
            inl = parse_inline(inl)
        }
        if failed { continue }                           // an error put it at the end: read no further (#624)
        if storage == 1 && at_word("let") && (tok_is(pos + 1, "enum") || tok_is(pos + 1, "struct") || tok_is(pos + 1, "union")) && tok_is(pos + 2, "{") {   // as kelvinc says it (#655)
            parse_error_at(pos + 1, "a function of a type is called by the type's name, and a type with no tag has none")
            continue
        }
        if storage == 1 && (at_word("let") || at_word("var")) && toks[pos + 1].kind == T_ID && !head_method(pos + 1) && head_attribute(pos + 1) {
            let is_let = at_word("let")                  // static let T.x:R = v (#133)
            advance()
            let recv:int64 = type_path(pos)
            while pos < path_end { advance() }
            advance()
            self_name = recv
            if is_let && static_computed(pos) && builtin_static(recv, true) {   // (#611)
            } else if is_let && static_computed(pos) {   // static let T.x:R { }, computed (#595)
                parse_static_attribute(recv, inl)
            } else {
                parse_type_attribute(recv, is_let)
            }
            self_name = 0 - 1
            storage = 0
            if at_word(";") { advance() }
            skip_newlines()
            continue
        }
        if inl && toks[pos + 1].kind == T_ID && tok_is(pos + 1, "main") {
            parse_error_at(inline_tok, "main is C's main, called once: it is not inline")   // at its word, as kelvinc's (#684)
        }
        let first:int64 = decls.count as int64
        if at_word("static_assert") || at_word("_Static_assert") {
            decls += parse_assert(D_ASSERT)             // (#394)
        } else if at_kind(T_IMPORT) {
            let n:int64 = make_node(D_IMPORT, advance())
            if tok_is(nodes[n].t, "<IO>") { nodes[n].flag = 1 }
            if is_header(nodes[n].t) {
                nodes[n].flag = 2                   // a C header, as C (#207)
                c_headers = true
            }
            decls += n
        } else if (at_word("struct") || at_word("union")) && toks[pos + 1].kind == T_ID && tok_is(pos + 2, ";") && body_ahead(pos + 1) {
            advance()                                            // struct money; before its body, as a function's prototype (#42)
            advance()
            advance()
        } else if (at_word("struct") || at_word("union")) && toks[pos + 1].kind == T_ID && tok_is(pos + 2, ";") {
            let tag:int64 = at_word("union") ? 0 - 3 : 0 - 2     // struct timespec;, a C struct declared in Kelvin (#453):
            advance()                                            // T names it, C's, whose members C sees
            let name:String = tok_text(pos)
            c_tags[name] = tag
            c_tag_types += type_of_kind(Y_STRUCT, tag, advance())
            advance()
        } else if at_word("struct") || at_word("union") {
            let is_union = at_word("union")
            advance()
            let d:int64 = parse_struct()
            if is_union { nodes[d].flag = 1 }            // union bits { u:u64; f:f64 }, C's (#453)
            decls += d
            if at_word(";") { advance() }                // struct point { ... };, as C writes it (#451)
        } else if at_word("enum") {
            advance()
            let e:int64 = parse_enum()
            if e >= 0 { decls += e }                     // none of a top-level enum with no name and values, its type's made (#694)
            if at_word(";") { advance() }                // enum { LIMIT = 100 }; (#451)
        } else if at_word(";") {                         // as kelvinc says it, after a function's body
            parse_error("expected a declaration (let name(...):type, let or var name, struct, union, enum), found ';'")
        } else if at_kind(T_PUNCT) && overloadable_tok(pos) && tok_is(pos + 1, "(") {   // as kelvinc says it (#45)
            var m = $"a function is declared with let: write 'let "
            m += tok_text(pos)
            m += "(...)'"
            parse_error(m.cstr)
        } else if at_word("var") && toks[pos + 1].kind == T_PUNCT && overloadable_tok(pos + 1) && tok_is(pos + 2, "(") {
            advance()
            var m = $"a function is a let: write 'let "
            m += tok_text(pos)
            m += "(...)', or, for a variable holding a function, 'var f:(T):R := g'"
            parse_error_at(pos - 1, m.cstr)              // at its var, as kelvinc's (#686)
        } else if at_word("let") && toks[pos + 1].kind == T_PUNCT && !tok_is(pos + 1, "(") && !overloadable_tok(pos + 1) && !compound_tok(pos + 1) && tok_is(pos + 2, "(") {
            advance()
            var m = $"'"
            m += tok_text(pos)
            m += "' cannot be defined: an operator a struct defines is one of + - * / % ** == != < <= > >= & | ~ << >>, unary - and ~, or x op= y of one of them (#518)"
            parse_error(m.cstr)
        } else if at_word("let") && toks[pos + 2].kind == T_PUNCT && tok_is(pos + 2, "(") && (tok_is(pos + 1, "print") || tok_is(pos + 1, "println")) && !prelude_file(toks[pos].file) {
            advance()                                    // as kelvinc says it (#612)
            var m = $"'"
            m += tok_text(pos)
            m += "' is part of the Kelvin prelude and cannot be redefined"
            parse_error(m.cstr)
        } else if at_word("let") && toks[pos + 2].kind == T_PUNCT && tok_is(pos + 2, "(") {
            advance()
            let f:int64 = parse_function()
            decls += f
            if nodes[f].b < 0 && at_word(";") { advance() }   // let printf(fmt:cstr, ...):i32;, a declaration (#453)
        } else if (at_word("let") || at_word("var")) && toks[pos + 1].kind == T_ID && head_subscript(pos + 1) {   // let T[](i:I):R { } (#136)
            let is_var = at_word("var")
            advance()
            let recv:int64 = type_path(pos)
            while pos < path_end { advance() }
            if storage != 0 { parse_error("a subscript has self, so it is not static: write 'let [](i:I):R { ... }'") }
            self_name = recv
            parse_subscript(recv, is_var, inl)
            self_name = 0 - 1
            inl = false                                  // each of its functions told already
        } else if (at_word("let") || at_word("var")) && toks[pos + 1].kind == T_ID && head_attribute(pos + 1) {   // let T.x:R { } (#131, #132)
            let is_var = at_word("var")
            advance()
            let recv:int64 = type_path(pos)
            while pos < path_end { advance() }
            advance()
            if tok_is(pos + 1, "=") {
                var m = $"an instance attribute is computed, 'let "
                m += tok_text(recv)
                m += "."
                m += tok_text(pos)
                m += ":R { ... }': a stored one is a member of the struct; a value of the type is 'static let "
                m += tok_text(recv)
                m += "."
                m += tok_text(pos)
                m += " = ...'"
                advance()
                parse_error(m.cstr)
            } else {
                if storage == 2 { parse_error("extern is not for an attribute") }
                self_name = recv
                parse_attribute(recv, is_var, inl)
                self_name = 0 - 1
                inl = false                              // each of its functions told already
            }
        } else if (at_word("let") || at_word("var")) && storage == 0 && spelled_method(pos + 1) {   // let enum{...}.m(...), of a type with no tag, as kelvinc's #121 (#694)
            let is_var = at_word("var")
            advance()
            let y:int64 = parse_anon_record()
            if failed { continue }
            advance()                                       // its .
            let recv:int64 = types[y].name
            self_name = recv
            let n:int64 = parse_function()
            nodes[n].c = recv
            if is_var { nodes[n].flag = 2 }
            self_name = 0 - 1
            decls += n
        } else if (at_word("let") || at_word("var")) && toks[pos + 1].kind == T_ID && head_method(pos + 1) {   // let T.m(...) (#213)
            let is_var = at_word("var")                     // var T.m(...), self the caller's var (#320)
            if is_var && storage != 0 {                     // as kelvinc says it (#45, #611)
                var m = storage == 1 ? $"a function is a let: write 'static let " : $"a function is a let: write 'extern let "
                m += tok_text(pos + 1)
                m += "."
                m += tok_text(pos + 3)
                m += "(...)', or, for a variable holding a function, 'var f:(T):R := g'"
                parse_error(m.cstr)
                continue                                    // at the end now, read no further (#624)
            }
            advance()
            let recv_at:int64 = pos
            let recv:int64 = type_path(pos)                 // let point.kind.m(...) (#389)
            while pos < path_end { advance() }
            advance()
            if storage != 1 && receiver_wrong(recv, recv_at, false) { continue }   // (#612)
            if !failed && (tok_is(pos, "toString") || tok_is(pos, "fmt")) {   // shelved (#22), as kelvinc says it (#612)
                var m:String = tok_text(pos)
                m += "() is not a method: a value's text is 'x.cstr', and String(x.cstr) a String (#22, #55)"
                parse_error(m.cstr)
                continue
            }
            self_name = recv
            if storage == 1 && !failed && builtin_static(recv, false) { continue }   // (#611)
            let n:int64 = parse_function()
            nodes[n].c = recv
            if is_var { nodes[n].flag = 2 }
            self_name = 0 - 1
            decls += n
            if nodes[n].b < 0 && at_word(";") { advance() }   // let bag.each(f:(i64));, a method's prototype, as a function's (#453, #715)
        } else if at_word("extend") {
            advance()
            parse_extend()
        } else if at_word("typealias") && toks[pos + 1].kind == T_ID {   // typealias A = T (#149, #550)
            parse_typealias()
        } else if at_word("var") && toks[pos + 1].kind == T_ID && tok_is(pos + 2, "(") {   // var f(...) { }, as kelvinc says it
            var m = $"a function is a let: write 'let "
            m += tok_text(pos + 1)
            m += "(...)', or, for a variable holding a function, 'var f:(T):R := g'"
            parse_error(m.cstr)
        } else if at_word("let") || at_word("var") {
            let is_let:bool = at_word("let")
            advance()
            var more = true
            while more && !failed {                      // var a = 1, b = 2: each a global, as kelvinc's (#715)
                let n:int64 = parse_var(0)
                nodes[n].kind = D_GLOBAL
                if is_let { nodes[n].flag = 1 }
                if thread { thread_decls += n }          // (#641)
                if is_let && nodes[n].a < 0 && storage != 2 && !failed { let_needs_value(n) }   // but an extern's, C's (#611)
                decls += n
                more = at_word(",") && toks[pos + 1].kind == T_ID
                if more { advance() }
            }
            if at_word(";") { advance() }                // var calls = 0; (#451)
        } else if storage == 2 && at_word("lazy") {      // as kelvinc says it
            parse_error("'extern lazy' is a module's header's, which kelvinc --lib writes: a global is given its value at its first use where C cannot initialize it (#493)")
        } else if at_word("typedef") {                   // as kelvinc says it
            parse_error("'typedef' is C's: Kelvin names a type anew with typealias, 'typealias A = T', at the top level (#294)")
        } else if fnptr_decl(pos, true) {                // size_t (*f)(i64); at the top level
        } else if at_kind(T_ID) && (tok_is(pos + 1, "(") || (tok_is(pos + 1, ".") && toks[pos + 2].kind == T_ID && tok_is(pos + 3, "("))) {   // main() { }, as kelvinc says it
            let method = tok_is(pos + 1, ".")
            let after:int64 = group_end(method ? pos + 3 : pos + 1)
            var m = $""
            if !method && !tok_is(after, ":") && !tok_is(after, "{") {
                m += "expected a declaration (let name(...):type, let or var name, struct, union, enum), found '"
                m += tok_text(pos)
                m += "': a statement goes in a function"
            } else {
                m += "a function is declared with let: write '"
                if storage == 1 { m += "static " }
                if storage == 2 { m += "extern " }
                m += "let "
                m += tok_text(pos)
                if method {
                    m += "."
                    m += tok_text(pos + 2)
                }
                m += "(...)'"
            }
            parse_error(m.cstr)
        } else if at_kind(T_ID) && (tok_is(pos + 1, ":") || tok_is(pos + 1, "=") || tok_is(pos + 1, ":=")) {   // as kelvinc says it
            var m = $"declarations start with let or var: write 'var "
            m += tok_text(pos)
            m += " ...', or 'let "
            m += tok_text(pos)
            m += " ...' if it never changes"
            parse_error(m.cstr)
        } else {
            var m = $"expected a declaration (let name(...):type, let or var name, struct, union, enum), found '"   // as kelvinc says it
            m += tok_text(pos)
            m += "'"
            parse_error(m.cstr)
        }
        if align_expr >= 0 || align_type >= 0 {          // (#396)
            if decls.count as int64 > first && nodes[decls[decls.count - 1]].kind == D_GLOBAL {
                take_alignas(decls[decls.count - 1])
                end_alignas()
            } else if decls.count as int64 > first && nodes[decls[decls.count - 1]].kind == D_FN {
                parse_error_at(align_tok, "'alignas' is for a variable or a member: a function's alignment is the C compiler's")   // at its word, as kelvinc's (#681)
                end_alignas()
            } else {
                refuse_alignas()
            }
        }
        if storage > 0 && decls.count as int64 > first {    // (#459)
            let d:int64 = decls[decls.count - 1]
            if nodes[d].kind == D_FN && nodes[d].c >= 0 && storage == 1 {
                static_clash(nodes[d].c, nodes[d].t, static_named(nodes[d].c, nodes[d].t), false)   // (#595)
                nodes[d].flag = 1                        // static let T.f(), a function of the type, as in extend (#213)
            } else if nodes[d].kind == D_FN || nodes[d].kind == D_GLOBAL {
                if storage == 1 { static_decls += d } else { extern_decls += d }   // C's, a body or a value too
            } else {
                parse_error("static and extern are for a function or a variable")
            }
        }
        if inl {
            if decls.count as int64 == first || nodes[decls[decls.count - 1]].kind != D_FN {
                parse_error_at(inline_tok, "'inline' is for a function, a method or an operator")   // at its word, as kelvinc's (#681)
            } else {
                inline_fns += decls[decls.count - 1]
            }
        }
        skip_newlines()
    }
    if !failed && anon_tagged.count > 0 {                // read for kelvinc's errors of its words, not yet built (#655)
        parse_error_at(nodes[anon_tagged[0]].t, "expected a name, found 'enum'")   // as kelvinc says it (#702)
    }
}
