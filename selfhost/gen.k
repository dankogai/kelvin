// gen.k - the C of the program, for kc (selfhost/kc.k), as kelvinc
// writes it: the same runtime, kelvin_prelude.h and libkelvin, and the
// same names for what it makes, so that the two can be compared.

struct sym {
    t: int64           // the token of its name
    ty: int64
    how: int64         // 0 a var; 1 a let; 2 a parameter; 3 each element in turn; 4 a range's count (#271)
}

var out:String             // the C
var locals:$[sym]          // the variables in scope, the innermost last
var marks:$[int64]         // where each block's variables begin
var serial:int64           // for the names kc makes
var current:int64          // the function being written
var uses_io:bool           // #import <IO>, whose kOS.h has kv_sys_init
var global_owners:bool     // whether a global owns, freed at exit by _kv_free_globals, as kelvinc does (#215)

// ---------- writing ----------

let put(s:cstr) {
    out += s
}

let put_tok(t:int64) {
    let at:int64 = toks[t].at
    for i in 0..<toks[t].len {
        out += codes[at + i].uchr
    }
}

// a string's token from its from-th code, a '?' after a '?' escaped:
// Kelvin has no trigraphs, which C11 would read in it (#220)
let put_text(t:int64, from:int64) {
    let at:int64 = toks[t].at
    for i in from..<toks[t].len {
        if codes[at + i] == '?' && i > from && codes[at + i - 1] == '?' { out += "\\" }
        out += codes[at + i].uchr
    }
}

let put_int(n:int64) {
    out += String(n)                             // a number's text (#212)
}

let gen_error(n:int64, what:cstr) {
    if !failed {
        let t:tok = toks[nodes[n].t]
        println(fnames[t.file], ":", t.line, ": error: ", what)
    }
    failed = true
}

// ---------- types ----------

let tagged_of(y:int64):int64    // prototypes: an enum with values owns where a case does (#215)
let tagged_owns(d:int64):bool
let decl_named(t:int64, kind:nkind):int64    // a prototype: put_ctype and is_owner ask it of a struct

let is_owner(y:int64):bool {
    if y < 0 { return false }
    if types[y].owns() { return true }
    let d = tagged_of(y)
    if d >= 0 { return tagged_owns(d) }
    if types[y].kind != Y_STRUCT { return false }
    let s = decl_named(types[y].name, D_STRUCT)          // a struct owns where a member does (#225)
    var f:int64 = s >= 0 ? nodes[s].a : -1            // c ? a : b in kc's own source (#232)
    while f >= 0 {
        if is_owner(nodes[f].ty) { return true }
        f = nodes[f].next
    }
    return false
}

let mangled(y:int64):String    // a prototype: put_elem_name names a type as kelvinc does

// the part of an Array's name its element gives: i64, String, Array_i64,
// kelvinc's mangled_type, so that an Array or a Dictionary of them has
// its own name (#267)
let put_elem_name(y:int64) {
    let m:String = mangled(y)
    out += &m
}

let put_array_name(y:int64) {
    put("_kv_array_")
    put_elem_name(types[y].elem)
}

// a Dictionary's name: _kv_dict_String_i64 (#211)
// a Set's name: _kv_set_i64 (#274)
let put_set_name(y:int64) {
    put("_kv_set_")
    put_elem_name(types[y].elem)
}

let put_dict_name(y:int64) {
    put("_kv_dict_")
    put_elem_name(types[y].name)
    put("_")
    put_elem_name(types[y].elem)
}

// the prefix of an owner's functions, its _free, _take and the rest
let put_owner_prefix(y:int64) {
    switch types[y].kind {
    case Y_STRING: put("kv_string")
    case Y_IO: put("kv_io")
    case Y_DICT: put_dict_name(y)
    case Y_SET: put_set_name(y)
    case Y_STRUCT:                                 // an enum with values: _kv_T (#215)
        put("_kv_")
        put_tok(types[y].name)
    default: put_array_name(y)
    }
}

// an element's free and copy, as KV_ARRAY and KV_DICT take them
let put_free_copy(y:int64) {
    if is_owner(y) {
        put_owner_prefix(y)
        put("_free, ")
        put_owner_prefix(y)
        put("_copy")
    } else {
        put("KV_PLAIN_FREE, KV_PLAIN_COPY")
    }
}


let put_ctype(y:int64) {
    switch types[y].kind {                                       // every kind of type (#210)
    case Y_VOID, Y_C: put("void")
    case Y_I64: put("int64_t")
    case Y_I32: put("int32_t")
    case Y_U8: put("uint8_t")
    case Y_U32: put("uint32_t")
    case Y_F64: put("double")
    case Y_F32: put("float")
    case Y_BOOL: put("bool")
    case Y_CSTR: put("const uint8_t *")
    case Y_STRING: put("kv_string")
    case Y_IO: put("kv_io")
    case Y_UCHR: put("kv_uchr")
    case Y_ARRAY: put_array_name(y)
    case Y_DICT: put_dict_name(y)
    case Y_SET: put_set_name(y)
    case Y_STRUCT:
        if decl_named(types[y].name, D_STRUCT) >= 0 || tagged_of(y) >= 0 {
            put("struct ")                                       // an enum with values too (#215)
        } else if decl_named(types[y].name, D_ENUM) >= 0 {
            put("enum ")                                         // (#210)
        }                                                        // else a C header's typedef (#207)
        put_tok(types[y].name)
    case Y_PTR:
        if types[y].name == 1 { put("const ") }         // const T^ (#272)
        put_ctype(types[y].elem)
        put(" *")
    case Y_ARGV: put("char **")
    }
}

// the function that frees an owner
let put_free(y:int64) {
    put_owner_prefix(y)
    put("_free")
}

// ---------- names ----------

let open_scope() {
    marks += locals.count as int64
}

let close_scope() {
    let m:int64 = marks.pop()
    while locals.count as int64 > m { locals.pop() }
}

let declare_as(t:int64, y:int64, how:int64) {
    let s:sym = {t, y, how}
    locals += s
}

let declare(t:int64, y:int64) { declare_as(t, y, 0) }

let may_change(n:int64):bool    // a prototype: assignments and pop and remove ask it (#271)
let changed_root(n:int64):int64    // and type_of of &x (#272)

// how name t was declared, as sym.how: 1 a global let; 0 a var, or a
// name of no variable
let how_declared(t:int64):int64 {
    var i:int64 = locals.count as int64 - 1
    while i >= 0 {
        if same_text(locals[i].t, t) { return locals[i].how }
        i -= 1
    }
    let g:int64 = decl_named(t, D_GLOBAL)
    return g >= 0 && nodes[g].flag == 1 ? 1 : 0
}

// the declarations by their names (#211), where kc walked every one:
// each name's first, as a prototype's before its definition
var fn_names:Dictionary<String, int64>
var global_names:Dictionary<String, int64>
var struct_names:Dictionary<String, int64>
var enum_names:Dictionary<String, int64>
var enumerators:Dictionary<String, int64>  // an enumerator's enum
var method_names:Dictionary<String, int64> // a method or a function of a type, by "T.m" (#213)

// "T.m", a method's name among the methods (#213)
let method_key(recv:int64, t:int64):String {
    var name:String = tok_text(recv)
    name += "."
    var m:String = tok_text(t)
    name += &m
    return name
}

// the method m, a token, of the type named as token recv, or -1
let method_named(recv:int64, m:int64):int64 {
    var name:String = method_key(recv, m)
    return method_names.get(name, -1)
}

let index_name(names:Dictionary<String, int64>^, t:int64, d:int64) {
    var name:String = tok_text(t)
    if !names^.has(name) { names^[name] = d }
}

var indexed = 0                 // the declarations index_names has seen (#227)

// every declaration by its name, before anything is written, and those
// made since, as the T? a chain makes (#221, #227)
let index_names() {
    let from = indexed
    indexed = decls.count as int64
    for i in from..<decls.count as int64 {
        let d:int64 = decls[i]
        switch nodes[d].kind {
        case D_FN:
            if nodes[d].c >= 0 {                           // T.m (#213)
                var name:String = method_key(nodes[d].c, nodes[d].t)
                if !method_names.has(name) { method_names[name] = d }
            } else {
                index_name(&fn_names, nodes[d].t, d)
            }
        case D_GLOBAL: index_name(&global_names, nodes[d].t, d)
        case D_STRUCT: index_name(&struct_names, nodes[d].t, d)
        case D_ENUM:
            index_name(&enum_names, nodes[d].t, d)
            var m:int64 = nodes[d].a
            while m >= 0 && nodes[d].flag != 1 {           // a case of values is the enum's alone (#215)
                index_name(&enumerators, nodes[m].t, d)
                m = nodes[m].next
            }
        default: continue
        }
    }
}

// the declaration of a global, a function, a struct or an enum named as
// token t, or -1
let decl_named(t:int64, kind:nkind):int64 {
    if decls.count as int64 > indexed { index_names() }
    var name:String = tok_text(t)
    switch kind {
    case D_FN: return fn_names.get(name, -1)
    case D_GLOBAL: return global_names.get(name, -1)
    case D_STRUCT: return struct_names.get(name, -1)
    case D_ENUM: return enum_names.get(name, -1)
    default: return -1
    }
    return -1
}

// the enum whose enumerator is named as token t, or -1 (#210)
let enum_of(t:int64):int64 {
    var name:String = tok_text(t)
    return enumerators.get(name, -1)
}

// the type of the variable named as token t, or -1
let var_type(t:int64):int64 {
    var i:int64 = locals.count as int64 - 1
    while i >= 0 {
        if same_text(locals[i].t, t) { return locals[i].ty }
        i -= 1
    }
    let g:int64 = decl_named(t, D_GLOBAL)
    if g >= 0 { return nodes[g].ty }
    let e:int64 = enum_of(t)
    if e >= 0 { return type_of_kind(Y_STRUCT, -1, nodes[e].t) }
    return -1
}

// the type of a member of a struct
let field_type(sy:int64, t:int64):int64 {
    for i in 0..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind == D_STRUCT && same_text(nodes[d].t, types[sy].name) {
            var f:int64 = nodes[d].a
            while f >= 0 {
                if same_text(nodes[f].t, t) { return nodes[f].ty }
                f = nodes[f].next
            }
        }
    }
    return -1
}

// ---------- the types of expressions ----------

let is_comparison(t:int64):bool {
    return tok_is(t, "==") || tok_is(t, "!=") || tok_is(t, "<") || tok_is(t, "<=") || tok_is(t, ">") || tok_is(t, ">=") || tok_is(t, "&&") || tok_is(t, "||")
}

let type_of(n:int64):int64
let is_case_word(n:int64):bool    // prototypes: type_of and gen_value ask them of c ? a : b (#232)
let owner_choice(n:int64):bool
let call_target(n:int64):int64    // the overload a call calls (#234)

// whether node a names a struct, not a variable: T of T.f(...)
let names_type(a:int64):bool {
    if nodes[a].kind != N_ID || var_type(nodes[a].t) >= 0 { return false }
    if decl_named(nodes[a].t, D_STRUCT) >= 0 { return true }
    let e = decl_named(nodes[a].t, D_ENUM)                // an enum with values, as T.c(v) names it (#229)
    return e >= 0 && nodes[e].flag == 1
}

// ---------- enums with values (#215) ----------

// the enum with values that type y is, or -1
let tagged_of(y:int64):int64 {
    if y < 0 || types[y].kind != Y_STRUCT { return -1 }
    let d = decl_named(types[y].name, D_ENUM)
    if d >= 0 && nodes[d].flag == 1 { return d }
    return -1
}

// the enum with values node a names, T of T.c(v) and T.none, or -1
let tagged_named(a:int64):int64 {
    if nodes[a].kind != N_ID || var_type(nodes[a].t) >= 0 { return -1 }
    let d = decl_named(nodes[a].t, D_ENUM)
    if d >= 0 && nodes[d].flag == 1 { return d }
    return -1
}

// the case named as token t of enum d, its node, or none (#217)
let case_named(d:int64, t:int64):int64? {
    var m = nodes[d].a
    while m >= 0 {
        if same_text(nodes[m].t, t) { return m }
        m = nodes[m].next
    }
    return none
}

// the place of case m among its enum's, its tag
let case_tag(d:int64, m:int64):int64 {
    var i = 0
    var c = nodes[d].a
    while c >= 0 && c != m {
        i += 1
        c = nodes[c].next
    }
    return i
}

let tagged_owns(d:int64):bool {
    var m = nodes[d].a
    while m >= 0 {
        if nodes[m].ty >= 0 && is_owner(nodes[m].ty) { return true }
        m = nodes[m].next
    }
    return false
}

// the method or the function of a type that x.m(...) or T.f(...) calls, or -1 (#213)
let method_of(n:int64):int64 {
    let a:int64 = nodes[n].a
    if names_type(a) { return method_named(nodes[a].t, nodes[n].t) }
    let y:int64 = type_of(a)
    if y < 0 || types[y].kind != Y_STRUCT { return -1 }
    return method_named(types[y].name, nodes[n].t)
}

// ---------- Optional and Result (#217) ----------

// the type an Optional's some holds, or -1 where y is no Optional
let some_type(y:int64):int64 {
    let d = tagged_of(y)
    if d < 0 || nodes[d].c != 1 { return -1 }
    return nodes[nodes[nodes[d].a].next].ty
}

// whether n is a case's word of the enum d, which no name of the program
// takes: none, or some of some(v), ok of ok(v), err of err(e)
let case_word_of(n:int64, d:int64):int64 {
    if nodes[n].kind == N_ID && var_type(nodes[n].t) < 0 { return case_named(d, nodes[n].t) ?? 0 - 1 }
    if nodes[n].kind == N_CALL && nodes[nodes[n].a].kind == N_ID {
        let f = nodes[n].a
        if var_type(nodes[f].t) < 0 && decl_named(nodes[f].t, D_FN) < 0 { return case_named(d, nodes[f].t) ?? 0 - 1 }
    }
    return -1
}

// the type of x?.rest (#221): a T? of the rest's T, where the rest is of
// the name bound to what x holds; the rest's own Optional, not wrapped again
let chain_type(n:int64):int64 {
    let inner = some_type(type_of(nodes[n].a))
    if inner < 0 {
        gen_error(n, "?. and ?[ take an Optional on their left")
        return -1
    }
    open_scope()
    declare(nodes[n].c, inner)
    let y = type_of(nodes[n].b)
    close_scope()
    if y < 0 || failed { return -1 }
    if types[y].kind == Y_VOID {
        gen_error(n, "the rest of this chain gives no value, which kc cannot put in an Optional")
        return -1
    }
    if some_type(y) >= 0 { return y }
    return optional_of(y)
}

// the text of token t is w, letters in any case: nan, NaN, NAN (#262)
let word_no_case(t:int64, w:cstr):bool {
    let n:int64 = toks[t].len
    var i = 0
    while i < n {
        if w[i] == 0 { return false }
        var c:uint32 = codes[toks[t].at + i]
        if c >= 'A' && c <= 'Z' { c += 32 }
        if c != w[i] as uint32 { return false }
        i += 1
    }
    return w[n] == 0
}

// nan, inf and infinity, in any case: f64 literals where no variable has
// the name, as kelvinc's (#261, #262)
let float_word(n:int64):bool {
    if nodes[n].kind != N_ID || var_type(nodes[n].t) >= 0 { return false }
    let t:int64 = nodes[n].t
    return word_no_case(t, "nan") || word_no_case(t, "inf") || word_no_case(t, "infinity")
}

// whether number token t is a float's, 1.5 or 1e9, not 0x1e (#262)
let float_tok(t:int64):bool {
    let at:int64 = toks[t].at
    let n:int64 = toks[t].len
    if n > 1 && codes[at] == '0' && (codes[at + 1] == 'x' || codes[at + 1] == 'X') { return false }
    for i in 0..<n {
        let c:uint32 = codes[at + i]
        if c == '.' || c == 'e' || c == 'E' { return true }
    }
    return false
}

let dict_key_type(y:int64):int64    // a prototype: type_of asks it of ${k: v} (#267)

// whether n is s + t of Strings, as kelvinc has it (#183): the left a
// String, or the right one where the left owns nothing (#284)
let is_string_plus(n:int64):bool {
    if nodes[n].kind != N_BIN || !tok_is(nodes[n].t, "+") { return false }
    let ya:int64 = type_of(nodes[n].a)
    let yb:int64 = type_of(nodes[n].b)
    if ya >= 0 && types[ya].kind == Y_STRING { return true }
    return !is_owner(ya) && yb >= 0 && types[yb].kind == Y_STRING
}

