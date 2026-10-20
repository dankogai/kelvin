// gen.k - the C of the program, for kc (selfhost/kc.k), as kelvinc
// writes it: the same runtime, kelvin_prelude.h and libkelvin, and the
// same names for what it makes, so that the two can be compared.

struct sym {
    t: int64           // the token of its name
    ty: int64
}

var out:String             // the C
var locals:$[sym]          // the variables in scope, the innermost last
var marks:$[int64]         // where each block's variables begin
var serial:int64           // for the names kc makes
var current:int64          // the function being written
var uses_io:bool           // #import <IO>, whose kOS.h has kv_sys_init

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

let is_owner(y:int64):bool {
    if y < 0 { return false }
    return types[y].owns()
}

// the part of an Array's name its element gives: i64, String, tok
let put_elem_name(y:int64) {
    switch types[y].kind {
    case Y_I64: put("i64")
    case Y_I32: put("i32")
    case Y_U8: put("u8")
    case Y_U32: put("u32")
    case Y_BOOL: put("bool")
    case Y_STRING: put("String")
    case Y_STRUCT: put_tok(types[y].name)
    default: put("unknown")
    }
}

let put_array_name(y:int64) {
    put("_kv_array_")
    put_elem_name(types[y].elem)
}

// a Dictionary's name: _kv_dict_String_i64 (#211)
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
    default: put_array_name(y)
    }
}

let decl_named(t:int64, kind:nkind):int64    // a prototype: put_ctype asks it of a struct