let type_of(n:int64):int64 {
    let k:nkind = nodes[n].kind
    if k == N_CHAIN { return chain_type(n) }
    if k == N_COND {                                  // c ? a : b: a's type, or b's where a is a word, as none (#232)
        if is_case_word(nodes[n].b) { return type_of(nodes[n].c) }
        return type_of(nodes[n].b)
    }
    let t:int64 = nodes[n].t
    if k == N_NUM && float_tok(t) { return base_type(Y_F64) }      // (#262)
    if k == N_SET {                                                   // ${a, b}: of a's type, a String's of text (#274)
        let e:int64 = dict_key_type(type_of(nodes[n].b))
        if e < 0 { return -1 }
        return type_of_kind(Y_SET, e, -1)
    }
    if k == N_DICT {                                                  // ${k: v}: of the first entry's types (#267)
        let ky:int64 = dict_key_type(type_of(nodes[n].b))
        let vy:int64 = type_of(nodes[nodes[n].b].next)
        if ky < 0 || vy < 0 { return -1 }
        optional_of(vy)                                               // V?, which d[k] read whole is (#219)
        return type_of_kind(Y_DICT, vy, ky)
    }
    if k == N_ARRAY {                                                 // $[a, b]: an Array of a's type (#266)
        let e:int64 = type_of(nodes[n].b)
        if e < 0 { return -1 }
        return type_of_kind(Y_ARRAY, e, -1)
    }
    if k == N_NUM || k == N_CHAR { return base_type(Y_I64) }
    if k == N_STR { return base_type(Y_CSTR) }
    if k == N_DSTR { return base_type(Y_STRING) }
    if k == N_BOOL { return base_type(Y_BOOL) }
    if k == N_NULL { return base_type(Y_C) }
    if k == N_SELF { return type_of_kind(Y_STRUCT, -1, nodes[current].c) }      // (#213)
    if float_word(n) { return base_type(Y_F64) }                      // nan, inf (#262)
    if k == N_ID {
        let y:int64 = var_type(t)
        if y < 0 && c_headers { return base_type(Y_C) }      // a C header's (#207)
        if y < 0 { gen_error(n, "this name is not known") }
        return y
    }
    if k == N_CALL {
        let f:int64 = nodes[n].a
        if nodes[f].kind == N_TYPE {
            if tok_is(nodes[f].t, "IO") { return base_type(Y_IO) }
            return base_type(Y_STRING)
        }
        if tok_is(nodes[f].t, "println") || tok_is(nodes[f].t, "print") { return base_type(Y_VOID) }
        let d:int64 = call_target(n)                       // the overload its arguments fit (#234)
        if d < 0 && c_headers { return base_type(Y_C) }      // a C header's function (#207)
        if d < 0 {
            gen_error(n, "this function is not known")
            return -1
        }
        return nodes[d].ty
    }
    if k == N_FIELD {
        let e = tagged_named(nodes[n].a)
        if e >= 0 { return type_of_kind(Y_STRUCT, -1, nodes[e].t) }      // T.none (#215)
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        let d = tagged_of(y)
        if d >= 0 {                                                      // v.c, the case's value
            if let some(m) = case_named(d, t) {
                if nodes[m].ty >= 0 { return nodes[m].ty }
            }
            gen_error(n, "this is no case of a value of this enum")
            return -1
        }
        let yk:ykind = types[y].kind
        if tok_is(t, "count") && (yk == Y_STRING || yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET) { return base_type(Y_I64) }
        if yk == Y_SET && tok_is(t, "elements") { return type_of_kind(Y_ARRAY, types[y].elem, -1) }   // an Array of copies (#278)
        if yk == Y_DICT && tok_is(t, "keys") { return type_of_kind(Y_ARRAY, types[y].name, -1) }      // (#285)
        if yk == Y_DICT && tok_is(t, "values") { return type_of_kind(Y_ARRAY, types[y].elem, -1) }
        if yk == Y_IO && tok_is(t, "string") { return base_type(Y_STRING) }
        if yk == Y_IO { return base_type(Y_I32) }
        if yk == Y_STRING && tok_is(t, "cstr") { return base_type(Y_CSTR) }
        if tok_is(t, "uchr") { return base_type(Y_UCHR) }
        if tok_is(t, "utf32") { return base_type(Y_U32) }
        if yk == Y_STRUCT && decl_named(types[y].name, D_STRUCT) >= 0 { return field_type(y, t) }
        if yk == Y_STRUCT || yk == Y_C { return base_type(Y_C) }      // of what only C sees (#207)
        gen_error(n, "this member is not known")
        return -1
    }
    if k == N_METHOD {
        if nodes[nodes[n].a].kind == N_TYPE { return base_type(Y_IO) }       // IO.exec(args, mode)
        let f:int64 = method_of(n)
        if f >= 0 { return nodes[f].ty }                                     // (#213)
        let e = tagged_named(nodes[n].a)
        if e >= 0 { return type_of_kind(Y_STRUCT, -1, nodes[e].t) }      // T.c(v) (#215)
        if tok_is(t, "is") { return base_type(Y_BOOL) }
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        if tok_is(t, "copy") { return y }
        if tok_is(t, "pop") || tok_is(t, "get") { return types[y].elem }
        if tok_is(t, "has") { return base_type(Y_BOOL) }
        if tok_is(t, "remove") && types[y].kind == Y_DICT { return base_type(Y_BOOL) }   // true if it was there (#270)
        if (tok_is(t, "remove") || tok_is(t, "insert")) && types[y].kind == Y_SET { return base_type(Y_BOOL) }   // (#274)
        if (tok_is(t, "union") || tok_is(t, "intersection") || tok_is(t, "difference")) && types[y].kind == Y_SET { return y }   // a new Set (#275)
        return base_type(Y_VOID)
    }
    if k == N_INDEX {
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        let yk:ykind = types[y].kind
        if yk == Y_DICT && nodes[n].flag == 1 { return optional_of(types[y].elem) }    // d[k] read whole (#219)
        if yk == Y_ARRAY || yk == Y_DICT { return types[y].elem }
        if yk == Y_ARGV { return base_type(Y_CSTR) }
        return base_type(Y_U8)
    }
    if k == N_UNARY {
        if tok_is(t, "!") { return base_type(Y_BOOL) }
        return type_of(nodes[n].a)
    }
    if k == N_BIN {
        if is_comparison(t) { return base_type(Y_BOOL) }
        if tok_is(t, "??") { return some_type(type_of(nodes[n].a)) }   // (#217)
        if is_string_plus(n) { return base_type(Y_STRING) }            // s + t, a new String (#284)
        return type_of(nodes[n].a)
    }
    if k == N_CAST { return nodes[n].ty }
    if k == N_ADDR {                                   // &x, a const T^ of a let (#272)
        let r:int64 = changed_root(nodes[n].a)
        let fixed = r >= 0 && how_declared(nodes[r].t) != 0
        return type_of_kind(Y_PTR, type_of(nodes[n].a), fixed ? 1 : 0 - 1)
    }
    if k == N_DEREF {
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        return types[y].elem
    }
    return -1
}

// ---------- expressions ----------

// whether n is text, a cstr, a literal too
let is_cstr_text(n:int64):bool {
    let y:int64 = type_of(n)
    return y >= 0 && types[y].kind == Y_CSTR
}

// whether n is a String
let is_string_value(n:int64):bool {
    let y:int64 = type_of(n)
    return y >= 0 && types[y].kind == Y_STRING
}

// the kind of a built-in owner y is, a String, an Array, a Dictionary,
// a Set or an IO, else Y_VOID
let builtin_kind(y:int64):ykind {
    if y < 0 { return Y_VOID }
    let k = types[y].kind
    if k == Y_STRING || k == Y_ARRAY || k == Y_DICT || k == Y_SET || k == Y_IO { return k }
    return Y_VOID
}

// an operator of an Array, a Dictionary or a Set, the left's or else the
// right's, that kelvinc has not: an error in its words (#287); a Set's
// | & ~ are its own (#276), and == and != of an Array or a Dictionary
// kelvinc's (#235, #247), not yet kc's
let reject_container_math(n:int64) {
    let t = nodes[n].t
    if tok_is(t, "??") { return }
    var k:ykind = builtin_kind(type_of(nodes[n].a))
    if k == Y_VOID { k = builtin_kind(type_of(nodes[n].b)) }
    if k != Y_ARRAY && k != Y_DICT && k != Y_SET { return }
    if k == Y_SET && (tok_is(t, "|") || tok_is(t, "&") || tok_is(t, "~")) { return }
    if k != Y_SET && (tok_is(t, "==") || tok_is(t, "!=")) { return }
    var m = $"an Array"
    if k == Y_DICT { m = $"a Dictionary" }
    if k == Y_SET { m = $"a Set" }
    m += " has no operator '"
    let op:String = tok_text(t)
    m += &op
    m += "': compare its "
    if k == Y_DICT { m += "entries" } else { m += "elements" }
    gen_error(n, m.cstr)
}

// + and - of a cstr, as kelvinc has them (#282, #283): only a String
// joins, and a cstr is text, not a cursor (#52); p - s stays an offset
let reject_cstr_math(n:int64) {
    let t:int64 = nodes[n].t
    let plus = tok_is(t, "+")
    if !plus && !tok_is(t, "-") { return }
    if plus && (is_string_value(nodes[n].a) || is_string_value(nodes[n].b)) { return }
    let ta = is_cstr_text(nodes[n].a)
    let tb = is_cstr_text(nodes[n].b)
    if plus && ta && tb {
        gen_error(n, "'+' joins Strings, and a cstr is not one (#282): make one a String, as in '$\"a\" + \"b\"'")
    } else if ta || (plus && tb) {
        gen_error(n, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a 'var p:u8^ := s'")
    }
}

let gen_expr(n:int64)

let gen_value(n:int64, y:int64)

let gen_args(first:int64) {
    var a:int64 = first
    while a >= 0 {
        if a != first { put(", ") }
        gen_expr(a)
        a = nodes[a].next
    }
}

let is_place(n:int64):bool    // a prototype: gen_args_to and gen_call ask it

// the arguments of a call of the function d, each by its parameter's type
// (#217); an owner it takes by value moves in, which it frees (#226): a
// whole variable by _take, an owner an expression gives as it is
let type_text(y:int64):String    // a prototype: gen_args_to names the types (#272)

// "a" or "an" before a type's name, as it is read, as kelvinc's article:
// an i64, a String, an f64 (#273)
let article_of(w:const String^):cstr {
    let s:cstr := w^.cstr
    let c:uint8 = s[0]
    if c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'A' || c == 'E' || c == 'I' || c == 'O' { return "an" }
    if c == 'f' && s[1] >= '0' && s[1] <= '9' { return "an" }
    return "a"
}

// whether value n goes where a t goes: not a const T^, a let's borrow,
// where a T^ that may change what it borrows goes (#272, #273); who
// names what takes it, as kelvinc's lead
let takes_borrow(n:int64, t:int64, who:const String^):bool {
    let at = type_of(n)
    if at < 0 || t < 0 || types[at].kind != Y_PTR || types[at].name != 1 || types[t].kind != Y_PTR || types[t].name == 1 {
        return true
    }
    var m = who^.copy()
    m += " is "
    let w:String = type_text(t)
    m += article_of(&w)
    m += " "
    m += &w
    m += ", which may change what it borrows, and this is "
    let v:String = type_text(at)
    m += &v
    m += ", a let's: write const in the type taken, or borrow a var"
    gen_error(n, m.cstr)
    return false
}

let gen_args_to(first:int64, d:int64) {
    var a:int64 = first
    var p:int64 = d >= 0 ? nodes[d].a : -1
    while a >= 0 {
        if a != first { put(", ") }
        if p >= 0 && is_owner(nodes[p].ty) && nodes[a].kind == N_ID && var_type(nodes[a].t) >= 0 {
            put_owner_prefix(nodes[p].ty)
            put("_take(&")
            put_tok(nodes[a].t)
            put(")")
            p = nodes[p].next
        } else if p >= 0 && is_owner(nodes[p].ty) && is_place(a) {
            gen_error(a, "an owner moves into a function only as a whole variable: pass a borrow, &..., or a copy")
            return
        } else if p >= 0 {
            var who = $"'"                              // a let's borrow where a T^ that may change it goes (#272),
            who += tok_text(nodes[p].t)                 // of an owner too, as kelvinc since #273
            who += "' of '"
            who += tok_text(nodes[d].t)
            who += "'"
            if !takes_borrow(a, nodes[p].ty, &who) { return }
            gen_value(a, nodes[p].ty)
            p = nodes[p].next
        } else {
            gen_expr(a)
        }
        a = nodes[a].next
    }
}

// the address of what n names: &x, or a pointer as it is
let gen_place(n:int64) {
    put("&(")
    gen_expr(n)
    put(")")
}

// a type as kelvinc's messages name it: an Array an Array<T> (#284, #286)
let kelvin_type_text(y:int64):String {
    if types[y].kind == Y_ARRAY {
        var s = $"Array<"
        let e:String = kelvin_type_text(types[y].elem)
        s += &e
        s += ">"
        return s
    }
    return type_text(y)
}

// a side of s + t as kelvinc names it where it is not text: a literal is
// a number, an Array an Array<T> (#284)
let plus_side_text(n:int64):String {
    let k = nodes[n].kind
    if k == N_NUM || k == N_CHAR || k == N_BOOL { return $"a number" }
    let y:int64 = type_of(n)
    if y < 0 { return $"not text" }
    return kelvin_type_text(y)
}


// s + t of Strings (#284), as kelvinc's: each side a String, a cstr or
// a uchr, the left no uchr; a new String, the left copied from a
// variable, taken from an expression or made of text, and the right
// appended, a String in a variable lent
let gen_string_plus(n:int64) {
    let a = nodes[n].a
    let b = nodes[n].b
    var side = a
    while side >= 0 {
        let y:int64 = type_of(side)
        let text = y >= 0 && (types[y].kind == Y_STRING || types[y].kind == Y_UCHR || types[y].kind == Y_CSTR)
        if !text {
            var s = $"'+' of a String joins text: a String, a cstr or a uchr, and this is "
            let what:String = plus_side_text(side)
            s += &what
            s += "; show a number with a template, $`${n}`, or String(n)"
            gen_error(side, s.cstr)
            return
        }
        side = side == a ? b : -1
    }
    let ya:int64 = type_of(a)
    if types[ya].kind == Y_UCHR {
        gen_error(a, "'+' of a String starts with a String or text: write $\"\" + c, or String(c)")
        return
    }
    put("({ kv_string _kv_cat = ")
    if types[ya].kind != Y_STRING {
        put("KV_STRING_OF(")
        gen_expr(a)
        put(")")
    } else if is_place(a) {
        put("kv_string_copy(&(")
        gen_expr(a)
        put("))")
    } else {
        put("(")
        gen_expr(a)
        put(")")
    }
    put("; KV_STRING_APPEND(&_kv_cat, ")
    let yb:int64 = type_of(b)
    if types[yb].kind == Y_STRING && is_place(b) {
        gen_place(b)
    } else {
        gen_expr(b)
    }
    put("); _kv_cat; })")
}

// a Dictionary's key: a String's text, as KV_DICT looks it up (#211)
let gen_key_of(key:int64, k:int64)    // a prototype: a Set's element too (#274)

let gen_key(y:int64, k:int64) {
    gen_key_of(types[y].name, k)
}

// k as a Dictionary's key or a Set's element of type key is asked for:
// the text of a String's, else k (#274)
let gen_key_of(key:int64, k:int64) {
    let ky:int64 = type_of(k)
    if types[key].kind == Y_STRING && ky >= 0 && types[ky].kind == Y_STRING {
        put("kv_bytes_cstr(&(")
        gen_expr(k)
        put(").b)")
    } else {
        gen_expr(k)
    }
}


// whether n is none, ok(v) or err(e), which only the type that takes them
// reads: no name of the program (#221)
let is_case_word(n:int64):bool {
    if nodes[n].kind == N_ID { return var_type(nodes[n].t) < 0 }
    if nodes[n].kind == N_CALL && nodes[nodes[n].a].kind == N_ID {
        let f = nodes[n].a
        return var_type(nodes[f].t) < 0 && decl_named(nodes[f].t, D_FN) < 0
    }
    return false
}

// ---------- temporaries (#227) ----------

var held:Dictionary<int64, int64>    // an expression held in a temporary, by its node: the temporary's number

// whether n gives an owner that no variable holds: a call's, a String
// literal's, a member of one, which reading it holds in a temporary
let needs_hold(n:int64):bool {
    if n < 0 || is_case_word(n) || is_place(n) { return false }
    return is_owner(type_of(n))
}

// ({ T _kv_tmpN = n; ... : n held where it is read, freed once the
// expression is done, as kelvinc holds it; gen_expr of n names it
let hold_open(n:int64) {
    serial += 1
    let s = serial                                   // its own: n may hold temporaries too
    let y = type_of(n)
    put("({ __attribute__((cleanup(")
    put_free(y)
    put("))) ")
    put_ctype(y)
    put(" _kv_tmp")
    put_int(s)
    put(" = ")
    gen_expr(n)
    put("; ")
    held[n] = s
}

let hold_close(n:int64) {
    put("; })")
    held[n] = 0 - 1
}

// the owners a call's arguments give where the function does not take
// them by value, as println's: each held for the call (#227)
let hold_args(first:int64, d:int64):$[int64] {
    var opened:$[int64] = $[]
    var a:int64 = first
    var p:int64 = d >= 0 ? nodes[d].a : -1
    while a >= 0 {
        let by_value = p >= 0 && is_owner(nodes[p].ty)           // which the function frees (#226)
        if !by_value && needs_hold(a) {
            hold_open(a)
            opened += a
        } else if !by_value && nodes[a].kind == N_ADDR && needs_hold(nodes[a].a) {   // f(&g()), lent
            hold_open(nodes[a].a)
            opened += nodes[a].a
        }
        a = nodes[a].next
        if p >= 0 { p = nodes[p].next }
    }
    return opened
}

let close_holds(opened:$[int64]^) {
    for i in 0..<opened^.count as int64 { hold_close(opened^[i]) }
}

// ---------- overloading (#234) ----------

var fn_sigs:Dictionary<String, int64>       // each function's name and signature: its first declaration
var fn_bodies:Dictionary<String, int64>     // those of them a declaration defines
var fn_overloads:Dictionary<String, int64>  // how many signatures a name has
var targets:Dictionary<int64, int64>        // the overload each call of an overloaded name chose

// a type in a C name, as kelvinc's mangled_type: i64, String, vecp,
// Array_i64, Dictionary_String_i64, opt_i64, res_i64_String
let mangled(y:int64):String {
    switch types[y].kind {
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
    case Y_ARGV: return $"acstr"
    case Y_PTR:
        var s = mangled(types[y].elem)
        s += "p"
        return s
    case Y_ARRAY:
        var s = $"Array_"
        s += mangled(types[y].elem)
        return s
    case Y_DICT:
        var s = $"Dictionary_"
        s += mangled(types[y].name)
        s += "_"
        s += mangled(types[y].elem)
        return s
    case Y_SET:
        var s = $"Set_"
        s += mangled(types[y].elem)
        return s
    case Y_STRUCT:
        let d = tagged_of(y)
        if d >= 0 && nodes[d].c == 1 {
            var s = $"opt_"
            s += mangled(some_type(y))
            return s
        }
        if d >= 0 && types[y].name > eof_pos {          // a Result, made by kc
            let m = nodes[d].a
            var s = $"res_"
            s += mangled(nodes[m].ty)
            s += "_"
            s += mangled(nodes[nodes[m].next].ty)
            return s
        }
        return tok_text(types[y].name)
    default: return $"C"
    }
}

// a function's parameters in its C name: __i64__String, or __void
let params_key(d:int64):String {
    var s = $""
    var p:int64 = nodes[d].a
    if p < 0 { s += "__void" }
    while p >= 0 {
        s += "__"
        s += mangled(nodes[p].ty)
        p = nodes[p].next
    }
    return s
}

let sig_key(d:int64):String {
    var key = tok_text(nodes[d].t)
    key += params_key(d)
    return key
}

// the signatures of each name: a prototype and its definition are one
let count_overloads() {
    for i in 0..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind != D_FN || nodes[d].c >= 0 { continue }
        var key = sig_key(d)
        if !fn_sigs.has(key) {
            fn_sigs[key] = d
            var name = tok_text(nodes[d].t)
            fn_overloads[name] = fn_overloads.get(name, 0) + 1
        }
        if nodes[d].b >= 0 { fn_bodies[key] = 1 }
    }
}

// a function's C name, as kelvinc's: a defined overload by its
// parameters' types, twice__i64; one declared and never defined is C's
let put_fn_name(d:int64) {
    put_tok(nodes[d].t)
    var name = tok_text(nodes[d].t)
    var key = sig_key(d)
    if fn_overloads.get(name, 0) > 1 && fn_bodies.has(key) && !tok_is(nodes[d].t, "main") {
        var types_of = params_key(d)
        out += &types_of
    }
}

// a number to choose overloads by, as kelvinc's numeric_type: bool too, as C's _Bool
let is_number_kind(k:ykind):bool {
    return k == Y_I64 || k == Y_I32 || k == Y_U8 || k == Y_U32 || k == Y_F64 || k == Y_F32 || k == Y_BOOL
}

// how a call's argument a fits a parameter of type t, as kelvinc's fit:
// 2 its very type, 1 one it converts to, 0 none; a T fits a T? only
// where wraps is, the second look (#222)
let arg_fit(a:int64, t:int64, wraps:bool):int64 {
    if t < 0 { return 0 }
    let k:nkind = nodes[a].kind
    let tk:ykind = types[t].kind
    if is_case_word(a) {                                 // none, ok(v), err(e): of the type that takes them
        let d = tagged_of(t)
        if d < 0 { return 0 }
        let w = k == N_CALL ? nodes[nodes[a].a].t : nodes[a].t
        return case_named(d, w).is(some) ? 1 : 0
    }
    let literal = k == N_NUM || k == N_CHAR || (k == N_UNARY && tok_is(nodes[a].t, "-") && nodes[nodes[a].a].kind == N_NUM)
    let at = type_of(a)
    if at == t { return 2 }
    if literal && is_number_kind(tk) { return 1 }
    if k == N_STR && tk == Y_STRING { return 1 }          // a String of it (#223)
    if at >= 0 && types[at].kind == Y_C { return 1 }      // what only C sees, which C converts
    if at >= 0 && is_number_kind(types[at].kind) && is_number_kind(tk) { return 1 }
    if wraps && some_type(t) >= 0 && arg_fit(a, some_type(t), wraps) > 0 { return 1 }
    return 0
}

// the overload of name that call n's arguments fit best: exactly, or as
// well on each argument as any other and better on one; -2 a tie, -1 none
let choose_overload(n:int64, name:String^, wraps:bool):int64 {
    var cands:$[int64] = $[]
    var fits:$[int64] = $[]
    var nargs = 0
    var a:int64 = nodes[n].b
    while a >= 0 {
        nargs += 1
        a = nodes[a].next
    }
    for i in 0..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind != D_FN || nodes[d].c >= 0 || tok_text(nodes[d].t) != name^ { continue }
        var key = sig_key(d)
        if fn_sigs.get(key, -1) != d { continue }         // a signature once
        var np = 0
        var p:int64 = nodes[d].a
        var ok = true
        a = nodes[n].b
        let at = fits.count as int64
        while p >= 0 && a >= 0 {
            let f = arg_fit(a, nodes[p].ty, wraps)
            if f == 0 { ok = false }
            fits += f
            np += 1
            p = nodes[p].next
            a = nodes[a].next
        }
        if !ok || p >= 0 || a >= 0 {                      // no fit, or another count of arguments
            while fits.count as int64 > at { fits.pop() }
            continue
        }
        cands += d
    }
    var best = -1
    var ties = 0
    for i in 0..<cands.count as int64 {
        var beaten = false
        for j in 0..<cands.count as int64 {
            if i == j { continue }
            var all = true
            var more = false
            for k in 0..<nargs as int64 {
                let x = fits[j * nargs + k]
                let y = fits[i * nargs + k]
                if x < y { all = false }
                if x > y { more = true }
            }
            if all && more { beaten = true }
        }
        if !beaten {
            if best >= 0 { ties += 1 }
            best = cands[i]
        }
    }
    if ties > 0 { return 0 - 2 }
    return best
}

// the function call n calls: the one of its name, or the overload its
// arguments fit, chosen once; -1 C's
let call_target(n:int64):int64 {
    let f:int64 = nodes[n].a
    let first = decl_named(nodes[f].t, D_FN)
    if first < 0 { return -1 }
    var name = tok_text(nodes[f].t)
    if fn_overloads.get(name, 0) < 2 { return first }
    if targets.has(n) { return targets.get(n, -1) }
    var a:int64 = -1
    var d = choose_overload(n, &name, false)
    if d == -1 { d = choose_overload(n, &name, true) }   // a T where a T? goes (#222)
    if d == -2 {
        var why = name.copy()
        var bare = false                                  // a none that two Optionals take
        a = nodes[n].b
        while a >= 0 {
            if nodes[a].kind == N_ID && is_case_word(a) { bare = true }
            a = nodes[a].next
        }
        why += bare ? "(...) fits more than one of its overloads equally: say which Optional none is, binding it first, as in 'let n:int64? = none'" : "(...) fits more than one of its overloads equally: convert an argument, as in 'x as int64'"
        gen_error(n, why.cstr)
        d = first
    } else if d < 0 {
        var why = name.copy()
        why += "(...) fits none of its overloads: C's function of the name is not called where a Kelvin function has it (#223); declare C's beside them"
        gen_error(n, why.cstr)
        d = first
    }
    targets[n] = d
    return d
}

// ---------- printing an enum with values, a struct (#229) and an Array (#230) ----------

var shown:$[int64]                       // the types whose _kv_show_T is written, in order
var shown_types:Dictionary<int64, int64>

// the struct a type names, or -1
let struct_of(y:int64):int64 {
    if y < 0 || types[y].kind != Y_STRUCT { return -1 }
    return decl_named(types[y].name, D_STRUCT)
}

// whether print shows v as it is: a number, a bool, text
let plain_shown(v:int64):bool {
    let k:ykind = types[v].kind
    return k == Y_I64 || k == Y_I32 || k == Y_U8 || k == Y_U32 || k == Y_F64 || k == Y_F32 || k == Y_BOOL || k == Y_STRING || k == Y_CSTR
}

// whether print shows y by a _kv_show_T of its own: an enum with values
// (an Optional, a Result), a struct, an Array or a Dictionary (#268)
let shown_by_type(y:int64):bool {
    return y >= 0 && (tagged_of(y) >= 0 || struct_of(y) >= 0 || types[y].kind == Y_ARRAY || types[y].kind == Y_DICT || types[y].kind == Y_SET)
}

// whether print can show a value of y, an enum with values (an Optional, a
// Result), a struct or an Array, as kelvinc does, by a _kv_show_T of its
// own; what it holds is shown too. Where kc cannot show it, n is an error
let need_show(y:int64, n:int64):bool {
    if shown_types.has(y) { return true }
    shown_types[y] = 1
    if types[y].kind == Y_ARRAY || types[y].kind == Y_DICT || types[y].kind == Y_SET {   // its elements (#230, #274), its values (#268)
        let v = types[y].elem
        if !plain_shown(v) && !shown_by_type(v) {
            gen_error(n, "kc prints a number, a bool, text, an Array, a Dictionary, an enum with values or a struct of them; not yet what this holds")
            return false
        }
        if !plain_shown(v) && !need_show(v, n) { return false }
        shown += y
        return true
    }
    let d = tagged_of(y)
    var m:int64 = d >= 0 ? nodes[d].a : nodes[struct_of(y)].a
    while m >= 0 {
        let v = nodes[m].ty
        if v >= 0 && !plain_shown(v) {
            if !shown_by_type(v) {
                gen_error(n, "kc prints a number, a bool, text, an Array, a Dictionary, an enum with values or a struct of them; not yet what this holds")
                return false
            }
            if !need_show(v, n) { return false }
        }
        m = nodes[m].next
    }
    shown += y
    return true
}

let put_show_name(y:int64) {
    put("_kv_show_")
    if types[y].kind == Y_ARRAY {
        put_array_name(y)                                 // _kv_show__kv_array_i64 (#230)
    } else if types[y].kind == Y_DICT {
        put_dict_name(y)                                  // _kv_show__kv_dict_String_i64 (#268)
    } else if types[y].kind == Y_SET {
        put_set_name(y)                                   // _kv_show__kv_set_i64 (#274)
    } else {
        put_tok(types[y].name)
    }
}

// self->path, and t's name after it where t is one
let put_self(path:cstr, t:int64) {
    put("self->")
    put(path)
    if t >= 0 { put_tok(t) }
}

// the value of v at self->path, t its name, as kelvinc shows it: text
// quoted, an enum with values or a struct by its _kv_show_T at level
let show_value(v:int64, path:cstr, t:int64, level:cstr) {
    let k:ykind = types[v].kind
    if k == Y_STRING {
        put("kv_out_quoted(o, (")
        put_self(path, t)
        put(").b.at, (")
        put_self(path, t)
        put(").b.count, false);\n")
    } else if k == Y_CSTR {
        put("kv_out_quoted_text(o, (const void *)(")
        put_self(path, t)
        put("));\n")
    } else if !plain_shown(v) {
        put_show_name(v)
        put("(o, &(")
        put_self(path, t)
        put("), ")
        put(level)
        put(");\n")
    } else {
        put("{ uint8_t _kv_b[256]; ")
        put(k == Y_BOOL ? "kv_cstr_bool" : k == Y_U8 || k == Y_U32 ? "kv_cstr_u64" : k == Y_F64 ? "kv_cstr_f64" : k == Y_F32 ? "kv_cstr_f32" : "kv_cstr_i64")
        put("(")
        put_self(path, t)
        put(", _kv_b); kv_out_put(o, _kv_b); }\n")
    }
}

// _kv_show_T of y, as kelvinc writes it: of an enum with values, a case's
// name and what it holds in parentheses; of a struct, {x: 1, y: 2}
let gen_show(y:int64) {
    put("static void ")
    put_show_name(y)
    put("(kv_out *o, const void *_kv_v, int level)\n{\n    const ")
    if types[y].kind == Y_ARRAY {                         // [1, 2], [] where empty (#230)
        put_array_name(y)
        put(" *self = _kv_v;\n    __attribute__((unused)) int _kv_nl = level < 0 ? -1 : level + 1;\n")
        put("    if (!self->count)\n    {\n        kv_out_put(o, \"[]\");\n        return;\n    }\n")
        put("    kv_out_put(o, \"[\");\n    for (size_t _kv_i = 0; _kv_i < self->count; _kv_i++)\n    {\n")
        put("        kv_out_sep(o, level, _kv_i == 0);\n        ")
        show_value(types[y].elem, "at[_kv_i]", 0 - 1, "_kv_nl")
        put("    }\n    kv_out_end(o, level);\n    kv_out_put(o, \"]\");\n}\n\n")
        return
    }
    if types[y].kind == Y_SET {                           // {3, 1, 4}, {} where empty, in the order added (#274)
        put_set_name(y)
        put(" *self = _kv_v;\n    __attribute__((unused)) int _kv_nl = level < 0 ? -1 : level + 1;\n")
        put("    if (!self->count)\n    {\n        kv_out_put(o, \"{}\");\n        return;\n    }\n")
        put("    kv_out_put(o, \"{\");\n    bool _kv_first = true;\n")
        put("    for (size_t _kv_i = 0; _kv_i < self->len; _kv_i++)\n    {\n")
        put("        if (!self->at[_kv_i].live)\n            continue;\n")
        put("        kv_out_sep(o, level, _kv_first);\n        _kv_first = false;\n        ")
        show_value(types[y].elem, "at[_kv_i].key", 0 - 1, "_kv_nl")
        put("    }\n    kv_out_end(o, level);\n    kv_out_put(o, \"}\");\n}\n\n")
        return
    }
    if types[y].kind == Y_DICT {                          // {"ann": 31}, {} where empty, in the order added (#268)
        put_dict_name(y)
        put(" *self = _kv_v;\n    __attribute__((unused)) int _kv_nl = level < 0 ? -1 : level + 1;\n")
        put("    if (!self->count)\n    {\n        kv_out_put(o, \"{}\");\n        return;\n    }\n")
        put("    kv_out_put(o, \"{\");\n    bool _kv_first = true;\n")
        put("    for (size_t _kv_i = 0; _kv_i < self->len; _kv_i++)\n    {\n")
        put("        if (!self->at[_kv_i].live)\n            continue;\n")
        put("        kv_out_sep(o, level, _kv_first);\n        _kv_first = false;\n        ")
        show_value(types[y].name, "at[_kv_i].key", 0 - 1, "_kv_nl")
        put("        kv_out_put(o, \": \");\n        ")
        show_value(types[y].elem, "at[_kv_i].value", 0 - 1, "_kv_nl")
        put("    }\n    kv_out_end(o, level);\n    kv_out_put(o, \"}\");\n}\n\n")
        return
    }
    put("struct ")
    put_tok(types[y].name)
    put(" *self = _kv_v;\n")
    let d = tagged_of(y)
    if d < 0 {
        let s = struct_of(y)
        put("    int _kv_nl = level < 0 ? -1 : level + 1;\n    kv_out_put(o, \"{\");\n")
        var f = nodes[s].a
        while f >= 0 {
            put("    kv_out_sep(o, level, ")
            put(f == nodes[s].a ? "true" : "false")
            put(");\n    kv_out_put(o, \"")
            put_tok(nodes[f].t)
            put(": \");\n    ")
            show_value(nodes[f].ty, "", nodes[f].t, "_kv_nl")
            f = nodes[f].next
        }
        put("    kv_out_end(o, level);\n    kv_out_put(o, \"}\");\n}\n\n")
        return
    }
    put("    switch (self->tag)\n    {\n")
    var m = nodes[d].a
    while m >= 0 {
        put("    case ")
        put_int(case_tag(d, m))
        put(":\n        kv_out_put(o, \"")
        put_tok(nodes[m].t)
        if nodes[m].ty < 0 {
            put("\");\n        break;\n")
        } else {
            put("(\");\n        ")
            show_value(nodes[m].ty, "u.", nodes[m].t, "level")
            put("        kv_out_put(o, \")\");\n        break;\n")
        }
        m = nodes[m].next
    }
    put("    default: kv_out_put(o, \"?\"); break;\n    }\n}\n\n")
}