let put_ctype(y:int64) {
    switch types[y].kind {                                       // every kind of type (#210)
    case Y_VOID, Y_C: put("void")
    case Y_I64: put("int64_t")
    case Y_I32: put("int32_t")
    case Y_U8: put("uint8_t")
    case Y_U32: put("uint32_t")
    case Y_BOOL: put("bool")
    case Y_CSTR: put("const uint8_t *")
    case Y_STRING: put("kv_string")
    case Y_IO: put("kv_io")
    case Y_UCHR: put("kv_uchr")
    case Y_ARRAY: put_array_name(y)
    case Y_DICT: put_dict_name(y)
    case Y_STRUCT:
        if decl_named(types[y].name, D_STRUCT) >= 0 {
            put("struct ")
        } else if decl_named(types[y].name, D_ENUM) >= 0 {
            put("enum ")                                         // (#210)
        }                                                        // else a C header's typedef (#207)
        put_tok(types[y].name)
    case Y_PTR:
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

let declare(t:int64, y:int64) {
    let s:sym = {t, y}
    locals += s
}

// the declarations by their names (#211), where kc walked every one:
// each name's first, as a prototype's before its definition
var fn_names:Dictionary<String, int64>
var global_names:Dictionary<String, int64>
var struct_names:Dictionary<String, int64>
var enum_names:Dictionary<String, int64>
var enumerators:Dictionary<String, int64>  // an enumerator's enum
var method_names:Dictionary<String, int64> // a method or a function of a type, by "T.m" (#213)

// the text of token t, a String
let tok_text(t:int64):String {
    var s:String = $""
    let at:int64 = toks[t].at
    for i in 0..<toks[t].len {
        s += codes[at + i].uchr
    }
    return s
}

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

// every declaration by its name, before anything is written
let index_names() {
    for i in 0..<decls.count as int64 {
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
            while m >= 0 {
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

// whether node a names a struct, not a variable: T of T.f(...)
let names_type(a:int64):bool {
    return nodes[a].kind == N_ID && var_type(nodes[a].t) < 0 && decl_named(nodes[a].t, D_STRUCT) >= 0
}

// the method or the function of a type that x.m(...) or T.f(...) calls, or -1 (#213)
let method_of(n:int64):int64 {
    let a:int64 = nodes[n].a
    if names_type(a) { return method_named(nodes[a].t, nodes[n].t) }
    let y:int64 = type_of(a)
    if y < 0 || types[y].kind != Y_STRUCT { return -1 }
    return method_named(types[y].name, nodes[n].t)
}

let type_of(n:int64):int64 {
    let k:nkind = nodes[n].kind
    let t:int64 = nodes[n].t
    if k == N_NUM || k == N_CHAR { return base_type(Y_I64) }
    if k == N_STR { return base_type(Y_CSTR) }
    if k == N_DSTR { return base_type(Y_STRING) }
    if k == N_BOOL { return base_type(Y_BOOL) }
    if k == N_NULL { return base_type(Y_C) }
    if k == N_SELF { return type_of_kind(Y_STRUCT, -1, nodes[current].c) }      // (#213)
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
        let d:int64 = decl_named(nodes[f].t, D_FN)
        if d < 0 && c_headers { return base_type(Y_C) }      // a C header's function (#207)
        if d < 0 {
            gen_error(n, "this function is not known")
            return -1
        }
        return nodes[d].ty
    }
    if k == N_FIELD {
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        let yk:ykind = types[y].kind
        if tok_is(t, "count") && (yk == Y_STRING || yk == Y_ARRAY || yk == Y_DICT) { return base_type(Y_I64) }
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
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        if tok_is(t, "copy") { return y }
        if tok_is(t, "pop") || tok_is(t, "get") { return types[y].elem }
        if tok_is(t, "has") { return base_type(Y_BOOL) }
        return base_type(Y_VOID)
    }
    if k == N_INDEX {
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        let yk:ykind = types[y].kind
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
        return type_of(nodes[n].a)
    }
    if k == N_CAST { return nodes[n].ty }
    if k == N_ADDR { return type_of_kind(Y_PTR, type_of(nodes[n].a), -1) }
    if k == N_DEREF {
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        return types[y].elem
    }
    return -1
}

// ---------- expressions ----------

let gen_expr(n:int64)

let gen_args(first:int64) {
    var a:int64 = first
    while a >= 0 {
        if a != first { put(", ") }
        gen_expr(a)
        a = nodes[a].next
    }
}

// the address of what n names: &x, or a pointer as it is
let gen_place(n:int64) {
    put("&(")
    gen_expr(n)
    put(")")
}

// a Dictionary's key: a String's text, as KV_DICT looks it up (#211)
let gen_key(y:int64, k:int64) {
    let key:int64 = types[y].name
    let ky:int64 = type_of(k)
    if types[key].kind == Y_STRING && ky >= 0 && types[ky].kind == Y_STRING {
        put("kv_bytes_cstr(&(")
        gen_expr(k)
        put(").b)")
    } else {
        gen_expr(k)
    }
}

let is_place(n:int64):bool    // a prototype: gen_call asks it

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
    var a:int64 = args                             // what kelvinc holds, kc does not (#212)
    while a >= 0 {
        if is_owner(type_of(a)) && !is_place(a) {
            gen_error(a, "an owner an expression gives is passed to a function: bind it to a variable first, which kc frees")
        }
        a = nodes[a].next
    }
    put_tok(nodes[f].t)
    put("(")
    gen_args(args)
    put(")")
}

let gen_field(n:int64) {
    let a:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let y:int64 = type_of(a)
    if y < 0 { return }
    let yk:ykind = types[y].kind
    if tok_is(t, "count") && (yk == Y_STRING || yk == Y_ARRAY || yk == Y_DICT) {
        put("((int64_t)(")
        gen_expr(a)
        put(").count)")
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

let gen_method(n:int64) {
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
        gen_args(nodes[n].b)
        put(")")
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
    if yk == Y_STRING && tok_is(t, "copy") {
        put("kv_string_copy(")
        gen_place(a)
        put(")")
    } else if yk == Y_ARRAY && tok_is(t, "pop") {
        put_array_name(y)
        put("_pop(")
        gen_place(a)
        put(")")
    } else if yk == Y_DICT && (tok_is(t, "has") || tok_is(t, "get")) {   // d.has(k), d.get(k, v) (#211)
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
    return k == N_ID || k == N_FIELD || k == N_INDEX || k == N_DEREF
}

// a == b of Strings; one an expression gives is held in a temporary,
// freed once compared, as kelvinc holds it (#187)
let gen_string_eq(a:int64, b:int64) {
    if is_place(a) && is_place(b) {
        put("kv_string_eq(")
        gen_place(a)
        put(", ")
        gen_place(b)
        put(")")
        return
    }
    serial += 1
    let s:int64 = serial
    put("({ __attribute__((cleanup(kv_string_free))) kv_string _kv_tmp")
    put_int(s)
    put(" = ")
    if is_place(a) {
        gen_expr(b)
    } else {
        gen_expr(a)
    }
    put("; kv_string_eq(")
    if is_place(a) {
        gen_place(a)
    } else {
        gen_place(b)
    }
    put(", &_kv_tmp")
    put_int(s)
    put("); })")
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

let gen_expr(n:int64) {
    if failed { return }
    let k:nkind = nodes[n].kind
    let t:int64 = nodes[n].t
    if k == N_ID && var_type(t) < 0 && !c_headers {
        gen_error(n, "this name is not known")
    } else if k == N_NULL {
        put("NULL")
    } else if k == N_SELF {
        put("self")
    } else if k == N_NUM || k == N_CHAR || k == N_STR || k == N_ID {
        put_tok(t)
    } else if k == N_DSTR {
        put("KV_STRING_OF(")
        let at:int64 = toks[t].at
        for i in 1..<toks[t].len {
            out += codes[at + i].uchr
        }
        put(")")
    } else if k == N_BOOL {
        put("((bool)")                           // C's true is an int, which String(...) would write as 1 (#212)
        put_tok(t)
        put(")")
    } else if k == N_CALL {
        gen_call(n)
    } else if k == N_FIELD {
        gen_field(n)
    } else if k == N_METHOD {
        gen_method(n)
    } else if k == N_INDEX {
        let y:int64 = type_of(nodes[n].a)
        if y >= 0 && types[y].kind == Y_ARRAY {
            put("(*")
            put_array_name(y)
            put("_at(")
            gen_place(nodes[n].a)
            put(", ")
            gen_expr(nodes[n].b)
            put("))")
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
    } else if k == N_UNARY {
        if tok_is(t, "!") { put("(bool)") }          // C's ! gives an int, which prints as 1
        put("(")
        put_tok(t)
        gen_expr(nodes[n].a)
        put(")")
    } else if k == N_BIN {
        let y:int64 = type_of(nodes[n].a)
        if y >= 0 && types[y].kind == Y_STRING && (tok_is(t, "==") || tok_is(t, "!=")) {
            if tok_is(t, "!=") { put("(bool)!") }
            gen_string_eq(nodes[n].a, nodes[n].b)
        } else {
            if is_comparison(t) { put("(bool)") }    // C's comparisons give an int
            put("(")
            gen_expr(nodes[n].a)
            put(" ")
            put_tok(t)
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
let gen_var(n:int64) {
    let y:int64 = nodes[n].ty
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
        gen_expr(nodes[n].a)
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
    return has_call(nodes[n].a) || has_call(nodes[n].b)
}

let gen_assign(n:int64) {
    let lhs:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let y:int64 = type_of(lhs)
    if y < 0 { return }
    let yk:ykind = types[y].kind
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
    } else if yk == Y_ARRAY && tok_is(t, "+=") {
        put_array_name(y)
        put("_append(")
        gen_place(lhs)
        put(", ")
        gen_expr(nodes[n].b)
        put(");\n")
    } else if is_owner(y) {
        gen_error(n, "an owner is assigned only as a String")
    } else if has_element(lhs) && has_call(nodes[n].b) {
        serial += 1                                   // the value first, then where it goes
        put("{ ")
        put_ctype(y)
        put(" _kv_v")
        put_int(serial)
        put(" = ")
        gen_expr(nodes[n].b)
        put("; ")
        gen_expr(lhs)
        put(" ")
        put_tok(t)
        put(" _kv_v")
        put_int(serial)
        put("; }\n")
    } else {
        gen_expr(lhs)
        put(" ")
        put_tok(t)
        put(" ")
        gen_expr(nodes[n].b)
        put(";\n")
    }
}

let gen_return(n:int64) {
    let a:int64 = nodes[n].a
    if a < 0 {
        put("return;\n")
        return
    }
    let y:int64 = type_of(a)
    if nodes[a].kind == N_ID && is_owner(y) {            // a local owner moves out
        put("return ")
        put_owner_prefix(y)
        put("_take(&")
        put_tok(nodes[a].t)
        put(");\n")
        return
    }
    put("return ")
    if nodes[a].kind == N_INIT {                         // return {a, b}: of the function's type (#213)
        put("(")
        put_ctype(nodes[current].ty)
        put(")")
    }
    gen_expr(a)
    put(";\n")
}

// for c in s { }: each codepoint of a String, or each element of an Array
let gen_each(n:int64, depth:int64) {
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return }
    serial += 1
    put("{\n")
    indent(depth + 1)
    if types[y].kind == Y_STRING {
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
        declare(nodes[n].t, base_type(Y_UCHR))
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
        declare(nodes[n].t, types[y].elem)
    }
    indent(depth + 2)
    gen_block(nodes[n].c, depth + 2)
    close_scope()
    indent(depth + 1)
    put("}\n")
    indent(depth)
    put("}\n")
}

// whether s leaves its case: a return, a break, a continue
let is_jump(s:int64):bool {
    if s < 0 { return false }
    return nodes[s].jumps()
}

// whether a switch's cases name every enumerator of the enum d
let names_every(n:int64, d:int64):bool {
    var m:int64 = nodes[d].a
    while m >= 0 {
        var found:bool = false
        var c:int64 = nodes[n].b
        while c >= 0 {
            var v:int64 = nodes[c].a
            while v >= 0 {
                if nodes[v].kind == N_ID && same_text(nodes[v].t, nodes[m].t) { found = true }
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
    put("switch (")
    gen_expr(nodes[n].a)
    put(")\n")
    indent(depth)
    put("{\n")
    var whole:bool = false
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
                gen_expr(v)
                put(":\n")
                v = nodes[v].next
            }
        }
        indent(depth + 1)
        put("{\n")
        open_scope()
        var s:int64 = nodes[c].b
        var last:int64 = -1
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
        var d:int64 = -1
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
        declare(nodes[n].t, nodes[n].ty)
    case S_ASSIGN: gen_assign(n)
    case S_EXPR:
        gen_expr(nodes[n].a)
        put(";\n")
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
        declare(nodes[n].t, base_type(Y_I64))
        indent(depth)
        gen_block(nodes[n].c, depth)
        close_scope()
    case S_EACH: gen_each(n, depth)
    case S_SWITCH: gen_switch(n, depth)
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
    }
    put_tok(nodes[d].t)
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
        put_tok(nodes[p].t)
        p = nodes[p].next
    }
    put(")")
}

let gen_function(d:int64) {
    current = d
    gen_signature(d)
    put("\n")
    open_scope()
    var p:int64 = nodes[d].a
    while p >= 0 {
        declare(nodes[p].t, nodes[p].ty)
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
        put("    {\n")
        var s:int64 = nodes[nodes[d].b].a
        open_scope()
        while s >= 0 && !failed {
            gen_stmt(s, 2)
            s = nodes[s].next
        }
        close_scope()
        put("    }\n}\n")
    } else {
        gen_block(nodes[d].b, 0)
    }
    close_scope()
    put("\n")
}

let gen_program() {
    index_names()
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
        if nodes[d].kind == D_ENUM {
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
    for i in 0..<decls.count as int64 {                  // the structs
        let d:int64 = decls[i]
        if nodes[d].kind == D_STRUCT {
            put("struct ")
            put_tok(nodes[d].t)
            put("\n{\n")
            var f:int64 = nodes[d].a
            while f >= 0 {
                put("    ")
                put_ctype(nodes[f].ty)
                put(" ")
                put_tok(nodes[f].t)
                put(";\n")
                f = nodes[f].next
            }
            put("};\n\n")
        }
    }
    for i in 0..<arrays.count as int64 {                 // the Arrays of them
        let y:int64 = arrays[i]
        put("KV_ARRAY(")
        put_ctype(types[y].elem)
        put(", ")
        put_array_name(y)
        if types[types[y].elem].kind == Y_STRING {
            put(", kv_string_free, kv_string_copy)\n")
        } else {
            put(", KV_PLAIN_FREE, KV_PLAIN_COPY)\n")
        }
    }
    for i in 0..<dicts.count as int64 {                  // the Dictionaries (#211)
        let y:int64 = dicts[i]
        let key:int64 = types[y].name
        let value:int64 = types[y].elem
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
        if types[value].kind == Y_STRING {
            put("kv_string_free, kv_string_copy)\n")
        } else {
            put("KV_PLAIN_FREE, KV_PLAIN_COPY)\n")
        }
    }
    put("\n")
    for i in 0..<decls.count as int64 {                  // the globals
        let d:int64 = decls[i]
        if nodes[d].kind == D_GLOBAL {
            if nodes[d].flag == 1 { put("const ") }
            put_ctype(nodes[d].ty)
            put(" ")
            put_tok(nodes[d].t)
            put(" = ")
            if nodes[d].a >= 0 {
                gen_expr(nodes[d].a)
            } else if is_owner(nodes[d].ty) || types[nodes[d].ty].kind == Y_STRUCT {
                put("{0}")
            } else {
                put("0")
            }
            put(";\n")
        }
    }
    put("\n")
    for i in 0..<decls.count as int64 {                  // the prototypes
        let d:int64 = decls[i]
        if nodes[d].kind == D_FN && nodes[d].b >= 0 && !is_main(d) {
            gen_signature(d)
            put(";\n")
        }
    }
    put("\n")
    for i in 0..<decls.count as int64 {                  // the functions
        let d:int64 = decls[i]
        if nodes[d].kind == D_FN && nodes[d].b >= 0 && !failed { gen_function(d) }
    }
}