// print's and println's values: an enum with values, a struct (#229) or an
// Array (#230) by its _kv_show_T, which writes it where the value stands,
// as kelvinc does
let gen_print_args(first:int64) {
    var a:int64 = first
    while a >= 0 {
        if a != first { put(", ") }
        let y = type_of(a)
        if !is_case_word(a) && shown_by_type(y) && need_show(y, a) {
            put("({ __auto_type _kv_sv = (")
            gen_expr(a)
            put("); ")
            put_show_name(y)
            put("(&(kv_out){.fp = NULL, .width = 2}, &_kv_sv, -1); (const uint8_t *)\"\"; })")
        } else {
            gen_expr(a)
        }
        a = nodes[a].next
    }
}

let gen_call(n:int64) {
    let f:int64 = nodes[n].a
    let args:int64 = nodes[n].b
    if nodes[f].kind == N_TYPE {
        if tok_is(nodes[f].t, "IO") {
            put("kv_io_open(")
            gen_expr(args)
            put(", ")
            gen_expr(nodes[args].next)
            put(")")
        } else {
            put("KV_STRING_OF(")
            gen_expr(args)
            put(")")
        }
        return
    }
    if tok_is(nodes[f].t, "println") || tok_is(nodes[f].t, "print") {
        var count = 0                              // the prelude's macro counts up to 16 (#214)
        var x = args
        while x >= 0 {
            count += 1
            x = nodes[x].next
        }
        if count > 16 { gen_error(n, "println and print take up to 16 values: write two calls") }
    }
    if nodes[f].kind == N_ID && var_type(nodes[f].t) >= 0 {   // kc has no function values
        gen_error(n, "this calls a variable, which hides the function of its name here: rename one of them")
        return
    }
    let d = call_target(n)                          // the overload its arguments fit (#234)
    var opened = hold_args(args, d)                 // as kelvinc holds them (#227)
    if d >= 0 { put_fn_name(d) } else { put_tok(nodes[f].t) }
    put("(")
    if tok_is(nodes[f].t, "println") || tok_is(nodes[f].t, "print") {
        gen_print_args(args)
    } else {
        gen_args_to(args, d)
    }
    put(")")
    close_holds(&opened)
}

let gen_member(n:int64)         // prototypes: the reading of a member and of a method, held or not (#227)
let gen_method_of(n:int64)

// a.t of what an expression gives (#227): a held, a member that owns
// copied out of it, as kelvinc does; a pointer into it an error
let is_made_array(n:int64):bool    // a prototype: gen_field asks it (#285)

let gen_field(n:int64) {
    let a:int64 = nodes[n].a
    if !needs_hold(a) {
        gen_member(n)
        return
    }
    let y = type_of(n)
    if y >= 0 && (types[y].kind == Y_CSTR || types[y].kind == Y_PTR) {
        gen_error(n, "this is a pointer into an owner that an expression gives, which is freed once the expression is done: bind it to a variable first")
        return
    }
    hold_open(a)
    let made = is_made_array(n)              // s.elements, d.keys, d.values are new, no member to copy (#278, #285)
    if is_owner(y) && !made {
        put_owner_prefix(y)
        put("_copy(&(")
        gen_member(n)
        put("))")
    } else {
        gen_member(n)
    }
    hold_close(a)
}

// whether n is s.elements, d.keys or d.values: a new Array of copies,
// no member (#278, #285)
let is_made_array(n:int64):bool {
    if nodes[n].kind != N_FIELD { return false }
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return false }
    let t = nodes[n].t
    if types[y].kind == Y_SET { return tok_is(t, "elements") }
    return types[y].kind == Y_DICT && (tok_is(t, "keys") || tok_is(t, "values"))
}

// an Array of copies of the elements of the Set or the keys or values of
// the Dictionary a gives, of type y, in the order added (#278, #285), as
// kelvinc's: each live slot's key, or value, ey, copied where it owns
let gen_slots_array(a:int64, y:int64, ey:int64, value:bool) {
    let ay:int64 = type_of_kind(Y_ARRAY, ey, -1)
    serial += 1
    let s = serial
    put("({ const ")
    if types[y].kind == Y_SET { put_set_name(y) } else { put_dict_name(y) }
    put(" *_kv_p")
    put_int(s)
    put(" = ")
    gen_place(a)
    put("; ")
    put_array_name(ay)
    put(" _kv_e")
    put_int(s)
    put(" = {0}; ")
    put_array_name(ay)
    put("_reserve(&_kv_e")
    put_int(s)
    put(", _kv_p")
    put_int(s)
    put("->count); for (size_t _kv_j")
    put_int(s)
    put(" = 0; _kv_j")
    put_int(s)
    put(" < _kv_p")
    put_int(s)
    put("->len; _kv_j")
    put_int(s)
    put("++) if (_kv_p")
    put_int(s)
    put("->at[_kv_j")
    put_int(s)
    put("].live) ")
    put_array_name(ay)
    put("_append(&_kv_e")
    put_int(s)
    put(", ")
    let owns = is_owner(ey)
    if owns {
        put_owner_prefix(ey)
        put("_copy(&")
    }
    put("_kv_p")
    put_int(s)
    put("->at[_kv_j")
    put_int(s)
    if value { put("].value") } else { put("].key") }
    if owns { put(")") }
    put("); _kv_e")
    put_int(s)
    put("; })")
}

let gen_member(n:int64) {
    let a:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let e = tagged_named(a)
    if e >= 0 {                                        // T.none: a case of no value (#215)
        put("_kv_")
        put_tok(nodes[e].t)
        put("_make_")
        put_tok(t)
        put("()")
        return
    }
    let y:int64 = type_of(a)
    if y < 0 { return }
    if tagged_of(y) >= 0 {                             // v.c, checked
        put("(*_kv_")
        put_tok(types[y].name)
        put("_at_")
        put_tok(t)
        put("(")
        gen_place(a)
        put("))")
        return
    }
    let yk:ykind = types[y].kind
    if tok_is(t, "count") && (yk == Y_STRING || yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET) {
        put("((int64_t)(")
        gen_expr(a)
        put(").count)")
    } else if yk == Y_SET && tok_is(t, "elements") {     // s.elements (#278): an Array of copies, in the order added
        gen_slots_array(a, y, types[y].elem, false)
    } else if yk == Y_DICT && (tok_is(t, "keys") || tok_is(t, "values")) {   // d.keys, d.values (#285)
        gen_slots_array(a, y, tok_is(t, "keys") ? types[y].name : types[y].elem, tok_is(t, "values"))
    } else if yk == Y_IO {
        if tok_is(t, "string") {
            put("kv_io_read_string(")
        } else if tok_is(t, "error") {
            put("kv_io_error(")
        } else {
            put("kv_io_status(")
        }
        gen_place(a)
        put(")")
    } else if yk == Y_STRING && tok_is(t, "cstr") {
        put("kv_bytes_cstr(&(")
        gen_expr(a)
        put(").b)")
    } else if tok_is(t, "uchr") {
        put("kv_uchr_of(")
        gen_expr(a)
        put(")")
    } else if tok_is(t, "utf32") {
        put("(")
        gen_expr(a)
        put(").cp")
    } else {
        put("(")
        gen_expr(a)
        put(").")
        put_tok(t)
    }
}

// a.m(...) of what an expression gives: a held for the call (#227)
let gen_method(n:int64) {
    let a:int64 = nodes[n].a
    if !needs_hold(a) {
        gen_method_of(n)
        return
    }
    hold_open(a)
    gen_method_of(n)
    hold_close(a)
}

let gen_method_of(n:int64) {
    let a:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let f:int64 = method_of(n)
    if f >= 0 {                                                       // T__m(x, ...), T__f(...) (#213)
        put_tok(nodes[f].c)
        put("__")
        put_tok(nodes[f].t)
        put("(")
        if nodes[f].flag != 1 {
            gen_expr(a)
            if nodes[n].b >= 0 { put(", ") }
        }
        gen_args_to(nodes[n].b, f)                                    // by the parameters' types (#226)
        put(")")
        return
    }
    let e = tagged_named(a)
    if e >= 0 {                                                       // T.c(v) (#215)
        put("_kv_")
        put_tok(nodes[e].t)
        put("_make_")
        put_tok(t)
        put("(")
        let v = nodes[n].b
        if v >= 0 && nodes[v].kind == N_ID && is_owner(type_of(v)) {   // a local owner moves in
            put_owner_prefix(type_of(v))
            put("_take(&")
            put_tok(nodes[v].t)
            put(")")
        } else {
            gen_args(v)
        }
        put(")")
        return
    }
    if tok_is(t, "is") && tagged_of(type_of(a)) >= 0 {               // v.is(c)
        let d = tagged_of(type_of(a))
        let m = case_named(d, nodes[nodes[n].b].t) ?? 0 - 1
        if m < 0 {
            gen_error(n, "this is no case of this enum")
            return
        }
        put("((bool)((")
        gen_expr(a)
        put(").tag == ")
        put_int(case_tag(d, m))
        put("))")
        return
    }
    if nodes[a].kind == N_TYPE && tok_is(t, "exec") {                 // IO.exec(args, mode)
        let args:int64 = nodes[n].b
        put("kv_io_exec_strings((")
        gen_expr(args)
        put(").at, (")
        gen_expr(args)
        put(").count, ")
        gen_expr(nodes[args].next)
        put(", NULL, NULL, false)")
        return
    }
    let y:int64 = type_of(a)
    if y < 0 { return }
    let yk:ykind = types[y].kind
    if is_owner(y) && yk != Y_IO && tok_is(t, "copy") {         // a String's, an Array's, a struct's... (#226)
        put_owner_prefix(y)
        put("_copy(")
        gen_place(a)
        put(")")
    } else if yk == Y_ARRAY && tok_is(t, "pop") {
        if !may_change(a) { return }                    // (#271)
        put_array_name(y)
        put("_pop(")
        gen_place(a)
        put(")")
    } else if yk == Y_SET && (tok_is(t, "union") || tok_is(t, "intersection") || tok_is(t, "difference")) {
        let other:int64 = nodes[n].b                    // s.union(&t) and the rest (#275): a new Set, of a borrow of another
        let ot:int64 = other >= 0 ? type_of(other) : 0 - 1
        if ot < 0 || types[ot].kind != Y_PTR || types[ot].elem != y || nodes[other].next >= 0 {
            var m = $"'."
            m += tok_text(t)
            m += "' takes a borrow of another "
            let w:String = type_text(y)
            m += &w
            m += ", '&other'"
            gen_error(n, m.cstr)
            return
        }
        put_set_name(y)                                   // a Set an expression gives is held as any receiver is (#227)
        put("_")
        put_tok(t)
        put("(")
        gen_place(a)
        put(", ")
        gen_expr(other)
        put(")")
    } else if yk == Y_SET && (tok_is(t, "has") || tok_is(t, "insert") || tok_is(t, "remove")) {   // s.has(x), s.insert(x), s.remove(x) (#274)
        let key:int64 = nodes[n].b
        if !tok_is(t, "has") && !may_change(a) { return }
        let hold = needs_hold(key)                        // a String an expression gives, held for the call
        if hold { hold_open(key) }
        put_set_name(y)
        put("_")
        put_tok(t)
        put("(")
        gen_place(a)
        put(", ")
        gen_key_of(types[y].elem, key)
        put(")")
        if hold { hold_close(key) }
    } else if yk == Y_DICT && (tok_is(t, "has") || tok_is(t, "get") || tok_is(t, "remove")) {   // d.has(k), d.get(k, v) (#211), d.remove(k) (#270)
        let key:int64 = nodes[n].b
        if tok_is(t, "remove") && !may_change(a) { return }   // (#271)
        let hold = needs_hold(key)                        // a String key an expression gives, held for the call (#270)
        if hold { hold_open(key) }
        put_dict_name(y)
        put("_")
        put_tok(t)
        put("(")
        gen_place(a)
        put(", ")
        gen_key(y, nodes[n].b)
        if tok_is(t, "get") {
            put(", ")
            gen_expr(nodes[nodes[n].b].next)
        }
        put(")")
        if hold { hold_close(key) }
    } else if yk == Y_IO && tok_is(t, "write") {
        put("kv_io_write_string(")
        gen_place(a)
        put(", ")
        gen_expr(nodes[n].b)
        put(")")
    } else if yk == Y_IO && tok_is(t, "close") {
        put("kv_io_close(")
        gen_place(a)
        put(")")
    } else {
        gen_error(n, "this method is not known")
    }
}

// whether n names a place, whose address is taken as it is
let is_place(n:int64):bool {
    let k:nkind = nodes[n].kind
    if k == N_INDEX && nodes[n].flag == 1 {                  // d[k] read whole is a value (#219)
        let y = type_of(nodes[n].a)
        if y >= 0 && types[y].kind == Y_DICT { return false }
    }
    if is_made_array(n) { return false }                     // s.elements, d.keys, a new Array (#278, #285)
    if k == N_FIELD || k == N_INDEX { return is_place(nodes[n].a) }   // of what an expression gives, no place (#227)
    if k == N_COND { return is_place(nodes[n].b) && is_place(nodes[n].c) }   // two places are one (#232)
    return k == N_ID || k == N_DEREF || k == N_SELF
}

// a == b of Strings; one an expression gives is held in a temporary,
// freed once compared, as kelvinc holds it (#187)
let gen_string_eq(a:int64, b:int64) {
    let ha = needs_hold(a)                           // each side an expression gives (#227)
    let hb = needs_hold(b)
    if ha { hold_open(a) }
    if hb { hold_open(b) }
    put("kv_string_eq(")
    gen_place(a)
    put(", ")
    gen_place(b)
    put(")")
    if hb { hold_close(b) }
    if ha { hold_close(a) }
}

// a condition: a comparison without the parentheses C would warn of
let gen_cond(n:int64) {
    if nodes[n].kind == N_BIN && is_comparison(nodes[n].t) {
        let y:int64 = type_of(nodes[n].a)
        if y < 0 || types[y].kind != Y_STRING {
            gen_expr(nodes[n].a)
            put(" ")
            put_tok(nodes[n].t)
            put(" ")
            gen_expr(nodes[n].b)
            return
        }
    }
    gen_expr(n)
}

// {a, b} of the struct s (#225): each member by its field's type, so that
// none and a T of a T? are what a variable of that type takes; a local
// owner is copied, x.copy(), as kelvinc has it
let gen_init(n:int64, s:int64) {
    put("{")
    var a:int64 = nodes[n].b
    var f:int64 = nodes[s].a
    while a >= 0 {
        if a != nodes[n].b { put(", ") }
        if f < 0 {
            gen_error(a, "this struct has fewer members")
            return
        }
        if nodes[a].kind == N_ID && var_type(nodes[a].t) >= 0 && is_owner(type_of(a)) {
            gen_error(a, "an owner is not copied by '=' (#54): copy it with .copy()")
            return
        }
        gen_value(a, nodes[f].ty)
        a = nodes[a].next
        f = nodes[f].next
    }
    put("}")
}

// a case's value made where an enum with values is expected (#217): none,
// ok(v), err(e) by the type that takes them, and a T where a T? goes as
// some(T), as kelvinc has them, whose some(v) is a pattern alone; a local
// owner moves in; else the expression as it is
// whether n is a value that t takes, as some(n) where a t? goes: a t; a
// number literal of any number; {a, b} of a struct; one a t of a t? takes
// (#217, #229)
let fits_value(n:int64, t:int64):bool {
    if t < 0 { return false }
    let k:nkind = nodes[n].kind
    let tk:ykind = types[t].kind
    let literal = k == N_NUM || k == N_CHAR || (k == N_UNARY && tok_is(nodes[n].t, "-") && nodes[nodes[n].a].kind == N_NUM)
    if literal && (tk == Y_I64 || tk == Y_I32 || tk == Y_U8 || tk == Y_U32 || tk == Y_F64 || tk == Y_F32) { return true }
    if k == N_INIT { return struct_of(t) >= 0 || (some_type(t) >= 0 && fits_value(n, some_type(t))) }
    if type_of(n) == t { return true }
    return some_type(t) >= 0 && fits_value(n, some_type(t))
}

// whether the elements of $[a, b] have one type, as kelvinc asks of a
// list where no type is written (#266)
let one_type(n:int64):bool {
    let y = type_of(nodes[n].b)
    var e = nodes[nodes[n].b].next
    while e >= 0 && y >= 0 {
        if type_of(e) != y {
            gen_error(n, "the elements have no one type kc sees here: write the Array's type, as name:$[T]")
            return false
        }
        e = nodes[e].next
    }
    if y < 0 { gen_error(n, "the elements have no type kc sees here: write the Array's type, as name:$[T]") }
    return y >= 0
}

// $[a, b] (#266): a new Array, each element appended as a value of the
// element type, of y where one is written, else of the elements' one
// type; an owner a variable holds is not copied, as by =
let gen_array(n:int64, given:int64) {
    var y = given
    if y < 0 {
        if !one_type(n) { return }
        y = type_of(n)
    }
    let elem:int64 = types[y].elem
    serial += 1
    let s = serial
    put("({ ")
    put_array_name(y)
    put(" _kv_l")
    put_int(s)
    put(" = {0}; ")
    var e = nodes[n].b
    while e >= 0 && !failed {
        if is_owner(elem) && is_place(e) {
            gen_error(e, "an owner is not copied by '=' (#54): copy it with .copy()")
            return
        }
        put_array_name(y)
        put("_append(&_kv_l")
        put_int(s)
        put(", ")
        if nodes[e].kind == N_INIT || nodes[e].kind == N_EMPTY {   // {a, b} of a struct, $[], ${:}: C's compound literal there
            put("(")
            put_ctype(elem)
            put(")")
        }
        gen_value(e, elem)
        put("); ")
        e = nodes[e].next
    }
    put("_kv_l")
    put_int(s)
    put("; })")
}

// a Dictionary's key type of a key of type y: a String where it is text,
// as kelvinc's: a cstr is no key (#267)
let dict_key_type(y:int64):int64 {
    if y >= 0 && types[y].kind == Y_CSTR { return base_type(Y_STRING) }
    return y
}

let type_text(y:int64):String    // a prototype: one_entry_type names the types (#267)

// whether the keys of ${k: v} have one type and the values one, as
// kelvinc asks where no type is written (#267)
let one_entry_type(n:int64):bool {
    let first:int64 = nodes[n].b
    let ky = dict_key_type(type_of(first))
    let vy = type_of(nodes[first].next)
    if ky < 0 || vy < 0 {
        gen_error(n, "the entries have no type kc sees here: write the Dictionary's type, as name:Dictionary<K, V>")
        return false
    }
    var k = nodes[nodes[first].next].next
    while k >= 0 {
        let v:int64 = nodes[k].next
        let kk = dict_key_type(type_of(k))
        if kk != ky {
            var s = $"every key of a Dictionary has one type: this one is "
            s += kk >= 0 ? type_text(kk) : $"unseen"
            s += ", the first "
            s += type_text(ky)
            gen_error(k, s.cstr)
            return false
        }
        if type_of(v) != vy && nodes[v].kind != N_EMPTY {   // ${:} or $[] takes the first's type (#268)
            var s = $"every value of a Dictionary has one type: this one is "
            s += type_of(v) >= 0 ? type_text(type_of(v)) : $"unseen"
            s += ", the first "
            s += type_text(vy)
            gen_error(v, s.cstr)
            return false
        }
        k = nodes[v].next
    }
    return true
}

// ${k: v} (#267): a new Dictionary, each entry set in order, a later key's
// value winning, of y where one is written, else of the first entry's
// types; a String key an expression gives is held while it is copied in,
// and a value that owns, held by a variable, is not copied
let gen_dict(n:int64, given:int64) {
    var y = given
    if y < 0 {
        if !one_entry_type(n) { return }
        y = type_of(n)
    }
    let elem:int64 = types[y].elem
    serial += 1
    let s = serial
    put("({ ")
    put_dict_name(y)
    put(" _kv_m")
    put_int(s)
    put(" = {0}; ")
    var k = nodes[n].b
    while k >= 0 && !failed {
        let v:int64 = nodes[k].next
        if is_owner(elem) && is_place(v) {
            gen_error(v, "an owner is not copied by '=' (#54): copy it with .copy()")
            return
        }
        let hold = needs_hold(k)
        if hold { hold_open(k) }
        put_dict_name(y)
        put("_set(&_kv_m")
        put_int(s)
        put(", ")
        gen_key(y, k)
        put(", ")
        if nodes[v].kind == N_INIT || nodes[v].kind == N_EMPTY {   // {a, b} of a struct, ${:}, $[]: C's compound literal there
            put("(")
            put_ctype(elem)
            put(")")
        }
        gen_value(v, elem)
        put(")")
        if hold { hold_close(k) }
        put("; ")
        k = nodes[v].next
    }
    put("_kv_m")
    put_int(s)
    put("; })")
}

// ${a, b} (#274): a new Set, each element inserted in order, of y where
// one is written, else of the elements' one type, text a String's; a
// String an expression gives is held while it is copied in
let gen_set(n:int64, first:int64, given:int64) {
    var y = given
    if y < 0 {
        let e0:int64 = dict_key_type(type_of(first))
        var e = nodes[first].next
        while e >= 0 {
            if dict_key_type(type_of(e)) != e0 {
                gen_error(n, "the elements have no one type kc sees here: write the Set's type, as name:Set<T>")
                return
            }
            e = nodes[e].next
        }
        y = type_of(n)
        if y < 0 { return }
    }
    serial += 1
    let s = serial
    put("({ ")
    put_set_name(y)
    put(" _kv_s")
    put_int(s)
    put(" = {0}; ")
    var e = first
    while e >= 0 && !failed {
        let hold = needs_hold(e)
        if hold { hold_open(e) }
        put_set_name(y)
        put("_insert(&_kv_s")
        put_int(s)
        put(", ")
        gen_key_of(types[y].elem, e)
        put(")")
        if hold { hold_close(e) }
        put("; ")
        e = nodes[e].next
    }
    put("_kv_s")
    put_int(s)
    put("; })")
}

// s | t, s & t, s ~ t (#276): a new Set, the union, the intersection or
// what is in one alone, of two Sets of the same elements in variables,
// as kelvinc's
let gen_set_op(n:int64, y:int64) {
    let a:int64 = nodes[n].a
    let b:int64 = nodes[n].b
    let t:int64 = nodes[n].t
    if type_of(b) != y || !is_place(a) || !is_place(b) {
        var m = $"'"
        m += tok_text(t)
        m += "' takes two Sets of the same elements, both in variables"
        gen_error(n, m.cstr)
        return
    }
    put_set_name(y)
    put(tok_is(t, "|") ? "_union(" : tok_is(t, "&") ? "_intersection(" : "_symdiff(")
    gen_place(a)
    put(", ")
    gen_place(b)
    put(")")
}

let gen_value(n:int64, y:int64) {
    if nodes[n].kind == N_ARRAY && y >= 0 && types[y].kind == Y_ARRAY {   // $[a, b] of the type written (#266)
        gen_array(n, y)
        return
    }
    if nodes[n].kind == N_DICT && y >= 0 && types[y].kind == Y_DICT {     // ${k: v} of the type written (#267)
        gen_dict(n, y)
        return
    }
    if (nodes[n].kind == N_SET || nodes[n].kind == N_INIT) && y >= 0 && types[y].kind == Y_SET {   // ${a, b}, {a, b} (#274)
        gen_set(n, nodes[n].b, y)
        return
    }
    if nodes[n].kind == N_STR && y >= 0 && types[y].kind == Y_STRING {   // a String of text where one goes (#234)
        put("KV_STRING_OF(")
        gen_expr(n)
        put(")")
        return
    }
    if nodes[n].kind == N_COND {                         // each arm by the type that takes it (#232)
        if !owner_choice(n) { return }
        if is_owner(type_of(n)) && is_place(n) {
            gen_error(n, "an owner is not copied by '=' (#54): copy it with .copy()")
            return
        }
        put("(")
        gen_expr(nodes[n].a)
        put(" ? ")
        gen_value(nodes[n].b, y)
        put(" : ")
        gen_value(nodes[n].c, y)
        put(")")
        return
    }
    if nodes[n].kind == N_INIT && y >= 0 && types[y].kind == Y_STRUCT && decl_named(types[y].name, D_STRUCT) >= 0 {
        gen_init(n, decl_named(types[y].name, D_STRUCT))       // {a, b} of a struct (#225)
        return
    }
    let d = tagged_of(y)
    if d < 0 && y >= 0 && !failed && some_type(type_of(n)) >= 0 {     // as kelvinc says it (#219)
        gen_error(n, "this is an Optional where a value goes: unwrap it with '!', or give a default with '??'")
        return
    }
    if d < 0 || failed {
        gen_expr(n)
        return
    }
    var m = case_word_of(n, d)
    if m >= 0 && nodes[d].c == 1 && nodes[n].kind == N_CALL {
        gen_error(n, "some(v) makes no Optional: give v where the T? is expected")
        return
    }
    var v = -1
    if m >= 0 && nodes[n].kind == N_CALL { v = nodes[n].b }
    if m < 0 && nodes[d].c == 1 && fits_value(n, some_type(y)) {
        m = nodes[nodes[d].a].next
        v = n
    }
    if m < 0 {
        gen_expr(n)
        return
    }
    put("_kv_")
    put_tok(nodes[d].t)
    put("_make_")
    put_tok(nodes[m].t)
    put("(")
    if v >= 0 && nodes[v].kind == N_ID && is_owner(type_of(v)) {
        put_owner_prefix(type_of(v))
        put("_take(&")
        put_tok(nodes[v].t)
        put(")")
    } else if v >= 0 && nodes[m].ty >= 0 {             // what the case holds, by its type: a T?? of a T (#229)
        if nodes[v].kind == N_INIT && struct_of(nodes[m].ty) >= 0 {
            put("(struct ")
            put_tok(types[nodes[m].ty].name)
            put(")")
        }
        gen_value(v, nodes[m].ty)
    } else if v >= 0 {
        gen_expr(v)
    }
    put(")")
}

// x ?? d: what the Optional x holds, else d, x read once (#217)
let gen_coalesce(n:int64) {
    let y = type_of(nodes[n].a)
    let inner = some_type(y)
    if inner < 0 {
        gen_error(n, "?? takes an Optional on its left")
        return
    }
    if is_owner(inner) {
        gen_error(n, "?? of an Optional that owns: read it with if let, which kc frees")
        return
    }
    serial += 1
    let s = serial                                   // its own: x may make names too (#221)
    put("({ ")
    put_ctype(y)
    put(" _kv_o")
    put_int(s)
    put(" = ")
    gen_expr(nodes[n].a)
    put("; _kv_o")
    put_int(s)
    put(".tag == 1 ? _kv_o")
    put_int(s)
    put(".u.some : (")
    gen_value(nodes[n].b, inner)
    put("); })")
}

// d[k] read whole (#219): some of a copy of the entry's value, or none
// where the key is missing, as kelvinc's dict_lookup
let gen_lookup(n:int64, y:int64) {
    let value:int64 = types[y].elem
    let opt:int64 = optional_of(value)
    put("({ __auto_type _kv_p = ")
    put_dict_name(y)
    put("_find(")
    gen_place(nodes[n].a)
    put(", ")
    gen_key(y, nodes[n].b)
    put("); _kv_p ? _kv_")
    put_tok(types[opt].name)
    put("_make_some(")
    if is_owner(value) {
        put_owner_prefix(value)
        put("_copy(_kv_p)")
    } else {
        put("*_kv_p")
    }
    put(") : _kv_")
    put_tok(types[opt].name)
    put("_make_none(); })")
}

// x?.rest (#221): the rest of the chain of what x holds, bound by name
// and borrowed, in some, an owner the rest reads copied out; none where x
// is none. x is read once, and freed where an expression gave it
let gen_chain(n:int64) {
    let res = type_of(n)
    if res < 0 || failed { return }
    let y = type_of(nodes[n].a)
    let body = nodes[n].b
    serial += 1
    let s = serial
    put("({ ")
    put_ctype(res)
    put(" _kv_r")
    put_int(s)
    put("; ")
    if is_owner(y) && !is_place(nodes[n].a) {
        put("__attribute__((cleanup(")
        put_free(y)
        put("))) ")
    }
    put_ctype(y)
    put(" _kv_s")
    put_int(s)
    put(" = ")
    gen_expr(nodes[n].a)
    put("; if (_kv_s")
    put_int(s)
    put(".tag == 1) { ")
    open_scope()
    declare_as(nodes[n].c, some_type(y), 3)                // if let's, as each element (#271)
    put_ctype(some_type(y))
    put(" ")
    put_tok(nodes[n].c)
    put(" = _kv_s")
    put_int(s)
    put(".u.some; _kv_r")
    put_int(s)
    put(" = ")
    let by = type_of(body)
    if by != res {
        put("_kv_")
        put_tok(types[res].name)
        put("_make_some(")
    }
    if is_owner(by) && is_place(body) {
        put_owner_prefix(by)
        put("_copy(&(")
        gen_expr(body)
        put("))")
    } else {
        gen_expr(body)
    }
    if by != res { put(")") }
    close_scope()
    put("; } else _kv_r")
    put_int(s)
    put(" = _kv_")
    put_tok(types[res].name)
    put("_make_none(); _kv_r")
    put_int(s)
    put("; })")
}

// a[i]: an Array's element, checked; a Dictionary's entry, or its Optional
// read whole (#219); C's element
let gen_element(n:int64) {
    let y:int64 = type_of(nodes[n].a)
    if y >= 0 && types[y].kind == Y_ARRAY {
        put("(*")
        put_array_name(y)
        put("_at(")
        gen_place(nodes[n].a)
        put(", ")
        gen_expr(nodes[n].b)
        put("))")
    } else if y >= 0 && types[y].kind == Y_DICT && nodes[n].flag == 1 {
        gen_lookup(n, y)
    } else if y >= 0 && types[y].kind == Y_DICT {   // d[k], checked (#211)
        put("(*")
        put_dict_name(y)
        put("_at(")
        gen_place(nodes[n].a)
        put(", ")
        gen_key(y, nodes[n].b)
        put("))")
    } else {
        gen_expr(nodes[n].a)
        put("[")
        gen_expr(nodes[n].b)
        put("]")
    }
}

// whether c ? a : b of owners chooses between alike, as kelvinc's O12
// has it (#232): two places, or two values expressions give; one of each
// would free one and not the other
let owner_choice(n:int64):bool {
    if !is_owner(type_of(n)) || is_place(nodes[n].b) == is_place(nodes[n].c) { return true }
    gen_error(n, "this ?: chooses between an owner's place and a value an expression gives, so one would be freed and the other not: return it, copy the place with .copy(), or choose with if")
    return false
}

// c ? a : b read (#232): two places are read where they are, as a place
let gen_choice(n:int64) {
    if !owner_choice(n) { return }
    put("(")
    gen_expr(nodes[n].a)
    put(" ? ")
    gen_expr(nodes[n].b)
    put(" : ")
    gen_expr(nodes[n].c)
    put(")")
}

// what return moves out of c ? a : b (#232): a local owner by _take,
// another choice by its own arms, a value an expression gives as it is
let gen_moved(n:int64, y:int64) {
    if nodes[n].kind == N_COND {
        put("(")
        gen_expr(nodes[n].a)
        put(" ? ")
        gen_moved(nodes[n].b, y)
        put(" : ")
        gen_moved(nodes[n].c, y)
        put(")")
    } else if nodes[n].kind == N_ID && !is_case_word(n) && is_owner(type_of(n)) {
        put_owner_prefix(type_of(n))
        put("_take(&")
        put_tok(nodes[n].t)
        put(")")
    } else if is_place(n) && is_owner(type_of(n)) {
        gen_error(n, "return moves an owner only out of a whole variable: copy this with .copy()")
    } else {
        gen_value(n, y)
    }
}

// a[i] of what an expression gives (#227): a held, an element that owns
// copied out of it; a Dictionary's lookup is a copy already (#219)
let gen_index(n:int64) {
    let a:int64 = nodes[n].a
    let y = type_of(n)
    let lookup = nodes[n].flag == 1 && types[type_of(a)].kind == Y_DICT
    hold_open(a)
    if is_owner(y) && !lookup {
        put_owner_prefix(y)
        put("_copy(&(")
        gen_element(n)
        put("))")
    } else {
        gen_element(n)
    }
    hold_close(a)
}

let gen_expr(n:int64) {
    if failed { return }
    if held.get(n, 0 - 1) >= 0 {                         // held in a temporary (#227)
        put("_kv_tmp")
        put_int(held.get(n, 0 - 1))
        return
    }
    let k:nkind = nodes[n].kind
    let t:int64 = nodes[n].t
    if float_word(n) {                                   // nan, inf: gcc's and clang's constants (#262)
        put(word_no_case(t, "nan") ? "__builtin_nan(\"\")" : "__builtin_inf()")
    } else if k == N_ID && var_type(t) < 0 && !c_headers {
        gen_error(n, "this name is not known")
    } else if k == N_NULL {
        put("NULL")
    } else if k == N_SELF {
        put("self")
    } else if k == N_NUM || k == N_CHAR || k == N_ID {
        put_tok(t)
    } else if k == N_STR {
        put_text(t, 0)
    } else if k == N_DSTR {
        put("KV_STRING_OF(")
        put_text(t, 1)
        put(")")
    } else if k == N_BOOL {
        put("((bool)")                           // C's true is an int, which String(...) would write as 1 (#212)
        put_tok(t)
        put(")")
    } else if k == N_CALL {
        gen_call(n)
    } else if k == N_CHAIN {
        gen_chain(n)
    } else if k == N_COND {
        gen_choice(n)
    } else if k == N_FIELD {
        gen_field(n)
    } else if k == N_METHOD {
        gen_method(n)
    } else if k == N_INDEX && needs_hold(nodes[n].a) {
        gen_index(n)                                 // of what an expression gives (#227)
    } else if k == N_INDEX {
        gen_element(n)
    } else if k == N_UNARY {
        if tok_is(t, "!") { put("(bool)") }          // C's ! gives an int, which prints as 1
        put("(")
        put_tok(t)
        gen_expr(nodes[n].a)
        put(")")
    } else if k == N_BIN && tok_is(t, "??") {
        gen_coalesce(n)
    } else if k == N_BIN && is_string_plus(n) {
        gen_string_plus(n)                               // s + t (#284)
    } else if k == N_BIN {
        let y:int64 = type_of(nodes[n].a)
        reject_cstr_math(n)                              // "a" + "b", "a" + 1, x - y (#283)
        reject_container_math(n)                         // xs + 2, d < d2, s - t (#287)
        if y >= 0 && types[y].kind == Y_SET && (tok_is(t, "|") || tok_is(t, "&") || tok_is(t, "~")) {
            gen_set_op(n, y)                             // s | t, s & t, s ~ t (#276)
        } else if y >= 0 && types[y].kind == Y_STRING && (tok_is(t, "==") || tok_is(t, "!=")) {
            if tok_is(t, "!=") { put("(bool)!") }
            gen_string_eq(nodes[n].a, nodes[n].b)
        } else {
            if is_comparison(t) { put("(bool)") }    // C's comparisons give an int
            put("(")
            gen_expr(nodes[n].a)
            put(" ")
            if tok_is(t, "~") { put("^") } else { put_tok(t) }   // Kelvin's XOR is ~ (#276)
            put(" ")
            gen_expr(nodes[n].b)
            put(")")
        }
    } else if k == N_CAST {
        put("((")
        put_ctype(nodes[n].ty)
        put(")(")
        gen_expr(nodes[n].a)
        put("))")
    } else if k == N_ADDR {
        gen_place(nodes[n].a)
    } else if k == N_DEREF {
        put("(*")
        gen_expr(nodes[n].a)
        put(")")
    } else if k == N_INIT {
        put("{")
        gen_args(nodes[n].b)
        put("}")
    } else if k == N_EMPTY {
        put("{0}")
    } else if k == N_ARRAY {
        gen_array(n, -1)
    } else if k == N_DICT {
        gen_dict(n, -1)
    } else if k == N_SET {
        gen_set(n, nodes[n].b, -1)
    } else {
        gen_error(n, "this expression is not known")
    }
}

// ---------- statements ----------

let gen_block(n:int64, depth:int64)
let gen_stmt(n:int64, depth:int64)

let indent(depth:int64) {
    for i in 0..<depth { put("    ") }
}

// a variable, its type, its name, and its value or nothing
// the type of a variable written without one, from its value, as kelvinc
// infers it (#214): a literal, a bool, a comparison, a cast, and what kc
// sees of a name, a call, a member or an element; not arithmetic, nor
// what only C sees; "text" by := is a cstr
let inferred(n:int64):int64 {
    let v:int64 = nodes[n].a
    if v < 0 {
        gen_error(n, "a variable without a type has a value to infer it from: write name:T")
        return -1
    }
    let k:nkind = nodes[v].kind
    if k == N_STR {
        if nodes[n].c != 1 { gen_error(n, "text is a reference, a cstr: assign it with :=, not =") }
        return base_type(Y_CSTR)
    }
    if k == N_CHAR { return base_type(Y_U8) }
    if k == N_UNARY && tok_is(nodes[v].t, "-") && nodes[nodes[v].a].kind == N_NUM { return type_of(nodes[v].a) }   // -1, -1.5 (#262)
    if k == N_ARRAY && !one_type(v) { return -1 }                     // $[a, b] (#266)
    if k == N_DICT && !one_entry_type(v) { return -1 }                // ${k: v} (#267)
    let set_op = k == N_BIN && type_of(nodes[v].a) >= 0 && types[type_of(nodes[v].a)].kind == Y_SET   // s | t, a Set, as kelvinc infers it (#276)
    if k == N_BIN && !is_comparison(nodes[v].t) && !tok_is(nodes[v].t, "??") && !set_op && !is_string_plus(v) {   // x ?? d is x's T (#217); s + t a String (#284)
        gen_error(n, "this variable needs a type: write name:T, since a type is not inferred from arithmetic")
        return -1
    }
    if k == N_EMPTY || k == N_INIT || k == N_NULL {
        gen_error(n, "this variable needs a type: write name:T, since this value has none of its own")
        return -1
    }
    let y:int64 = type_of(v)
    if y < 0 || types[y].kind == Y_C || types[y].kind == Y_VOID {
        gen_error(n, "this variable needs a type: write name:T, since kc does not see this value's")
        return -1
    }
    return y
}

// a type as Kelvin spells it, for a message (#233): i64, cstr, i64^,
// $[String], i64?, Result<i64, String>
let type_text(y:int64):String {
    switch types[y].kind {
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
    case Y_ARGV: return $"[cstr]"
    case Y_ARRAY:
        var s = $"$["
        s += type_text(types[y].elem)
        s += "]"
        return s
    case Y_PTR:
        var s = types[y].name == 1 ? $"const " : $""     // (#272)
        let e = type_text(types[y].elem)
        s += &e
        s += "^"
        return s
    case Y_DICT:
        var s = $"Dictionary<"
        s += type_text(types[y].name)
        s += ", "
        s += type_text(types[y].elem)
        s += ">"
        return s
    case Y_SET:
        var s = $"Set<"
        s += type_text(types[y].elem)
        s += ">"
        return s
    case Y_STRUCT:
        let d = tagged_of(y)
        if d >= 0 && nodes[d].c == 1 {
            var s = type_text(some_type(y))
            s += "?"
            return s
        }
        if d >= 0 && types[y].name > eof_pos {           // made by kc, as no Optional: Result<T, E>
            let m = nodes[d].a
            var s = $"Result<"
            s += type_text(nodes[m].ty)
            s += ", "
            s += type_text(nodes[nodes[m].next].ty)
            s += ">"
            return s
        }
        return tok_text(types[y].name)
    default: return $"a type only C sees"
    }
}

// whether = or := suits y, as kelvinc has it (#233): a reference, a cstr or
// a T^, takes :=, and a value =; else an error that names t, the name
// assigned, and what it is
let assigns_as(n:int64, t:int64, y:int64, colon:bool):bool {
    let k:ykind = y >= 0 ? types[y].kind : Y_C
    if k == Y_C || k == Y_ARRAY || k == Y_DICT { return true }   // what only C sees; an Array and a Dictionary, as kelvinc
    let reference = types[y].kind == Y_CSTR || types[y].kind == Y_PTR
    if reference == colon { return true }
    var what = $"'"
    what += tok_text(t)
    what += reference ? "' is a reference (" : "' is a value ("
    what += type_text(y)
    what += reference ? "): assign it with ':=', not '='" : "): assign it with '=', not ':='"
    gen_error(n, what.cstr)
    return false
}

let gen_var(n:int64) {
    if nodes[n].ty < 0 { set_ty(n, inferred(n)) }
    if failed { return }
    let y:int64 = nodes[n].ty
    if nodes[n].a >= 0 && !assigns_as(n, nodes[n].t, y, nodes[n].c == 1) { return }
    var who = $"'"                                       // a let's borrow, as an argument's (#273)
    who += tok_text(nodes[n].t)
    who += "'"
    if nodes[n].a >= 0 && !takes_borrow(nodes[n].a, y, &who) { return }
    if is_owner(y) {
        put("__attribute__((cleanup(")
        put_free(y)
        put("))) ")
    }
    put_ctype(y)
    put(" ")
    put_tok(nodes[n].t)
    put(" = ")
    if nodes[n].a < 0 {
        if is_owner(y) || types[y].kind == Y_STRUCT {
            put("{0}")
        } else {
            put("0")
        }
    } else {
        gen_value(nodes[n].a, y)                         // (#217)
    }
    put(";\n")
}

// whether n reads an element of an Array, whose place a call may move
let has_element(n:int64):bool {
    if n < 0 { return false }
    let k:nkind = nodes[n].kind
    if k == N_INDEX {
        let y:int64 = type_of(nodes[n].a)
        if y >= 0 && (types[y].kind == Y_ARRAY || types[y].kind == Y_DICT) { return true }
    }
    if k == N_FIELD || k == N_INDEX || k == N_DEREF { return has_element(nodes[n].a) }
    return false
}

// whether n calls a function, which may grow an Array
let has_call(n:int64):bool {
    if n < 0 { return false }
    let k:nkind = nodes[n].kind
    if k == N_CALL || k == N_METHOD { return true }
    if k == N_INIT {
        var a:int64 = nodes[n].b
        while a >= 0 {
            if has_call(a) { return true }
            a = nodes[a].next
        }
        return false
    }
    if k == N_COND && has_call(nodes[n].c) { return true }
    return has_call(nodes[n].a) || has_call(nodes[n].b)
}

// an assignment's operator in C: := of a reference is C's = (#233)
let put_op(t:int64) {
    if tok_is(t, ":=") {
        put("=")
    } else if tok_is(t, "~=") {                     // Kelvin's XOR is ~, C's ^ (#276)
        put("^=")
    } else {
        put_tok(t)
    }
}

// the variable a change of place n changes: n's name, a member's or an
// element's variable, not what a pointer points to; -1 where none
let changed_root(n:int64):int64 {
    let k:nkind = nodes[n].kind
    if k == N_ID { return n }
    if k == N_FIELD || k == N_INDEX { return changed_root(nodes[n].a) }
    return 0 - 1
}

// a change of place n where its variable is a let is an error, in
// kelvinc's words (#271); whether n may change
let may_change(n:int64):bool {
    var d = n                                           // p^ of a const T^, which a let's borrow is (#272)
    while nodes[d].kind == N_FIELD || nodes[d].kind == N_INDEX { d = nodes[d].a }
    if nodes[d].kind == N_DEREF {
        let p:int64 = type_of(nodes[d].a)
        if p >= 0 && types[p].kind == Y_PTR && types[p].name == 1 {
            var s = $"this changes what a "
            s += type_text(p)
            s += " points to, a read-only borrow, as a let's is: borrow a var, or take it without const"
            gen_error(n, s.cstr)
            return false
        }
        return true
    }
    let r = changed_root(n)
    if r < 0 { return true }
    let how = how_declared(nodes[r].t)
    if how == 0 { return true }
    var s = $"'"
    s += tok_text(nodes[r].t)
    if how == 2 {
        s += "' is a let parameter and cannot change; write 'var "
        s += tok_text(nodes[r].t)
        s += "' in the parameter list"
    } else if how == 3 {
        s += "' is each element in turn and cannot change; copy it into a var under another name"
    } else if how == 4 {
        s += "' counts the range and cannot change; copy it under another name, as in 'var k:i64 = "
        s += tok_text(nodes[r].t)
        s += "'"
    } else {
        s += "' is a let and cannot change; declare it with var"
    }
    gen_error(n, s.cstr)
    return false
}

let gen_assign(n:int64) {
    let lhs:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    if !may_change(lhs) { return }                      // (#271)
    let y:int64 = type_of(lhs)
    if y < 0 { return }
    if nodes[lhs].kind == N_ID {                         // q := &x of a let (#273)
        var who = $"'"
        who += tok_text(nodes[lhs].t)
        who += "'"
        if !takes_borrow(nodes[n].b, y, &who) { return }
    }
    let named = nodes[lhs].kind == N_ID || nodes[lhs].kind == N_FIELD
    if named && (tok_is(t, "=") || tok_is(t, ":=")) && !assigns_as(n, nodes[lhs].t, y, tok_is(t, ":=")) { return }
    let yk:ykind = types[y].kind
    if nodes[lhs].kind == N_FIELD && tok_is(t, "=") && tagged_of(type_of(nodes[lhs].a)) >= 0 {
        put("_kv_")                                     // v.c = x sets the case, freeing what it held (#215)
        put_tok(types[type_of(nodes[lhs].a)].name)
        put("_set_")
        put_tok(nodes[lhs].t)
        put("(")
        gen_place(nodes[lhs].a)
        put(", ")
        gen_expr(nodes[n].b)
        put(");\n")
        return
    }
    var into:int64 = -1                                  // what lhs indexes
    if nodes[lhs].kind == N_INDEX { into = type_of(nodes[lhs].a) }
    if into >= 0 && types[into].kind == Y_DICT && tok_is(t, "=") {
        put_dict_name(into)                              // d[k] = v sets the entry (#211)
        put("_set(")
        gen_place(nodes[lhs].a)
        put(", ")
        gen_key(into, nodes[lhs].b)
        put(", ")
        gen_expr(nodes[n].b)
        put(");\n")
    } else if yk == Y_STRING && tok_is(t, "=") {
        put("kv_string_assign(")
        gen_place(lhs)
        put(", ")
        gen_expr(nodes[n].b)
        put(");\n")
    } else if yk == Y_STRING && tok_is(t, "+=") {
        put("KV_STRING_APPEND(")
        gen_place(lhs)
        put(", ")
        gen_expr(nodes[n].b)
        put(");\n")
    } else if yk == Y_SET && (tok_is(t, "|=") || tok_is(t, "&=") || tok_is(t, "~=")) {   // s |= t and the rest, in place (#276)
        let v:int64 = nodes[n].b
        if type_of(v) != y || !is_place(v) {
            var m = $"'"
            m += tok_text(t)
            m += "' takes another "
            let w:String = type_text(y)
            m += &w
            m += ", in a variable"
            gen_error(n, m.cstr)
            return
        }
        put_set_name(y)
        put(tok_is(t, "|=") ? "_insert_all(" : tok_is(t, "&=") ? "_intersect_with(" : "_symdiff_with(")
        gen_place(lhs)
        put(", ")
        gen_place(v)
        put(");\n")
    } else if yk == Y_SET && tok_is(t, "+=") {           // s += x inserts x, s += &t t's elements (#274)
        let v:int64 = nodes[n].b
        let vy = type_of(v)
        if vy >= 0 && types[vy].kind == Y_PTR && types[vy].elem == y {
            put_set_name(y)
            put("_insert_all(")
            gen_place(lhs)
            put(", ")
            gen_expr(v)
            put(");\n")
        } else {
            let hold = needs_hold(v)
            if hold { hold_open(v) }
            put_set_name(y)
            put("_insert(")
            gen_place(lhs)
            put(", ")
            gen_key_of(types[y].elem, v)
            put(")")
            if hold { hold_close(v) }
            put(";\n")
        }
    } else if yk == Y_ARRAY && tok_is(t, "+=") {
        put_array_name(y)
        put("_append(")
        gen_place(lhs)
        put(", ")
        gen_expr(nodes[n].b)
        put(");\n")
    } else if is_owner(y) && yk == Y_STRUCT && tok_is(t, "=") {
        serial += 1                                      // the new value first, then the old one freed (#217, #225)
        put("{ ")
        put_ctype(y)
        put(" _kv_v")
        put_int(serial)
        put(" = ")
        gen_value(nodes[n].b, y)
        put("; ")
        put_free(y)
        put("(")
        gen_place(lhs)
        put("); ")
        gen_expr(lhs)
        put(" = _kv_v")
        put_int(serial)
        put("; }\n")
    } else if is_owner(y) {
        gen_error(n, "an owner is assigned only as a String")
    } else if has_element(lhs) && has_call(nodes[n].b) {
        serial += 1                                   // the value first, then where it goes
        put("{ ")
        put_ctype(y)
        put(" _kv_v")
        put_int(serial)
        put(" = ")
        gen_value(nodes[n].b, y)
        put("; ")
        gen_expr(lhs)
        put(" ")
        put_op(t)
        put(" _kv_v")
        put_int(serial)
        put("; }\n")
    } else {
        gen_expr(lhs)
        put(" ")
        put_op(t)
        put(" ")
        gen_value(nodes[n].b, y)                       // (#217)
        put(";\n")
    }
}

let gen_return(n:int64) {
    let a:int64 = nodes[n].a
    if a < 0 {
        put("return;\n")
        return
    }
    if nodes[a].kind == N_COND && is_owner(type_of(a)) {     // return c ? a : b moves either out (#232)
        put("return ")
        gen_moved(a, nodes[current].ty)
        put(";\n")
        return
    }
    if nodes[a].kind == N_ID && !is_case_word(a) {          // not none, which gen_value reads (#221)
        let y:int64 = type_of(a)
        if is_owner(y) && y == nodes[current].ty {           // a local owner moves out
            put("return ")
            put_owner_prefix(y)
            put("_take(&")
            put_tok(nodes[a].t)
            put(");\n")
            return
        }
    }
    put("return ")
    if nodes[a].kind == N_INIT {                         // return {a, b}: of the function's type (#213)
        put("(")
        put_ctype(nodes[current].ty)
        put(")")
    }
    gen_value(a, nodes[current].ty)                      // none, some(v), ok(v), err(e) (#217)
    put(";\n")
}

// for c in s { }: each codepoint of a String, or each element of an Array
let gen_each(n:int64, depth:int64) {
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return }
    if nodes[n].b >= 0 && types[y].kind != Y_DICT {    // as kelvinc says it (#269)
        var s = $"two loop variables walk a Dictionary's entries, 'for k, v in d', and this is "
        s += type_text(y)
        gen_error(n, s.cstr)
        return
    }
    serial += 1
    put("{\n")
    indent(depth + 1)
    let src = nodes[n].a
    if needs_hold(src) {                              // for x in f(): f()'s owner held for the loop (#227)
        let h = serial
        put("__attribute__((cleanup(")
        put_free(y)
        put("))) ")
        put_ctype(y)
        put(" _kv_tmp")
        put_int(h)
        put(" = ")
        gen_expr(src)
        put(";\n")
        indent(depth + 1)
        held[src] = h
    }
    let keyed = types[y].kind == Y_SET ? types[y].elem : types[y].name    // a Set's element, as a Dictionary's key (#274)
    if types[y].kind == Y_DICT || types[y].kind == Y_SET {   // for k, v in d, for k in d (#269), for x in s (#274): each live entry in the order added
        put("for (size_t _kv_i")
        put_int(serial)
        put(" = 0; _kv_i")
        put_int(serial)
        put(" < (")
        gen_expr(nodes[n].a)
        put(").len; _kv_i")
        put_int(serial)
        put("++)\n")
        indent(depth + 1)
        put("{\n")
        indent(depth + 2)
        put("if (!(")
        gen_expr(nodes[n].a)
        put(").at[_kv_i")
        put_int(serial)
        put("].live) continue;\n")
        indent(depth + 2)
        put_ctype(keyed)                              // the key and the value, lets the Dictionary owns
        put(" ")
        put_tok(nodes[n].t)
        put(" = (")
        gen_expr(nodes[n].a)
        put(").at[_kv_i")
        put_int(serial)
        put("].key;\n")
        open_scope()
        declare_as(nodes[n].t, keyed, 3)                  // (#271)
        if nodes[n].b >= 0 {
            indent(depth + 2)
            put_ctype(types[y].elem)
            put(" ")
            put_tok(nodes[nodes[n].b].t)
            put(" = (")
            gen_expr(nodes[n].a)
            put(").at[_kv_i")
            put_int(serial)
            put("].value;\n")
            declare_as(nodes[nodes[n].b].t, types[y].elem, 3)
        }
    } else if types[y].kind == Y_STRING {
        put("const uint8_t *_kv_p")
        put_int(serial)
        put(" = (")
        gen_expr(nodes[n].a)
        put(").b.at;\n")
        indent(depth + 1)
        put("const uint8_t *const _kv_e")
        put_int(serial)
        put(" = _kv_p")
        put_int(serial)
        put(" + (")
        gen_expr(nodes[n].a)
        put(").b.count;\n")
        indent(depth + 1)
        put("while (_kv_p")
        put_int(serial)
        put(" < _kv_e")
        put_int(serial)
        put(")\n")
        indent(depth + 1)
        put("{\n")
        indent(depth + 2)
        put("const kv_uchr ")
        put_tok(nodes[n].t)
        put(" = (kv_uchr){kv_utf8_next(&_kv_p")
        put_int(serial)
        put(")};\n")
        open_scope()
        declare_as(nodes[n].t, base_type(Y_UCHR), 3)      // (#271)
    } else {
        put("for (size_t _kv_i")
        put_int(serial)
        put(" = 0; _kv_i")
        put_int(serial)
        put(" < (")
        gen_expr(nodes[n].a)
        put(").count; _kv_i")
        put_int(serial)
        put("++)\n")
        indent(depth + 1)
        put("{\n")
        indent(depth + 2)
        put_ctype(types[y].elem)
        put(" ")
        put_tok(nodes[n].t)
        put(" = (")
        gen_expr(nodes[n].a)
        put(").at[_kv_i")
        put_int(serial)
        put("];\n")
        open_scope()
        declare_as(nodes[n].t, types[y].elem, 3)          // (#271)
    }
    indent(depth + 2)
    gen_block(nodes[n].c, depth + 2)
    close_scope()
    indent(depth + 1)
    put("}\n")
    indent(depth)
    put("}\n")
    held[src] = 0 - 1
}

// if let c(x) = e { } else { } (#217): e read once, by its address where it
// is a place, else held, and freed, where it owns; x is the case's value,
// which e still owns
let gen_iflet(n:int64, depth:int64) {
    let e = nodes[n].a
    let y = type_of(e)
    let d = tagged_of(y)
    if d < 0 {
        gen_error(n, "if let takes an enum with values, an Optional or a Result")
        return
    }
    let m = case_named(d, nodes[n].t) ?? 0 - 1
    if m < 0 || nodes[m].ty < 0 {
        gen_error(n, "this is no case of a value of this enum")
        return
    }
    serial += 1
    let s = serial
    put("{\n")
    indent(depth + 1)
    if !is_place(e) {
        if is_owner(y) {
            put("__attribute__((cleanup(")
            put_free(y)
            put("))) ")
        }
        put_ctype(y)
        put(" _kv_held")
        put_int(s)
        put(" = ")
        gen_expr(e)
        put(";\n")
        indent(depth + 1)
    }
    put_ctype(y)
    put(" *_kv_l")
    put_int(s)
    put(" = ")
    if is_place(e) {
        gen_place(e)
    } else {
        put("&_kv_held")
        put_int(s)
    }
    put(";\n")
    indent(depth + 1)
    put("if (_kv_l")
    put_int(s)
    put("->tag == ")
    put_int(case_tag(d, m))
    put(")\n")
    indent(depth + 1)
    put("{\n")
    open_scope()
    indent(depth + 2)
    put_ctype(nodes[m].ty)
    put(" ")
    put_tok(nodes[n].flag)
    put(" = _kv_l")
    put_int(s)
    put("->u.")
    put_tok(nodes[m].t)
    put(";\n")
    declare_as(nodes[n].flag, nodes[m].ty, 3)              // a case's value (#271)
    var st = nodes[nodes[n].b].a
    while st >= 0 && !failed {
        gen_stmt(st, depth + 2)
        st = nodes[st].next
    }
    close_scope()
    indent(depth + 1)
    put("}\n")
    if nodes[n].c >= 0 {
        indent(depth + 1)
        put("else\n")
        gen_stmt(nodes[n].c, depth + 1)
    }
    indent(depth)
    put("}\n")
}

// whether s leaves its case: a return, a break, a continue
let is_jump(s:int64):bool {
    if s < 0 { return false }
    return nodes[s].jumps()
}

// the token a case names: n of case n:, and of case n(x): (#215)
let case_word(v:int64):int64 {
    if nodes[v].kind == N_CALL { return nodes[nodes[v].a].t }
    return nodes[v].t
}

// whether a switch's cases name every enumerator of the enum d
let names_every(n:int64, d:int64):bool {
    var m:int64 = nodes[d].a
    while m >= 0 {
        var found = false
        var c:int64 = nodes[n].b
        while c >= 0 {
            var v:int64 = nodes[c].a
            while v >= 0 {
                if same_text(case_word(v), nodes[m].t) { found = true }
                v = nodes[v].next
            }
            c = nodes[c].next
        }
        if !found { return false }
        m = nodes[m].next
    }
    return true
}

// switch e { case a, b: ... } as kelvinc writes it (#63, #210): each case a
// block of its own, ending with a break but after a jump; a switch on an
// enum that names every enumerator tells C nothing else comes
let gen_switch(n:int64, depth:int64) {
    let td = tagged_of(type_of(nodes[n].a))           // an enum with values, by its tag (#215)
    put("switch (")
    if td >= 0 { put("(") }
    gen_expr(nodes[n].a)
    if td >= 0 { put(").tag") }
    put(")\n")
    indent(depth)
    put("{\n")
    var whole = false
    var c:int64 = nodes[n].b
    while c >= 0 && !failed {
        if nodes[c].flag == 1 {
            whole = true
            indent(depth)
            put("default:\n")
        } else {
            var v:int64 = nodes[c].a
            while v >= 0 {
                indent(depth)
                put("case ")
                if td >= 0 {
                    let m = case_named(td, case_word(v)) ?? 0 - 1
                    if m < 0 { gen_error(v, "this is no case of this enum") }
                    put_int(case_tag(td, m))
                    put(" /* ")
                    put_tok(case_word(v))
                    put(" */")
                } else {
                    gen_expr(v)
                }
                put(":\n")
                v = nodes[v].next
            }
        }
        indent(depth + 1)
        put("{\n")
        open_scope()
        let first = nodes[c].a
        if td >= 0 && first >= 0 && nodes[first].kind == N_CALL && !failed {
            let m = case_named(td, case_word(first)) ?? 0 - 1    // case n(x): x is the case's value, the enum's still
            let x = nodes[first].b
            indent(depth + 2)
            put_ctype(nodes[m].ty)
            put(" ")
            put_tok(nodes[x].t)
            put(" = (")
            gen_expr(nodes[n].a)
            put(").u.")
            put_tok(case_word(first))
            put(";\n")
            declare_as(nodes[x].t, nodes[m].ty, 3)       // a case's value (#271)
        }
        var s:int64 = nodes[c].b
        var last = -1
        while s >= 0 && !failed {
            gen_stmt(s, depth + 2)
            last = s
            s = nodes[s].next
        }
        if !is_jump(last) {
            indent(depth + 2)
            put("break;\n")
        }
        close_scope()
        indent(depth + 1)
        put("}\n")
        c = nodes[c].next
    }
    if !whole {
        let y:int64 = type_of(nodes[n].a)
        var d = -1
        if y >= 0 && types[y].kind == Y_STRUCT { d = decl_named(types[y].name, D_ENUM) }
        if d < 0 {
            gen_error(n, "a switch that is not on an enum has default:")
        } else if !names_every(n, d) {
            gen_error(n, "a switch on an enum names every enumerator, or has default:")
        } else {
            indent(depth)
            put("default:\n")
            indent(depth + 1)
            put("__builtin_unreachable();\n")
        }
    }
    indent(depth)
    put("}\n")
}

let gen_stmt(n:int64, depth:int64) {
    if failed { return }
    let k:nkind = nodes[n].kind
    if k == S_BLOCK {
        gen_block(n, depth)
        return
    }
    indent(depth)
    switch k {                                                   // (#210)
    case S_VAR:
        gen_var(n)
        declare_as(nodes[n].t, nodes[n].ty, nodes[n].flag == 1 ? 1 : 0)   // a let or a var (#271)
    case S_ASSIGN: gen_assign(n)
    case S_EXPR:
        let v = nodes[n].a
        if needs_hold(v) {                            // an owner no one takes, freed (#227)
            let y = type_of(v)
            put("{ __attribute__((cleanup(")
            put_free(y)
            put("))) ")
            put_ctype(y)
            put(" _kv_dropped = ")
            gen_expr(v)
            put("; }\n")
        } else {
            gen_expr(v)
            put(";\n")
        }
    case S_IF:
        put("if (")
        gen_cond(nodes[n].a)
        put(")\n")
        indent(depth)
        gen_block(nodes[n].b, depth)
        if nodes[n].c >= 0 {
            indent(depth)
            put("else\n")
            gen_stmt(nodes[n].c, depth)
        }
    case S_WHILE:
        put("while (")
        gen_cond(nodes[n].a)
        put(")\n")
        indent(depth)
        gen_block(nodes[n].b, depth)
    case S_FOR:
        serial += 1
        put("for (int64_t ")
        put_tok(nodes[n].t)
        put(" = ")
        gen_expr(nodes[n].a)
        put(", _kv_end")
        put_int(serial)
        put(" = ")
        gen_expr(nodes[n].b)
        put("; ")
        put_tok(nodes[n].t)
        put(" < _kv_end")
        put_int(serial)
        put("; ")
        put_tok(nodes[n].t)
        put("++)\n")
        open_scope()
        declare_as(nodes[n].t, base_type(Y_I64), 4)        // the range's count (#271)
        indent(depth)
        gen_block(nodes[n].c, depth)
        close_scope()
    case S_EACH: gen_each(n, depth)
    case S_SWITCH: gen_switch(n, depth)
    case S_IFLET: gen_iflet(n, depth)
    case S_RETURN: gen_return(n)
    case S_BREAK: put("break;\n")
    case S_CONTINUE: put("continue;\n")
    default: gen_error(n, "this statement is not known")
    }
}

// { statements }, written after an indent
let gen_block(n:int64, depth:int64) {
    put("{\n")
    open_scope()
    var s:int64 = nodes[n].a
    while s >= 0 && !failed {
        gen_stmt(s, depth + 1)
        s = nodes[s].next
    }
    close_scope()
    indent(depth)
    put("}\n")
}

// ---------- declarations ----------

let is_main(d:int64):bool {
    return tok_is(nodes[d].t, "main") && nodes[d].c < 0
}

let gen_signature(d:int64) {
    put_ctype(nodes[d].ty)
    put(" ")
    let recv:int64 = nodes[d].c
    if recv >= 0 {                                     // T__m (#213)
        put_tok(recv)
        put("__")
        put_tok(nodes[d].t)
    } else {
        put_fn_name(d)                                 // twice__i64 of an overload (#234)
    }
    put("(")
    var p:int64 = nodes[d].a
    let takes_self:bool = recv >= 0 && nodes[d].flag != 1
    if takes_self {                                    // a method's self, a T, first
        put_ctype(type_of_kind(Y_STRUCT, -1, recv))
        put(" self")
    }
    if p < 0 && !takes_self { put("void") }
    while p >= 0 {
        if p != nodes[d].a || takes_self { put(", ") }
        put_ctype(nodes[p].ty)
        put(" ")
        if is_owner(nodes[p].ty) { put("_kv_") }        // an owner taken by value: _kv_x_in, bound to x (#226)
        put_tok(nodes[p].t)
        if is_owner(nodes[p].ty) { put("_in") }
        p = nodes[p].next
    }
    put(")")
}

// whether the function d takes an owner by value, which it frees (#226)
let takes_owner(d:int64):bool {
    var p:int64 = nodes[d].a
    while p >= 0 {
        if is_owner(nodes[p].ty) { return true }
        p = nodes[p].next
    }
    return false
}

// ---------- a body's value (#286) ----------

// whether e, a statement, has no value: println, print, or a call of a
// function kc sees has no result, as kelvinc's no_value
let no_value(e:int64):bool {
    let k = nodes[e].kind
    if k == N_COND { return no_value(nodes[e].b) || no_value(nodes[e].c) }
    if k != N_CALL { return false }
    let y:int64 = type_of(e)
    return y >= 0 && types[y].kind == Y_VOID
}

// whether e, a statement, leaves a value behind: one with no effect, or,
// with calls, a call of a function kc sees has a result, as kelvinc's
// drops_value; a call of C's, or of a type, has an effect
let drops_value(e:int64, calls:bool):bool {
    let k = nodes[e].kind
    if k == N_COND { return drops_value(nodes[e].b, calls) || drops_value(nodes[e].c, calls) }
    if k != N_CALL && k != N_METHOD { return true }
    if !calls || k != N_CALL || nodes[nodes[e].a].kind != N_ID { return false }
    if tok_is(nodes[nodes[e].a].t, "println") || tok_is(nodes[nodes[e].a].t, "print") { return false }
    if call_target(e) < 0 { return false }
    let y:int64 = type_of(e)
    return y >= 0 && types[y].kind != Y_VOID
}

// the last of the statements from s on, or -1
let last_of(s:int64):int64 {
    var last:int64 = -1
    var t:int64 = s
    while t >= 0 {
        last = t
        t = nodes[t].next
    }
    return last
}

// the statement at the end of a path through s that drops a value: of a
// block, either arm of an if, each case of a switch; -1 if none
let dropped_at_end(s:int64, calls:bool):int64 {
    if s < 0 { return -1 }
    let k = nodes[s].kind
    if k == S_EXPR { return drops_value(nodes[s].a, calls) ? s : -1 }
    if k == S_BLOCK { return dropped_at_end(last_of(nodes[s].a), calls) }
    if k == S_IF || k == S_IFLET {
        let b = dropped_at_end(nodes[s].b, calls)
        return b >= 0 ? b : dropped_at_end(nodes[s].c, calls)
    }
    if k == S_SWITCH {
        var c:int64 = nodes[s].b
        while c >= 0 {
            let x = dropped_at_end(last_of(nodes[c].b), calls)
            if x >= 0 { return x }
            c = nodes[c].next
        }
    }
    return -1
}

// a function with a result whose body is one expression returns it, as
// kelvinc's (#26, #35); main keeps C's rule that its end returns 0. One
// assignment, or one call with no value, is an error there, as is a body
// that ends, on any path, in a value it drops; in main, one with no effect
let implicit_return(d:int64) {
    let first:int64 = nodes[nodes[d].b].a
    if first < 0 { return }
    let ry:int64 = nodes[d].ty
    let main = is_main(d)
    if ry < 0 || types[ry].kind == Y_VOID { return }
    let last = last_of(first)
    if nodes[first].next < 0 && !main {
        if nodes[first].kind == S_ASSIGN {
            var m = $"an assignment has no value (#26), but this function has a result, of type "
            let what:String = kelvin_type_text(ry)
            m += &what
            m += ": assign, then 'return' a value"
            gen_error(first, m.cstr)
            return
        }
        if nodes[first].kind == S_EXPR {
            if no_value(nodes[first].a) {
                var m = $"this has no value, but this function has a result, of type "
                let what:String = kelvin_type_text(ry)
                m += &what
                m += ": write 'return' with a value after it"
                gen_error(first, m.cstr)
                return
            }
            nodes[first].kind = S_RETURN              // its value returned, an owner moved out
            return
        }
    }
    let dropped = dropped_at_end(last, !main)
    if dropped >= 0 && main {
        gen_error(dropped, "main's end returns 0, as in C, so it does not return this value: write 'return' before it")
    } else if dropped >= 0 {
        gen_error(dropped, "this value would be dropped: a body returns its value without 'return' only when it is one expression, so write 'return' before it")
    }
}

let gen_function(d:int64) {
    current = d
    implicit_return(d)
    if failed { return }
    gen_signature(d)
    put("\n")
    open_scope()
    var p:int64 = nodes[d].a
    while p >= 0 {
        declare_as(nodes[p].t, nodes[p].ty, nodes[p].flag == 1 ? 2 : 0)   // a parameter, a let unless var (#271)
        p = nodes[p].next
    }
    if is_main(d) {
        put("{\n")
        if uses_io && nodes[d].a >= 0 {
            put("    kv_sys_init(")
            put_tok(nodes[nodes[d].a].t)
            put(", ")
            put_tok(nodes[nodes[nodes[d].a].next].t)
            put(");\n")
        }
        if global_owners { put("    atexit(_kv_free_globals);\n") }
        put("    {\n")
        var s:int64 = nodes[nodes[d].b].a
        open_scope()
        while s >= 0 && !failed {
            gen_stmt(s, 2)
            s = nodes[s].next
        }
        close_scope()
        put("    }\n}\n")
    } else if takes_owner(d) {                           // each owner taken by value, freed where it ends (#226)
        put("{\n")
        p = nodes[d].a
        while p >= 0 {
            if is_owner(nodes[p].ty) {
                put("    __attribute__((cleanup(")
                put_free(nodes[p].ty)
                put("))) ")
                put_ctype(nodes[p].ty)
                put(" ")
                put_tok(nodes[p].t)
                put(" = _kv_")
                put_tok(nodes[p].t)
                put("_in;\n")
            }
            p = nodes[p].next
        }
        indent(1)
        gen_block(nodes[d].b, 1)
        put("}\n")
    } else {
        gen_block(nodes[d].b, 0)
    }
    close_scope()
    put("\n")
}

// struct T, written for an enum with values
let put_struct(name:int64) {
    put("struct ")
    put_tok(name)
}

// an enum with values as kelvinc writes it (#215): a struct of a tag and
// a union; its cases' names; _free, _take and _copy where a case owns;
// and for each case, _make and _set, and _at, checked, of one with a value
let gen_tagged(d:int64) {
    let name = nodes[d].t
    put_struct(name)
    put("\n{\n    uint8_t tag;\n    union\n    {\n")
    var m = nodes[d].a
    while m >= 0 {
        if nodes[m].ty >= 0 {
            put("        ")
            put_ctype(nodes[m].ty)
            put(" ")
            put_tok(nodes[m].t)
            put(";\n")
        }
        m = nodes[m].next
    }
    put("    } u;\n};\n")
    put("__attribute__((unused)) static const char *const _kv_")
    put_tok(name)
    put("_cases[] = {")
    m = nodes[d].a
    while m >= 0 {
        if m != nodes[d].a { put(", ") }
        put("\"")
        put_tok(nodes[m].t)
        put("\"")
        m = nodes[m].next
    }
    put("};\n")
    let owns = tagged_owns(d)
    if owns {
        put("__attribute__((unused)) static inline void _kv_")
        put_tok(name)
        put("_free(")
        put_struct(name)
        put(" *self)\n{\n    switch (self->tag)\n    {\n")
        m = nodes[d].a
        while m >= 0 {
            if nodes[m].ty >= 0 && is_owner(nodes[m].ty) {
                put("    case ")
                put_int(case_tag(d, m))
                put(": ")
                put_free(nodes[m].ty)
                put("(&self->u.")
                put_tok(nodes[m].t)
                put("); break;\n")
            }
            m = nodes[m].next
        }
        put("    default: break;\n    }\n    *self = (")
        put_struct(name)
        put("){0};\n}\n")
        put("__attribute__((unused)) static inline ")
        put_struct(name)
        put(" _kv_")
        put_tok(name)
        put("_take(")
        put_struct(name)
        put(" *self)\n{\n    ")
        put_struct(name)
        put(" _kv_v = *self;\n    *self = (")
        put_struct(name)
        put("){0};\n    return _kv_v;\n}\n")
        put("__attribute__((unused)) static inline ")
        put_struct(name)
        put(" _kv_")
        put_tok(name)
        put("_copy(const ")
        put_struct(name)
        put(" *self)\n{\n    ")
        put_struct(name)
        put(" _kv_v = *self;\n    switch (self->tag)\n    {\n")
        m = nodes[d].a
        while m >= 0 {
            if nodes[m].ty >= 0 && is_owner(nodes[m].ty) {
                put("    case ")
                put_int(case_tag(d, m))
                put(": _kv_v.u.")
                put_tok(nodes[m].t)
                put(" = ")
                put_owner_prefix(nodes[m].ty)
                put("_copy(&self->u.")
                put_tok(nodes[m].t)
                put("); break;\n")
            }
            m = nodes[m].next
        }
        put("    default: break;\n    }\n    return _kv_v;\n}\n")
    }
    m = nodes[d].a
    while m >= 0 {
        let tag = case_tag(d, m)
        let v = nodes[m].ty
        if v >= 0 {                                    // _at, checked
            put("__attribute__((unused)) static inline ")
            put_ctype(v)
            put(" *_kv_")
            put_tok(name)
            put("_at_")
            put_tok(nodes[m].t)
            put("(const ")
            put_struct(name)
            put(" *self)\n{\n    if (self->tag != ")
            put_int(tag)
            put(") kv_case_fail(\"")
            put_tok(name)
            put("\", \"")
            put_tok(nodes[m].t)
            put("\", _kv_")
            put_tok(name)
            put("_cases[self->tag]);\n    return (")
            put_ctype(v)
            put(" *)&self->u.")
            put_tok(nodes[m].t)
            put(";\n}\n")
        }
        put("__attribute__((unused)) static inline void _kv_")       // _set, freeing what it held
        put_tok(name)
        put("_set_")
        put_tok(nodes[m].t)
        put("(")
        put_struct(name)
        put(" *self")
        if v >= 0 {
            put(", ")
            put_ctype(v)
            put(" v")
        }
        put(")\n{\n")
        if owns {
            put("    _kv_")
            put_tok(name)
            put("_free(self);\n")
        }
        put("    self->tag = ")
        put_int(tag)
        put(";\n")
        if v >= 0 {
            put("    self->u.")
            put_tok(nodes[m].t)
            put(" = v;\n")
        }
        put("}\n")
        put("__attribute__((unused)) static inline ")       // _make
        put_struct(name)
        put(" _kv_")
        put_tok(name)
        put("_make_")
        put_tok(nodes[m].t)
        put("(")
        if v >= 0 {
            put_ctype(v)
            put(" v")
        } else {
            put("void")
        }
        put(")\n{\n    ")
        put_struct(name)
        put(" _kv_v = {0};\n    _kv_v.tag = ")
        put_int(tag)
        put(";\n")
        if v >= 0 {
            put("    _kv_v.u.")
            put_tok(nodes[m].t)
            put(" = v;\n")
        }
        put("    return _kv_v;\n}\n")
        m = nodes[m].next
    }
    put("\n")
}

// a struct's functions where it owns (#225), as kelvinc writes them: its
// members freed, taken and copied
let gen_struct_owner(d:int64) {
    let name = nodes[d].t
    put("__attribute__((unused)) static inline void _kv_")
    put_tok(name)
    put("_free(")
    put_struct(name)
    put(" *self)\n{\n")
    var f = nodes[d].a
    while f >= 0 {
        if is_owner(nodes[f].ty) {
            put("    ")
            put_free(nodes[f].ty)
            put("(&self->")
            put_tok(nodes[f].t)
            put(");\n")
        }
        f = nodes[f].next
    }
    put("}\n__attribute__((unused)) static inline ")
    put_struct(name)
    put(" _kv_")
    put_tok(name)
    put("_take(")
    put_struct(name)
    put(" *self)\n{\n    ")
    put_struct(name)
    put(" _kv_v = *self;\n    *self = (")
    put_struct(name)
    put("){0};\n    return _kv_v;\n}\n__attribute__((unused)) static inline ")
    put_struct(name)
    put(" _kv_")
    put_tok(name)
    put("_copy(const ")
    put_struct(name)
    put(" *self)\n{\n    ")
    put_struct(name)
    put(" _kv_v = *self;\n")
    f = nodes[d].a
    while f >= 0 {
        if is_owner(nodes[f].ty) {
            put("    _kv_v.")
            put_tok(nodes[f].t)
            put(" = ")
            put_owner_prefix(nodes[f].ty)
            put("_copy(&self->")
            put_tok(nodes[f].t)
            put(");\n")
        }
        f = nodes[f].next
    }
    put("    return _kv_v;\n}\n\n")
}

var written:Dictionary<int64, int64>     // the types whose C is written (#225)

// the C of type y once, after the types it holds by value: an Array's
// element before the Array, a struct's members before the struct, an
// enum's values before the enum (#225); a pointer needs no more than C's
// name of what it points to
let write_type(y:int64) {
    if y < 0 || written.has(y) { return }
    written[y] = 1
    let k:ykind = types[y].kind
    if k == Y_ARRAY {
        write_type(types[y].elem)
        put("KV_ARRAY(")
        put_ctype(types[y].elem)
        put(", ")
        put_array_name(y)
        put(", ")
        put_free_copy(types[y].elem)
        put(")\n")
    } else if k == Y_DICT {
        let key:int64 = types[y].name
        let value:int64 = types[y].elem
        write_type(key)
        write_type(value)
        put("KV_DICT(")
        if types[key].kind == Y_STRING {
            put("kv_string, const uint8_t *, ")
        } else {
            put_ctype(key)
            put(", ")
            put_ctype(key)
            put(", ")
        }
        put_ctype(value)
        put(", ")
        put_dict_name(y)
        if types[key].kind == Y_STRING {
            put(", KV_HASH_TEXT, KV_EQ_TEXT, KV_STORE_TEXT, KV_MISSING_TEXT, kv_string_free, kv_string_copy, ")
        } else {
            put(", KV_HASH_INT, KV_EQ_INT, KV_STORE_INT, KV_MISSING_INT, KV_PLAIN_FREE, KV_PLAIN_COPY, ")
        }
        put_free_copy(value)
        put(")\n")
    } else if k == Y_SET {                            // as kelvinc's set_args (#274)
        let e:int64 = types[y].elem
        write_type(e)
        put("KV_SET(")
        if types[e].kind == Y_STRING {
            put("kv_string, const uint8_t *, ")
        } else {
            put_ctype(e)
            put(", ")
            put_ctype(e)
            put(", ")
        }
        put_set_name(y)
        if types[e].kind == Y_STRING {
            put(", KV_HASH_TEXT, KV_EQ_TEXT, KV_STORE_TEXT, KV_LK_TEXT, kv_string_free, kv_string_copy)\n")
        } else {
            put(", KV_HASH_INT, KV_EQ_INT, KV_STORE_INT, KV_LK_INT, KV_PLAIN_FREE, KV_PLAIN_COPY)\n")
        }
    } else if k == Y_STRUCT {
        let d = decl_named(types[y].name, D_STRUCT)
        if d >= 0 {
            var f:int64 = nodes[d].a
            while f >= 0 {
                write_type(nodes[f].ty)
                f = nodes[f].next
            }
            put("struct ")
            put_tok(nodes[d].t)
            put("\n{\n")
            f = nodes[d].a
            while f >= 0 {
                put("    ")
                put_ctype(nodes[f].ty)
                put(" ")
                put_tok(nodes[f].t)
                put(";\n")
                f = nodes[f].next
            }
            put("};\n\n")
            if is_owner(y) { gen_struct_owner(d) }
            return
        }
        let e = tagged_of(y)
        if e >= 0 {
            var m = nodes[e].a
            while m >= 0 {
                write_type(nodes[m].ty)
                m = nodes[m].next
            }
            gen_tagged(e)
        }
    }
}

let gen_program() {
    index_names()
    count_overloads()
    put("/* generated by kc, selfhost/kc.k */\n")
    put("#if !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)\n")
    put("#ifndef _XOPEN_SOURCE\n#define _XOPEN_SOURCE 700\n#endif\n")
    put("#ifndef _DEFAULT_SOURCE\n#define _DEFAULT_SOURCE 1\n#endif\n")
    put("#endif\n")
    put("#ifndef _DARWIN_C_SOURCE\n#define _DARWIN_C_SOURCE\n#endif\n")
    put("#include <stdbool.h>\n#include <stdint.h>\n#include <string.h>\n#include <kelvin_prelude.h>\n")
    for i in 0..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind == D_IMPORT && nodes[d].flag == 1 {
            put("#include <kOS.h>\n#include <kIO.h>\n")
            uses_io = true
        }
        if nodes[d].kind == D_IMPORT && nodes[d].flag == 2 {     // #import <x.h> as C (#207)
            put("#include ")
            put_tok(nodes[d].t)
            put("\n")
        }
    }
    put("\n")
    for i in 0..<decls.count as int64 {                  // the enums, C's (#210)
        let d:int64 = decls[i]
        if nodes[d].kind == D_ENUM && nodes[d].flag != 1 {
            put("enum ")
            put_tok(nodes[d].t)
            put("\n{\n")
            var m:int64 = nodes[d].a
            while m >= 0 {
                put("    ")
                put_tok(nodes[m].t)
                if nodes[m].a >= 0 {
                    put(" = ")
                    gen_expr(nodes[m].a)
                }
                put(",\n")
                m = nodes[m].next
            }
            put("};\n\n")
        }
    }
    for i in 0..<decls.count as int64 {                  // the structs and the enums with values (#215), each
        let d:int64 = decls[i]                           // after what it holds, as the Arrays and Dictionaries (#225)
        if nodes[d].kind == D_STRUCT || (nodes[d].kind == D_ENUM && nodes[d].flag == 1) {
            write_type(type_of_kind(Y_STRUCT, -1, nodes[d].t))
        }
    }
    for i in 0..<arrays.count as int64 { write_type(arrays[i]) }
    for i in 0..<dicts.count as int64 { write_type(dicts[i]) }
    for i in 0..<sets.count as int64 { write_type(sets[i]) }     // (#274)
    put("\n")
    for i in 0..<decls.count as int64 {                  // the globals
        let d:int64 = decls[i]
        if nodes[d].kind == D_GLOBAL {
            if nodes[d].ty < 0 { set_ty(d, inferred(d)) }       // (#214)
            if failed { return }
            if nodes[d].a >= 0 && !assigns_as(d, nodes[d].t, nodes[d].ty, nodes[d].c == 1) { return }   // (#233)
            if nodes[d].flag == 1 { put("const ") }
            put_ctype(nodes[d].ty)
            put(" ")
            put_tok(nodes[d].t)
            put(" = ")
            if nodes[d].a >= 0 {
                gen_value(nodes[d].a, nodes[d].ty)
            } else if is_owner(nodes[d].ty) || types[nodes[d].ty].kind == Y_STRUCT {
                put("{0}")
            } else {
                put("0")
            }
            put(";\n")
        }
    }
    put("\n")
    for i in 0..<decls.count as int64 {                  // the globals that own, freed at exit (#215)
        let d:int64 = decls[i]
        if nodes[d].kind == D_GLOBAL && is_owner(nodes[d].ty) { global_owners = true }
    }
    if global_owners {
        put("static void _kv_free_globals(void)\n{\n")
        for i in 0..<decls.count as int64 {
            let d:int64 = decls[i]
            if nodes[d].kind == D_GLOBAL && is_owner(nodes[d].ty) {
                put("    ")
                put_free(nodes[d].ty)
                put("(&")
                put_tok(nodes[d].t)
                put(");\n")
            }
        }
        put("}\n\n")
    }
    for i in 0..<decls.count as int64 {                  // the prototypes
        let d:int64 = decls[i]
        if nodes[d].kind == D_FN && nodes[d].b >= 0 && !is_main(d) {
            gen_signature(d)
            put(";\n")
        }
    }
    put("\n")
    let made = decls.count as int64                      // the T? a chain makes in a function go before them (#221)
    var head:String = out.copy()
    out = $""
    for i in 0..<made {                                  // the functions
        let d:int64 = decls[i]
        if nodes[d].kind == D_FN && nodes[d].b >= 0 && !failed { gen_function(d) }
    }
    var body:String = out.copy()
    out = head.copy()
    for i in 0..<arrays.count as int64 { write_type(arrays[i]) }   // the Arrays a $[a, b] in a function makes (#266)
    for i in 0..<dicts.count as int64 { write_type(dicts[i]) }     // and the Dictionaries of ${k: v} (#267)
    for i in 0..<sets.count as int64 { write_type(sets[i]) }       // and the Sets of ${a, b} (#274)
    for i in made..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind == D_ENUM && nodes[d].flag == 1 { write_type(type_of_kind(Y_STRUCT, -1, nodes[d].t)) }
    }
    for i in 0..<shown.count as int64 {                 // the printers print needs, after the functions (#229)
        put("static void ")
        put_show_name(shown[i])
        put("(kv_out *, const void *, int);\n")
    }
    out += &body
    for i in 0..<shown.count as int64 { gen_show(shown[i]) }
}
