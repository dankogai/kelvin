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
    var from = 0
    if codes[at] == '$' && toks[t].len > 1 {           // $0 is _kv_arg0 in C, as kelvinc names it (#326)
        out += "_kv_arg"
        from = 1
    }
    for i in from..<toks[t].len {
        out += codes[at + i].uchr
    }
}

// whether token t starts with _kv_, a name of kelvinc's own (#388)
let kelvin_word(t:int64):bool {
    let at:int64 = toks[t].at
    return toks[t].len >= 4 && codes[at] == '_' && codes[at + 1] == 'k' && codes[at + 2] == 'v' && codes[at + 3] == '_'
}

// whether token t holds more than ASCII (#385)
let wide_tok(t:int64):bool {
    for i in 0..<toks[t].len {
        if codes[toks[t].at + i] >= 128 { return true }
    }
    return false
}


// c in lower-case hex, as %x writes it
let hex_lower(c:uint32):String {
    let digits:cstr := "0123456789abcdef"
    var p:uint32 = 268435456
    while p > 1 && c / p == 0 { p = p / 16 }
    var s = $""
    while p > 0 {
        s += digits[(c / p) % 16].uchr
        p = p / 16
    }
    return s
}

// whether c goes on with a name in the C kc writes: ASCII's letters,
// digits and _, and any codepoint past ASCII
let c_name_char(c:uint32):bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c >= 128
}

// a word of the C, as kelvinc's ascii_names writes it (#385): one that
// holds more than ASCII is _kv_u, then each ASCII letter or digit as it is
// and any other codepoint as _, its hex, _
let put_c_word(r:String^, w:const String^, wide:bool) {
    var first = true
    var digit = false
    for c in w^ {
        if first { digit = c.utf32 >= '0' && c.utf32 <= '9' }
        first = false
    }
    if !wide || digit {
        r^ += w
        return
    }
    r^ += "_kv_u"
    for c in w^ {
        let v:uint32 = c.utf32
        if (v >= 'a' && v <= 'z') || (v >= 'A' && v <= 'Z') || (v >= '0' && v <= '9') {
            r^ += c
        } else {
            r^ += "_"
            let h:String = hex_lower(v)
            r^ += &h
            r^ += "_"
        }
    }
}

// the C kc writes, each name past ASCII spelled in ASCII, as kelvinc's
// (#385); text, a character, a comment and an #include line as they are
let ascii_names(s:const String^):String {
    var r = $""
    var w = $""
    var wide = false
    var mode:int64 = 0                                   // 0 code, 1 text, 2 a character, 3 a comment, 4 to the line's end, 5 a directive's word
    var escaped = false
    var prev:uint32 = 10
    var directive = $""
    for c in s^ {
        let v:uint32 = c.utf32
        if mode == 0 && c_name_char(v) {
            w += c
            wide = wide || v >= 128
            prev = v
            continue
        }
        if w.count > 0 {
            put_c_word(&r, &w, wide)
            w = $""
            wide = false
        }
        if mode == 5 {
            if (v >= 'a' && v <= 'z') {
                directive += c
                r += c
                prev = v
                continue
            }
            mode = directive == $"include" ? 4 : 0
            directive = $""
        }
        r += c
        if mode == 0 {
            if v == '"' {
                mode = 1
            } else if v == 39 {
                mode = 2
            } else if v == '*' && prev == '/' {
                mode = 3
            } else if v == '/' && prev == '/' {
                mode = 4
            } else if v == '#' && prev == 10 {
                mode = 5
            }
            prev = v
            continue
        }
        if mode == 1 || mode == 2 {
            if escaped {
                escaped = false
            } else if v == 92 {
                escaped = true
            } else if (mode == 1 && v == '"') || (mode == 2 && v == 39) {
                mode = 0
            }
        } else if mode == 3 && v == '/' && prev == '*' {
            mode = 0
            prev = 0
            continue
        } else if mode == 4 && v == 10 {
            mode = 0
        }
        prev = v
    }
    if w.count > 0 { put_c_word(&r, &w, wide) }
    return r
}

// an error at token t, as gen_error's at a node
let tok_error(t:int64, what:cstr) {
    if !failed {
        let k:tok = toks[t]
        println(fnames[k.file], ":", k.line, ": error: ", what)
    }
    failed = true
}

// v in hex, upper case
let hex_upper(v:int64):String {
    var s = $""
    if v >= 16 { s = hex_upper(v / 16) }
    let digits:cstr := "0123456789ABCDEF"
    s += (digits[v % 16] as uint32).uchr
    return s
}

// the code at i of string token t, or 0 past it
let text_code(t:int64, i:int64):int64 {
    if i < toks[t].len { return codes[toks[t].at + i] }
    return 0
}

// whether c is a hex digit, and its value
let is_hex_code(c:int64):bool {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

let hex_code_value(c:int64):int64 {
    if c >= '0' && c <= '9' { return c - '0' }
    if c >= 'a' && c <= 'f' { return c - 'a' + 10 }
    return c - 'A' + 10
}

// the \u escape at i of string token t, as kelvinc's ucn_text (#292, #293):
// \u{X}, \uXXXX or \UXXXXXXXX, the codepoint's UTF-8 bytes in octal, three
// digits each, which C takes for any codepoint; where the escape ends
let put_ucn(t:int64, i:int64):int64 {
    let braced = text_code(t, i + 1) == 'u' && text_code(t, i + 2) == '{'
    var want:int64 = 8
    if !braced && text_code(t, i + 1) == 'u' { want = 4 }
    var q:int64 = i + 2
    if braced { q += 1 }
    var cp:int64 = 0
    var digits:int64 = 0
    while is_hex_code(text_code(t, q)) && digits < (braced ? 8 : want) {
        cp = cp * 16 + hex_code_value(text_code(t, q))
        q += 1
        digits += 1
    }
    if (braced && (digits == 0 || text_code(t, q) != '}')) || (!braced && digits != want) {
        tok_error(t, "a \\u escape is \\u{X}, \\uXXXX or \\UXXXXXXXX: a codepoint in hex digits (#292)")
        return toks[t].len
    }
    if braced { q += 1 }
    if cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
        var m = $"\\u{"
        let h:String = hex_upper(cp)
        m += &h
        m += "} is no codepoint: a surrogate, D800 to DFFF, or past 10FFFF (#292)"
        tok_error(t, m.cstr)
        return toks[t].len
    }
    var bytes:$[int64] = $[]
    if cp < 0x80 {
        bytes += cp
    } else if cp < 0x800 {
        bytes += 0xC0 | (cp / 64)
        bytes += 0x80 | (cp % 64)
    } else if cp < 0x10000 {
        bytes += 0xE0 | (cp / 4096)
        bytes += 0x80 | ((cp / 64) % 64)
        bytes += 0x80 | (cp % 64)
    } else {
        bytes += 0xF0 | (cp / 262144)
        bytes += 0x80 | ((cp / 4096) % 64)
        bytes += 0x80 | ((cp / 64) % 64)
        bytes += 0x80 | (cp % 64)
    }
    for k in 0..<bytes.count as int64 {
        let b = bytes[k]
        out += "\\"
        let d0:int64 = '0' + b / 64
        let d1:int64 = '0' + (b / 8) % 8
        let d2:int64 = '0' + b % 8
        out += d0.uchr
        out += d1.uchr
        out += d2.uchr
    }
    return q
}

// a string's token from its from-th code, as kelvinc writes it: a '?'
// after a '?' escaped, as Kelvin has no trigraphs, which C11 would read
// in it (#220); each \u escape the codepoint's UTF-8 bytes (#293); every
// other escape C's, its two codes as they are, so that \\u is no escape
let put_text(t:int64, from:int64) {
    let at:int64 = toks[t].at
    var i:int64 = from
    while i < toks[t].len {
        let c = codes[at + i]
        if c == '\\' && (text_code(t, i + 1) == 'u' || text_code(t, i + 1) == 'U') {
            i = put_ucn(t, i)
            continue
        }
        if c == '?' && i > from && codes[at + i - 1] == '?' { out += "\\" }
        out += c.uchr
        if c == '\\' && i + 1 < toks[t].len {
            i += 1
            out += codes[at + i].uchr
        }
        i += 1
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
    if types[y].kind == Y_FIXED {                        // a counted one owns where its elements do (#364)
        var e:int64 = y
        while types[e].kind == Y_FIXED {
            if types[e].name < 0 { return false }
            e = types[e].elem
        }
        return is_owner(e)
    }
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
    case Y_TASK: put("kv_task")                    // (#313)
    case Y_ITER: put("kv_iter")                    // (#326)
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


let put_fixed_base(y:int64)    // prototypes: put_ctype, a case's [a, b] and a [T](N)^ ask these (#360, #362)
let put_fixed_counts(y:int64)

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
    case Y_TASK: put("kv_task")                                  // (#313)
    case Y_ITER: put("kv_iter")                                  // (#326)
    case Y_RANGE:                                                // _kv_range_i64 (#373)
        put("_kv_range_")
        let w:String = mangled(types[y].elem)
        put(w.cstr)
    case Y_UCHR: put("kv_uchr")
    case Y_BITS: put("kv_bits")                                  // (#387)
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
    case Y_FIXED:                                                // a fixed array is declared by put_fixed_decl (#354)
        if types[y].name >= 0 {                                  // __typeof__(int64_t[4]), which a pointer to one takes (#362)
            put("__typeof__(")
            put_fixed_base(y)
            put_fixed_counts(y)
            put(")")
        } else if types[y].name == 0 - 1 {                       // __typeof__(int64_t[]), of no count, [T]^'s (#363)
            put("__typeof__(")
            put_ctype(types[y].elem)
            put("[])")
        } else {
            if types[y].name == 0 - 4 { put("const ") }          // a parameter's, a pointer, of const elements (#357)
            put_ctype(types[y].elem)
            put(" *")
        }
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
    if wide_tok(t) && marks.count > 0 {                  // as kelvinc says it (#385)
        var i:int64 = locals.count as int64 - 1
        while i >= marks[marks.count - 1] {
            if same_text(locals[i].t, t) {
                var m = $"'"
                m += tok_text(t)
                m += "' is declared already in this block"
                tok_error(t, m.cstr)
                return
            }
            i -= 1
        }
    }
    let s:sym = {t, y, how}
    locals += s
}

let declare(t:int64, y:int64) { declare_as(t, y, 0) }

// a loop's variable: `for _ in` names none, as kelvinc's (#388)
let declare_each(t:int64, y:int64, how:int64) {
    if !tok_is(t, "_") { declare_as(t, y, how) }
}

let may_change(n:int64):bool    // a prototype: assignments and pop and remove ask it (#271)
let fixed_inside(y:int64):bool    // a prototype: type_of and gen_array ask it of an Array of a fixed array (#355)
let owner_part(v:int64):bool    // a prototype: let, = and return refuse what it says (#365)
let fixed_elem_ok(y:int64):bool    // prototypes: a member's fixed array is written by gen_written (#356)
let fixed_list_fits(v:int64, y:int64):bool
let gen_fixed_list(v:int64, y:int64)
let fixed_refused(n:int64)
let fixed_case(m:int64):bool    // and if let and switch bind a case's elements (#360)
let put_fixed_free(y:int64, path:cstr)    // and an enum's free and copy loop over a case's owners (#364)
let put_fixed_copy(y:int64, to:cstr, from:cstr)
let changeable_place(n:int64):bool    // prototypes: a var method's call asks them (#320)
let changes_var(n:int64, lead:const String^):bool
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

let float_tok(t:int64):bool    // a prototype: literal_arith asks it (#385)

// whether the program declares a name of this text, as kelvinc's name_known
let name_known_text(s:const String^):bool {
    for i in 0..<locals.count as int64 {
        let w:String = tok_text(locals[i].t)
        if w == s^ { return true }
    }
    if decls.count as int64 > indexed { index_names() }
    let name:String = s^.copy()
    return fn_names.get(name, -1) >= 0 || global_names.get(name, -1) >= 0 || struct_names.get(name, -1) >= 0 || enum_names.get(name, -1) >= 0 || enumerators.get(name, -1) >= 0
}

// a name past ASCII not declared where it is used (#385), in kelvinc's
// words, with the one that differs by a variation selector, U+FE0F
let unknown_wide(n:int64, t:int64) {
    let name:String = tok_text(t)
    var with = name.copy()
    with += "\u{FE0F}"
    var without = $""
    for i in 0..<toks[t].len {
        let c:uint32 = codes[toks[t].at + i]
        if c != 65038 && c != 65039 { without += c.uchr }
    }
    var near = $""
    if name_known_text(&with) {
        near = with.copy()
    } else if without.count != name.count && name_known_text(&without) {
        near = without.copy()
    }
    var m = $"'"
    m += &name
    if near.count > 0 {
        m += "' is not known, but '"
        m += &near
        m += "', which differs from it by a variation selector, U+FE0F, is"
    } else {
        m += "' is not known: declare it before it is used"
    }
    gen_error(n, m.cstr)
}

// arithmetic of literals alone (#385), as kelvinc's: 1 of integers, 2
// where any is floating-point, 0 of anything else
let literal_arith(v:int64):int64 {
    let k:nkind = nodes[v].kind
    if k == N_NUM { return float_tok(nodes[v].t) ? 2 : 1 }
    if k == N_UNARY && tok_is(nodes[v].t, "-") { return literal_arith(nodes[v].a) }
    if k != N_BIN { return 0 }
    let t:int64 = nodes[v].t
    if !(tok_is(t, "+") || tok_is(t, "-") || tok_is(t, "*") || tok_is(t, "/") || tok_is(t, "%") || tok_is(t, "&") || tok_is(t, "|") || tok_is(t, "~")) { return 0 }
    let a:int64 = literal_arith(nodes[v].a)
    let b:int64 = literal_arith(nodes[v].b)
    if a == 0 || b == 0 { return 0 }
    return a == 2 || b == 2 ? 2 : 1
}

var widened:Dictionary<int64, bool>     // arithmetic of integer literals whose type was inferred, an i64 (#385)
var widen_ints = false                  // while it is written, each literal an i64, as kelvinc casts it

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
let lazy_of(n:int64):int64    // prototypes: a lazy Sequence's (#324)
let lazy_type_of(n:int64):int64
let is_lazy_type(y:int64):bool
let lazy_field_type(n:int64):int64
let iter_type_of(n:int64):int64    // prototypes: an Iterator's (#326)
let gen_iter_make(n:int64)
let iter_lazy_of(n:int64):int64
let iter_lazy_type_of(n:int64):int64
let iter_prefix_of(n:int64):int64    // prototypes: x.prefix(n), x.prefix { ... } (#372)
let iter_prefix_type_of(n:int64):int64
let walked_elem(y:int64):int64
let prefix_of(n:int64):int64
let gen_prefix(n:int64)
let merge_of(n:int64):int64    // prototypes: a Dictionary's merge and merging (#338)
let gen_merge(n:int64)
let put_merge_value(vy:int64)
let search_of(n:int64):int64    // prototypes: a Dictionary's contains, firstKey and lastKey (#339)
let search_type_of(n:int64):int64
let gen_search(n:int64)
let value_mismatch_text(v:int64, vy:int64):String    // a prototype: ?? asks it too (#340)
let eager_of(n:int64):int64    // prototypes: eager map and the rest (#329)
let eager_type_of(n:int64):int64
let gen_eager(n:int64)
let gen_iter_value(i:int64)
let range_type_of(n:int64):int64    // prototypes: a Range's (#373)
let range_member_error(n:int64)
let range_iter_of(n:int64):int64
let range_max(y:int64):cstr
let put_range_walk(ey:int64, r:cstr, p:cstr)
let range_operand_error(n:int64):bool
let gen_range_member(n:int64)
let is_range_eq(n:int64):bool
let gen_range_eq(n:int64)
let is_slice(n:int64):bool
let range_unsigned(y:int64):bool
let gen_range_stride(n:int64)
let power_type(a:int64, b:int64):int64    // prototypes: b ** e and b.pow(e, m) (#380)
let power_int(y:int64):bool
let power_float(y:int64):bool
let power_int_literal(v:int64):bool
let power_magnitude(v:int64):int64
let float_field_at(t:int64, wide:bool):cstr    // (#383)
let float_field_mask(t:int64, wide:bool):cstr
let power_operand(v:int64):bool
let pow_arity(n:int64):bool
let pow_method_type(n:int64):int64
let gen_power(a:int64, b:int64)
let gen_pow_method(n:int64)
let is_case_word(n:int64):bool    // prototypes: type_of and gen_value ask them of c ? a : b (#232)
let owner_choice(n:int64):bool
let call_target(n:int64):int64    // the overload a call calls (#234)
let kelvin_type_text(y:int64):String    // and an await of no Task names its type (#313)

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

// whether y is a Result, the enum with values kc makes of ok and err (#344)
let is_result(y:int64):bool {
    let d = tagged_of(y)
    return d >= 0 && nodes[d].c != 1 && types[y].name > eof_pos && tok_is(nodes[nodes[d].a].t, "ok")
}

// whether y is an Optional or a Result, whose == kc writes (#343, #344)
let is_variant(y:int64):bool {
    return some_type(y) >= 0 || is_result(y)
}

// the case a T on the side of a variant's == is wrapped in: an
// Optional's some, a Result's ok; or -1 (#344)
let value_case(y:int64):int64 {
    if some_type(y) >= 0 { return nodes[nodes[tagged_of(y)].a].next }
    if is_result(y) { return nodes[tagged_of(y)].a }
    return 0 - 1
}

let wrap_type(y:int64):int64 {
    let m = value_case(y)
    return m >= 0 ? nodes[m].ty : 0 - 1
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
    if k == N_RANGE { return range_type_of(n) }          // lo..<hi and the rest, a Range<T> (#373)
    if k == N_RITER {                                    // the Iterator<T> of a Range (#373)
        let ry:int64 = type_of(nodes[n].a)
        return ry >= 0 ? type_of_kind(Y_ITER, types[ry].elem, -1) : 0 - 1
    }
    if k == N_NUM || k == N_CHAR { return base_type(Y_I64) }
    if k == N_STR { return base_type(Y_CSTR) }
    if k == N_DSTR { return base_type(Y_STRING) }
    if k == N_BOOL { return base_type(Y_BOOL) }
    if k == N_NULL { return base_type(Y_C) }
    if k == N_SELF { return type_of_kind(Y_STRUCT, -1, nodes[current].c) }      // (#213)
    if float_word(n) { return base_type(Y_F64) }                      // nan, inf (#262)
    if k == N_ID {
        if t < eof_pos && kelvin_word(t) {               // as an unnamed parameter's (#388)
            var m = $"names starting with _kv_ are kelvinc's own, in the C it writes: '"
            m += tok_text(t)
            m += "' is none of the program's"
            gen_error(n, m.cstr)
            return -1
        }
        let y:int64 = var_type(t)
        if y < 0 && wide_tok(t) {                        // a name past ASCII is Kelvin's (#385)
            if decl_named(t, D_FN) < 0 { unknown_wide(n, t) }
            return -1
        }
        if y < 0 && tok_is(t, "_") && decl_named(t, D_FN) < 0 {   // (#388)
            gen_error(n, "'_' names nothing to read: it leaves out a name, as of an unnamed parameter or of 'for _ in'")
            return -1
        }
        if y < 0 && c_headers { return base_type(Y_C) }      // a C header's (#207)
        if y < 0 { gen_error(n, "this name is not known") }
        return y
    }
    if k == N_CALL {
        let f:int64 = nodes[n].a
        if nodes[f].kind == N_TYPE {
            if tok_is(nodes[f].t, "IO") { return base_type(Y_IO) }
            if tok_is(nodes[f].t, "Bits") { return base_type(Y_BITS) }      // Bits(n) (#387)
            return base_type(Y_STRING)
        }
        if tok_is(nodes[f].t, "println") || tok_is(nodes[f].t, "print") { return base_type(Y_VOID) }
        let d:int64 = call_target(n)                       // the overload its arguments fit (#234)
        if nodes[f].kind == N_ID && wide_tok(nodes[f].t) && (d < 0 || (toks[nodes[d].t].file == toks[nodes[f].t].file && nodes[d].t > nodes[f].t)) {
            unknown_wide(n, nodes[f].t)                  // declared where it is used, as kelvinc has it (#385)
            return -1
        }
        if d < 0 && c_headers { return base_type(Y_C) }      // a C header's function (#207)
        if d < 0 {
            gen_error(n, "this function is not known")
            return -1
        }
        return nodes[d].ty
    }
    if k == N_ANON {
        gen_error(n, "kc reads an anonymous function only where one of these takes it: an Iterator, '.lazy.map' and '.lazy.filter', and map, filter, reduce, flatMap and their WithKey kin; kc has no function values, so call a function of the program here instead (#334)")
        return -1
    }
    if k == N_ITER { return iter_type_of(n) }           // Iterator(state) { ... } (#326)
    if k == N_LIST {                                     // [a, b], a fixed array of a's type; [T](n) (#354)
        if nodes[n].flag == 1 {                         // [T](n) of a count C computes, -10 - its node (#366)
            let c:int64 = nodes[nodes[n].a].kind == N_NUM ? tok_count(nodes[nodes[n].a].t) : 0 - 1
            return type_of_kind(Y_FIXED, nodes[n].ty, c >= 0 ? c : 0 - 10 - nodes[n].a)
        }
        let first:int64 = nodes[n].b
        if first < 0 || is_case_word(first) { return -1 }
        let e:int64 = type_of(first)
        if e < 0 { return -1 }
        var count = 0
        var x = first
        while x >= 0 {
            count += 1
            x = nodes[x].next
        }
        return type_of_kind(Y_FIXED, e, count)
    }
    if k == N_MAKE && nodes[n].ty < 0 {                 // Array([a, b]): an Array of a's type (#352)
        if nodes[n].flag == 4 {                         // Array(&a): a's type, an Array's (#353)
            let ay:int64 = type_of(nodes[nodes[n].a].a)
            return ay >= 0 && types[ay].kind == Y_ARRAY ? ay : 0 - 1
        }
        if nodes[n].flag == 5 {                         // Array(a) of a fixed array: of its elements (#355)
            let fy:int64 = type_of(nodes[n].a)
            if fy < 0 || types[fy].kind != Y_FIXED || fixed_inside(types[fy].elem) { return -1 }
            return type_of_kind(Y_ARRAY, types[fy].elem, -1)
        }
        if nodes[n].flag != 3 || nodes[n].b < 0 || is_case_word(nodes[n].b) { return -1 }
        let e:int64 = type_of(nodes[n].b)
        if e < 0 { return -1 }
        return type_of_kind(Y_ARRAY, e, -1)
    }
    if k == N_MAKE { return nodes[n].ty }               // Array<T>(), Dictionary<K, V>() (#349)
    if k == N_METHOD && tok_is(t, "next") {             // it.next() of an Iterator: a T? (#326)
        let iy:int64 = type_of(nodes[n].a)
        if iy >= 0 && types[iy].kind == Y_ITER { return optional_of(types[iy].elem) }
    }
    if k == N_FIELD && tok_is(t, "lazy") {             // s.lazy, before its map or filter (#324)
        let ly = lazy_field_type(n)
        if ly != 0 - 2 { return ly }
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
        if yk == Y_BITS && tok_is(t, "value") { return base_type(Y_C) }     // a Bits's u64, which kc has not: C's (#387)
        if yk == Y_BITS {
            var m = $"a Bits has value, flip, cstr, size, type and typename, and '."
            m += tok_text(t)
            m += "' is none of them"
            if !tok_is(t, "cstr") && !tok_is(t, "size") && !tok_is(t, "type") && !tok_is(t, "typename") { m += ": a bit is 'bv[n]'" } else { m = $"kc reads only '.value' of a Bits" }
            gen_error(n, m.cstr)
            return -1
        }
        if tok_is(t, "sign") && (yk == Y_F64 || yk == Y_F32) { return optional_of(base_type(Y_BOOL)) }   // a floating-point x.sign, a bool? (#383)
        if (tok_is(t, "exponent") || tok_is(t, "significand")) && (yk == Y_F64 || yk == Y_F32) { return base_type(Y_I64) }   // its fields (#383)
        if (tok_is(t, "abs") || tok_is(t, "sign")) && (yk == Y_I64 || yk == Y_I32 || yk == Y_F64 || yk == Y_F32) { return y }   // x.abs, x.sign, of its type (#381, #382)
        if (tok_is(t, "isNaN") || tok_is(t, "isInfinite") || tok_is(t, "isFinite")) && (yk == Y_F64 || yk == Y_F32) { return base_type(Y_BOOL) }   // x.isNaN (#382), x.isInfinite, x.isFinite (#384)
        if yk == Y_RANGE && tok_is(t, "count") { return base_type(Y_I64) }   // r.count, an i64 as kc's counts are (#374)
        if yk == Y_RANGE && (tok_is(t, "lowerBound") || tok_is(t, "upperBound")) { return types[y].elem }   // its bounds, of T (#375)
        if yk == Y_RANGE {                                               // as kelvinc's (#373)
            range_member_error(n)
            return -1
        }
        if tok_is(t, "count") && (yk == Y_STRING || yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET) { return base_type(Y_I64) }
        if (tok_is(t, "count") || tok_is(t, "size")) && yk == Y_FIXED { return base_type(Y_I64) }   // (#354)
        if (tok_is(t, "count") || tok_is(t, "size")) && yk == Y_PTR && types[types[y].elem].kind == Y_FIXED { return base_type(Y_I64) }   // gen_field's error (#362)
        if yk == Y_SET && tok_is(t, "elements") { return type_of_kind(Y_ARRAY, types[y].elem, -1) }   // an Array of copies (#278)
        if (yk == Y_SET || yk == Y_DICT) && tok_is(t, "pretty") { return base_type(Y_STRING) }      // its text indented, a new String (#336, #337)
        if (yk == Y_SET || yk == Y_DICT) && tok_is(t, "typename") { return base_type(Y_CSTR) }      // Set<i64> (#336, #337)
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
    if k == N_METHOD && iter_lazy_of(n) >= 0 { return iter_lazy_type_of(n) }   // it.lazy.map(f) of an Iterator (#328)
    if k == N_METHOD && iter_prefix_of(n) >= 0 { return iter_prefix_type_of(n) }   // it.prefix(n), lazily (#372)
    if k == N_METHOD && prefix_of(n) >= 0 { return type_of(nodes[n].a) }   // xs.prefix(n), a new one of its kind (#372)
    if k == N_METHOD && lazy_of(n) >= 0 { return lazy_type_of(n) }   // s.lazy.map(f), a lazy Sequence (#324)
    if k == N_METHOD && eager_of(n) >= 0 { return eager_type_of(n) }   // xs.map(f) and the rest (#329)
    if k == N_METHOD && (tok_is(t, "merge") || tok_is(t, "merging")) && merge_of(n) >= 0 {   // (#338)
        return tok_is(t, "merging") ? type_of(nodes[n].a) : base_type(Y_VOID)
    }
    if k == N_METHOD && search_of(n) >= 0 { return search_type_of(n) }   // d.contains(v), d.firstKey(v) and the rest (#339)
    if k == N_METHOD && !failed && nodes[nodes[n].a].kind == N_FIELD && tok_is(nodes[nodes[n].a].t, "lazy") && lazy_field_type(nodes[n].a) >= 0 {
        let ly:int64 = lazy_field_type(nodes[n].a)
        if types[ly].kind == Y_RANGE {                  // as kelvinc's (#373)
            gen_error(nodes[n].a, "'.lazy' makes '.map' or '.filter' after it lazy: write 'r.lazy.map { ... }' or 'r.lazy.filter { ... }'")
        } else if types[ly].kind == Y_ITER {            // as kelvinc's (#328)
            gen_error(nodes[n].a, "'.lazy' makes '.map' or '.filter' after it lazy: write 'it.lazy.map { ... }' or 'it.lazy.filter { ... }'")
        } else {
            gen_error(nodes[n].a, "'.lazy' makes '.map' or '.filter' after it lazy: write 's.lazy.map { ... }' or 's.lazy.filter { ... }'")
        }
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
        if types[y].kind == Y_RANGE && tok_is(t, "contains") { return base_type(Y_BOOL) }   // r.contains(x) (#374)
        if types[y].kind == Y_RANGE && tok_is(t, "reversed") { return type_of_kind(Y_ITER, types[y].elem, -1) }   // r.reversed(), down (#378)
        if types[y].kind == Y_RANGE && tok_is(t, "stride") { return type_of_kind(Y_ITER, types[y].elem, -1) }     // r.stride(n) (#379)
        if tok_is(t, "pow") && power_int(y) { return pow_method_type(n) }   // b.pow(e), b.pow(e, m) (#380)
        if types[y].kind == Y_BITS && tok_is(t, "flip") { return base_type(Y_VOID) }   // bv.flip(n) (#387)
        if types[y].kind == Y_BITS {
            var m = $"a Bits has value, flip, cstr, size, type and typename, and '."
            m += tok_text(t)
            m += "' is none of them: a bit is 'bv[n]'"
            gen_error(n, m.cstr)
            return -1
        }
        if types[y].kind == Y_RANGE {                                    // as kelvinc's (#373)
            range_member_error(n)
            return -1
        }
        if tok_is(t, "copy") { return y }
        if tok_is(t, "pop") || tok_is(t, "get") { return types[y].elem }
        if tok_is(t, "has") { return base_type(Y_BOOL) }
        if tok_is(t, "remove") && types[y].kind == Y_DICT { return base_type(Y_BOOL) }   // true if it was there (#270)
        if tok_is(t, "find") && types[y].kind == Y_DICT {   // a V^ to the value, or nullptr; a const V^ of a let (#337)
            let r:int64 = changed_root(nodes[n].a)
            let fixed = r >= 0 && how_declared(nodes[r].t) != 0
            return type_of_kind(Y_PTR, types[y].elem, fixed ? 1 : 0 - 1)
        }
        if (tok_is(t, "remove") || tok_is(t, "insert")) && types[y].kind == Y_SET { return base_type(Y_BOOL) }   // (#274)
        if (tok_is(t, "union") || tok_is(t, "intersection") || tok_is(t, "difference")) && types[y].kind == Y_SET { return y }   // a new Set (#275)
        if (tok_is(t, "escape") || tok_is(t, "unescape")) && types[y].kind == Y_STRING { return y }   // a new String (#300)
        return base_type(Y_VOID)
    }
    if k == N_INDEX {
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        let yk:ykind = types[y].kind
        let iy:int64 = nodes[n].b >= 0 ? type_of(nodes[n].b) : 0 - 1
        if iy >= 0 && types[iy].kind == Y_RANGE {                    // xs[r], a slice, a new one (#377)
            if yk != Y_ARRAY && yk != Y_STRING {
                var m = $"a slice [lo..<hi] is of an Array, a String or a Bytes, and this is "
                let w:String = kelvin_type_text(y)
                m += &w
                gen_error(n, m.cstr)
                return -1
            }
            return y
        }
        if yk == Y_DICT && nodes[n].flag == 1 { return optional_of(types[y].elem) }    // d[k] read whole (#219)
        if yk == Y_ARRAY || yk == Y_DICT || yk == Y_FIXED { return types[y].elem }   // a fixed array's (#354)
        if yk == Y_ARGV { return base_type(Y_CSTR) }
        if yk == Y_BITS { return base_type(Y_BOOL) }                    // bv[n], a bit (#387)
        return base_type(Y_U8)
    }
    if k == N_UNARY {
        if tok_is(t, "!") { return base_type(Y_BOOL) }                  // !!n too, a bit's bool (#387)
        return type_of(nodes[n].a)
    }
    if k == N_BIN {
        if is_comparison(t) { return base_type(Y_BOOL) }
        if tok_is(t, "??") { return some_type(type_of(nodes[n].a)) }   // (#217)
        if is_string_plus(n) { return base_type(Y_STRING) }            // s + t, a new String (#284)
        if tok_is(t, "**") { return power_type(nodes[n].a, nodes[n].b) }   // b ** e (#380)
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
    if k == N_ASYNC {                                  // a Task of the call's result (#313)
        let c:int64 = nodes[n].a
        if nodes[c].kind == N_CALL && nodes[nodes[c].a].kind == N_ID && decl_named(nodes[nodes[c].a].t, D_FN) < 0 {
            gen_error(c, "'async' takes a call of a Kelvin function or a function value, whose types kelvinc sees, as in 'async f(x)'")
            return -1
        }
        let r:int64 = type_of(c)
        if r < 0 { return -1 }
        return type_of_kind(Y_TASK, types[r].kind == Y_VOID ? 0 - 1 : r, -1)
    }
    if k == N_AWAIT {                                  // the Task's value, none of a Task (#313)
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        if types[y].kind != Y_TASK {
            var m = $"'await' waits for a Task, which 'async f(x)' gives, and this is "
            let what:String = kelvin_type_text(y)
            m += &what
            gen_error(nodes[n].a, m.cstr)
            return -1
        }
        if types[y].elem < 0 { return base_type(Y_VOID) }
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
    if is_case_word(n) { return true }                  // none, ok(v), err(e): no borrow, and gen_value reads them (#341)
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

// whether a goes to py, a parameter's array, as kelvinc's #49 has it: a
// fixed array of its elements, a local's, a member, a parameter's; where
// the parameter may change them, not a let's or a [const T]'s (#357)
let fixed_arg_ok(a:int64, py:int64, who:const String^):bool {
    let ay:int64 = nodes[a].kind == N_NUM || nodes[a].kind == N_STR ? 0 - 1 : type_of(a)
    let pw:String = type_text(py)
    if ay < 0 || types[ay].kind != Y_FIXED || types[ay].elem != types[py].elem {
        var m = who^.copy()
        m += " is "
        m += article_of(&pw)
        m += " "
        m += &pw
        m += ", and this is "
        let aw:String = nodes[a].kind == N_NUM ? $"a number" : nodes[a].kind == N_STR ? $"text" : ay >= 0 ? kelvin_type_text(ay) : $"not one"
        m += &aw
        gen_error(a, m.cstr)
        return false
    }
    if types[py].name == 0 - 4 || types[ay].name == 0 - 2 { return true }
    let r:int64 = changed_root(a)
    let let_s = types[ay].name == 0 - 4 || (r >= 0 && how_declared(nodes[r].t) != 0)
    if !let_s { return true }
    var m = who^.copy()
    m += " is "
    m += article_of(&pw)
    m += " "
    m += &pw
    m += ", which may change its elements, and this is "
    let aw:String = type_text(ay)
    m += &aw
    m += types[ay].name == 0 - 4 ? ", which reads them alone: write [const T] in the type taken" : ", a let's: write [const T] in the type taken, or pass a var's"
    gen_error(a, m.cstr)
    return false
}

// whether a goes where py, a [T](N)^, goes: a pointer to an array of its
// elements and count, nullptr, where kelvinc's C warns; not a let's where
// what it points to may change, as #272 has it (#362)
let fixed_ptr_ok(a:int64, py:int64, who:const String^):bool {
    if py < 0 || types[py].kind != Y_PTR || types[types[py].elem].kind != Y_FIXED || nodes[a].kind == N_NULL { return true }
    let ay:int64 = type_of(a)
    let pw:String = type_text(py)
    let pe:int64 = types[py].elem
    let ae:int64 = ay >= 0 && types[ay].kind == Y_PTR ? types[ay].elem : 0 - 1
    let alike = ae >= 0 && types[ae].kind == Y_FIXED && types[ae].elem == types[pe].elem && (types[ae].name == types[pe].name || types[ae].name == 0 - 1 || types[pe].name == 0 - 1)   // a count of none takes any, as C has it (#363)
    if !alike {
        var m = who^.copy()
        m += " is "
        m += article_of(&pw)
        m += " "
        m += &pw
        m += ", and this is "
        let aw:String = ay >= 0 ? type_text(ay) : $"not one"
        m += &aw
        gen_error(a, m.cstr)
        return false
    }
    if types[ay].name == 1 && types[py].name != 1 {
        var m = who^.copy()
        m += " is "
        m += article_of(&pw)
        m += " "
        m += &pw
        m += ", which may change what it points to, and this is a let's: borrow a var"
        gen_error(a, m.cstr)
        return false
    }
    return true
}

// the argument a of the parameter p of d; false where it is an error
let gen_arg_to(a:int64, p:int64, d:int64):bool {
    if is_owner(nodes[p].ty) && nodes[a].kind == N_ID && var_type(nodes[a].t) >= 0 {
        put_owner_prefix(nodes[p].ty)
        put("_take(&")
        put_tok(nodes[a].t)
        put(")")
        return true
    }
    if is_owner(nodes[p].ty) && is_place(a) {
        gen_error(a, "an owner moves into a function only as a whole variable: pass a borrow, &..., or a copy")
        return false
    }
    var who = $"'"                                      // a let's borrow where a T^ that may change it goes (#272),
    who += tok_text(nodes[p].t)                         // of an owner too, as kelvinc since #273
    who += "' of '"
    who += tok_text(nodes[d].t)
    who += "'"
    if !fixed_ptr_ok(a, nodes[p].ty, &who) { return false }
    if !takes_borrow(a, nodes[p].ty, &who) { return false }
    let py:int64 = nodes[p].ty
    if py >= 0 && types[py].kind == Y_FIXED {            // an array, which C passes as a pointer (#357)
        if !fixed_arg_ok(a, py, &who) { return false }
        gen_expr(a)
        return true
    }
    gen_value(a, nodes[p].ty)
    return true
}

let gen_args_to(first:int64, d:int64) {
    var a:int64 = first
    var p:int64 = d >= 0 ? nodes[d].a : -1
    while a >= 0 {
        if a != first { put(", ") }
        if p >= 0 {
            if !gen_arg_to(a, p, d) { return }
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
    let k = types[y].kind
    if k == Y_ARRAY || k == Y_SET {
        var s = $"Array<"
        if k == Y_SET { s = $"Set<" }
        let e:String = kelvin_type_text(types[y].elem)
        s += &e
        s += ">"
        return s
    }
    if k == Y_DICT {                                     // (#288)
        var s = $"Dictionary<"
        let key:String = kelvin_type_text(types[y].name)
        s += &key
        s += ", "
        let v:String = kelvin_type_text(types[y].elem)
        s += &v
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
        if nodes[a].kind == N_STR { put("KV_STRING_LIT(") } else { put("KV_STRING_OF(") }   // a literal's every byte (#299)
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
    case Y_BITS: return $"Bits"
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
    case Y_ITER:                                       // (#326)
        var s = $"Iterator_"
        s += mangled(types[y].elem)
        return s
    case Y_RANGE:                                      // (#373)
        var s = $"Range_"
        s += mangled(types[y].elem)
        return s
    case Y_TASK:                                       // (#313)
        var s = $"Task"
        if types[y].elem >= 0 {
            s += "_"
            s += mangled(types[y].elem)
        }
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
    return k == Y_I64 || k == Y_I32 || k == Y_U8 || k == Y_U32 || k == Y_F64 || k == Y_F32 || k == Y_BOOL || k == Y_STRING || k == Y_CSTR || k == Y_BITS
}

// whether print shows y by a _kv_show_T of its own: an enum with values
// (an Optional, a Result), a struct, an Array or a Dictionary (#268)
let shown_by_type(y:int64):bool {
    return y >= 0 && (tagged_of(y) >= 0 || struct_of(y) >= 0 || types[y].kind == Y_ARRAY || types[y].kind == Y_DICT || types[y].kind == Y_SET || types[y].kind == Y_RANGE)
}

// whether print can show a value of y, an enum with values (an Optional, a
// Result), a struct or an Array, as kelvinc does, by a _kv_show_T of its
// own; what it holds is shown too. Where kc cannot show it, n is an error
let need_show(y:int64, n:int64):bool {
    if shown_types.has(y) { return true }
    shown_types[y] = 1
    if types[y].kind == Y_RANGE {                        // 0..<3, as kelvinc prints it (#373)
        shown += y
        return true
    }
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
        var v = nodes[m].ty
        while v >= 0 && types[v].kind == Y_FIXED { v = types[v].elem }   // a member's fixed array, by its elements (#356)
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
    } else if types[y].kind == Y_RANGE {
        put_ctype(y)                                      // _kv_show__kv_range_i64 (#373)
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
var show_depth = 0                       // the loop of a fixed array's elements, nested, in a printer (#356)

let show_value(v:int64, path:cstr, t:int64, level:cstr) {
    let k:ykind = types[v].kind
    if k == Y_FIXED {                                    // [7, 8, 9], every element, as kelvinc prints a member's (#356)
        let d = show_depth
        show_depth += 1
        put("kv_out_put(o, \"[\");\n    for (size_t _kv_i")
        put_int(d)
        put(" = 0; _kv_i")
        put_int(d)
        put(" < sizeof ")
        put_self(path, t)
        put(" / sizeof ")
        put_self(path, t)
        put("[0]; _kv_i")
        put_int(d)
        put("++)\n    {\n    kv_out_sep(o, ")
        put(level)
        put(", _kv_i")
        put_int(d)
        put(" == 0);\n    ")
        var p = String(path)
        if t >= 0 { p += tok_text(t) }
        p += "[_kv_i"
        let ds:String = String(d)
        p += &ds
        p += "]"
        show_value(types[v].elem, p.cstr, 0 - 1, level)
        put("    }\n    kv_out_end(o, ")
        put(level)
        put(");\n    kv_out_put(o, \"]\");\n")
        show_depth -= 1
        return
    }
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
        put(k == Y_BOOL ? "kv_cstr_bool" : k == Y_BITS ? "kv_cstr_bits" : k == Y_U8 || k == Y_U32 ? "kv_cstr_u64" : k == Y_F64 ? "kv_cstr_f64" : k == Y_F32 ? "kv_cstr_f32" : "kv_cstr_i64")
        put("(")
        put_self(path, t)
        put(", _kv_b); kv_out_put(o, _kv_b); }\n")
    }
}

// _kv_show_T of y, as kelvinc writes it: of an enum with values, a case's
// name and what it holds in parentheses; of a struct, {x: 1, y: 2}
// ---------- == of Arrays and Dictionaries (#288) ----------

var compared:$[int64]                       // the types whose T_eq is written, in order

let eq_case(y:int64):int64    // a prototype: what a case holds compares too

// y as kelvinc names it in =='s errors: a struct and an enum with
// values as struct T (#345), the rest as kelvin_type_text
let eq_type_text(y:int64):String {
    if types[y].kind == Y_STRUCT && !is_variant(y) {
        var s = $"struct "
        s += tok_text(types[y].name)
        return s
    }
    return kelvin_type_text(y)
}

var eq_asked:Dictionary<int64, int64>      // the enums with values eq_type is asking of, 1 while it is

// whether values of y compare with ==, as kelvinc's eq_type: an Array or
// a Dictionary where its elements or values do, an Optional, a Result or
// an enum with values where what its cases hold does (#343, #344, #345);
// a Set, an IO or a struct does not. An enum that holds itself, through
// an Array, compares as far as it goes, as kelvinc's no_eq
let eq_type(y:int64):bool {
    if y < 0 { return true }
    let k = types[y].kind
    if k == Y_ARRAY || k == Y_DICT { return eq_type(types[y].elem) }
    if k == Y_FIXED {                                    // a case's, by its elements (#360)
        let e:int64 = types[y].elem
        return is_number_kind(types[e].kind) || types[e].kind == Y_BOOL || types[e].kind == Y_CSTR
    }
    if tagged_of(y) >= 0 {
        if eq_asked.get(y, 0) == 1 { return true }
        eq_asked[y] = 1
        let r = eq_case(y) < 0
        eq_asked[y] = 0
        return r
    }
    if k == Y_SET || k == Y_IO || k == Y_STRUCT { return false }
    return true
}

// the first case of the variant y whose value has no ==, or -1
let eq_case(y:int64):int64 {
    var m = nodes[tagged_of(y)].a
    while m >= 0 {
        if nodes[m].ty >= 0 && !eq_type(nodes[m].ty) { return m }
        m = nodes[m].next
    }
    return 0 - 1
}

// whether T_eq of y is written: an Array's, a Dictionary's, an enum with
// values', an Optional and a Result among them
let has_eq_fn(y:int64):bool {
    return y >= 0 && (types[y].kind == Y_ARRAY || types[y].kind == Y_DICT || tagged_of(y) >= 0)
}

// T_eq of y written after the functions, and of what it holds
let need_eq(y:int64) {
    for i in 0..<compared.count as int64 {
        if compared[i] == y { return }
    }
    compared += y
    if tagged_of(y) < 0 {
        if has_eq_fn(types[y].elem) { need_eq(types[y].elem) }
        return
    }
    var m = nodes[tagged_of(y)].a                    // what each case holds (#344)
    while m >= 0 {
        if has_eq_fn(nodes[m].ty) { need_eq(nodes[m].ty) }
        m = nodes[m].next
    }
}

let put_eq_name(y:int64) {
    if types[y].kind == Y_ARRAY {
        put_array_name(y)
    } else if types[y].kind == Y_DICT {
        put_dict_name(y)
    } else {
        put_owner_prefix(y)                         // an Optional's, _kv_opt_T (#343); a Result's (#344); _kv_T (#345)
    }
    put("_eq")
}

// whether x and y, two values of type y, are equal, in C
let put_eq_code(y:int64, x:cstr, z:cstr) {
    let k = types[y].kind
    if k == Y_STRING {
        put("kv_string_eq(&")
        put(x)
        put(", &")
        put(z)
        put(")")
    } else if k == Y_UCHR {
        put(x)
        put(".cp == ")
        put(z)
        put(".cp")
    } else if k == Y_BITS {                          // by its u64 (#387)
        put(x)
        put(".value == ")
        put(z)
        put(".value")
    } else if k == Y_ARRAY || k == Y_DICT {
        put_eq_name(y)
        put("(&")
        put(x)
        put(", &")
        put(z)
        put(")")
    } else if k == Y_FIXED {                         // element by element, as == compares each (#360)
        put("({ bool _kv_r = true; for (size_t _kv_q = 0; _kv_q < sizeof(")
        put(x)
        put(") / sizeof((")
        put(x)
        put(")[0]); _kv_q++) if (!((")
        put(x)
        put(")[_kv_q] == (")
        put(z)
        put(")[_kv_q])) { _kv_r = false; break; } _kv_r; })")
    } else if k == Y_RANGE {                         // its kind and bounds, lo...'s hi none, as kelvinc's (#376)
        put("((")
        put(x)
        put(").kind == (")
        put(z)
        put(").kind && (")
        put(x)
        put(").lo == (")
        put(z)
        put(").lo && ((")
        put(x)
        put(").kind == 2 || (")
        put(x)
        put(").hi == (")
        put(z)
        put(").hi))")
    } else if tagged_of(y) >= 0 {                    // by value, as kelvinc's (#343, #344, #345)
        put_eq_name(y)
        put("(")
        put(x)
        put(", ")
        put(z)
        put(")")
    } else {
        put(x)
        put(" == ")
        put(z)
    }
}

// a0 == a1 (#247), d0 == d1 (#235), as kelvinc's: two of one type, each
// side an expression gives held; != its negation. The elements, or the
// values, must compare
let gen_container_eq(n:int64) {
    let t = nodes[n].t
    let a = nodes[n].a
    let b = nodes[n].b
    let ya:int64 = type_of(a)
    let yb:int64 = type_of(b)
    var ka:ykind = builtin_kind(ya)
    let dict = ka == Y_DICT || (ka == Y_VOID && builtin_kind(yb) == Y_DICT)
    let lit_a = nodes[a].kind == N_NUM || nodes[a].kind == N_CHAR || nodes[a].kind == N_BOOL
    let lit_b = nodes[b].kind == N_NUM || nodes[b].kind == N_CHAR || nodes[b].kind == N_BOOL
    let ta:String = ya < 0 || lit_a ? $"not one" : kelvin_type_text(ya)
    let tb:String = yb < 0 || lit_b ? $"not one" : kelvin_type_text(yb)
    if ka == Y_VOID || builtin_kind(yb) == Y_VOID || ta != tb {
        var m = $"'"
        let op:String = tok_text(t)
        m += &op
        if dict { m += "' compares two Dictionaries of the same key and value types, and these are " } else { m += "' compares two Arrays of the same element type, and these are " }
        m += &ta
        m += " and "
        m += &tb
        gen_error(n, m.cstr)
        return
    }
    if !eq_type(types[ya].elem) {
        let e:int64 = types[ya].elem
        var m = $"'"
        let op:String = tok_text(t)
        m += &op
        m += "' of "
        if types[e].kind == Y_STRUCT && !is_variant(e) {   // Array<struct P>, as kelvinc names it (#345)
            if dict {
                m += "Dictionary<"
                let kw:String = kelvin_type_text(types[ya].name)
                m += &kw
                m += ", "
            } else {
                m += "Array<"
            }
            let sw:String = eq_type_text(e)
            m += &sw
            m += ">"
        } else {
            m += &ta
        }
        if dict { m += " compares the values, and " } else { m += " compares the elements, and " }
        let et:String = kelvin_type_text(e)
        m += &et
        m += " has no '=='"
        gen_error(n, m.cstr)
        return
    }
    need_eq(ya)
    let ha = needs_hold(a)
    let hb = needs_hold(b)
    if ha { hold_open(a) }
    if hb { hold_open(b) }
    if tok_is(t, "!=") { put("((bool)!") }
    put_eq_name(ya)
    put("(")
    gen_place(a)
    put(", ")
    gen_place(b)
    put(")")
    if tok_is(t, "!=") { put(")") }
    if hb { hold_close(b) }
    if ha { hold_close(a) }
}

// an enum with values' _kv_T_eq, its two by value: an Optional's (#343),
// a Result's (#344), any (#345)
let put_eq_head(y:int64) {
    put("__attribute__((unused)) static inline bool ")
    put_eq_name(y)
    put("(const ")
    put_ctype(y)
    put(" a, const ")
    put_ctype(y)
    put(" b)")
}

// the enum with values either side of a binary operator is, its type,
// or -1; a case word, none, has no type of its own (#343)
let tagged_side(n:int64):int64 {
    let a:int64 = nodes[n].a
    let b:int64 = nodes[n].b
    if !is_case_word(a) && tagged_of(type_of(a)) >= 0 { return type_of(a) }
    if !is_case_word(b) && tagged_of(type_of(b)) >= 0 { return type_of(b) }
    return 0 - 1
}

// whether x, a side of == of the Optional or the Result rt, is a value
// made here that is freed after: one an expression gives, a T wrapped, a
// copy of a place, ok(v) or err(e) (#344); not a place of rt, nor none
let opt_operand_owns(x:int64, rt:int64):bool {
    if !is_owner(rt) { return false }
    if is_case_word(x) { return nodes[x].kind == N_CALL && is_result(rt) }
    if type_of(x) == rt { return !is_place(x) }
    return true
}

// x as a value of the Optional or the Result rt: itself, none read by rt,
// a T wrapped, or ok(v) and err(e) of a Result (#344), a place's value
// copied, so that it is not moved (#343); of another enum, itself (#345)
let gen_opt_operand(x:int64, rt:int64) {
    if !is_case_word(x) && type_of(x) == rt || !is_variant(rt) {
        gen_expr(x)
        return
    }
    var m:int64 = value_case(rt)
    var v = x
    if is_case_word(x) {
        m = case_word_of(x, tagged_of(rt))
        if m < 0 || !is_result(rt) || nodes[x].kind != N_CALL || nodes[x].b < 0 {
            gen_value(x, rt)                             // none, and the errors of a case rt has not
            return
        }
        v = nodes[x].b
    }
    let cy:int64 = nodes[m].ty
    put_owner_prefix(rt)
    put("_make_")
    put_tok(nodes[m].t)
    put("(")
    if is_place(v) && is_owner(cy) {
        put_owner_prefix(cy)
        put("_copy(")
        gen_place(v)
        put(")")
    } else {
        gen_value(v, cy)                                 // text a String, a T a T? of a T?? (#229)
    }
    put(")")
}

let put_opt_operand(x:int64, rt:int64, name:cstr, s:int64) {
    if opt_operand_owns(x, rt) {
        put("__attribute__((cleanup(")
        put_free(rt)
        put("))) ")
    }
    put_ctype(rt)
    put(" ")
    put(name)
    put_int(s)
    put(" = ")
    gen_opt_operand(x, rt)
    put("; ")
}

// what the other side of == of rt, an enum with values, is, where it is
// not one of rt, as kelvinc says it: a literal or a case word is not
// one; else its type (#345)
let enum_mismatch_text(x:int64):String {
    let k:nkind = nodes[x].kind
    let literal = k == N_NUM || k == N_CHAR || k == N_BOOL || k == N_STR || (k == N_UNARY && tok_is(nodes[x].t, "-") && nodes[nodes[x].a].kind == N_NUM)
    if literal || is_case_word(x) { return $"not one" }
    return eq_type_text(type_of(x))
}

// a == b, x != none of an Optional, r == err(e) of a Result, as kelvinc's
// #79: the same case, and equal values, by _kv_T_eq; the other side one of
// rt, a T wrapped, none, ok(v) or err(e). Each side is read once, and one
// made here is freed after (#343, #344). Of another enum with values, the
// other side is one of rt (#345)
let gen_variant_eq(n:int64, rt:int64) {
    let t:int64 = nodes[n].t
    let a:int64 = nodes[n].a
    let b:int64 = nodes[n].b
    let ow:String = eq_type_text(rt)
    if !tok_is(t, "==") && !tok_is(t, "!=") {         // as kelvinc says it
        var m = ow.copy()
        m += " has no operator '"
        m += tok_text(t)
        m += "': compare with == and !="
        if !is_variant(rt) {                         // one of its own is kelvinc's, not kc's
            m += "; an operator of its own, as 'let "
            m += tok_text(t)
            m += "(a:T, b:T):T { ... }' (#121), is not kc's yet"
        }
        gen_error(n, m.cstr)
        return
    }
    let c:int64 = eq_case(rt)
    var m = $"'"
    m += tok_text(t)
    if c >= 0 {
        let inner:int64 = nodes[c].ty
        m += "' of "
        m += &ow
        m += " compares the values, and case '"
        m += tok_text(nodes[c].t)
        m += "' holds "
        let iw:String = kelvin_type_text(inner)
        m += &iw
        m += ", which has no '=='"
        gen_error(n, m.cstr)
        return
    }
    var bad = $""
    if is_variant(rt) {
        bad = value_mismatch_text(a, rt)
        if bad.count == 0 { bad = value_mismatch_text(b, rt) }
    } else {
        let other:int64 = !is_case_word(a) && type_of(a) == rt ? b : a
        if is_case_word(other) || type_of(other) != rt { bad = enum_mismatch_text(other) }
    }
    if bad.count > 0 {
        m += "' compares two "
        m += &ow
        m += ", and this is "
        m += &bad
        gen_error(n, m.cstr)
        return
    }
    need_eq(rt)
    serial += 1
    let s = serial                                   // its own: a side may make names too
    put("({ ")
    put_opt_operand(a, rt, "_kv_ea", s)
    put_opt_operand(b, rt, "_kv_eb", s)
    if tok_is(t, "!=") { put("(bool)!") }
    put_eq_name(rt)
    put("(_kv_ea")
    put_int(s)
    put(", _kv_eb")
    put_int(s)
    put("); })")
}

// T_eq of y, as kelvinc's emit_array_eq and emit_dict_eq; an enum with
// values' as its _kv_T_eq of #79: the same case, and equal values (#343,
// #344, #345)
let gen_eq(y:int64) {
    if tagged_of(y) >= 0 {
        put_eq_head(y)
        put("\n{\n    if (a.tag != b.tag) return false;\n    switch (a.tag)\n    {\n")
        var m = nodes[tagged_of(y)].a
        var i = 0
        while m >= 0 {
            if nodes[m].ty >= 0 {
                put("    case ")
                put_int(i)
                put(": return ")
                var x = $"a.u."
                x += tok_text(nodes[m].t)
                var z = $"b.u."
                z += tok_text(nodes[m].t)
                put_eq_code(nodes[m].ty, x.cstr, z.cstr)
                put(";\n")
            }
            i += 1
            m = nodes[m].next
        }
        put("    default: return true;\n    }\n}\n")
        return
    }
    put("__attribute__((unused)) static inline bool ")
    put_eq_name(y)
    put("(const ")
    put_owner_prefix(y)
    put(" *a, const ")
    put_owner_prefix(y)
    put(" *b)\n{\n    if (a->count != b->count) return false;\n")
    if types[y].kind == Y_ARRAY {
        put("    for (size_t i = 0; i < a->count; i++)\n        if (!(")
        put_eq_code(types[y].elem, "a->at[i]", "b->at[i]")
        put(")) return false;\n")
    } else {
        put("    for (size_t i = 0; i < a->len; i++)\n    {\n        if (!a->at[i].live) continue;\n        const ")
        put_dict_name(y)
        put("_entry *e = ")
        put_dict_name(y)
        if types[types[y].name].kind == Y_STRING {
            put("_lookup(b, KV_LK_TEXT(&a->at[i].key), a->at[i].hash);\n")
        } else {
            put("_lookup(b, KV_LK_INT(&a->at[i].key), a->at[i].hash);\n")
        }
        put("        if (!e || !(")
        put_eq_code(types[y].elem, "a->at[i].value", "e->value")
        put(")) return false;\n    }\n")
    }
    put("    return true;\n}\n")
}

let gen_show(y:int64) {
    put("static void ")
    put_show_name(y)
    put("(kv_out *o, const void *_kv_v, int level)\n{\n    const ")
    if types[y].kind == Y_RANGE {                         // 0..<3, 1...3, 0..., which paste back, as kelvinc's (#373)
        put_ctype(y)
        put(" *self = _kv_v;\n    (void)level;\n    ")
        show_value(types[y].elem, "lo", 0 - 1, "level")
        put("    kv_out_put(o, self->kind ? \"...\" : \"..<\");\n    if (self->kind != 2)\n    {\n    ")
        show_value(types[y].elem, "hi", 0 - 1, "level")
        put("    }\n}\n\n")
        return
    }
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
        if y >= 0 && types[y].kind == Y_FIXED && nodes[a].kind != N_LIST {   // kelvinc prints its address (#354)
            gen_error(a, "a fixed array is printed by its elements, a[i]: kc does not print the array, whose address kelvinc prints")
            return
        }
        if y >= 0 && types[y].kind == Y_TASK {                   // as kelvinc's (#313)
            var m = $"a Task has no text: print its value, 'await "
            m += nodes[a].kind == N_ID ? tok_text(nodes[a].t) : $"t"
            m += "'"
            gen_error(a, m.cstr)
            return
        }
        let pr:int64 = nodes[a].kind == N_FIELD && tok_is(nodes[a].t, "pretty") ? type_of(nodes[a].a) : 0 - 1
        if pr >= 0 && (types[pr].kind == Y_SET || types[pr].kind == Y_DICT) && need_show(pr, a) {   // s.pretty where print shows it, written in place (#336, #337)
            put("({ __auto_type _kv_sv = (")
            gen_expr(nodes[a].a)
            put("); ")
            put_show_name(pr)
            put("(&(kv_out){.fp = NULL, .width = 2}, &_kv_sv, 0); (const uint8_t *)\"\"; })")
        } else if !is_case_word(a) && shown_by_type(y) && need_show(y, a) {
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

let refuse_valueless_args(n:int64):bool    // a prototype: each call asks it (#317)

let gen_call(n:int64) {
    let f:int64 = nodes[n].a
    let args:int64 = nodes[n].b
    if refuse_valueless_args(n) { return }
    if nodes[f].kind == N_TYPE {
        if tok_is(nodes[f].t, "IO") {
            put("kv_io_open(")
            gen_expr(args)
            put(", ")
            gen_expr(nodes[args].next)
            put(")")
        } else {
            if nodes[args].kind == N_STR { put("KV_STRING_LIT(") } else { put("KV_STRING_OF(") }   // (#299)
            gen_expr(args)
            put(")")
        }
        return
    }
    if tok_is(nodes[f].t, "println") || tok_is(nodes[f].t, "print") {
        var each:int64 = args
        while each >= 0 {                          // a lazy Sequence has no text, as kelvinc's (#324)
            let ey:int64 = type_of(each)
            if ey >= 0 && types[ey].kind == Y_ITER {      // as kelvinc's (#326)
                gen_error(each, "an Iterator has no text: walk it with for, or gather it, as in '.map { $0 }'")
                return
            }
            if is_lazy_type(ey) {
                var m = tok_text(nodes[f].t)
                m += " cannot show a lazy Sequence, whose values are made only as they are asked for: walk it with for, or fold it, as in '.reduce'"
                gen_error(each, m.cstr)
                return
            }
            each = nodes[each].next
        }
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
    if y >= 0 && (types[y].kind == Y_CSTR || types[y].kind == Y_PTR) && !tok_is(nodes[n].t, "typename") {   // a type's name is text of its own (#336)
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
    if types[y].kind == Y_SET { return tok_is(t, "elements") || tok_is(t, "pretty") }   // a new String too (#336)
    return types[y].kind == Y_DICT && (tok_is(t, "keys") || tok_is(t, "values") || tok_is(t, "pretty"))   // (#337)
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
    let lent = is_place(a) || held.get(a, 0 - 1) >= 0    // a place, or one held in a temporary (#227)
    if tagged_of(y) >= 0 && !lent && is_owner(y) {      // of a call's enum that owns, which would go unfreed (#360)
        gen_error(n, "kc reads a case's value of an enum that owns where a variable holds it: bind it first, 'let v = f()'")
        return
    }
    if tagged_of(y) >= 0 {                             // v.c, checked
        put("(*_kv_")
        put_tok(types[y].name)
        put("_at_")
        put_tok(t)
        put("(")
        if lent {
            gen_place(a)
        } else {                                       // of a call's: a one-element array's, as kelvinc (#360)
            put("(const struct ")
            put_tok(types[y].name)
            put("[]){")
            gen_expr(a)
            put("}")
        }
        put("))")
        return
    }
    let yk:ykind = types[y].kind
    let fixed_ptr = yk == Y_PTR && types[types[y].elem].kind == Y_FIXED   // q.count of a [T](N)^, as kelvinc says it (#362)
    if yk == Y_FIXED && types[y].name == 0 - 1 && (tok_is(t, "count") || tok_is(t, "size")) {   // q^.count of a [T]^, where kelvinc's C fails (#363)
        var m = type_text(y)
        m += " has no count, which C does not keep: pass it beside it"
        gen_error(n, m.cstr)
    } else if (yk == Y_FIXED && (types[y].name == 0 - 2 || types[y].name == 0 - 4) || fixed_ptr) && (tok_is(t, "count") || tok_is(t, "size")) {   // a parameter's, as kelvinc says it (#357)
        var m = $"'."
        m += tok_text(t)
        m += "' is a property of arrays, and this is "
        let w:String = type_text(y)
        m += &w
        m += ", a pointer: an array passed to a function is one, so its count is passed beside it"
        gen_error(n, m.cstr)
    } else if yk == Y_FIXED && tok_is(t, "count") {      // a fixed array's, as kelvinc's (#354)
        put("((int64_t)(sizeof(")
        gen_expr(a)
        put(") / sizeof((")
        gen_expr(a)
        put(")[0])))")
    } else if yk == Y_FIXED && tok_is(t, "size") {
        put("((int64_t)sizeof(")
        gen_expr(a)
        put("))")
    } else if tok_is(t, "count") && (yk == Y_STRING || yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET) {
        put("((int64_t)(")
        gen_expr(a)
        put(").count)")
    } else if yk == Y_SET && tok_is(t, "elements") {     // s.elements (#278): an Array of copies, in the order added
        gen_slots_array(a, y, types[y].elem, false)
    } else if (yk == Y_SET || yk == Y_DICT) && tok_is(t, "pretty") {   // s.pretty, d.pretty (#336, #337), as kelvinc's: its text indented, a new String
        if !need_show(y, n) { return }
        put("({ kv_string _kv_ps = kv_string_new(); __auto_type _kv_sv = (")
        gen_expr(a)
        put("); ")
        put_show_name(y)
        put("(&(kv_out){.s = &_kv_ps, .width = 2}, &_kv_sv, 0); _kv_ps; })")
    } else if (yk == Y_SET || yk == Y_DICT) && tok_is(t, "typename") {   // s.typename, d.typename (#336, #337): its type's name, text
        put("\"")
        let w:String = kelvin_type_text(y)
        out += &w
        put("\"")
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
let gen_lazy_make(n:int64)    // a prototype: a lazy Sequence (#324)

let gen_method(n:int64) {
    let il:int64 = iter_lazy_of(n)
    if il >= 0 {                                        // it.lazy.map(f) of an Iterator (#328)
        gen_iter_value(il)
        return
    }
    let ip:int64 = iter_prefix_of(n)
    if ip >= 0 {                                        // it.prefix(n), it.prefix { ... } (#372)
        gen_iter_value(ip)
        return
    }
    if prefix_of(n) >= 0 {                              // xs.prefix(n), xs.prefix { ... } (#372)
        gen_prefix(n)
        return
    }
    if lazy_of(n) >= 0 {                                // s.lazy.map(f), s.lazy.filter(f) (#324)
        gen_lazy_make(n)
        return
    }
    if eager_of(n) >= 0 {                               // xs.map(f) and the rest (#329)
        gen_eager(n)
        return
    }
    if (tok_is(nodes[n].t, "merge") || tok_is(nodes[n].t, "merging")) && merge_of(n) >= 0 {   // (#338)
        gen_merge(n)
        return
    }
    if search_of(n) >= 0 {                              // d.contains(v), d.firstKey(v) and the rest (#339)
        gen_search(n)
        return
    }
    let ny:int64 = tok_is(nodes[n].t, "next") ? type_of(nodes[n].a) : 0 - 1
    if ny >= 0 && types[ny].kind == Y_ITER {             // it.next() of an Iterator (#326), on a var
        let lead = $"'.next' is a var method, which changes "
        if !changes_var(nodes[n].a, &lead) { return }
        if !changeable_place(nodes[n].a) {
            gen_error(n, "'.next' is a var method, which changes the value it is called on, so that value is a variable")
            return
        }
        put("({ ")
        put_ctype(optional_of(types[ny].elem))
        put(" _kv_nv; kv_iter_next(&(")
        gen_expr(nodes[n].a)
        put("), &_kv_nv); _kv_nv; })")
        return
    }
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
    if refuse_valueless_args(n) { return }
    let f:int64 = method_of(n)
    if f >= 0 {                                                       // T__m(x, ...), T__f(...) (#213)
        if nodes[f].flag == 2 {                                       // a var method's receiver, a var (#320)
            var lead = $"'."
            lead += tok_text(t)
            lead += "' is a var method, which changes "
            if !changes_var(a, &lead) { return }
            if !changeable_place(a) {
                lead += "the value it is called on, so that value is a variable"
                gen_error(n, lead.cstr)
                return
            }
        }
        put_tok(nodes[f].c)
        put("__")
        put_tok(nodes[f].t)
        put("(")
        if nodes[f].flag == 2 {                                       // by its address, T__m(&(x), ...)
            gen_place(a)
            if nodes[n].b >= 0 { put(", ") }
        } else if nodes[f].flag != 1 {
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
        let cm:int64 = case_named(e, t) ?? 0 - 1
        if v >= 0 && nodes[v].kind == N_ID && is_owner(type_of(v)) {   // a local owner moves in
            put_owner_prefix(type_of(v))
            put("_take(&")
            put_tok(nodes[v].t)
            put(")")
        } else if v >= 0 && cm >= 0 && fixed_case(cm) {   // a fixed array's elements, by their type (#360)
            gen_value(v, nodes[cm].ty)
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
    } else if yk == Y_STRING && (tok_is(t, "escape") || tok_is(t, "unescape")) {
        if nodes[n].b >= 0 {                            // s.escape(), s.unescape() (#300): kelvinc's, with no RegExp
            var m = $"'."
            m += tok_text(t)
            m += "' takes 0 arguments"
            gen_error(n, m.cstr)
            return
        }
        put("kv_string_")
        put_tok(t)
        put("(")
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
    } else if yk == Y_SET && (tok_is(t, "clear") || tok_is(t, "reserve")) {   // s.clear(), s.reserve(n) (#336), in place
        if !may_change(a) { return }
        put_set_name(y)
        put("_")
        put_tok(t)
        put("(")
        gen_place(a)
        if tok_is(t, "reserve") {
            put(", ")
            gen_expr(nodes[n].b)
        }
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
    } else if yk == Y_DICT && (tok_is(t, "clear") || tok_is(t, "reserve")) {   // d.clear(), d.reserve(n) (#337), in place
        if !may_change(a) { return }
        put_dict_name(y)
        put("_")
        put_tok(t)
        put("(")
        gen_place(a)
        if tok_is(t, "reserve") {
            put(", ")
            gen_expr(nodes[n].b)
        }
        put(")")
    } else if yk == Y_DICT && (tok_is(t, "has") || tok_is(t, "get") || tok_is(t, "remove") || tok_is(t, "find")) {   // d.has(k), d.get(k, v) (#211), d.remove(k) (#270), d.find(k) (#337)
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
    if k == N_FIELD && tagged_named(nodes[n].a) >= 0 { return false }   // T.none, a case made here (#345)
    if is_made_array(n) { return false }                     // s.elements, d.keys, a new Array (#278, #285)
    if is_slice(n) { return false }                          // xs[r], a new one (#377)
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
    if is_range_eq(n) {                                  // (#376)
        gen_range_eq(n)
        return
    }
    if range_operand_error(n) { return }                 // a Range has no operators (#373) but == and != (#376)
    if nodes[n].kind == N_BIN && is_comparison(nodes[n].t) {
        let y:int64 = type_of(nodes[n].a)
        let owners = tagged_side(n) >= 0 || builtin_kind(y) != Y_VOID || builtin_kind(type_of(nodes[n].b)) != Y_VOID   // an Optional's == (#343), String ==, xs == ys (#288), refusals (#287)
        if !owners {
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
let gen_array(n:int64, given:int64)    // a prototype: Array<T>([a, b]) is $[a, b] of T (#350)
let gen_dict(n:int64, given:int64)     // and Dictionary<K, V>({k: v}) ${k: v} of K and V (#351)

// Array<T>() and Dictionary<K, V>(), an empty one, as kelvinc's #57 and
// #65: C's compound literal of its type. Without (), and with the
// entries or a copy of a Dictionary, which kc does not make yet, an
// error (#349). Of an Array (#350), as kelvinc's #57 and #58: [a, b] the
// elements, as $[a, b] of T; &a a copy of another, by _copy; n, a count,
// as many zero elements, by _zeros. Of a Dictionary (#351), as kelvinc's
// #65: {k: v} the entries, as ${k: v} of K and V; &d a copy of another
// Dictionary<K, V>({k: v}) and Dictionary<K, V>(&d), as kelvinc's #65
// (#351): the literal as ${...} of y, its errors as kelvinc says them;
// a copy of the Dictionary &d lends, by _copy
let gen_make_dict(n:int64, y:int64, w:const String^) {
    let x:int64 = nodes[n].a
    if nodes[n].flag == 0 {                              // Dictionary<K, V>(), an empty one (#349)
        put("(")
        put_ctype(y)
        put("){0}")
        return
    }
    if nodes[n].flag == 6 {
        var m = $"expected ')', found '"
        m += tok_text(nodes[n].c)
        m += "'"
        gen_error(n, m.cstr)
        return
    }
    if nodes[n].flag == 3 && nodes[x].kind == N_EMPTY {
        if nodes[x].flag == 1 {
            gen_error(x, "an empty Dictionary is written ${:}")
            return
        }
        put("(")
        put_ctype(y)
        put("){0}")
        return
    }
    if nodes[n].flag == 3 && nodes[x].kind == N_SET {
        gen_error(x, "an entry of a Dictionary is written key: value")
        return
    }
    if nodes[n].flag == 3 {
        gen_dict(x, y)
        return
    }
    let p:int64 = nodes[n].flag == 4 ? nodes[x].a : 0 - 1
    if p < 0 || type_of(p) != y {
        var m = w^.copy()
        m += " takes nothing, the entries in {k: v, ...}, or a borrow of another, '&d'"
        gen_error(x, m.cstr)
        return
    }
    let h = needs_hold(p)                                // one an expression gives, held and freed after
    if h { hold_open(p) }
    put_dict_name(y)
    put("_copy(")
    gen_place(p)
    put(")")
    if h { hold_close(p) }
}

// an Array of the fixed array x's elements, as kelvinc's #57 and #58:
// _from of it and its count; of another element type, kc's error, where
// kelvinc's C warns; of fixed arrays, kelvinc's (#355)
let gen_from_fixed(x:int64, y:int64) {
    let fy:int64 = type_of(x)
    let fe:int64 = types[fy].elem
    if fixed_inside(fe) {                                // as kelvinc says it
        var m = $"an Array of "
        let ew:String = type_text(fe)
        m += &ew
        m += " is not here yet: an element is a value C returns"
        gen_error(x, m.cstr)
        return
    }
    if y >= 0 && fe != types[y].elem {
        let w:String = kelvin_type_text(y)
        var m = w.copy()
        m += "(a) takes a fixed array of "
        let ew:String = kelvin_type_text(types[y].elem)
        m += &ew
        m += ", and this is "
        let fw:String = type_text(fy)
        m += &fw
        gen_error(x, m.cstr)
        return
    }
    let ay:int64 = y >= 0 ? y : type_of_kind(Y_ARRAY, fe, -1)
    put_array_name(ay)
    put("_from(")
    gen_expr(x)
    put(", sizeof(")
    gen_expr(x)
    put(") / sizeof((")
    gen_expr(x)
    put(")[0]))")
}

// Array([a, b]), T the elements' one type, as kelvinc's #58 and as
// $[a, b] (#352); Array(&a), a copy of the Array a, of its type (#353);
// Array() and the rest kelvinc's errors in its words
let gen_make_inferred(n:int64) {
    let f:int64 = nodes[n].flag
    if f == 0 {
        gen_error(n, "Array() has no element type: write Array<T>(), or the elements, Array([...])")
    } else if f == 3 && nodes[n].b < 0 {
        gen_error(n, "Array([]) has no element type: write Array<T>()")
    } else if f == 3 {
        var e:int64 = nodes[n].b
        let y:int64 = is_case_word(e) ? 0 - 1 : type_of(e)
        while e >= 0 {
            if is_case_word(e) || type_of(e) != y || y < 0 {
                gen_error(n, "the elements have no one type kc sees here: write Array<T>([...])")
                return
            }
            e = nodes[e].next
        }
        gen_array(n, type_of(n))
    } else if f == 4 && type_of(n) >= 0 {               // a copy, by its _copy, as Array<T>(&a) (#350, #353)
        let p:int64 = nodes[nodes[n].a].a
        let h = needs_hold(p)                            // one an expression gives, held and freed after
        if h { hold_open(p) }
        put_array_name(type_of(n))
        put("_copy(")
        gen_place(p)
        put(")")
        if h { hold_close(p) }
    } else if f == 5 && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_FIXED {   // Array(a) of a fixed array (#355)
        gen_from_fixed(nodes[n].a, 0 - 1)
    } else if f == 4 || f == 5 {                         // as kelvinc says it of what is no Array
        gen_error(n, "Array(x) has no element type: write Array<T>(x), or the elements, Array([...])")
    } else if f == 6 {
        gen_error(n, "Array([...]) takes the elements alone: expected ')'")
    } else {
        gen_error(n, "Array takes nothing, a count, the elements in [...], a fixed array, or a borrow of an Array")
    }
}

let gen_make(n:int64) {
    if nodes[n].ty < 0 {                                 // Array([a, b]) (#352)
        gen_make_inferred(n)
        return
    }
    let y:int64 = nodes[n].ty
    let w:String = kelvin_type_text(y)
    if nodes[n].flag == 1 {                              // as kelvinc says it
        var m = w.copy()
        m += " is a type: make one with "
        m += &w
        m += "(), or write it after ':'"
        gen_error(n, m.cstr)
        return
    }
    if nodes[n].flag == 2 {
        var m = w.copy()
        m += " takes nothing, a count, the elements in [...], a fixed array, or a borrow of another"
        gen_error(n, m.cstr)
        return
    }
    if types[y].kind == Y_DICT {                         // (#351)
        gen_make_dict(n, y, &w)
        return
    }
    if nodes[n].flag == 6 {                              // as kelvinc says it (#350)
        gen_error(n, "Array([...]) takes the elements alone: expected ')'")
        return
    }
    if nodes[n].flag == 7 {
        gen_error(n, "Array<T> takes nothing, a count, the elements in [...], a fixed array, or a borrow of an Array")
        return
    }
    if nodes[n].flag == 3 {                              // the elements, each of T (#350)
        gen_array(n, y)
        return
    }
    let x:int64 = nodes[n].a
    if nodes[n].flag == 4 {                              // a copy of the Array that &a lends
        let p:int64 = nodes[x].a
        if type_of(p) != y {
            var m = w.copy()
            m += "(&a) copies an "
            m += &w
            m += ", and this lends "
            let pw:String = type_of(p) >= 0 ? kelvin_type_text(type_of(p)) : $"not one"
            m += &pw
            gen_error(x, m.cstr)
            return
        }
        let h = needs_hold(p)                            // one an expression gives, held and freed after
        if h { hold_open(p) }
        put_array_name(y)
        put("_copy(")
        gen_place(p)
        put(")")
        if h { hold_close(p) }
        return
    }
    if nodes[n].flag == 5 && type_of(x) >= 0 && types[type_of(x)].kind == Y_FIXED {   // Array<T>(a) of a fixed array (#355)
        gen_from_fixed(x, y)
        return
    }
    if nodes[n].flag == 5 {                              // a count of zero elements
        let xy:int64 = type_of(x)
        if xy >= 0 && is_owner(xy) && is_place(x) {      // as kelvinc says it
            gen_error(x, "Array<T>(a) would copy an owner: write a.copy(), or Array<T>(&a)")
            return
        }
        let k:nkind = nodes[x].kind
        if k == N_STR || (xy >= 0 && !is_number_kind(types[xy].kind) && types[xy].kind != Y_BOOL && types[xy].kind != Y_C) {
            var m = w.copy()
            m += "(n) takes a count, and this is "
            let xw:String = k == N_STR ? $"text" : kelvin_type_text(xy)
            m += &xw
            gen_error(x, m.cstr)
            return
        }
        put_array_name(y)
        put("_zeros(")
        gen_expr(x)
        put(")")
        return
    }
    put("(")
    put_ctype(y)
    put("){0}")
}

// whether v, $[], ${:} or ${}, is of y's kind: an Array, a Dictionary,
// a Set (#348)
let empty_fits(v:int64, y:int64):bool {
    if y < 0 { return false }
    let k:ykind = types[y].kind
    if tok_is(nodes[v].t, "$[") { return k == Y_ARRAY }
    if nodes[v].flag == 1 { return k == Y_SET }
    return k == Y_DICT
}

// $[], ${:} or ${} where no type of its kind is written, as kelvinc says
// it (#348)
let empty_error(v:int64) {
    if tok_is(nodes[v].t, "$[") {
        gen_error(v, "Array([]) has no element type: write Array<T>()")
    } else if nodes[v].flag == 1 {
        gen_error(v, "${} has no element type here: write Set<T>(), or give the variable a type, as in 'var s:${String} = ${}'")
    } else {
        gen_error(v, "${:} has no key and value types here: write Dictionary<K, V>(), or give the variable a type, as in 'var d:${String: i64} = ${:}'")
    }
}

// whether the fixed array y may be member f of a struct: counted, of
// numbers, bools, text or structs that own nothing, as a local's (#356)
let member_fixed_ok(f:int64, y:int64, what:cstr):bool {
    var g:int64 = y
    while types[g].kind == Y_FIXED {
        if types[g].name < 0 {
            var m = type_text(g)
            m += " as "
            m += what
            m += " takes its count: write ["
            let ew:String = type_text(types[g].elem)
            m += &ew
            m += "](N)"
            gen_error(f, m.cstr)
            return false
        }
        g = types[g].elem
    }
    if is_owner(g) && !fixed_inside(g) { return true }   // owners, as kelvinc's struct holds them (#364)
    if !fixed_elem_ok(y) {
        fixed_refused(f)
        return false
    }
    return true
}

// v where its type y is written, of a declaration, an element or a
// member: $[], ${:} and ${} are taken here alone, of y's kind, as kelvinc
// takes them (#348); else gen_value. A member's fixed array takes [a, b]
// and [T](n) (#356)
let gen_written(v:int64, y:int64) {
    if y >= 0 && types[y].kind == Y_FIXED {
        if nodes[v].kind == N_LIST && nodes[v].flag == 0 {
            if fixed_list_fits(v, y) { gen_fixed_list(v, y) }
        } else if nodes[v].kind == N_LIST && type_of(v) == y {
            put("{0}")
        } else {
            gen_error(v, "an array is not copied by '=': read its elements, a[i]; ':=' of one is not kc's yet")
        }
        return
    }
    if nodes[v].kind != N_EMPTY {
        gen_value(v, y)
        return
    }
    if !empty_fits(v, y) {
        let k:ykind = y >= 0 ? types[y].kind : Y_VOID
        if k == Y_SET && !tok_is(nodes[v].t, "$[") {        // as kelvinc says it
            gen_error(v, "an empty Set is written ${}; ${:} is an empty Dictionary")
        } else if k == Y_DICT && nodes[v].flag == 1 {
            gen_error(v, "an empty Dictionary is written ${:}")
        } else {
            empty_error(v)
        }
        return
    }
    put("{0}")
}

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
        gen_written(a, nodes[f].ty)                      // ${:} of a member (#348)
        a = nodes[a].next
        f = nodes[f].next
    }
    put("}")
}

// a case's value made where an enum with values is expected (#217): none,
// ok(v), err(e) by the type that takes them, and a T where a T? goes as
// some(T), where a Result goes as ok(T) (#344), as kelvinc has them, whose some(v) is a pattern alone; a local
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
    if fixed_inside(types[y].elem) {                     // $[a, b] of fixed arrays, as kelvinc says it (#355)
        var m = $"an Array of "
        let ew:String = type_text(types[y].elem)
        m += &ew
        m += " is not here yet: an element is a value C returns"
        gen_error(n, m.cstr)
        return
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
        if is_owner(elem) && is_place(e) && !is_case_word(e) {   // none is no place (#343)
            gen_error(e, "an owner is not copied by '=' (#54): copy it with .copy()")
            return
        }
        if given >= 0 {                                  // of the type written, as kelvinc says it (#350)
            let bad:String = value_mismatch_text(e, elem)
            if bad.count > 0 {
                var m = $"an element of "
                let aw:String = kelvin_type_text(y)
                m += &aw
                m += " is "
                let ew:String = kelvin_type_text(elem)
                m += article_of(&ew)
                m += " "
                m += &ew
                m += ", and this is "
                m += &bad
                gen_error(e, m.cstr)
                return
            }
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
        gen_written(e, elem)
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

// whether the entries of ${k: v} fit y, a Dictionary written: each key
// text of a String key, else an integer, as kelvinc says it; each value
// one of V, in kc's words, where kelvinc leaves it to C (#351)
let dict_entries_fit(n:int64, y:int64):bool {
    let key:int64 = types[y].name
    let yw:String = kelvin_type_text(y)
    var k = nodes[n].b
    while k >= 0 {
        let v:int64 = nodes[k].next
        let kk:nkind = nodes[k].kind
        let ky:int64 = kk == N_STR || kk == N_NUM ? 0 - 1 : type_of(k)
        let kind:ykind = ky >= 0 ? types[ky].kind : Y_VOID
        if types[key].kind == Y_STRING {
            if kk != N_STR && kind != Y_STRING && kind != Y_CSTR {
                var m = $"a key of "
                m += &yw
                m += " is text: a cstr, a template, or a String"
                gen_error(k, m.cstr)
                return false
            }
        } else {
            let integer = (kk == N_NUM && !float_tok(nodes[k].t)) || kind == Y_I64 || kind == Y_I32 || kind == Y_U8 || kind == Y_U32
            if !integer {
                var m = $"a key of "
                m += &yw
                m += " is an integer"
                if ky >= 0 {
                    m += ", not "
                    let kw:String = kelvin_type_text(ky)
                    m += &kw
                }
                gen_error(k, m.cstr)
                return false
            }
        }
        let bad:String = value_mismatch_text(v, types[y].elem)
        if bad.count > 0 {
            var m = $"a value of "
            m += &yw
            m += " is "
            let ew:String = kelvin_type_text(types[y].elem)
            m += article_of(&ew)
            m += " "
            m += &ew
            m += ", and this is "
            m += &bad
            gen_error(v, m.cstr)
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
    if given >= 0 && !dict_entries_fit(n, y) { return }   // of the types written (#351)
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
        if is_owner(elem) && is_place(v) && !is_case_word(v) {   // none is no place (#343)
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
        gen_written(v, elem)
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
    if nodes[n].kind == N_RANGE && y >= 0 {             // a range where a Range<T> or a Range<T>? goes is of T (#373)
        let ry:int64 = types[y].kind == Y_RANGE ? y : some_type(y)
        if ry >= 0 && types[ry].kind == Y_RANGE { nodes[n].ty = ry }
    }
    if y >= 0 && types[y].kind == Y_FIXED && nodes[n].kind == N_LIST {   // a case's [a, b], C's compound literal (#360)
        if nodes[n].flag == 0 && !fixed_list_fits(n, y) { return }
        if nodes[n].flag == 1 && type_of(n) != y {
            gen_error(n, "an array is not copied by '=': read its elements, a[i]; ':=' of one is not kc's yet")
            return
        }
        put("(")
        put_fixed_base(y)
        put_fixed_counts(y)
        put(")")
        if nodes[n].flag == 0 { gen_fixed_list(n, y) } else { put("{0}") }
        return
    }
    if y >= 0 && types[y].kind == Y_TASK {              // a Task of the value written (#313)
        let given:int64 = type_of(n)
        if given >= 0 && given != y {
            var m = nodes[n].kind == N_ASYNC ? $"this call gives " : $"this is "
            let g:String = type_text(given)
            m += &g
            m += nodes[n].kind == N_ASYNC ? ", and " : ", where "
            let w:String = type_text(y)
            m += &w
            m += nodes[n].kind == N_ASYNC ? " is wanted here" : " goes"
            gen_error(n, m.cstr)
            return
        }
    }
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
        put("KV_STRING_LIT(")                            // its every byte, a NUL too (#299)
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
    if m < 0 && is_case_word(n) {                       // a case the type has not, as kelvinc says it (#341)
        let w:int64 = nodes[n].kind == N_ID ? nodes[n].t : nodes[nodes[n].a].t
        let result = nodes[d].c != 1 && tok_is(nodes[nodes[d].a].t, "ok") && tok_is(nodes[nodes[nodes[d].a].next].t, "err")
        if nodes[d].c == 1 && (tok_is(w, "ok") || tok_is(w, "err")) {
            var e = $"an Optional has no case '"
            e += tok_text(w)
            e += "': its cases are none and some; a Result has ok and err"
            gen_error(n, e.cstr)
            return
        }
        if result && tok_is(w, "none") {
            gen_error(n, "a Result has no case 'none': write err(e), or ok(v)")
            return
        }
        if result && tok_is(w, "some") {                  // as kelvinc says it (#344)
            gen_error(n, "a Result has no case 'some': write ok(v), or err(e) (#224)")
            return
        }
    }
    var v = -1
    if m >= 0 && nodes[n].kind == N_CALL { v = nodes[n].b }
    if m < 0 && value_case(y) >= 0 && fits_value(n, wrap_type(y)) {   // a T as some(T), and as ok(T) of a Result (#344)
        m = value_case(y)
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
    let b:int64 = nodes[n].b
    if type_of(b) != y {                             // y's type in Kelvin's words, as kelvinc's (#340)
        let bad:String = value_mismatch_text(b, inner)
        if bad.count > 0 {
            var m = $"'??' of "
            let ow:String = kelvin_type_text(y)
            m += &ow
            m += " falls back to "
            let iw:String = kelvin_type_text(inner)
            m += article_of(&iw)
            m += " "
            m += &ow
            m += " or "
            m += article_of(&iw)
            m += " "
            m += &iw
            m += ", and this is "
            m += &bad
            gen_error(b, m.cstr)
            return
        }
    }
    serial += 1
    let s = serial                                   // its own: x may make names too (#221)
    put("({ ")
    put_ctype(y)
    put(" _kv_o")
    put_int(s)
    put(" = ")
    gen_expr(nodes[n].a)
    if is_owner(inner) {                             // as kelvinc's #250: x's value a copy where x is a place, else taken; y a copy where it is a place, else taken, made only where x has none (#340)
        put("; ")
        put_ctype(inner)
        put(" _kv_r")
        put_int(s)
        put("; if (_kv_o")
        put_int(s)
        put(".tag == 1) _kv_r")
        put_int(s)
        put(" = ")
        if is_place(nodes[n].a) {
            put_owner_prefix(inner)
            put("_copy(&_kv_o")
            put_int(s)
            put(".u.some)")
        } else {
            put("_kv_o")
            put_int(s)
            put(".u.some")
        }
        put("; else _kv_r")
        put_int(s)
        put(" = ")
        if is_owner(type_of(b)) && is_place(b) {
            put_owner_prefix(inner)
            put("_copy(&(")
            gen_expr(b)
            put("))")
        } else {
            gen_value(b, inner)
        }
        put("; _kv_r")
        put_int(s)
        put("; })")
        return
    }
    let flag = types[inner].kind == Y_BOOL               // b ?? false a bool, which prints true, as kelvinc's (#383)
    put(flag ? "; (bool)(_kv_o" : "; _kv_o")
    put_int(s)
    put(".tag == 1 ? _kv_o")
    put_int(s)
    put(".u.some : (")
    gen_value(b, inner)
    put(flag ? ")); })" : "); })")
}

// d[k] read whole (#219): some of a copy of the entry's value, or none
// where the key is missing, as kelvinc's dict_lookup
let gen_lookup(n:int64, y:int64) {
    let value:int64 = types[y].elem
    let opt:int64 = optional_of(value)
    let key:int64 = nodes[n].b
    let hold = needs_hold(key)                           // a String key an expression gives, held for the lookup (#314)
    if hold { hold_open(key) }
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
    if hold { hold_close(key) }
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
    if y >= 0 && types[y].kind == Y_PTR && types[types[y].elem].kind == Y_FIXED {   // where kelvinc's C reads an address (#362)
        gen_error(n, "this points to an array: index what it points to, q^[i]")
        return
    }
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
        let key:int64 = nodes[n].b
        let hold = needs_hold(key)                   // a String key an expression gives, held while the entry is
        put("(*")                                    // found, whose place outlives it, as d keeps its own (#314)
        if hold { hold_open(key) }
        put_dict_name(y)
        put("_at(")
        gen_place(nodes[n].a)
        put(", ")
        gen_key(y, key)
        put(")")
        if hold { hold_close(key) }
        put(")")
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
// whether n is xs[r], a slice of an Array or a String by a Range, written
// or a value (#377)
let is_slice(n:int64):bool {
    if nodes[n].kind != N_INDEX || nodes[n].b < 0 { return false }
    let iy:int64 = type_of(nodes[n].b)
    return iy >= 0 && types[iy].kind == Y_RANGE
}

// xs[r] (#377), as kelvinc's: a copy of the elements, or the codepoints,
// from lo up to hi, past it where closed, to the count without one; one
// out of range ends the program, as kelvinc's slice does; what an
// expression gives held while it is copied
let gen_slice(n:int64) {
    let a:int64 = nodes[n].a
    let y:int64 = type_of(a)
    let hold = needs_hold(a)
    if hold { hold_open(a) }
    put("({ __auto_type _kv_sr = (")
    gen_expr(nodes[n].b)
    put("); ")
    if types[y].kind == Y_STRING {
        put("kv_string_slice(")
    } else {
        put_array_name(y)
        put("_slice(")
    }
    gen_place(a)
    put(", _kv_sr.lo, _kv_sr.kind == 2 ? (")
    gen_place(a)
    put(")->count : _kv_sr.kind ? (uint64_t)_kv_sr.hi + 1 : (uint64_t)_kv_sr.hi); })")
    if hold { hold_close(a) }
}

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

// ---------- async f(x) and await (#313), as kelvinc's #312 ----------

var asyncs:$[int64]                  // each async f(x), in order: its environment and its thread's function
var async_names:$[String]            // and its name, _kv_f_fn, _kv_f_fn1, ..., an anonymous function's
var async_used:Dictionary<String, int64>

let async_name():String {
    var base = $"_kv_"
    base += tok_text(nodes[current].t)
    base += "_fn"
    var k = 0
    while true {
        var name = base.copy()
        if k > 0 {
            let number = String(k)
            name += &number
        }
        if !async_used.has(name) {
            async_used[name] = 1
            return name
        }
        k += 1
    }
    return base
}

let put_async_name(i:int64) {
    let name:String = async_names[i].copy()
    out += &name
}

// async f(x): the arguments kept in an environment, as a call passes them,
// a value copied and an owner moved in, then the thread that makes the call
let gen_async(n:int64) {
    let c:int64 = nodes[n].a
    if nodes[c].kind == N_METHOD {
        gen_error(c, "'async' runs a function, and this is a method, whose self the two threads would share: call a function, passing it what it needs")
        return
    }
    let f:int64 = nodes[c].kind == N_CALL ? nodes[c].a : 0 - 1
    var d:int64 = -1
    if f >= 0 && nodes[f].kind == N_ID && !tok_is(nodes[f].t, "println") && !tok_is(nodes[f].t, "print") && var_type(nodes[f].t) < 0 {
        d = call_target(c)
    }
    if d < 0 {
        gen_error(c, "'async' takes a call of a Kelvin function or a function value, whose types kelvinc sees, as in 'async f(x)'")
        return
    }
    if refuse_valueless_args(c) { return }
    var a:int64 = nodes[c].b
    var p:int64 = nodes[d].a
    while a >= 0 && p >= 0 {                          // a pointer would share what it points to
        let k:ykind = types[nodes[p].ty].kind
        if k == Y_CSTR {
            gen_error(a, "'async' would share this text with the call's thread: the parameter is a cstr, where a String would move in")
            return
        }
        if k == Y_PTR || k == Y_ARGV {
            var m = $"'async' would share what this points to with the call's thread: the parameter is "
            let w:String = kelvin_type_text(nodes[p].ty)
            m += &w
            m += ", and the function takes values, copied, and owners, moved"
            gen_error(a, m.cstr)
            return
        }
        a = nodes[a].next
        p = nodes[p].next
    }
    asyncs += n
    async_names += async_name()
    let i:int64 = asyncs.count as int64 - 1
    put("({ struct ")
    put_async_name(i)
    put("_env *_kv_e = kv_task_env(sizeof *_kv_e); ")
    a = nodes[c].b
    p = nodes[d].a
    var k = 0
    while a >= 0 && p >= 0 {
        put("_kv_e->_kv_a")
        put_int(k)
        put(" = ")
        if !gen_arg_to(a, p, d) { return }
        put("; ")
        k += 1
        a = nodes[a].next
        p = nodes[p].next
    }
    put("kv_task_start(")
    put_async_name(i)
    put("_run, _kv_e, ")
    if is_owner(nodes[d].ty) {
        put_async_name(i)
        put("_drop")
    } else {
        put("NULL")
    }
    put("); })")
}

// await t: the thread joined, its value moved out; a Task an expression
// gives is held while it is awaited
let gen_await(n:int64) {
    let x:int64 = nodes[n].a
    let v:int64 = type_of(n)
    if failed || v < 0 { return }
    let place = is_place(x)
    let valued = types[v].kind != Y_VOID
    put("({ ")
    if !place {
        put("kv_task _kv_t = ")
        gen_expr(x)
        put("; ")
    }
    if valued {
        put_ctype(v)
        put(" _kv_v; ")
    }
    put("kv_task_result(")
    if place { gen_place(x) } else { put("&_kv_t") }
    put(valued ? ", &_kv_v, sizeof _kv_v); _kv_v; })" : ", NULL, 0); })")
}

// each async f(x)'s environment, the value first, and its thread's
// function and drop, declared before the functions
let put_async_heads() {
    for i in 0..<asyncs.count as int64 {
        let d = call_target(nodes[asyncs[i]].a)
        let r:int64 = nodes[d].ty
        put("struct ")
        put_async_name(i)
        put("_env {")
        var some_member = false
        if r >= 0 && types[r].kind != Y_VOID {
            put(" ")
            put_ctype(r)
            put(" _kv_value;")
            some_member = true
        }
        var p:int64 = nodes[d].a
        var k = 0
        while p >= 0 {
            put(" ")
            put_ctype(nodes[p].ty)
            put(" _kv_a")
            put_int(k)
            put(";")
            some_member = true
            k += 1
            p = nodes[p].next
        }
        if !some_member { put(" char _kv_none;") }
        put(" };\nstatic void *")
        put_async_name(i)
        put("_run(void *_kv_p);\n")
        if is_owner(r) {
            put("static void ")
            put_async_name(i)
            put("_drop(void *_kv_p);\n")
        }
    }
}

// and written after them: the thread makes the call and keeps the value;
// the drop frees the value of a Task never awaited
let put_async_bodies() {
    for i in 0..<asyncs.count as int64 {
        let d = call_target(nodes[asyncs[i]].a)
        let r:int64 = nodes[d].ty
        put("static void *")
        put_async_name(i)
        put("_run(void *_kv_p)\n{\n    struct ")
        put_async_name(i)
        put("_env *_kv_e = _kv_p;\n    ")
        if r >= 0 && types[r].kind != Y_VOID { put("_kv_e->_kv_value = ") }
        put_fn_name(d)
        put("(")
        var p:int64 = nodes[d].a
        var k = 0
        while p >= 0 {
            if k > 0 { put(", ") }
            put("_kv_e->_kv_a")
            put_int(k)
            k += 1
            p = nodes[p].next
        }
        put(");\n    return NULL;\n}\n\n")
        if is_owner(r) {
            put("static void ")
            put_async_name(i)
            put("_drop(void *_kv_p) { ")
            put_free(r)
            put("(&((struct ")
            put_async_name(i)
            put("_env *)_kv_p)->_kv_value); }\n\n")
        }
    }
}

// ---------- Bits (#387) ----------

// whether y is a Bits
let is_bits(y:int64):bool {
    return y >= 0 && types[y].kind == Y_BITS
}

// whether x is a number a Bits takes, as kelvinc's check_bit_number: an
// integer, or an enum's value, by which flags are named; 0 to 63 where it
// is a literal and a place, a bit's or a shift's; what names it
let bit_number(x:int64, what:cstr, place:bool):bool {
    let y:int64 = type_of(x)
    if failed { return false }
    let enum_value = y >= 0 && types[y].kind == Y_STRUCT && decl_named(types[y].name, D_ENUM) >= 0
    if y >= 0 && !power_int(y) && !enum_value && types[y].kind != Y_C {
        var m = String(what)
        m += " is an integer of 64 bits or fewer, or an enum's value, and this is "
        if types[y].kind == Y_BOOL {
            m += "a bool"
        } else {
            let w:String = kelvin_type_text(y)
            m += &w
        }
        gen_error(x, m.cstr)
        return false
    }
    let neg = nodes[x].kind == N_UNARY && tok_is(nodes[x].t, "-")
    let lit:int64 = neg ? nodes[x].a : x
    let v:int64 = nodes[lit].kind == N_NUM ? tok_count(nodes[lit].t) : 0 - 1
    if place && ((neg && v > 0) || v > 63) {
        var m = String(what)
        m += " is 0 to 63, and this is "
        if neg { m += "-" }
        m += tok_text(nodes[lit].t)
        gen_error(x, m.cstr)
        return false
    }
    return true
}

// Bits(n), !!n, ~b, b[n], b.value, b.flip(n) and the operators of a Bits,
// as kelvinc writes them, through the prelude's kv_bits_ functions; false
// where n is none of them
let gen_bits(n:int64):bool {
    let k:nkind = nodes[n].kind
    let t:int64 = nodes[n].t
    let a:int64 = nodes[n].a
    if k == N_CALL && nodes[a].kind == N_TYPE && tok_is(nodes[a].t, "Bits") {      // all zeros, or n's bits
        let v:int64 = nodes[n].b
        if v >= 0 && nodes[v].next >= 0 {
            gen_error(n, "Bits takes nothing, all zeros, or an integer, its bits")
            return true
        }
        if v >= 0 && !bit_number(v, "Bits(n)'s n", false) { return true }
        put("((kv_bits){(uint64_t)(")
        if v >= 0 { gen_expr(v) } else { put("0") }
        put(")})")
        return true
    }
    if k == N_UNARY && nodes[n].flag == 1 {              // !!n: the bool of an integer 0 or 1
        let y:int64 = type_of(a)
        if y >= 0 && types[y].kind == Y_BOOL {
            gen_error(n, "'!!' makes a bool of an integer 0 or 1, and this is a bool already: write it as it is, or '! !b' for two nots")
            return true
        }
        if y >= 0 && !power_int(y) && types[y].kind != Y_C {
            var m = $"'!!' makes a bool of an integer 0 or 1, and this is "
            let w:String = kelvin_type_text(y)
            m += &w
            gen_error(a, m.cstr)
            return true
        }
        let neg = nodes[a].kind == N_UNARY && tok_is(nodes[a].t, "-")
        let lit:int64 = neg ? nodes[a].a : a
        let v:int64 = nodes[lit].kind == N_NUM ? tok_count(nodes[lit].t) : 0 - 1
        if (neg && v > 0) || v > 1 {
            var m = $"'!!' takes an integer 0 or 1, and this is "
            if neg { m += "-" }
            m += tok_text(nodes[lit].t)
            gen_error(a, m.cstr)
            return true
        }
        put("KV_BIT_OF(")
        gen_expr(a)
        put(")")
        return true
    }
    if a < 0 { return false }
    if k == N_UNARY && is_bits(type_of(a)) {             // ~b, each bit flipped
        if !tok_is(t, "~") {
            var m = $"a Bits has the prefix '~', which flips each bit, and no prefix '"
            m += tok_text(t)
            m += "'"
            gen_error(n, m.cstr)
            return true
        }
        put("((kv_bits){~(")
        gen_expr(a)
        put(").value})")
        return true
    }
    if k == N_INDEX && is_bits(type_of(a)) {             // b[n], a bit
        if !bit_number(nodes[n].b, "a bit's place in a Bits", true) { return true }
        put("kv_bits_at(")
        gen_expr(a)
        put(", (uint64_t)(")
        gen_expr(nodes[n].b)
        put("))")
        return true
    }
    if k == N_FIELD && tok_is(t, "value") && is_bits(type_of(a)) {
        put("(")
        gen_expr(a)
        put(").value")
        return true
    }
    if k == N_METHOD && tok_is(t, "flip") && is_bits(type_of(a)) {     // b.flip(n), in the var that holds b
        let v:int64 = nodes[n].b
        if v < 0 || nodes[v].next >= 0 {
            gen_error(n, "'.flip(n)' takes one bit's place, 0 to 63")
            return true
        }
        if !bit_number(v, "a bit's place in a Bits", true) { return true }
        let lead = $"'.flip' is a var method, which changes "
        if !changes_var(a, &lead) { return true }
        if !changeable_place(a) {
            gen_error(n, "'.flip' is a var method, which changes the value it is called on, so that value is a variable")
            return true
        }
        put("kv_bits_flip(&(")
        gen_expr(a)
        put("), (uint64_t)(")
        gen_expr(v)
        put("))")
        return true
    }
    if k != N_BIN { return false }
    let b:int64 = nodes[n].b
    let left = is_bits(type_of(a))
    if !left && !is_bits(type_of(b)) { return false }
    let shift = tok_is(t, "<<") || tok_is(t, ">>")
    let eq = tok_is(t, "==") || tok_is(t, "!=")
    if !shift && !eq && !tok_is(t, "|") && !tok_is(t, "&") && !tok_is(t, "~") {
        var m = $"a Bits has '|', '&', '~', '<<', '>>', '==' and '!=', and no '"
        m += tok_text(t)
        m += "': its u64 is '.value'"
        gen_error(n, m.cstr)
        return true
    }
    if shift {
        if !left {
            var m = $"'"
            m += tok_text(t)
            m += "' shifts a Bits, on its left, by an integer"
            gen_error(n, m.cstr)
            return true
        }
        if !bit_number(b, "a shift of a Bits", true) { return true }
        put(tok_is(t, "<<") ? "kv_bits_shl(" : "kv_bits_shr(")
        gen_expr(a)
        put(", (uint64_t)(")
        gen_expr(b)
        put("))")
        return true
    }
    if !left || !is_bits(type_of(b)) {
        var m = $"'"
        m += tok_text(t)
        m += "' of a Bits takes another Bits: 'Bits(n)' makes one of an integer"
        gen_error(n, m.cstr)
        return true
    }
    put(eq ? "((bool)((" : "((kv_bits){(")
    gen_expr(a)
    put(").value ")
    if tok_is(t, "~") { put("^") } else { put_tok(t) }
    put(" (")
    gen_expr(b)
    put(eq ? ").value))" : ").value})")
    return true
}

// b[n] = x, b[n] |= x, &= and ~= of a bool, b.value = n and its kin, and
// b |= c, &=, ~=, <<= and >>= of a whole Bits (#387), in the var that holds
// b, as kelvinc writes them; false where n assigns none of them
let gen_bits_assign(n:int64):bool {
    let lhs:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let v:int64 = nodes[n].b
    let lk:nkind = nodes[lhs].kind
    let base:int64 = lk == N_INDEX || lk == N_FIELD ? nodes[lhs].a : 0 - 1
    if lk == N_INDEX && is_bits(type_of(base)) {
        if !tok_is(t, "=") && !tok_is(t, "|=") && !tok_is(t, "&=") && !tok_is(t, "~=") {
            var m = $"a bit of a Bits is set with '=', '|=', '&=' or '~=', and a bool, and has no '"
            m += tok_text(t)
            m += "'"
            gen_error(n, m.cstr)
            return true
        }
        if !bit_number(nodes[lhs].b, "a bit's place in a Bits", true) { return true }
        let vy:int64 = type_of(v)
        if vy >= 0 && types[vy].kind != Y_BOOL {
            var m = $"a bit of a Bits is set with a bool, and this is "
            let w:String = kelvin_type_text(vy)
            m += &w
            m += ": '!!n' makes one of an integer 0 or 1"
            gen_error(v, m.cstr)
            return true
        }
        put(tok_is(t, "=") ? "kv_bits_put(&(" : tok_is(t, "|=") ? "kv_bits_or(&(" : tok_is(t, "&=") ? "kv_bits_and(&(" : "kv_bits_xor(&(")
        gen_expr(base)
        put("), (uint64_t)(")
        gen_expr(nodes[lhs].b)
        put("), ")
        gen_expr(v)
        put(");\n")
        return true
    }
    if lk == N_FIELD && tok_is(nodes[lhs].t, "value") && is_bits(type_of(base)) {
        if !bit_number(v, "what '.value' of a Bits takes", false) { return true }
        put("(")
        gen_expr(base)
        put(").value ")
        if tok_is(t, "~=") { put("^=") } else { put_tok(t) }
        put(" (")
        gen_expr(v)
        put(");\n")
        return true
    }
    if !is_bits(type_of(lhs)) || tok_is(t, "=") || tok_is(t, ":=") { return false }
    let shift = tok_is(t, "<<=") || tok_is(t, ">>=")
    if !shift && !tok_is(t, "|=") && !tok_is(t, "&=") && !tok_is(t, "~=") {
        var m = $"a Bits has '|=', '&=', '~=', '<<=' and '>>=', and no '"
        m += tok_text(t)
        m += "': its u64 is '.value'"
        gen_error(n, m.cstr)
        return true
    }
    if shift {
        if !bit_number(v, "a shift of a Bits", true) { return true }
        put("({ kv_bits *_kv_bp = &(")
        gen_expr(lhs)
        put(tok_is(t, "<<=") ? "); *_kv_bp = kv_bits_shl(*_kv_bp, (uint64_t)(" : "); *_kv_bp = kv_bits_shr(*_kv_bp, (uint64_t)(")
        gen_expr(v)
        put(")); (void)0; });\n")
        return true
    }
    if !is_bits(type_of(v)) {
        var m = $"'"
        m += tok_text(t)
        m += "' of a Bits takes another Bits: 'Bits(n)' makes one of an integer"
        gen_error(v, m.cstr)
        return true
    }
    put("({ kv_bits *_kv_bp = &(")
    gen_expr(lhs)
    put("); _kv_bp->value ")
    if tok_is(t, "~=") { put("^=") } else { put_tok(t) }
    put(" (")
    gen_expr(v)
    put(").value; (void)0; });\n")
    return true
}

let gen_expr(n:int64) {
    if failed { return }
    if held.get(n, 0 - 1) >= 0 {                         // held in a temporary (#227)
        put("_kv_tmp")
        put_int(held.get(n, 0 - 1))
        return
    }
    if gen_bits(n) { return }                            // a Bits's (#387)
    let k:nkind = nodes[n].kind
    let t:int64 = nodes[n].t
    if k == N_ANON {
        type_of(n)                                       // its error (#324)
        return
    }
    if k == N_BIN && nodes[nodes[n].a].kind == N_EMPTY { // xs == $[]: no type is written there (#348)
        empty_error(nodes[n].a)
        return
    }
    if k == N_BIN && nodes[nodes[n].b].kind == N_EMPTY {
        empty_error(nodes[n].b)
        return
    }
    if k == N_MAKE {                                     // Array<T>(), Dictionary<K, V>(), an empty one (#349)
        gen_make(n)
        return
    }
    if k == N_LIST {                                     // as kelvinc says it, kc's for its compound literal (#354)
        gen_error(n, "an array is not a value here: kc reads [a, b] as a declaration's value; not yet a compound literal, ([i32])[1, 2, 3] (#48)")
        return
    }
    if k == N_ITER {                                     // (#326)
        gen_iter_make(n)
        return
    }
    if k == N_RANGE {                                    // lo..<hi, lo...hi, lo... (#373): kind 0, 1, 2, as kelvinc's
        let ry:int64 = type_of(n)
        if ry < 0 { return }
        put("((")
        put_ctype(ry)
        put("){")
        if nodes[n].a >= 0 { gen_expr(nodes[n].a) } else { put("0") }
        put(", ")
        if nodes[n].b >= 0 { gen_expr(nodes[n].b) } else { put(range_max(types[ry].elem)) }
        put(", ")
        put_int(nodes[n].flag)
        put("})")
        return
    }
    if k == N_RITER {                                    // a Range's Iterator, kc's (#373)
        let i = range_iter_of(n)
        if i >= 0 { gen_iter_value(i) }
        return
    }
    if is_range_eq(n) {                                  // r == s, r != s (#376)
        gen_range_eq(n)
        return
    }
    if range_operand_error(n) { return }                 // a Range has no operators (#373) but == and != (#376)
    if k == N_METHOD && tok_is(t, "reversed") && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_RANGE {
        let a:int64 = nodes[n].a                         // r.reversed() (#378), as kelvinc's
        if nodes[n].b >= 0 {
            gen_error(nodes[n].b, "'.reversed()' takes nothing")
            return
        }
        if nodes[a].kind == N_RANGE && nodes[a].flag == 2 {
            let lo:int64 = nodes[a].a
            var m = $"'.reversed()' walks a Range from its end, and "
            if nodes[lo].kind == N_NUM { m += tok_text(nodes[lo].t) } else { m += "lo" }
            m += "... has none: take the first few, as in '.prefix(10).reversed()'"
            gen_error(n, m.cstr)
            return
        }
        let i = range_iter_of(n)
        if i >= 0 { gen_iter_value(i) }
        return
    }
    if k == N_METHOD && tok_is(t, "stride") && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_RANGE {
        gen_range_stride(n)                              // r.stride(n) (#379)
        return
    }
    if k == N_METHOD && tok_is(t, "pow") && power_int(type_of(nodes[n].a)) {
        gen_pow_method(n)                                // b.pow(e), b.pow(e, m) of an integer (#380)
        return
    }
    if k == N_FIELD && (tok_is(t, "isNaN") || tok_is(t, "isInfinite") || tok_is(t, "isFinite")) && type_of(nodes[n].a) >= 0 && power_float(type_of(nodes[n].a)) {
        put(tok_is(t, "isNaN") ? "((bool)__builtin_isnan(" : tok_is(t, "isInfinite") ? "((bool)__builtin_isinf(" : "((bool)__builtin_isfinite(")   // x.isNaN (#382), x.isInfinite, x.isFinite (#384), as kelvinc's
        gen_expr(nodes[n].a)
        put("))")
        return
    }
    if k == N_FIELD && tok_is(t, "sign") && type_of(nodes[n].a) >= 0 {
        let sy:int64 = type_of(nodes[n].a)               // x.sign (#382), as kelvinc's: -1, 0 or 1 of its type;
        let sk:ykind = types[sy].kind                    // a floating-point one's by its sign bit, NaN of NaN
        if sk == Y_F64 || sk == Y_F32 {                  // a bool? (#383): true by its sign bit's 0, none of NaN
            let oy:int64 = optional_of(base_type(Y_BOOL))
            put("({ ")
            put_ctype(sy)
            put(" _kv_fv = (")
            gen_expr(nodes[n].a)
            put("); _kv_fv != _kv_fv ? _kv_")
            put_tok(types[oy].name)
            put("_make_none() : _kv_")
            put_tok(types[oy].name)
            put("_make_some((bool)!__builtin_signbit(_kv_fv)); })")
            return
        }
        if sk == Y_I64 || sk == Y_I32 {
            put("({ ")
            put_ctype(sy)
            put(" _kv_sg = (")
            gen_expr(nodes[n].a)
            put("); (")
            put_ctype(sy)
            put(")((_kv_sg > 0) - (_kv_sg < 0)); })")
            return
        }
    }
    if k == N_FIELD && (tok_is(t, "exponent") || tok_is(t, "significand")) && power_float(type_of(nodes[n].a)) {
        let wide = types[type_of(nodes[n].a)].kind == Y_F64     // IEEE 754's fields (#383), as kelvinc's
        put(wide ? "({ double _kv_fv = (" : "({ float _kv_fv = (")
        gen_expr(nodes[n].a)
        put(wide ? "); uint64_t _kv_fb; __builtin_memcpy(&_kv_fb, &_kv_fv, 8); (int64_t)(_kv_fb >> " : "); uint32_t _kv_fb; __builtin_memcpy(&_kv_fb, &_kv_fv, 4); (int64_t)(_kv_fb >> ")
        put(float_field_at(t, wide))
        put(" & ")
        put(float_field_mask(t, wide))
        put("); })")
        return
    }
    if k == N_FIELD && tok_is(t, "abs") && type_of(nodes[n].a) >= 0 {
        let ay:int64 = type_of(nodes[n].a)
        let ak:ykind = types[ay].kind
        if ak == Y_F64 || ak == Y_F32 {                  // x.abs (#381), as kelvinc's: fabs
            put(ak == Y_F32 ? "__builtin_fabsf(" : "__builtin_fabs(")
            gen_expr(nodes[n].a)
            put(")")
            return
        }
        if ak == Y_I64 || ak == Y_I32 {                  // negated in its unsigned type, where i64's least wraps
            let u:cstr := ak == Y_I64 ? "uint64_t" : "uint32_t"
            put("({ ")
            put_ctype(ay)
            put(" _kv_ab = (")
            gen_expr(nodes[n].a)
            put("); (")
            put_ctype(ay)
            put(")(_kv_ab < 0 ? 0u - (")
            put(u)
            put(")_kv_ab : (")
            put(u)
            put(")_kv_ab); })")
            return
        }
    }
    if (k == N_FIELD && (tok_is(t, "count") || tok_is(t, "lowerBound") || tok_is(t, "upperBound")) || k == N_METHOD && tok_is(t, "contains")) && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_RANGE {
        gen_range_member(n)                              // r.count, r.contains(x) (#374), its bounds (#375)
        return
    }
    if k == N_FIELD && tok_is(t, "lazy") && lazy_field_type(n) != 0 - 2 {
        let ly:int64 = type_of(nodes[n].a)
        if ly >= 0 && types[ly].kind == Y_RANGE {        // as kelvinc's (#373)
            gen_error(n, "'.lazy' makes '.map' or '.filter' after it lazy: write 'r.lazy.map { ... }' or 'r.lazy.filter { ... }'")
        } else {
            gen_error(n, "'.lazy' makes '.map' or '.filter' after it lazy: write 's.lazy.map { ... }' or 's.lazy.filter { ... }'")
        }
        return
    }
    if float_word(n) {                                   // nan, inf: gcc's and clang's constants (#262)
        put(word_no_case(t, "nan") ? "__builtin_nan(\"\")" : "__builtin_inf()")
    } else if k == N_ID && var_type(t) < 0 && tok_is(t, "_") && decl_named(t, D_FN) < 0 {
        gen_error(n, "'_' names nothing to read: it leaves out a name, as of an unnamed parameter or of 'for _ in'")   // (#388)
    } else if k == N_ID && var_type(t) < 0 && wide_tok(t) && decl_named(t, D_FN) < 0 {
        unknown_wide(n, t)                               // (#385)
    } else if k == N_ID && var_type(t) < 0 && !c_headers {
        gen_error(n, "this name is not known")
    } else if k == N_NULL {
        put("NULL")
    } else if k == N_SELF {
        put("self")
    } else if k == N_NUM && widen_ints && !float_tok(t) {
        put("((int64_t)")                                // an i64, as kelvinc casts it (#385)
        put_tok(t)
        put(")")
    } else if k == N_NUM || k == N_CHAR || k == N_ID {
        put_tok(t)
    } else if k == N_STR {
        put_text(t, 0)
    } else if k == N_DSTR {
        put("KV_STRING_LIT(")                            // $"...", its every byte, a NUL too (#299)
        put_text(t, 1)
        put(")")
    } else if k == N_BOOL {
        put("((bool)")                           // C's true is an int, which String(...) would write as 1 (#212)
        put_tok(t)
        put(")")
    } else if k == N_CALL {
        gen_call(n)
    } else if k == N_ASYNC {
        gen_async(n)                                 // (#313)
    } else if k == N_AWAIT {
        gen_await(n)
    } else if k == N_CHAIN {
        gen_chain(n)
    } else if k == N_COND {
        gen_choice(n)
    } else if k == N_FIELD {
        gen_field(n)
    } else if k == N_METHOD {
        gen_method(n)
    } else if k == N_INDEX && is_slice(n) {
        gen_slice(n)                                 // xs[r], xs[lo..<hi] (#377)
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
    } else if k == N_BIN && tagged_side(n) >= 0 {
        gen_variant_eq(n, tagged_side(n))                // a == b, x != none of an Optional (#343), of a Result (#344), of any enum with values (#345)
    } else if k == N_BIN && is_string_plus(n) {
        gen_string_plus(n)                               // s + t (#284)
    } else if k == N_BIN && !widen_ints && widened.get(n, false) {
        widen_ints = true                                // arithmetic of integer literals, inferred an i64 (#385)
        gen_expr(n)
        widen_ints = false
    } else if k == N_BIN && tok_is(t, "**") {
        gen_power(nodes[n].a, nodes[n].b)                // b ** e (#380)
    } else if k == N_BIN {
        let y:int64 = type_of(nodes[n].a)
        reject_cstr_math(n)                              // "a" + "b", "a" + 1, x - y (#283)
        reject_container_math(n)                         // xs + 2, d < d2, s - t (#287)
        if y >= 0 && types[y].kind == Y_SET && (tok_is(t, "|") || tok_is(t, "&") || tok_is(t, "~")) {
            gen_set_op(n, y)                             // s | t, s & t, s ~ t (#276)
        } else if (builtin_kind(y) == Y_ARRAY || builtin_kind(y) == Y_DICT || builtin_kind(type_of(nodes[n].b)) == Y_ARRAY || builtin_kind(type_of(nodes[n].b)) == Y_DICT) && (tok_is(t, "==") || tok_is(t, "!=")) {
            gen_container_eq(n)                          // xs == ys, d != d2 (#288)
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
        empty_error(n)                                   // where no type is written (#348)
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
    let set_op = k == N_BIN && type_of(nodes[v].a) >= 0 && (types[type_of(nodes[v].a)].kind == Y_SET || types[type_of(nodes[v].a)].kind == Y_BITS)   // s | t, a Set, as kelvinc infers it (#276); b | c, a Bits (#387)
    if k == N_BIN && literal_arith(v) == 2 { return base_type(Y_F64) }   // 1.0 / 0.0, of literals alone (#385)
    if k == N_BIN && literal_arith(v) == 1 {             // 60 * 60, reckoned in an i64
        widened[v] = true
        return base_type(Y_I64)
    }
    if k == N_BIN && tok_is(nodes[v].t, "**") && (!power_operand(nodes[v].a) || !power_operand(nodes[v].b)) { return -1 }   // as kelvinc says it (#380)
    if k == N_METHOD && tok_is(nodes[v].t, "pow") && power_int(type_of(nodes[v].a)) && !pow_arity(v) { return -1 }
    if k == N_BIN && !is_comparison(nodes[v].t) && !tok_is(nodes[v].t, "??") && !tok_is(nodes[v].t, "**") && !set_op && !is_string_plus(v) {   // x ?? d is x's T (#217); s + t a String (#284); b ** e kelvinc's (#380)
        gen_error(n, "this variable needs a type: write name:T, since a type is not inferred from arithmetic")
        return -1
    }
    let w:int64 = k == N_ID ? nodes[v].t : k == N_CALL && nodes[nodes[v].a].kind == N_ID ? nodes[nodes[v].a].t : 0 - 1
    let word = w >= 0 && is_case_word(v) && (tok_is(w, "none") || tok_is(w, "ok") || tok_is(w, "err") || tok_is(w, "some"))   // none, ok(v), err(e) (#341)
    if k == N_EMPTY {                                    // as kelvinc says it (#348)
        empty_error(v)
        return -1
    }
    if k == N_INIT || k == N_NULL || word {
        gen_error(n, "this variable needs a type: write name:T, since this value has none of its own")
        return -1
    }
    let y:int64 = type_of(v)
    if k == N_AWAIT && y >= 0 && types[y].kind == Y_VOID {      // as kelvinc's (#313)
        gen_error(v, "this Task has no value, as its function has no result: await it alone, as a line of its own")
        return -1
    }
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
    case Y_BITS: return $"Bits"
    case Y_ARGV: return $"[cstr]"
    case Y_FIXED:                                    // [i64](3), as kelvinc names it (#354)
        if types[y].name == 0 - 2 || types[y].name == 0 - 4 {   // a parameter's: i64^, as kelvinc names it (#357)
            var s = types[y].name == 0 - 4 ? $"const " : $""
            s += type_text(types[y].elem)
            s += "^"
            return s
        }
        var s = types[y].name == 0 - 3 ? $"[const " : $"["
        s += type_text(types[y].elem)
        s += "]"
        if types[y].name <= 0 - 10 {                     // [u8](n), of a count C computes (#366)
            let c:int64 = 0 - 10 - types[y].name
            s += "("
            s += nodes[c].kind == N_ID ? tok_text(nodes[c].t) : $"n"
            s += ")"
        } else if types[y].name >= 0 {
            s += "("
            let c:String = String(types[y].name)
            s += &c
            s += ")"
        }
        return s
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
    case Y_ITER:                                     // Iterator<i64> (#326)
        var s = $"Iterator<"
        let e:String = kelvin_type_text(types[y].elem)
        s += &e
        s += ">"
        return s
    case Y_RANGE:                                    // Range<i64> (#373)
        var s = $"Range<"
        let e:String = type_text(types[y].elem)
        s += &e
        s += ">"
        return s
    case Y_TASK:                                     // as kelvinc names it, Task<Array<i64>> (#313)
        if types[y].elem < 0 { return $"Task" }
        var s = $"Task<"
        let e:String = kelvin_type_text(types[y].elem)
        s += &e
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

// whether y holds a fixed array where kc does not take one: behind a
// pointer, in an Array, a Dictionary, a Set or an enum with values (#354)
let fixed_inside(y:int64):bool {
    if y < 0 { return false }
    let k:ykind = types[y].kind
    if k == Y_FIXED { return true }
    if k == Y_PTR && types[types[y].elem].kind == Y_FIXED {   // [T](N)^, a pointer to one, counted (#362), or of no count (#363)
        let e:int64 = types[y].elem
        return types[e].name < 0 - 1 || !fixed_elem_ok(e)
    }
    if k == Y_PTR || k == Y_ARRAY || k == Y_SET { return fixed_inside(types[y].elem) }
    if k == Y_DICT { return fixed_inside(types[y].elem) || fixed_inside(types[y].name) }
    let d = tagged_of(y)
    if d >= 0 && types[y].name > eof_pos {               // an Optional's or a Result's, which kc makes
        var m = nodes[d].a
        while m >= 0 {
            if fixed_inside(nodes[m].ty) { return true }
            m = nodes[m].next
        }
    }
    return false
}

// the Optional or the Result in y that holds a fixed array, or -1 (#368)
let fixed_variant(y:int64):int64 {
    if y < 0 { return 0 - 1 }
    let k:ykind = types[y].kind
    if is_variant(y) {
        var m:int64 = nodes[tagged_of(y)].a
        while m >= 0 {
            let cy:int64 = nodes[m].ty
            if cy >= 0 && types[cy].kind == Y_FIXED { return y }
            let r:int64 = fixed_variant(cy)
            if r >= 0 { return r }
            m = nodes[m].next
        }
        return 0 - 1
    }
    if k == Y_PTR || k == Y_ARRAY || k == Y_SET { return fixed_variant(types[y].elem) }
    if k == Y_DICT {
        let r:int64 = fixed_variant(types[y].elem)
        return r >= 0 ? r : fixed_variant(types[y].name)
    }
    return 0 - 1
}

// a fixed array in y where kc takes none: in an Optional or a Result,
// kelvinc's error in its words, as it refuses one by design; else kc's
// not yet (#368)
// kelvinc's words of an Array, a Dictionary or a Set in y that holds a
// fixed array, or "" (#369)
let fixed_container_text(y:int64):String {
    if y < 0 { return $"" }
    let k:ykind = types[y].kind
    if k == Y_ARRAY || k == Y_DICT || k == Y_SET {
        let e:int64 = types[y].elem
        let key:int64 = k == Y_SET ? e : k == Y_DICT ? types[y].name : 0 - 1
        if key >= 0 && types[key].kind == Y_FIXED {
            var m = $"a key of a Dictionary is an integer or a String, not "
            let w:String = type_text(key)
            m += &w
            return m
        }
        if k != Y_SET && types[e].kind == Y_FIXED {
            var m = $"an Array of "
            let w:String = type_text(e)
            m += &w
            m += " is not here yet: an element is a value C returns"
            return m
        }
        var r:String = fixed_container_text(e)
        if r.count == 0 && key >= 0 { r = fixed_container_text(key) }
        return r
    }
    if k == Y_PTR { return fixed_container_text(types[y].elem) }
    return $""
}

let refuse_fixed(n:int64, y:int64) {
    let v:int64 = fixed_variant(y)
    let held:String = v < 0 ? fixed_container_text(y) : $""
    if v < 0 && held.count > 0 {                         // as kelvinc says it (#369)
        gen_error(n, held.cstr)
        return
    }
    if v < 0 {
        fixed_refused(n)
        return
    }
    var fe:int64 = 0 - 1
    var m:int64 = nodes[tagged_of(v)].a
    while m >= 0 {
        if nodes[m].ty >= 0 && types[nodes[m].ty].kind == Y_FIXED && fe < 0 { fe = types[nodes[m].ty].elem }
        m = nodes[m].next
    }
    var s = some_type(v) >= 0 ? $"an Optional" : $"a Result"
    s += " holds a value, and an array is none: hold an Array, $["
    let ew:String = type_text(fe)
    s += &ew
    s += "]"
    gen_error(n, s.cstr)
}

let fixed_refused(n:int64) {
    gen_error(n, "kc reads a fixed array as a variable, a struct's member, an enum's case, a parameter, or behind a pointer of its count, [T](N)^; not yet one in another type, as an Optional")
}

// whether y may be a fixed array's element, as kc takes it: a number, a
// bool, a cstr, a struct that owns nothing, or a fixed array in turn
let fixed_elem_ok(y:int64):bool {
    let k:ykind = types[y].kind
    if k == Y_FIXED { return fixed_elem_ok(types[y].elem) }
    if is_owner(y) || fixed_inside(y) { return false }
    return is_number_kind(k) || k == Y_BOOL || k == Y_CSTR || k == Y_STRUCT
}

// a fixed array's C declarator: its element type, name, and [N] for each
// count, the outer first, as C's int64_t m[2][3] (#354)
var fixed_const = false                  // a let global's elements, const in C (#359)

let put_fixed_decl(y:int64, name:int64) {
    put_fixed_base(y)
    if fixed_const { put(" const") }                     // int64_t const g[3], const uint8_t * const s[2]
    put(" ")
    put_tok(name)
    put_fixed_counts(y)
}

// a fixed array's element type, the innermost (#354)
let put_fixed_base(y:int64) {
    var base:int64 = y
    while types[base].kind == Y_FIXED { base = types[base].elem }
    put_ctype(base)
}

// a fixed array's counts, [2][3], the outer first (#354)
let put_fixed_counts(y:int64) {
    var f:int64 = y
    while types[f].kind == Y_FIXED {
        put("[")
        if types[f].name <= 0 - 10 {                    // a count C computes (#366)
            gen_expr(0 - 10 - types[f].name)
        } else {
            put_int(types[f].name)
        }
        put("]")
        f = types[f].elem
    }
}

// [a, b] of the fixed array y: C's {a, b}, each by its element type, a
// list within a list of its own (#354)
let gen_fixed_list(v:int64, y:int64) {
    let e:int64 = types[y].elem
    put("{")
    var x = nodes[v].b
    while x >= 0 && !failed {
        if x != nodes[v].b { put(", ") }
        if nodes[x].kind == N_LIST && nodes[x].flag == 0 && types[e].kind == Y_FIXED {
            gen_fixed_list(x, e)
        } else {
            gen_value(x, e)
        }
        x = nodes[x].next
    }
    put("}")
}

// whether the elements of [a, b] fit y, a fixed array: each of its element
// type, as gen_array asks of $[a, b], no more than its count (#354)
let fixed_list_fits(v:int64, y:int64):bool {
    let e:int64 = types[y].elem
    var count = 0
    var x = nodes[v].b
    while x >= 0 {
        count += 1
        if nodes[x].kind == N_LIST && nodes[x].flag == 0 && types[e].kind == Y_FIXED {
            if !fixed_list_fits(x, e) { return false }
        } else if is_owner(e) && is_place(x) && !is_case_word(x) {   // as an Array's elements (#364)
            gen_error(x, "an owner is not copied by '=' (#54): copy it with .copy()")
            return false
        } else {
            let bad:String = value_mismatch_text(x, e)
            if bad.count > 0 || is_case_word(x) {
                var m = $"an element of "
                let aw:String = type_text(y)
                m += &aw
                m += " is "
                let ew:String = kelvin_type_text(e)
                m += article_of(&ew)
                m += " "
                m += &ew
                m += ", and this is "
                m += bad.count > 0 ? bad.copy() : $"not one"
                gen_error(x, m.cstr)
                return false
            }
        }
        x = nodes[x].next
    }
    if types[y].name >= 0 && count > types[y].name {
        var m = type_text(y)
        m += " holds "
        let c:String = String(types[y].name)
        m += &c
        m += " elements, and this gives "
        let g:String = String(count)
        m += &g
        gen_error(v, m.cstr)
        return false
    }
    return true
}

// whether a fixed array holds one of a count C computes, deeper in (#366)
let fixed_computed(y:int64):bool {
    var f:int64 = y
    while types[f].kind == Y_FIXED {
        if types[f].name <= 0 - 10 { return true }
        f = types[f].elem
    }
    return false
}

// whether n, of y, a count C computes, is a var's in a function, its count
// an integer, given no elements, as C has it; else kelvinc's error, or
// kc's where kelvinc leaves it to C (#366)
let computed_ok(n:int64, y:int64, v:int64):bool {
    if nodes[n].kind == D_GLOBAL {
        gen_error(n, "a global's array is counted by a number: a count computed at run time is a local var's")
        return false
    }
    if nodes[n].flag == 1 && v < 0 {                     // as kelvinc says it
        var m = $"a let needs a value: write 'let "
        m += tok_text(nodes[n].t)
        m += " = ...', or 'var "
        m += tok_text(nodes[n].t)
        m += "' if it changes later"
        gen_error(n, m.cstr)
        return false
    }
    if nodes[n].flag == 1 {                              // as kelvinc says it
        var m = $"'"
        m += tok_text(nodes[n].t)
        m += "' is a let of a count computed at run time, which C cannot fill: write 'var "
        m += tok_text(nodes[n].t)
        m += "'"
        gen_error(n, m.cstr)
        return false
    }
    if v >= 0 && !(nodes[v].kind == N_LIST && nodes[v].flag == 1) {
        gen_error(v, "an array of a count computed at run time takes no elements in C: give them one by one, a[i] = ...")
        return false
    }
    var f:int64 = y                                      // each count C computes, the outer and the inner (#367)
    while types[f].kind == Y_FIXED {
        if types[f].name <= 0 - 10 {
            let c:int64 = 0 - 10 - types[f].name
            let cy:int64 = type_of(c)
            if nodes[c].kind == N_STR || cy < 0 || !is_number_kind(types[cy].kind) || types[cy].kind == Y_F64 || types[cy].kind == Y_F32 {
                var m = $"an array's count is an integer, and this is "
                let w:String = nodes[c].kind == N_STR ? $"text" : cy >= 0 ? kelvin_type_text(cy) : $"not one"
                m += &w
                gen_error(c, m.cstr)
                return false
            }
        }
        f = types[f].elem
    }
    return true
}

// let a:[T](N) = [a, b], var a = [1, 2], var z = [T](n), var a:[T](N): a
// local fixed array, as kelvinc's #48 and #49, declared as C's T a[N] =
// {a, b}, and {0} where nothing or [T](n) gives its elements (#354)
let gen_fixed_var(n:int64) {
    var y:int64 = nodes[n].ty
    let v:int64 = nodes[n].a
    if types[y].name == 0 - 3 {                          // [const T] of a local: a let's (#357)
        if nodes[n].flag != 1 {
            gen_error(n, "a var of [const T] would not change its elements: declare it with let")
            return
        }
        y = type_of_kind(Y_FIXED, types[y].elem, 0 - 1)
    }
    if !fixed_elem_ok(types[y].elem) {
        if is_owner(types[y].elem) {                     // as kelvinc says it
            gen_error(n, "an array of owners is not here yet: a struct may hold them")
        } else {
            fixed_refused(n)
        }
        return
    }
    let zeros_computed = v >= 0 && nodes[v].kind == N_LIST && nodes[v].flag == 1 && type_of(v) >= 0 && types[type_of(v)].name <= 0 - 10
    if types[y].name <= 0 - 10 || zeros_computed || fixed_computed(types[y].elem) {   // a count C computes, a local var's (#366)
        if types[y].name == 0 - 1 { y = type_of(v) }
        if !computed_ok(n, y, v) { return }
        set_ty(n, y)
        put_fixed_decl(y, nodes[n].t)
        put("; memset(")
        put_tok(nodes[n].t)
        put(", 0, sizeof ")
        put_tok(nodes[n].t)
        put(");\n")
        return
    }
    if v >= 0 && nodes[v].kind == N_LIST && nodes[v].flag == 1 {   // [T](n)
        let zy:int64 = type_of(v)
        if types[y].name == 0 - 1 { y = zy }
        if y != zy {
            var m = $"'"
            m += tok_text(nodes[n].t)
            m += "' is "
            let w:String = type_text(y)
            m += &w
            m += ", and this is "
            let zw:String = type_text(zy)
            m += &zw
            gen_error(v, m.cstr)
            return
        }
    } else if v >= 0 && nodes[v].kind == N_LIST {      // [a, b]
        if nodes[v].b < 0 {
            gen_error(v, "[] has no elements: write [T](N), N zero elements")
            return
        }
        if !fixed_list_fits(v, y) { return }
        if types[y].name < 0 { y = type_of_kind(Y_FIXED, types[y].elem, type_of(v) >= 0 ? types[type_of(v)].name : 0) }
    } else if v >= 0 {                                   // a copy, as C has none
        gen_error(v, "an array is not copied by '=': read its elements, a[i]; ':=' of one is not kc's yet")
        return
    } else if types[y].name < 0 {
        var m = type_text(y)
        m += " takes its count from its elements: write ["
        let ew:String = type_text(types[y].elem)
        m += &ew
        m += "](N), or the elements"
        gen_error(n, m.cstr)
        return
    }
    set_ty(n, y)                                         // S_VAR declares it so
    put_fixed_decl(y, nodes[n].t)
    put(" = ")
    if v >= 0 && nodes[v].kind == N_LIST && nodes[v].flag == 0 {
        gen_fixed_list(v, y)
    } else {
        put("{0}")
    }
    put(";\n")
}

let gen_var(n:int64) {
    if nodes[n].ty < 0 { set_ty(n, inferred(n)) }
    if failed { return }
    if types[nodes[n].ty].kind == Y_ARGV && nodes[n].a >= 0 && nodes[nodes[n].a].kind == N_LIST {   // let names:[cstr] = ["a"] (#354)
        set_ty(n, type_of_kind(Y_FIXED, base_type(Y_CSTR), -1))
    }
    if types[nodes[n].ty].kind == Y_FIXED {              // (#354)
        gen_fixed_var(n)
        return
    }
    if fixed_inside(nodes[n].ty) {
        refuse_fixed(n, nodes[n].ty)                     // an Optional's, kelvinc's words (#368)
        return
    }
    let y:int64 = nodes[n].ty
    if nodes[n].a >= 0 && !assigns_as(n, nodes[n].t, y, nodes[n].c == 1) { return }
    var who = $"'"                                       // a let's borrow, as an argument's (#273)
    who += tok_text(nodes[n].t)
    who += "'"
    if nodes[n].a >= 0 && owner_part(nodes[n].a) && nodes[n].c != 1 {   // as kelvinc says it, an alias else (#365)
        gen_error(nodes[n].a, "an owner is not copied by '=' (#54): copy its bytes with it.copy(), or borrow it with ':= &...'")
        return
    }
    if nodes[n].a >= 0 && !fixed_ptr_ok(nodes[n].a, y, &who) { return }   // q := &a of a [T](N)^ (#362)
    if nodes[n].a >= 0 && !takes_borrow(nodes[n].a, y, &who) { return }
    if nodes[n].a >= 0 && types[y].kind == Y_TASK && is_place(nodes[n].a) {   // as kelvinc's (#313)
        gen_error(nodes[n].a, "a Task is not copied: pass it on, or await it")
        return
    }
    if nodes[n].a >= 0 && types[y].kind == Y_ITER && is_place(nodes[n].a) {   // as kelvinc's (#326)
        gen_error(nodes[n].a, "an Iterator is not copied: pass it on, or walk it")
        return
    }
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
        gen_written(nodes[n].a, y)                       // (#217); ${:} (#348)
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
    var e = n                                           // a[i] of a parameter's array, its caller's element (#357)
    while nodes[e].kind == N_FIELD || nodes[e].kind == N_INDEX {
        if nodes[e].kind == N_INDEX {
            let ay:int64 = type_of(nodes[e].a)
            if ay >= 0 && types[ay].kind == Y_FIXED && types[ay].name == 0 - 2 { return true }
            if ay >= 0 && types[ay].kind == Y_FIXED && types[ay].name == 0 - 4 {
                var m = $"this changes an element of a "
                let w:String = type_text(ay)
                m += &w
                m += ", which reads them alone, as [const T] takes them: take [T] to change them"
                gen_error(n, m.cstr)
                return false
            }
        }
        e = nodes[e].a
    }
    var d = n                                           // p^ of a const T^, which a let's borrow is (#272)
    while nodes[d].kind == N_FIELD || nodes[d].kind == N_INDEX { d = nodes[d].a }
    if nodes[d].kind == N_SELF && current >= 0 && nodes[current].c >= 0 && nodes[current].flag != 2 {   // (#320)
        var m = $"a method reads self and never changes it, as a let method: a var method, 'var "
        m += tok_text(nodes[current].c)
        m += "."
        m += tok_text(nodes[current].t)
        m += "(...)', changes the caller's var (#318)"
        gen_error(n, m.cstr)
        return false
    }
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

// whether n is a place a var method changes: a variable, self, a member,
// an element, or what a pointer points to, as kelvinc's (#320)
let changeable_place(n:int64):bool {
    let k:nkind = nodes[n].kind
    if k != N_ID && k != N_SELF && k != N_FIELD && k != N_INDEX && k != N_DEREF { return false }
    return is_place(n)
}

// whether what place n changes is a var: where it is a let, or self in a
// let method, or behind a read-only borrow, an error that goes on from
// lead, in kelvinc's words (#320)
let changes_var(n:int64, lead:const String^):bool {
    var d = n
    while nodes[d].kind == N_FIELD || nodes[d].kind == N_INDEX { d = nodes[d].a }
    var who = $""
    if nodes[d].kind == N_SELF && current >= 0 && nodes[current].c >= 0 && nodes[current].flag != 2 {
        who = $"self"
    } else if nodes[d].kind == N_ID && how_declared(nodes[d].t) != 0 {
        who = tok_text(nodes[d].t)
    }
    if who.count > 0 {
        var m = lead^.copy()
        m += "'"
        m += &who
        m += "', a let: declare it with var"
        gen_error(n, m.cstr)
        return false
    }
    if nodes[d].kind == N_DEREF { return may_change(n) }    // through a const T^, may_change's words
    return true
}

// the operator of a compound assignment, + of +=
let compound_op(t:int64):cstr {
    if tok_is(t, "+=") { return "+" }
    if tok_is(t, "-=") { return "-" }
    if tok_is(t, "*=") { return "*" }
    if tok_is(t, "/=") { return "/" }
    if tok_is(t, "%=") { return "%" }
    if tok_is(t, "|=") { return "|" }
    if tok_is(t, "&=") { return "&" }
    if tok_is(t, "~=") { return "^" }
    return "**"
}

// where a floating-point number's field begins, and its mask, as kelvinc
// writes them (#383)
let float_field_at(t:int64, wide:bool):cstr {
    if tok_is(t, "sign") { return wide ? "63" : "31" }
    if tok_is(t, "exponent") { return wide ? "52" : "23" }
    return "0"
}

let float_field_mask(t:int64, wide:bool):cstr {
    if tok_is(t, "sign") { return "0x1" }
    if tok_is(t, "exponent") { return wide ? "0x7ff" : "0xff" }
    return wide ? "0xfffffffffffff" : "0x7fffff"
}

// x.sign = b, x.exponent = e, x.significand = s of a floating-point
// number (#383), as kelvinc's: its bits set in the var that holds it, e
// and s within their fields or the program ends; x.abs and the rest are
// read, never set
let gen_float_set(n:int64) {
    let lhs:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let f:int64 = nodes[lhs].t
    let x:int64 = nodes[lhs].a
    let xy:int64 = type_of(x)
    let fl = power_float(xy)
    let sign = tok_is(f, "sign")
    if !fl || !(sign || tok_is(f, "exponent") || tok_is(f, "significand")) {
        var m = $"'."
        m += tok_text(f)
        m += fl ? "' of a floating-point number is read, never set: it is worked out of the value" : "' of an integer is read, never set: it is worked out of the value"
        gen_error(n, m.cstr)
        return
    }
    if tok_is(t, ":=") {
        var m = $"':=' sets a reference: '."
        m += tok_text(f)
        m += "' is set with '='"
        gen_error(n, m.cstr)
        return
    }
    let k:nkind = nodes[x].kind
    if k != N_ID && k != N_FIELD && k != N_INDEX && k != N_DEREF {
        var m = $"'."
        m += tok_text(f)
        m += "' changes the number it is of, so that number is a variable"
        gen_error(n, m.cstr)
        return
    }
    let v:int64 = nodes[n].b
    let compound = !tok_is(t, "=")
    if compound && sign {
        gen_error(n, "'.sign' is set with '=', and a bool: true for positive, false for negative")
        return
    }
    if compound && has_call(x) {
        var m = $"'x."
        m += tok_text(f)
        m += " "
        m += tok_text(t)
        m += " y' is 'x."
        m += tok_text(f)
        m += " = x."
        m += tok_text(f)
        m += " "
        m += compound_op(t)
        m += " y', which reads x twice, so x may not hold a call"
        gen_error(n, m.cstr)
        return
    }
    if sign && nodes[v].kind == N_ID && tok_is(nodes[v].t, "none") {   // a NaN's sign is its own, as kelvinc says it
        gen_error(v, "'.sign' of a floating-point number is set with a bool: true for positive, false for negative")
        return
    }
    let vy:int64 = type_of(v)
    if vy < 0 { return }
    if sign && types[vy].kind != Y_BOOL {
        gen_error(v, "'.sign' of a floating-point number is set with a bool: true for positive, false for negative")
        return
    }
    if !sign && !power_int(vy) {
        var m = $"'."
        m += tok_text(f)
        m += "' is set with an integer, and this is "
        let w:String = power_float(vy) ? $"a floating-point number" : types[vy].kind == Y_BOOL ? $"a bool" : nodes[v].kind == N_STR || types[vy].kind == Y_CSTR ? $"text" : kelvin_type_text(vy)
        m += &w
        gen_error(v, m.cstr)
        return
    }
    let wide = types[xy].kind == Y_F64
    let most:int64 = tok_is(f, "exponent") ? (wide ? 2047 : 255) : (wide ? 4503599627370495 : 8388607)
    if !sign && power_int_literal(v) && ((nodes[v].kind == N_UNARY && power_magnitude(v) != 0) || power_magnitude(v) < 0 || power_magnitude(v) > most) {
        var m = $"'."
        m += tok_text(f)
        m += wide ? "' of an f64 is 0 to " : "' of an f32 is 0 to "
        m += tok_is(f, "exponent") ? (wide ? "2047" : "255") : (wide ? "4503599627370495" : "8388607")
        m += ", and this is "
        if nodes[v].kind == N_UNARY {
            m += "-"
            m += tok_text(nodes[nodes[v].a].t)
        } else {
            m += tok_text(nodes[v].t)
        }
        gen_error(v, m.cstr)
        return
    }
    let bt:cstr := wide ? "uint64_t" : "uint32_t"
    put(wide ? "({ double *_kv_fp = &(" : "({ float *_kv_fp = &(")
    gen_expr(x)
    put(sign ? "); bool _kv_fs = (" : "); int64_t _kv_fs = (")
    if compound && tok_is(t, "**=") {
        gen_power(lhs, v)
    } else if compound {
        gen_expr(lhs)
        put(" ")
        put(compound_op(t))
        put(" (")
        gen_expr(v)
        put(")")
    } else {
        gen_expr(v)
    }
    put("); ")
    if !sign {
        put("if (_kv_fs < 0 || _kv_fs > (int64_t)")
        put(float_field_mask(f, wide))
        put(") kv_array_fail(\"'.")
        put_tok(f)
        put(wide ? "' of an f64 is 0 to " : "' of an f32 is 0 to ")
        put(tok_is(f, "exponent") ? (wide ? "2047" : "255") : (wide ? "2^52 - 1" : "2^23 - 1"))
        put(", and this set is past it\"); ")
    }
    put(bt)
    put(wide ? " _kv_fb; __builtin_memcpy(&_kv_fb, _kv_fp, 8); _kv_fb = (_kv_fb & ~((" : " _kv_fb; __builtin_memcpy(&_kv_fb, _kv_fp, 4); _kv_fb = (_kv_fb & ~((")
    put(bt)
    put(")")
    put(float_field_mask(f, wide))
    put(" << ")
    put(float_field_at(f, wide))
    put(")) | ((")
    put(bt)
    put(sign ? ")!_kv_fs << " : ")_kv_fs << ")
    put(float_field_at(f, wide))
    put(wide ? "); __builtin_memcpy(_kv_fp, &_kv_fb, 8); (void)0; });\n" : "); __builtin_memcpy(_kv_fp, &_kv_fb, 4); (void)0; });\n")
}

let gen_assign(n:int64) {
    let lhs:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    if nodes[lhs].kind == N_FIELD && (tok_is(nodes[lhs].t, "sign") || tok_is(nodes[lhs].t, "exponent") || tok_is(nodes[lhs].t, "significand") || tok_is(nodes[lhs].t, "abs") || tok_is(nodes[lhs].t, "isNaN") || tok_is(nodes[lhs].t, "isInfinite") || tok_is(nodes[lhs].t, "isFinite")) && type_of(nodes[lhs].a) >= 0 && (power_float(type_of(nodes[lhs].a)) || power_int(type_of(nodes[lhs].a))) {
        if !may_change(lhs) { return }                  // a number's own (#381, #382, #383)
        gen_float_set(n)
        return
    }
    if !may_change(lhs) { return }                      // (#271)
    if gen_bits_assign(n) { return }                    // a bit, '.value' or a whole Bits (#387)
    let y:int64 = type_of(lhs)
    if y < 0 { return }
    if tok_is(t, "**=") {                                // x **= y is x = x ** y (#380), as kelvinc's
        if has_call(lhs) {
            gen_error(lhs, "'x **= y' is 'x = x ** y', which evaluates x twice, so x may not hold a call")
            return
        }
        if !power_operand(lhs) || !power_operand(nodes[n].b) { return }
        gen_expr(lhs)
        put(" = ")
        gen_power(lhs, nodes[n].b)
        put(";\n")
        return
    }
    let case_set = nodes[lhs].kind == N_FIELD && tagged_of(type_of(nodes[lhs].a)) >= 0   // v.c = [a, b], its _set (#360)
    if types[y].kind == Y_FIXED && !case_set {           // C's, which kelvinc leaves to it (#354)
        gen_error(n, "an array is not assigned: assign its elements, a[i]")
        return
    }
    if is_owner(y) && owner_part(nodes[n].b) && tok_is(t, "=") {   // x = p.s, an alias else (#365)
        gen_error(nodes[n].b, "an owner is not copied by '=' (#54): copy its bytes with it.copy(), or borrow it with ':= &...'")
        return
    }
    if nodes[nodes[n].b].kind == N_EMPTY {               // d = ${:}: no type is written there, as kelvinc has it (#348)
        empty_error(nodes[n].b)
        return
    }
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
        if types[y].kind == Y_FIXED {                    // [a, b], its elements by their type (#360)
            gen_value(nodes[n].b, y)
        } else {
            gen_expr(nodes[n].b)
        }
        put(");\n")
        return
    }
    var into:int64 = -1                                  // what lhs indexes
    if nodes[lhs].kind == N_INDEX { into = type_of(nodes[lhs].a) }
    if into >= 0 && types[into].kind == Y_DICT && tok_is(t, "=") {
        let key:int64 = nodes[lhs].b
        let hold = needs_hold(key)                       // a String key an expression gives, held for the set (#314)
        if hold { hold_open(key) }
        put_dict_name(into)                              // d[k] = v sets the entry (#211)
        put("_set(")
        gen_place(nodes[lhs].a)
        put(", ")
        gen_key(into, key)
        put(", ")
        if is_case_word(nodes[n].b) {                    // d[k] = none of a V? (#341)
            gen_value(nodes[n].b, types[into].elem)
        } else {
            gen_expr(nodes[n].b)
        }
        put(")")
        if hold { hold_close(key) }
        put(";\n")
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
    } else if yk == Y_TASK && tok_is(t, "=") {           // the old one awaited and freed, as kelvinc's (#313)
        if is_place(nodes[n].b) {
            gen_error(nodes[n].b, "a Task is not copied: pass it on, or await it")
            return
        }
        put("kv_task_assign(")
        gen_place(lhs)
        put(", ")
        gen_value(nodes[n].b, y)
        put(");\n")
    } else if is_owner(y) && yk == Y_STRUCT && tok_is(t, "=") {
        serial += 1                                      // the new value first, then the old one freed (#217, #225)
        let sv = serial                                  // its own: the value may make names too (#341)
        put("{ ")
        put_ctype(y)
        put(" _kv_v")
        put_int(sv)
        put(" = ")
        gen_value(nodes[n].b, y)
        put("; ")
        put_free(y)
        put("(")
        gen_place(lhs)
        put("); ")
        gen_expr(lhs)
        put(" = _kv_v")
        put_int(sv)
        put("; }\n")
    } else if is_owner(y) {
        gen_error(n, "an owner is assigned only as a String")
    } else if has_element(lhs) && has_call(nodes[n].b) {
        serial += 1                                   // the value first, then where it goes
        let sv = serial                               // its own: the value may make names too (#341)
        put("{ ")
        put_ctype(y)
        put(" _kv_v")
        put_int(sv)
        put(" = ")
        gen_value(nodes[n].b, y)
        put("; ")
        gen_expr(lhs)
        put(" ")
        put_op(t)
        put(" _kv_v")
        put_int(sv)
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

// whether v is a part of an owner, a member, an element or what a pointer
// points to, that owns: what = would alias and return would move out of
// its owner, as kelvinc refuses them (#365)
let owner_part(v:int64):bool {
    let k:nkind = nodes[v].kind
    if k != N_FIELD && k != N_INDEX && k != N_DEREF { return false }
    if k == N_FIELD && (tagged_named(nodes[v].a) >= 0 || names_type(nodes[v].a)) { return false }   // T.none, a value made
    if k == N_FIELD {                                    // a struct's member or a case's value, not a property that makes one, as f.string
        let y:int64 = type_of(nodes[v].a)
        if y < 0 || (struct_of(y) < 0 && tagged_of(y) < 0) { return false }
    }
    return is_place(v) && is_owner(type_of(v))
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
    if owner_part(a) {                                   // as kelvinc says it (#365)
        gen_error(a, "an owner is returned as a whole variable, which moves out: a part of one is copied with .copy()")
        return
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
// the var method next of the struct y, which makes a value of y an
// iterator (#320), or -1
let iterator_next(y:int64):int64 {
    if y < 0 || types[y].kind != Y_STRUCT || types[y].name < 0 { return 0 - 1 }
    var key:String = tok_text(types[y].name)
    key += ".next"
    return method_names.get(key, -1)
}

// the let method makeIterator of the struct y, which makes a value of y
// a Sequence (#322), or -1
let sequence_maker(y:int64):int64 {
    if y < 0 || types[y].kind != Y_STRUCT || types[y].name < 0 { return 0 - 1 }
    var key:String = tok_text(types[y].name)
    key += ".makeIterator"
    return method_names.get(key, -1)
}

// ---------- lazy Sequences (#324) ----------

let gen_signature(d:int64)    // a prototype: the functions kc makes are declared by it

// a lazy Sequence kc makes for s.lazy.map(f) or s.lazy.filter(f), as
// kelvinc's #323: the struct seq { base }, whose makeIterator, maker,
// gives the struct walk { it } of the base's iterator, whose next, next,
// asks the base's next, nx, and calls f, fn, as each value is asked for
struct lazy_rec {
    node: int64             // the s.lazy.map(f) it is made for
    base: int64             // s, the base Sequence's expression
    base_y: int64           // its type
    mk: int64               // its makeIterator
    nx: int64               // its iterator's next
    fn: int64               // f, a function of the program or one kc makes of { ... }
    map: bool               // map, else filter
    seq: int64              // the lazy Sequence's struct, and its type
    seq_y: int64
    walk: int64             // its iterator's struct
    maker: int64            // its makeIterator and its iterator's next
    next: int64
}

var lazies:$[lazy_rec]
var lazy_at:Dictionary<int64, int64>      // a node's lazy Sequence, by its place in lazies
var anon_fns:$[int64]                     // the functions kc makes of { ... }, written after the others

// whether y is a lazy Sequence's type
let is_lazy_type(y:int64):bool {
    for i in 0..<lazies.count as int64 {
        if lazies[i].seq_y == y { return true }
    }
    return false
}

let lazy_type_of(n:int64):int64 {
    return lazies[lazy_of(n)].seq_y
}

// the type of s.lazy alone, s's own where s is a Sequence, so that the
// map or filter after it is read; -2 where s is no Sequence, and an
// iterator's .lazy is kelvinc's error
let lazy_field_type(n:int64):int64 {
    let y:int64 = type_of(nodes[n].a)
    if y >= 0 && (types[y].kind == Y_ITER || types[y].kind == Y_RANGE) { return y }  // an Iterator's, lazy too (#328), a Range's (#373)
    if sequence_maker(y) >= 0 { return y }
    if iterator_next(y) >= 0 {
        gen_error(n, "'.lazy' is a Sequence's, whose makeIterator gives a fresh iterator each time, and this is an iterator: give its type a 'let makeIterator()', or walk it with for (#323)")
        return -1
    }
    return 0 - 2
}

// a struct kc makes, of one member, named as token t
let lazy_struct(t:int64, member:cstr, y:int64):int64 {
    let d:int64 = make_node(D_STRUCT, t)
    var name = String(member)
    let f:int64 = make_node(S_VAR, made_token(&name))
    nodes[f].ty = y
    nodes[d].a = f
    decls += d
    return d
}

// a function kc makes, of the struct named as token recv: maker or next
let lazy_method(recv:int64, name:cstr, y:int64, flag:int64):int64 {
    var text = String(name)
    let d:int64 = make_node(D_FN, made_token(&text))
    nodes[d].c = recv
    nodes[d].ty = y
    nodes[d].flag = flag
    decls += d
    return d
}

// the function an anonymous function an makes, of values of the types
// ps: a function of the program kc writes after the others, its
// parameters $0, $1, ... of ps, or those written; its result written, ry
// where one is asked (#329), or its one expression's
let anon_function_of(an:int64, ps:const $[int64]^, ry:int64, me:const String^):int64 {
    var name = $"_kv_"
    name += tok_text(nodes[current].t)
    name += "_fn"
    name += String(anon_fns.count as int64 + 1)
    let d:int64 = make_node(D_FN, made_token(&name))
    if nodes[an].flag == 1 {
        var last:int64 = 0 - 1
        for k in 0..<ps^.count as int64 {
            var dollar = $"$"
            dollar += String(k)
            let p:int64 = make_node(S_VAR, made_token(&dollar))
            nodes[p].ty = ps^[k]
            nodes[p].flag = 1
            if last < 0 {
                nodes[d].a = p
            } else {
                nodes[last].next = p
            }
            last = p
        }
    } else if nodes[an].flag == 2 {                    // { v in ... }: each named, typed by where it goes (#330)
        nodes[d].a = nodes[an].a
        var p:int64 = nodes[d].a
        var k:int64 = 0
        while p >= 0 {
            if k < ps^.count as int64 { nodes[p].ty = ps^[k] }
            k += 1
            p = nodes[p].next
        }
        if k != ps^.count as int64 {                     // as kelvinc says it
            var m = $"this function names "
            m += String(k)
            m += k == 1 ? $" parameter" : $" parameters"
            m += ", and it is called with "
            m += String(ps^.count as int64)
            gen_error(an, m.cstr)
            return 0 - 1
        }
    } else {
        nodes[d].a = nodes[an].a
    }
    nodes[d].b = nodes[an].b
    nodes[d].ty = nodes[an].ty
    if nodes[d].ty < 0 && ry >= 0 { nodes[d].ty = ry }
    if nodes[d].ty < 0 {                               // the result its one expression gives
        let st:int64 = nodes[nodes[an].b].a
        if st < 0 || nodes[st].next >= 0 || nodes[st].kind != S_EXPR {
            var m = me^.copy()
            m += " takes a function whose body is one expression, whose value it gives: write its result's type, as in '{ (x:T):R in ... }'"
            gen_error(an, m.cstr)
            return 0 - 1
        }
        open_scope()
        var p:int64 = nodes[d].a
        while p >= 0 {
            declare_as(nodes[p].t, nodes[p].ty, 2)
            p = nodes[p].next
        }
        nodes[d].ty = type_of(nodes[st].a)
        close_scope()
    }
    decls += d
    anon_fns += d
    return d
}

// the function an anonymous function an, of a value of type ey, makes (#324)
let anon_function(an:int64, ey:int64, me:const String^):int64 {
    var ps:$[int64] = $[]
    ps += ey
    return anon_function_of(an, &ps, 0 - 1, me)
}

// the function of .lazy.map or .lazy.filter, n's, of each value of type
// ey: one of the program's or one kc makes of { ... }, checked as kelvinc
// checks it (#324, #328); -1 where it is in error
let lazy_fn_of(n:int64, ey:int64, is_map:bool, me:const String^):int64 {
    let f:int64 = nodes[n].b
    var fn:int64 = 0 - 1
    if f >= 0 && nodes[f].next < 0 && nodes[f].kind == N_ANON {
        fn = anon_function(f, ey, me)
        if fn < 0 { return 0 - 1 }
    } else if f >= 0 && nodes[f].next < 0 && nodes[f].kind == N_ID && var_type(nodes[f].t) < 0 {
        fn = decl_named(nodes[f].t, D_FN)
    }
    var p:int64 = fn >= 0 ? nodes[fn].a : 0 - 1
    if fn < 0 || p < 0 || nodes[p].next >= 0 || nodes[fn].ty < 0 || types[nodes[fn].ty].kind == Y_VOID {
        var m = me^.copy()
        m += " takes a function of one parameter, a value, with a result"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    if nodes[p].ty != ey {
        var m = me^.copy()
        m += " calls its function with each value, "
        let ew:String = kelvin_type_text(ey)
        m += &ew
        m += ", and this takes "
        let pw:String = kelvin_type_text(nodes[p].ty)
        m += &pw
        gen_error(n, m.cstr)
        return 0 - 1
    }
    if !is_map && types[nodes[fn].ty].kind != Y_BOOL && nodes[f].kind == N_ANON && nodes[f].flag != 0 {
        let e:int64 = nodes[nodes[nodes[f].b].a].a      // as kelvinc's: what an anonymous filter's one expression gives
        var m = me^.copy()
        m += " looks for what its function says true for, a bool, and this "
        if nodes[e].kind == N_NUM {
            m += "is a number: write 'true' or 'false'"
        } else {
            m += "gives "
            if nodes[e].kind == N_BIN {
                m += "a number"
            } else {
                let rw:String = kelvin_type_text(nodes[fn].ty)
                m += &rw
            }
            m += ": compare it, as in 'x != 0'"
        }
        gen_error(n, m.cstr)
        return 0 - 1
    }
    if !is_map && types[nodes[fn].ty].kind != Y_BOOL {
        var m = me^.copy()
        m += " takes a function that says whether to keep a value, a bool, and this gives "
        let rw:String = kelvin_type_text(nodes[fn].ty)
        m += &rw
        gen_error(n, m.cstr)
        return 0 - 1
    }
    return fn
}

// the lazy Sequence that s.lazy.map(f) or s.lazy.filter(f), or a lazy
// Sequence's map or filter, n, makes, by its place in lazies, made the
// first time it is asked; -1 where n is none
let lazy_of(n:int64):int64 {
    if nodes[n].kind != N_METHOD || !(tok_is(nodes[n].t, "map") || tok_is(nodes[n].t, "filter")) { return 0 - 1 }
    let seen = lazy_at.get(n, -1)
    if seen >= 0 { return seen }
    let a:int64 = nodes[n].a
    var base:int64 = 0 - 1
    if nodes[a].kind == N_FIELD && tok_is(nodes[a].t, "lazy") {
        let ly:int64 = lazy_field_type(a)
        if ly < 0 || types[ly].kind == Y_ITER { return 0 - 1 }   // an Iterator's is iter_lazy_of's (#328)
        base = nodes[a].a
    } else if nodes[a].kind != N_FIELD || !tok_is(nodes[a].t, "lazy") {
        if !is_lazy_type(type_of(a)) { return 0 - 1 }
        base = a                                        // a lazy Sequence's own map and filter are lazy
    }
    let is_map = tok_is(nodes[n].t, "map")
    var me = $"'.lazy."
    me += tok_text(nodes[n].t)
    me += "'"
    let by:int64 = type_of(base)
    let mk:int64 = sequence_maker(by)
    let iy:int64 = nodes[mk].ty
    let nx:int64 = iterator_next(iy)
    if nodes[mk].flag == 2 || nodes[mk].a >= 0 || nx < 0 {
        var m = $"a Sequence gives a fresh iterator by its makeIterator(), a let method that takes nothing and gives a value whose 'var next():T?' gives each value: write 'let "
        m += tok_text(types[by].name)
        m += ".makeIterator():I'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let ey:int64 = some_type(nodes[nx].ty)
    if nodes[nx].flag != 2 || nodes[nx].a >= 0 || ey < 0 {
        var m = me.copy()
        m += " walks an iterator by its next(), a var method that takes nothing and gives each value, then none: write 'var "
        m += tok_text(nodes[nx].c)
        m += ".next():T?'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let fn:int64 = lazy_fn_of(n, ey, is_map, &me)
    if fn < 0 { return 0 - 1 }
    let tag:int64 = lazies.count as int64 + 1
    var sname = $"_kv_lazy"
    sname += String(tag)
    let seq_t:int64 = made_token(&sname)
    sname += "_it"
    let walk_t:int64 = made_token(&sname)
    let seq:int64 = lazy_struct(seq_t, "base", by)
    let walk:int64 = lazy_struct(walk_t, "it", iy)
    let seq_y:int64 = type_of_kind(Y_STRUCT, -1, seq_t)
    let walk_y:int64 = type_of_kind(Y_STRUCT, -1, walk_t)
    let opt:int64 = is_map ? optional_of(nodes[fn].ty) : nodes[nx].ty
    let maker:int64 = lazy_method(seq_t, "makeIterator", walk_y, 0)
    let next:int64 = lazy_method(walk_t, "next", opt, 2)
    index_names()                                       // its structs and functions, found by name
    let r:lazy_rec = {n, base, by, mk, nx, fn, is_map, seq, seq_y, walk, maker, next}
    lazies += r
    lazy_at[n] = lazies.count as int64 - 1
    return lazies.count as int64 - 1
}

// s.lazy.map(f) (#324): the lazy Sequence's struct, of s, a copy where s
// is a place that owns, else s as it is, which moves in
let gen_lazy_make(n:int64) {
    let i = lazy_of(n)
    let base = lazies[i].base
    let by = lazies[i].base_y
    put("((struct ")
    put_tok(nodes[lazies[i].seq].t)
    put("){")
    if is_owner(by) && is_place(base) {
        put_owner_prefix(by)
        put("_copy(&(")
        gen_expr(base)
        put("))")
    } else {
        gen_expr(base)
    }
    put("})")
}

// the prototypes of the functions kc makes (#324), before the functions
let put_lazy_heads() {
    for i in 0..<anon_fns.count as int64 {
        gen_signature(anon_fns[i])
        put(";\n")
    }
    for i in 0..<lazies.count as int64 {
        gen_signature(lazies[i].maker)
        put(";\n")
        gen_signature(lazies[i].next)
        put(";\n")
    }
}

// the tag of an Optional's some, of type y
let some_tag(y:int64):int64 {
    let d = tagged_of(y)
    var m:int64 = nodes[d].a
    while m >= 0 {
        if tok_is(nodes[m].t, "some") { return case_tag(d, m) }
        m = nodes[m].next
    }
    return 1
}

// each lazy Sequence's makeIterator, and its iterator's next, as kelvinc's
// lazy_body (#323): a value that owns is given to f as a copy, which f
// owns, and freed unless filter keeps it
let put_lazy_bodies() {
    for i in 0..<lazies.count as int64 {
        let r:lazy_rec = lazies[i]
        gen_signature(r.maker)
        put("\n{\n    return (struct ")
        put_tok(nodes[r.walk].t)
        put("){")
        put_tok(nodes[r.mk].c)
        put("__")
        put_tok(nodes[r.mk].t)
        put("(self.base)};\n}\n\n")
        let in_y:int64 = nodes[r.nx].ty
        let ey:int64 = some_type(in_y)
        let out_y:int64 = nodes[r.next].ty
        gen_signature(r.next)
        put("\n{\n    for (;;)\n    {\n        ")
        put_ctype(in_y)
        put(" _kv_o = ")
        put_tok(nodes[r.nx].c)
        put("__")
        put_tok(nodes[r.nx].t)
        put("(&_kv_selfp->it);\n        if (_kv_o.tag != ")
        put_int(some_tag(in_y))
        put(") return _kv_")
        put_tok(types[out_y].name)
        put("_make_none();\n        ")
        if r.map {
            put_ctype(nodes[r.fn].ty)
            put(" _kv_v = ")
        } else {
            put("if (")
        }
        put_fn_name(r.fn)
        put("(")
        if is_owner(ey) {
            put_owner_prefix(ey)
            put("_copy(&_kv_o.u.some)")
        } else {
            put("_kv_o.u.some")
        }
        put(r.map ? ");\n" : ")) return _kv_o;\n")
        if is_owner(ey) {
            put("        ")
            put_free(ey)
            put("(&_kv_o.u.some);\n")
        }
        if r.map {
            put("        return _kv_")
            put_tok(types[out_y].name)
            put("_make_some(_kv_v);\n")
        }
        put("    }\n}\n\n")
    }
}

// ---------- Iterator<T> (#326) ----------

// an Iterator kc makes of Iterator(state) { ... }, as kelvinc's #325: its
// function, of the program or made of { ... }, over a state of type
// state_y, whose adapters _kv_iterN_next and _drop kc writes
struct iter_rec {
    node: int64
    state_y: int64
    fn: int64
    iter_y: int64
    op: int64               // 0 of Iterator(...), 1 of it.lazy.map(f), 2 of it.lazy.filter(f) (#328), 3 of x.prefix(n), 4 of x.prefix(f) (#372), 5 of a Range (#373), 6 of its reversed() (#378), 7 of its stride(n) (#379)
    src: int64              // the state's expression: the state, or the Iterator made lazy
    count: int64            // prefix(n)'s n, stride(n)'s n (#379); -1 else
}

var iters:$[iter_rec]
var iter_at:Dictionary<int64, int64>      // a node's Iterator, by its place in iters

// the first value a function's body returns, as kc types it: the locals
// before it declared in turn; -1 where it returns none alone
let first_return(s0:int64):int64 {
    var s:int64 = s0
    while s >= 0 && !failed {
        let k:nkind = nodes[s].kind
        if k == S_VAR {
            declare_as(nodes[s].t, nodes[s].ty >= 0 ? nodes[s].ty : inferred(s), nodes[s].flag == 1 ? 1 : 0)
        } else if k == S_RETURN && nodes[s].a >= 0 && !(nodes[nodes[s].a].kind == N_ID && tok_is(nodes[nodes[s].a].t, "none")) {
            return type_of(nodes[s].a)
        } else if k == S_IF || k == S_WHILE || k == S_BLOCK {
            open_scope()
            let y:int64 = first_return(k == S_BLOCK ? nodes[s].a : nodes[nodes[s].b].a)
            close_scope()
            if y >= 0 { return y }
            if k == S_IF && nodes[s].c >= 0 {
                open_scope()
                let z:int64 = first_return(nodes[nodes[s].c].kind == S_BLOCK ? nodes[nodes[s].c].a : nodes[s].c)
                close_scope()
                if z >= 0 { return z }
            }
        }
        s = nodes[s].next
    }
    return 0 - 1
}

// the function an Iterator's { ... } makes, over a state of type sy: $0,
// or its first parameter written, is the state itself, flag 3; its result
// written, T? of the T written, or T? of its first `return v`
let iter_function(an:int64, sy:int64, ty:int64):int64 {
    var name = $"_kv_"
    name += tok_text(nodes[current].t)
    name += "_fn"
    name += String(anon_fns.count as int64 + 1)
    let d:int64 = make_node(D_FN, made_token(&name))
    if nodes[an].flag == 1 {
        var zero = $"$0"
        let p:int64 = make_node(S_VAR, made_token(&zero))
        nodes[p].ty = sy
        nodes[p].flag = 3
        nodes[d].a = p
    } else {
        nodes[d].a = nodes[an].a
        if nodes[d].a < 0 || nodes[nodes[d].a].ty != sy {
            gen_error(an, "an Iterator's function takes its state, which it changes")
            return 0 - 1
        }
        nodes[nodes[d].a].flag = 3
    }
    nodes[d].b = nodes[an].b
    nodes[d].ty = nodes[an].ty
    if nodes[d].ty < 0 && ty >= 0 { nodes[d].ty = optional_of(ty) }
    if nodes[d].ty < 0 {                                // T? of what its first `return v` gives, as kelvinc's
        open_scope()
        declare_as(nodes[nodes[d].a].t, sy, 0)
        let ry:int64 = first_return(nodes[nodes[an].b].a)
        close_scope()
        if ry < 0 {
            gen_error(an, "an Iterator's function gives each value, 'return v', then none, 'return none', and this returns no value: return one, or write the type, as in 'Iterator<int64>(...)'")
            return 0 - 1
        }
        nodes[d].ty = optional_of(ry)
    }
    decls += d
    anon_fns += d
    return d
}

// the Iterator n makes, by its place in iters, made the first time it is
// typed; -1 where it is in error
let iter_of(n:int64):int64 {
    let seen = iter_at.get(n, -1)
    if seen >= 0 { return seen }
    let sy:int64 = type_of(nodes[n].a)
    if sy < 0 { return 0 - 1 }
    let f:int64 = nodes[n].b
    var fn:int64 = 0 - 1
    if nodes[f].kind == N_ANON {
        fn = iter_function(f, sy, nodes[n].ty)
        if fn < 0 { return 0 - 1 }
    } else if nodes[f].kind == N_ID && var_type(nodes[f].t) < 0 {
        fn = decl_named(nodes[f].t, D_FN)
        let p:int64 = fn >= 0 ? nodes[fn].a : 0 - 1
        if p < 0 || nodes[p].next >= 0 || types[nodes[p].ty].kind != Y_PTR || types[nodes[p].ty].elem != sy {
            var m = $"an Iterator's function takes its state, "
            let sw:String = kelvin_type_text(sy)
            m += &sw
            m += ", by a borrow that may change it, "
            m += &sw
            m += "^"
            if p >= 0 {
                m += ", and this takes "
                let pw:String = kelvin_type_text(nodes[p].ty)
                m += &pw
            }
            gen_error(f, m.cstr)
            return 0 - 1
        }
    }
    if fn < 0 || nodes[fn].ty < 0 || some_type(nodes[fn].ty) < 0 {
        gen_error(n, "an Iterator takes a function of its state that gives each value, a T?, then none")
        return 0 - 1
    }
    let ey:int64 = some_type(nodes[fn].ty)
    if nodes[n].ty >= 0 && nodes[n].ty != ey {
        var m = $"this Iterator gives "
        let tw:String = kelvin_type_text(nodes[n].ty)
        m += &tw
        m += ", and its function gives "
        let ew:String = kelvin_type_text(ey)
        m += &ew
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let r:iter_rec = {n, sy, fn, type_of_kind(Y_ITER, ey, -1), 0, nodes[n].a, 0 - 1}
    iters += r
    iter_at[n] = iters.count as int64 - 1
    return iters.count as int64 - 1
}

// the Iterator it.lazy.map(f) or it.lazy.filter(f), n, makes of an
// Iterator<T> (#328), as kelvinc's #327: its state the Iterator, moved in;
// -1 where n is none
let iter_lazy_of(n:int64):int64 {
    if nodes[n].kind != N_METHOD || !(tok_is(nodes[n].t, "map") || tok_is(nodes[n].t, "filter")) { return 0 - 1 }
    let a:int64 = nodes[n].a
    if nodes[a].kind != N_FIELD || !tok_is(nodes[a].t, "lazy") { return 0 - 1 }
    let seen = iter_at.get(n, -1)
    if seen >= 0 { return seen }
    var base:int64 = nodes[a].a
    var by:int64 = type_of(base)
    if by >= 0 && types[by].kind == Y_RANGE {           // a Range's values, of an Iterator kc makes of it (#373)
        let w:int64 = make_node(N_RITER, nodes[base].t)
        nodes[w].a = base
        base = w
        by = type_of(w)
    }
    if by < 0 || types[by].kind != Y_ITER { return 0 - 1 }
    let is_map = tok_is(nodes[n].t, "map")
    var me = $"'.lazy."
    me += tok_text(nodes[n].t)
    me += "'"
    let ey:int64 = types[by].elem
    let fn:int64 = lazy_fn_of(n, ey, is_map, &me)
    if fn < 0 { return 0 - 1 }
    let uy:int64 = is_map ? nodes[fn].ty : ey
    let r:iter_rec = {n, by, fn, type_of_kind(Y_ITER, uy, -1), is_map ? 1 : 2, base, 0 - 1}
    iters += r
    iter_at[n] = iters.count as int64 - 1
    return iters.count as int64 - 1
}

let iter_lazy_type_of(n:int64):int64 {
    return iters[iter_lazy_of(n)].iter_y
}

// what x.prefix(...), n, takes (#372): a count, an integer, -2, or a
// function of each value, of type ey, that says whether to keep it,
// checked as kelvinc checks them; -1 where it is in error
let prefix_arg(n:int64, ey:int64):int64 {
    let b:int64 = nodes[n].b
    if b < 0 {
        gen_error(n, "'.prefix' takes a count, '.prefix(n)', or a function of a value, '.prefix { ... }'")
        return 0 - 1
    }
    if nodes[b].next >= 0 {
        gen_error(nodes[b].next, "'.prefix' takes one count, or one function")
        return 0 - 1
    }
    if nodes[b].kind == N_ANON || nodes[b].kind == N_ID && var_type(nodes[b].t) < 0 && decl_named(nodes[b].t, D_FN) >= 0 {
        let me = $"'.prefix'"
        return lazy_fn_of(n, ey, false, &me)
    }
    let cy:int64 = type_of(b)
    if cy < 0 { return 0 - 1 }
    let k:ykind = types[cy].kind
    if k != Y_I64 && k != Y_I32 && k != Y_U8 && k != Y_U32 && k != Y_C {
        var m = $"'.prefix' takes a count, an integer, or a function that says whether to keep each value, and this is "
        let w:String = k == Y_BOOL ? $"a bool" : k == Y_F64 || k == Y_F32 ? $"a floating-point number" : kelvin_type_text(cy)
        m += &w
        gen_error(b, m.cstr)
        return 0 - 1
    }
    return 0 - 2
}

// the Iterator x.prefix(n) or x.prefix { ... }, n, makes of an
// Iterator<T>, an iterator or a Sequence (#372), as kelvinc's: its state
// the base, moved in, or a Sequence's fresh iterator, with the count left
// and whether it is done; -1 where n is none
let iter_prefix_of(n:int64):int64 {
    if nodes[n].kind != N_METHOD || !tok_is(nodes[n].t, "prefix") { return 0 - 1 }
    let seen = iter_at.get(n, -1)
    if seen >= 0 { return seen }
    let a:int64 = nodes[n].a
    if names_type(a) || method_of(n) >= 0 { return 0 - 1 }      // a method of its own wins
    let y:int64 = type_of(a)
    if y < 0 { return 0 - 1 }
    var sy:int64 = y
    var src:int64 = a
    let mk = sequence_maker(y)
    if mk >= 0 {                                         // a Sequence's fresh iterator, s.makeIterator()
        sy = nodes[mk].ty
        src = make_node(N_METHOD, nodes[mk].t)
        nodes[src].a = a
    } else if types[y].kind == Y_RANGE {                 // r.prefix { ... }: of an Iterator kc makes of it (#373)
        let b:int64 = nodes[n].b
        let fn_arg = b >= 0 && (nodes[b].kind == N_ANON || nodes[b].kind == N_ID && var_type(nodes[b].t) < 0 && decl_named(nodes[b].t, D_FN) >= 0)
        if !fn_arg { return 0 - 1 }                      // r.prefix(n), a Range: prefix_of's
        src = make_node(N_RITER, nodes[a].t)
        nodes[src].a = a
        sy = type_of(src)
    } else if types[y].kind != Y_ITER && iterator_next(y) < 0 {
        return 0 - 1
    }
    let ey:int64 = walked_elem(y)
    if ey < 0 { return 0 - 1 }
    let fn:int64 = prefix_arg(n, ey)
    if fn == 0 - 1 { return 0 - 1 }
    let r:iter_rec = {n, sy, fn < 0 ? 0 - 1 : fn, type_of_kind(Y_ITER, ey, -1), fn < 0 ? 3 : 4, src, fn < 0 ? nodes[n].b : 0 - 1}
    iters += r
    iter_at[n] = iters.count as int64 - 1
    return iters.count as int64 - 1
}

let iter_prefix_type_of(n:int64):int64 {
    return iters[iter_prefix_of(n)].iter_y
}

// ---------- Range<T> (#373) ----------

// the Range<T> of a range n, as kelvinc's: T the upper bound's type where
// kc sees it, else the lower one's, else i64; or the Range<T> it is given
// to (gen_value); a bound that is no integer kelvinc's error
let range_type_of(n:int64):int64 {
    if nodes[n].ty >= 0 { return nodes[n].ty }
    var ey:int64 = 0 - 1
    var i = 0
    while i < 2 {
        let b:int64 = i == 0 ? nodes[n].b : nodes[n].a
        i += 1
        if b < 0 { continue }
        let by:int64 = type_of(b)
        if by < 0 { return 0 - 1 }
        let k:ykind = types[by].kind
        if k != Y_I64 && k != Y_I32 && k != Y_U8 && k != Y_U32 && k != Y_C {
            var m = $"a range is of integers, not "
            let w:String = type_text(by)
            m += &w
            gen_error(b, m.cstr)
            return 0 - 1
        }
        let literal = nodes[b].kind == N_NUM || nodes[b].kind == N_CHAR || (nodes[b].kind == N_UNARY && nodes[nodes[b].a].kind == N_NUM)
        if ey < 0 && !literal && k != Y_C { ey = by }
    }
    if ey < 0 { ey = base_type(Y_I64) }
    nodes[n].ty = type_of_kind(Y_RANGE, ey, -1)
    return nodes[n].ty
}

// a member of a Range that it has not, as kelvinc says it
let range_member_error(n:int64) {
    var m = $"a Range has lowerBound, upperBound, count, contains, map, filter, reduce, flatMap, lazy, prefix, reversed and stride, and '."
    m += tok_text(nodes[n].t)
    m += "' is none of them"
    gen_error(n, m.cstr)
}

// T's largest, where a Range<T> without an end stops
let range_max(y:int64):cstr {
    let k:ykind = y >= 0 ? types[y].kind : Y_I64
    return k == Y_I32 ? "INT32_MAX" : k == Y_U8 ? "UINT8_MAX" : k == Y_U32 ? "UINT32_MAX" : "INT64_MAX"
}

// a Range's walk, as kelvinc's: of the Range r, the hidden p_lo, p_go and
// p_end of T, ey: from lo, whether it goes on at all, where it ends
let put_range_walk(ey:int64, r:cstr, p:cstr) {
    put_ctype(ey)
    put(" ")
    put(p)
    put("_lo = (")
    put(r)
    put(").lo, ")
    put(p)
    put("_go = (")
    put(r)
    put(").kind ? ")
    put(p)
    put("_lo <= (")
    put(r)
    put(").hi : ")
    put(p)
    put("_lo < (")
    put(r)
    put(").hi, ")
    put(p)
    put("_end = (")
    put(r)
    put(").kind || !")
    put(p)
    put("_go ? (")
    put(r)
    put(").hi : (")
    put(r)
    put(").hi - 1")
}

// the Iterator kc makes of the Range of an N_RITER, n (#373), or of
// r.reversed() (#378), down, or of r.stride(n) (#379): where it is, where
// it ends and whether it goes on
let range_iter_of(n:int64):int64 {
    let seen = iter_at.get(n, -1)
    if seen >= 0 { return seen }
    let ry:int64 = type_of(nodes[n].a)
    if ry < 0 { return 0 - 1 }
    let stride = nodes[n].kind == N_METHOD && tok_is(nodes[n].t, "stride")
    let op:int64 = stride ? 7 : nodes[n].kind == N_METHOD ? 6 : 5     // r.reversed(), from its end down (#378); r.stride(n) (#379)
    let r:iter_rec = {n, ry, 0 - 1, type_of_kind(Y_ITER, types[ry].elem, -1), op, nodes[n].a, stride ? nodes[n].b : 0 - 1}
    iters += r
    iter_at[n] = iters.count as int64 - 1
    return iters.count as int64 - 1
}

// whether a Range<T>'s T, y, is unsigned, which steps never down (#379)
let range_unsigned(y:int64):bool {
    return y >= 0 && (types[y].kind == Y_U8 || types[y].kind == Y_U32)
}

// r.stride(n) (#379), as kelvinc's: n one integer, a T, never 0; a
// negative one walks from the end, which a Range of unsigned T, or one
// written without an end, has not
let gen_range_stride(n:int64) {
    let a:int64 = nodes[n].a
    let ry:int64 = type_of(a)
    let v:int64 = nodes[n].b
    if v < 0 {
        gen_error(n, "'.stride' takes a step, an integer, as in 'r.stride(2)'")
        return
    }
    if nodes[v].next >= 0 {
        gen_error(nodes[v].next, "'.stride' takes one integer")
        return
    }
    let vy:int64 = type_of(v)
    if vy < 0 { return }
    let k:ykind = types[vy].kind
    if k != Y_I64 && k != Y_I32 && k != Y_U8 && k != Y_U32 && k != Y_C {
        var m = $"'.stride' takes an integer, and this is "
        let w:String = k == Y_BOOL ? $"a bool" : k == Y_F64 || k == Y_F32 ? $"a floating-point number" : type_text(vy)
        m += &w
        gen_error(v, m.cstr)
        return
    }
    if nodes[v].kind == N_NUM && tok_is(nodes[v].t, "0") {
        gen_error(v, "'.stride(0)' never moves: step by a number other than 0")
        return
    }
    let negative = nodes[v].kind == N_UNARY && tok_is(nodes[v].t, "-") && nodes[nodes[v].a].kind == N_NUM
    if negative && range_unsigned(types[ry].elem) {
        var m = $"a "
        let w:String = kelvin_type_text(ry)
        m += &w
        m += " steps by a "
        let e:String = kelvin_type_text(types[ry].elem)
        m += &e
        m += ", which is never negative: walk it down with '.reversed()'"
        gen_error(v, m.cstr)
        return
    }
    if negative && nodes[a].kind == N_RANGE && nodes[a].flag == 2 {
        let lo:int64 = nodes[a].a
        let step:String = tok_text(nodes[nodes[v].a].t)
        var m = $"'.stride(-"
        m += &step
        m += ")' walks a Range from its end, and "
        if nodes[lo].kind == N_NUM { m += tok_text(nodes[lo].t) } else { m += "lo" }
        m += "... has none: take the first few, as in '.prefix(10).stride(-"
        m += &step
        m += ")'"
        gen_error(n, m.cstr)
        return
    }
    let i = range_iter_of(n)
    if i >= 0 { gen_iter_value(i) }
}

// ---------- b ** e and b.pow(e, m) (#380) ----------

// whether y is one of kc's integers, or a floating-point type
let power_int(y:int64):bool {
    if y < 0 { return false }
    let k:ykind = types[y].kind
    return k == Y_I64 || k == Y_I32 || k == Y_U8 || k == Y_U32
}

let power_float(y:int64):bool {
    return y >= 0 && (types[y].kind == Y_F64 || types[y].kind == Y_F32)
}

// whether v is a literal in digits, possibly negated: an integer, or a
// floating-point one
let power_int_literal(v:int64):bool {
    let w:int64 = nodes[v].kind == N_UNARY && tok_is(nodes[v].t, "-") ? nodes[v].a : v
    return nodes[w].kind == N_NUM && !float_tok(nodes[w].t)
}

let power_float_literal(v:int64):bool {
    let w:int64 = nodes[v].kind == N_UNARY && tok_is(nodes[v].t, "-") ? nodes[v].a : v
    return nodes[w].kind == N_NUM && float_tok(nodes[w].t)
}

// an integer operand's type, promoted as C promotes a shift's left one,
// a u8 an i32, a literal an i64 as kelvinc has it
let power_promoted(v:int64):int64 {
    if power_int_literal(v) { return base_type(Y_I64) }
    let y:int64 = type_of(v)
    if y >= 0 && types[y].kind == Y_U8 { return base_type(Y_I32) }
    return y
}

// b ** e's type, as kelvinc's: of integers the base's promoted; else an
// f32 where neither is an f64, nor a floating-point literal
let power_type(a:int64, b:int64):int64 {
    let ay:int64 = type_of(a)
    let by:int64 = type_of(b)
    if !(power_int(ay) || power_float(ay)) || !(power_int(by) || power_float(by)) { return 0 - 1 }
    if power_float(ay) || power_float(by) {
        let fa = !power_float(ay) || (types[ay].kind == Y_F32 && !power_float_literal(a))
        let fb = !power_float(by) || (types[by].kind == Y_F32 && !power_float_literal(b))
        return base_type(fa && fb ? Y_F32 : Y_F64)
    }
    return power_promoted(a)
}

// whether v may be an operand of '**', else kelvinc's error
let power_operand(v:int64):bool {
    let y:int64 = type_of(v)
    if y < 0 { return false }
    if power_int(y) || power_float(y) { return true }
    let k:ykind = types[y].kind
    if k == Y_C {
        gen_error(v, "'**' takes numbers, and kelvinc cannot see this one's type: convert it, as in 'x as i64' or 'x as f64'")
        return false
    }
    var m = $"'**' takes numbers, and this is "
    let w:String = k == Y_BOOL ? $"a bool" : nodes[v].kind == N_STR || k == Y_CSTR ? $"text" : kelvin_type_text(y)
    m += &w
    gen_error(v, m.cstr)
    return false
}

// a literal integer's magnitude, written in decimal, 0x, 0b or C's octal;
// -1 past i64's largest
let power_magnitude(v:int64):int64 {
    let w:int64 = nodes[v].kind == N_UNARY ? nodes[v].a : v
    let at:int64 = toks[nodes[w].t].at
    let n:int64 = toks[nodes[w].t].len
    var base:int64 = 10
    var i:int64 = 0
    if n > 1 && codes[at] == '0' && (codes[at + 1] == 'x' || codes[at + 1] == 'X') {
        base = 16
        i = 2
    } else if n > 1 && codes[at] == '0' && (codes[at + 1] == 'b' || codes[at + 1] == 'B') {
        base = 2
        i = 2
    } else if n > 1 && codes[at] == '0' {
        base = 8
        i = 1
    }
    var m:int64 = 0
    while i < n {
        let c:uint32 = codes[at + i]
        var d:int64 = 0
        if c >= '0' && c <= '9' {
            d = c as int64 - 48
        } else if c >= 'a' && c <= 'f' {
            d = c as int64 - 87
        } else if c >= 'A' && c <= 'F' {
            d = c as int64 - 55
        }
        if m > (9223372036854775807 - d) / base { return 0 - 1 }
        m = m * base + d
        i += 1
    }
    return m
}

// x * y of two magnitudes, -1 of one past i64's largest
let power_product(x:int64, y:int64):int64 {
    if x == 0 || y == 0 { return 0 }
    if x < 0 || y < 0 || x > 9223372036854775807 / y { return 0 - 1 }
    return x * y
}

// b ** e of two integer literals, worked out as kelvinc does: an i64
let gen_power_literals(a:int64, b:int64) {
    let bm:int64 = power_magnitude(a)
    var em:int64 = power_magnitude(b)
    if em < 0 { em = 9223372036854775807 }
    var r:int64 = 1
    var x:int64 = bm
    var k:int64 = em
    while k > 0 {
        if k % 2 == 1 { r = power_product(r, x) }
        k = k / 2
        if k > 0 { x = power_product(x, x) }
    }
    let neg = nodes[a].kind == N_UNARY && em % 2 == 1 && r != 0
    if r < 0 {
        var shift:int64 = 0                              // (-2) ** 63, i64's least: |b| 2^k, and k e is 63
        var p:int64 = bm
        while p > 1 && p % 2 == 0 {
            p = p / 2
            shift += 1
        }
        if neg && p == 1 && shift > 0 && 63 % shift == 0 && 63 / shift == em {
            put("(-9223372036854775807 - 1)")
            return
        }
        var m = $"'**' of two literals is an i64, as a literal is, and this is past its "
        m += neg ? "least" : "largest"
        m += ": raise a floating-point number, as in '2.0 ** 64', or convert, as in 'u64(2) ** 63'"
        gen_error(a, m.cstr)
        return
    }
    if neg { put("(-") }
    put_int(r)
    if neg { put(")") }
}

// a literal's value, possibly negated, as an f64
let power_double(v:int64):float64 {
    let neg = nodes[v].kind == N_UNARY
    let w:int64 = neg ? nodes[v].a : v
    var x:float64 = 0.0
    if power_float_literal(w) {
        let s:String = tok_text(nodes[w].t)
        x = strtod(s.cstr, nullptr)
    } else {
        x = power_magnitude(w) as float64
    }
    return neg ? 0.0 - x : x
}

// b ** e of two literals, one floating-point, worked out by C's pow, as
// kelvinc does, so a global's value may be one
let gen_power_floats(a:int64, b:int64) {
    let v:float64 = pow(power_double(a), power_double(b))
    if v != v {
        put("__builtin_nan(\"\")")
        return
    }
    let neg = signbit(v) != 0
    let m:float64 = fabs(v)
    if neg { put("(-") }
    if m > 1.7976931348623157e308 {
        put("__builtin_inf()")
    } else {
        var buf:[uint8](40)
        snprintf(&buf[0], 40, "%.17g", m)
        let text:cstr := &buf[0]
        put(text)
        if strpbrk(text, ".e") == nullptr { put(".0") }
    }
    if neg { put(")") }
}

// b ** e (#380), as kelvinc writes it: of a floating-point number, C's pow
// or powf; of integers, multiplying in a u64, which wraps as '*' does, the
// exponent never negative; two literals worked out here
let gen_power(a:int64, b:int64) {
    if !power_operand(a) || !power_operand(b) { return }
    let ay:int64 = type_of(a)
    let by:int64 = type_of(b)
    let lits = (power_int_literal(a) || power_float_literal(a)) && (power_int_literal(b) || power_float_literal(b))
    if power_float(ay) || power_float(by) {
        if lits {
            gen_power_floats(a, b)
            return
        }
        let single = types[power_type(a, b)].kind == Y_F32
        put(single ? "__builtin_powf((float)(" : "__builtin_pow((double)(")
        gen_expr(a)
        put(single ? "), (float)(" : "), (double)(")
        gen_expr(b)
        put("))")
        return
    }
    if power_int_literal(b) && nodes[b].kind == N_UNARY && power_magnitude(b) != 0 {
        var m = $"'**' of integers takes an exponent of 0 or more, and this is -"
        m += tok_text(nodes[nodes[b].a].t)
        m += ": a power of an integer less than 0 is no integer, but a floating-point one's is, as in '2.0 ** -1'"
        gen_error(b, m.cstr)
        return
    }
    if lits {
        gen_power_literals(a, b)
        return
    }
    let rt:int64 = power_promoted(a)
    put("({ ")
    put_ctype(rt)
    put(" _kv_pb = (")
    gen_expr(a)
    put("); ")
    let ey:int64 = power_int_literal(b) ? base_type(Y_I64) : power_promoted(b)
    put_ctype(ey)
    put(" _kv_pe = (")
    gen_expr(b)
    put("); ")
    if !power_int_literal(b) && types[ey].kind != Y_U32 {
        put("if (_kv_pe < 0) kv_array_fail(\"'**' of integers takes an exponent of 0 or more: a power of an integer less than 0 is no integer\"); ")
    }
    put("uint64_t _kv_pr = 1, _kv_px = (uint64_t)_kv_pb; for (uint64_t _kv_pn = (uint64_t)_kv_pe; _kv_pn; _kv_pn >>= 1) { if (_kv_pn & 1) _kv_pr *= _kv_px; _kv_px *= _kv_px; } (")
    put_ctype(rt)
    put(")_kv_pr; })")
}

// b.pow(e) and b.pow(e, m)'s type: b ** e's, or what C gives b % m
let pow_method_type(n:int64):int64 {
    let e:int64 = nodes[n].b
    if e < 0 { return 0 - 1 }
    let m:int64 = nodes[e].next
    if m < 0 { return power_type(nodes[n].a, e) }
    let by:int64 = power_promoted(nodes[n].a)
    let my:int64 = power_promoted(m)
    if by < 0 || my < 0 { return 0 - 1 }
    if types[by].kind == Y_I64 || types[my].kind == Y_I64 { return base_type(Y_I64) }
    if types[by].kind == Y_U32 || types[my].kind == Y_U32 { return base_type(Y_U32) }
    return base_type(Y_I32)
}

// whether b.pow(...) has one argument or two, else kelvinc's error
let pow_arity(n:int64):bool {
    let e:int64 = nodes[n].b
    if e < 0 || (nodes[e].next >= 0 && nodes[nodes[e].next].next >= 0) {
        gen_error(n, "'.pow' of an integer takes an exponent, '.pow(e)', or an exponent and a modulus, '.pow(e, m)'")
        return false
    }
    return true
}

// b.pow(e) of an integer, b ** e; b.pow(e, m), Python's pow(b, e, m), the
// runtime's kv_pow_mod, as kelvinc writes them
let gen_pow_method(n:int64) {
    let b:int64 = nodes[n].a
    let e:int64 = nodes[n].b
    if !pow_arity(n) { return }
    let m:int64 = nodes[e].next
    if m < 0 {
        gen_power(b, e)
        return
    }
    var v:int64 = b
    for k in 0..<3 {
        let y:int64 = type_of(v)
        if y < 0 { return }
        if !power_int(y) {
            var msg = $"'.pow(e, m)' takes integers, and this is "
            let w:String = power_float(y) ? $"a floating-point number" : types[y].kind == Y_BOOL ? $"a bool" : nodes[v].kind == N_STR || types[y].kind == Y_CSTR ? $"text" : kelvin_type_text(y)
            msg += &w
            gen_error(v, msg.cstr)
            return
        }
        v = k == 0 ? e : m
    }
    if power_int_literal(m) && power_magnitude(m) == 0 {
        gen_error(m, "'.pow(e, m)' takes a modulus other than 0")
        return
    }
    put("((")
    put_ctype(pow_method_type(n))
    put(")kv_pow_mod((__int128)(")
    gen_expr(b)
    put("), (__int128)(")
    gen_expr(e)
    put("), (__int128)(")
    gen_expr(m)
    put(")))")
}

// whether n is an operator of a Range, which has none: kelvinc's error
let range_operand_error(n:int64):bool {
    if nodes[n].kind != N_BIN { return false }
    let ay:int64 = type_of(nodes[n].a)
    let by:int64 = type_of(nodes[n].b)
    let ar = ay >= 0 && types[ay].kind == Y_RANGE
    let br = by >= 0 && types[by].kind == Y_RANGE
    if !ar && !br { return false }
    let t:int64 = nodes[n].t
    if tok_is(t, "==") || tok_is(t, "!=") {             // r == s, r != s (#376); a Range? compares as an Optional
        let other:int64 = ar ? nodes[n].b : nodes[n].a
        let oy:int64 = ar ? by : ay
        if (ar && br) || (oy >= 0 && tagged_of(oy) >= 0) { return false }
        var m = $"a Range compares with a Range, and this is "
        let w:String = oy >= 0 ? type_text(oy) : $"not one"
        m += &w
        gen_error(other, m.cstr)
        return true
    }
    var m = $"a Range has no operator '"
    m += tok_text(t)
    m += "', but == and !=: walk it, or gather its values, as in '.map { $0 }'"
    gen_error(n, m.cstr)
    return true
}

// whether n is r == s or r != s of two Ranges (#376)
let is_range_eq(n:int64):bool {
    if nodes[n].kind != N_BIN || !(tok_is(nodes[n].t, "==") || tok_is(nodes[n].t, "!=")) { return false }
    let ay:int64 = type_of(nodes[n].a)
    let by:int64 = type_of(nodes[n].b)
    return ay >= 0 && by >= 0 && types[ay].kind == Y_RANGE && types[by].kind == Y_RANGE
}

// r == s, r != s (#376), as kelvinc's: the kinds and the bounds, compared
// by value, of any of kc's integers; lo...'s hi is no bound
let gen_range_eq(n:int64) {
    put("({ __auto_type _kv_ea = (")
    gen_expr(nodes[n].a)
    put("); __auto_type _kv_eb = (")
    gen_expr(nodes[n].b)
    put("); (bool)(")
    if tok_is(nodes[n].t, "!=") { put("!") }
    put("(_kv_ea.kind == _kv_eb.kind && (__int128)_kv_ea.lo == (__int128)_kv_eb.lo && (_kv_ea.kind == 2 || (__int128)_kv_ea.hi == (__int128)_kv_eb.hi))); })")
}

// r.count and r.contains(x), n (#374), and its bounds (#375), as kelvinc's: the count of one
// without an end ends the program, and is kelvinc's error written so;
// x is compared as a __int128, which holds any of kc's integers
let gen_range_member(n:int64) {
    let a:int64 = nodes[n].a
    let ry:int64 = type_of(a)
    let ey:int64 = types[ry].elem
    if nodes[n].kind == N_FIELD && tok_is(nodes[n].t, "lowerBound") {   // r.lowerBound (#375)
        put("((")
        gen_expr(a)
        put(").lo)")
        return
    }
    if nodes[n].kind == N_FIELD && tok_is(nodes[n].t, "upperBound") {   // r.upperBound (#375): one without an end has none
        if nodes[a].kind == N_RANGE && nodes[a].flag == 2 {
            let lo:int64 = nodes[a].a
            var m = $"'.upperBound' is a Range's end, and "
            if nodes[lo].kind == N_NUM { m += tok_text(nodes[lo].t) } else { m += "lo" }
            m += "... has none: its values go up to its type's largest"
            gen_error(n, m.cstr)
            return
        }
        put("({ ")
        put_ctype(ry)
        put(" _kv_ru = (")
        gen_expr(a)
        put("); if (_kv_ru.kind == 2) kv_array_fail(\"this Range has no end, and '.upperBound' is its end: its values go up to its type's largest\"); _kv_ru.hi; })")
        return
    }
    if nodes[n].kind == N_FIELD {
        if nodes[a].kind == N_RANGE && nodes[a].flag == 2 {
            let lo:int64 = nodes[a].a
            var m = $"'.count' counts a Range to its end, and "
            if nodes[lo].kind == N_NUM { m += tok_text(nodes[lo].t) } else { m += "lo" }
            m += "... has none: take the first few, as in '.prefix(10).count'"
            gen_error(n, m.cstr)
            return
        }
        put("({ ")
        put_ctype(ry)
        put(" _kv_rc = (")
        gen_expr(a)
        put("); if (_kv_rc.kind == 2) kv_array_fail(\"this Range has no end, and '.count' counts one to its end: take its first few, '.prefix(n)'\"); ")
        put_range_walk(ey, "_kv_rc", "_kv_c")
        put("; _kv_c_go ? (int64_t)((uint64_t)_kv_c_end - (uint64_t)_kv_c_lo + 1) : (int64_t)0; })")
        return
    }
    let v:int64 = nodes[n].b
    if v < 0 {
        gen_error(n, "'.contains' takes an integer, as in 'r.contains(3)'")
        return
    }
    if nodes[v].next >= 0 {
        gen_error(nodes[v].next, "'.contains' takes one integer")
        return
    }
    let vy:int64 = type_of(v)
    if vy < 0 { return }
    let k:ykind = types[vy].kind
    if k != Y_I64 && k != Y_I32 && k != Y_U8 && k != Y_U32 && k != Y_C {
        var m = $"'.contains' takes an integer, and this is "
        let w:String = k == Y_BOOL ? $"a bool" : k == Y_F64 || k == Y_F32 ? $"a floating-point number" : type_text(vy)
        m += &w
        gen_error(v, m.cstr)
        return
    }
    put("({ ")
    put_ctype(ry)
    put(" _kv_rh = (")
    gen_expr(a)
    put("); __int128 _kv_rv = (")
    gen_expr(v)
    put("); (bool)(_kv_rv >= _kv_rh.lo && (_kv_rh.kind ? _kv_rv <= _kv_rh.hi : _kv_rv < _kv_rh.hi)); })")
}

// each Range<T>'s struct, T's lo and hi and its kind, where the program
// makes a Range (#373): of each integer kc has, guarded as kelvinc's
let put_range_types() {
    var used = range_values > 0
    for i in 0..<types.count as int64 {
        if types[i].kind == Y_RANGE { used = true }
    }
    if !used { return }
    let words:[cstr] = ["i64", "i32", "u8", "u32"]
    let ctypes:[cstr] = ["int64_t", "int32_t", "uint8_t", "uint32_t"]
    for i in 0..<4 {
        put("#ifndef _KV_RANGE_")
        put(words[i])
        put("\n#define _KV_RANGE_")
        put(words[i])
        put("\ntypedef struct _kv_range_")
        put(words[i])
        put(" { ")
        put(ctypes[i])
        put(" lo, hi; uint8_t kind; } _kv_range_")
        put(words[i])
        put(";\n#endif\n")
    }
}

let iter_type_of(n:int64):int64 {
    let i = iter_of(n)
    if i < 0 { return 0 - 1 }
    return iters[i].iter_y
}

// Iterator(state) { ... } (#326): the state moved to the heap, as kelvinc's
let gen_iter_make(n:int64) {
    let i = iter_of(n)
    if i >= 0 { gen_iter_value(i) }
}

// an Iterator's value, iters[i]'s: its state, or the Iterator made lazy, moved to the heap (#326, #328)
let gen_iter_value(i:int64) {
    let sy:int64 = iters[i].state_y
    let a:int64 = iters[i].src
    let prefix = iters[i].op == 3 || iters[i].op == 4
    if iters[i].op == 7 {                                // r.stride(n) (#379): its step a T, never 0; a negative one, from its end down
        let sign = !range_unsigned(types[sy].elem)
        put("({ ")
        put_ctype(sy)
        put(" _kv_ri = (")
        gen_expr(a)
        put("); ")
        put_ctype(types[sy].elem)
        put(" _kv_rs = (")
        gen_expr(iters[i].count)
        put("); if (_kv_rs == 0) kv_array_fail(\"'.stride(n)' stepped by 0, which never moves\"); ")
        if sign { put("if (_kv_rs < 0 && _kv_ri.kind == 2) kv_array_fail(\"this Range has no end, and '.stride(n)' of a negative n walks one from its end: take its first few, '.prefix(n)'\"); ") }
        put_range_walk(types[sy].elem, "_kv_ri", "_kv_r")
        put("; struct _kv_iter")
        put_int(i + 1)
        put(sign ? "_st *_kv_is = kv_alloc(sizeof *_kv_is); _kv_is->at = _kv_rs < 0 ? _kv_r_end : _kv_r_lo; _kv_is->end = _kv_rs < 0 ? _kv_r_lo : _kv_r_end; _kv_is->step = _kv_rs; _kv_is->go = _kv_r_go; kv_iter_make(_kv_is, NULL, _kv_iter" : "_st *_kv_is = kv_alloc(sizeof *_kv_is); _kv_is->at = _kv_r_lo; _kv_is->end = _kv_r_end; _kv_is->step = _kv_rs; _kv_is->go = _kv_r_go; kv_iter_make(_kv_is, NULL, _kv_iter")
        put_int(i + 1)
        put("_next); })")
        return
    }
    if iters[i].op == 5 || iters[i].op == 6 {            // a Range's (#373), down (#378): where it starts, ends and goes, as kelvinc's
        let down = iters[i].op == 6
        put("({ ")
        put_ctype(sy)
        put(" _kv_ri = (")
        gen_expr(a)
        put("); ")
        if down { put("if (_kv_ri.kind == 2) kv_array_fail(\"this Range has no end, and '.reversed()' walks one from its end: take its first few, '.prefix(n)'\"); ") }
        put_range_walk(types[sy].elem, "_kv_ri", "_kv_r")
        put("; struct _kv_iter")
        put_int(i + 1)
        put(down ? "_st *_kv_is = kv_alloc(sizeof *_kv_is); _kv_is->at = _kv_r_end; _kv_is->end = _kv_r_lo; _kv_is->go = _kv_r_go; kv_iter_make(_kv_is, NULL, _kv_iter" : "_st *_kv_is = kv_alloc(sizeof *_kv_is); _kv_is->at = _kv_r_lo; _kv_is->end = _kv_r_end; _kv_is->go = _kv_r_go; kv_iter_make(_kv_is, NULL, _kv_iter")
        put_int(i + 1)
        put("_next); })")
        return
    }
    put("({ ")
    if prefix {                                          // x.prefix(n): the base, the count and the flag (#372)
        put("struct _kv_iter")
        put_int(i + 1)
        put("_st *_kv_is = kv_alloc(sizeof *_kv_is); _kv_is->left = (int64_t)(")
        if iters[i].count >= 0 {
            gen_expr(iters[i].count)
        } else {
            put("0")
        }
        put("); _kv_is->done = false; _kv_is->base = ")
    } else {
        put_ctype(sy)
        put(" *_kv_is = kv_alloc(sizeof *_kv_is); *_kv_is = ")
    }
    if is_owner(sy) && nodes[a].kind == N_ID && var_type(nodes[a].t) >= 0 {   // a var's moves in
        put_owner_prefix(sy)
        put("_take(&")
        put_tok(nodes[a].t)
        put(")")
    } else {
        gen_expr(a)
    }
    put("; kv_iter_make(_kv_is, ")
    if is_owner(sy) {
        put("_kv_iter")
        put_int(i + 1)
        put("_drop")
    } else {
        put("NULL")
    }
    put(", _kv_iter")
    put_int(i + 1)
    put("_next); })")
}

// each Iterator's adapters: next writes the T? its function gives of the
// state, drop frees a state that owns; heads, their prototypes alone
let put_iter_adapters(heads:bool) {
    for i in 0..<iters.count as int64 {
        let r:iter_rec = iters[i]
        if heads && (r.op == 5 || r.op == 6 || r.op == 7) {   // a Range's state (#373, #378), its step (#379)
            put("struct _kv_iter")
            put_int(i + 1)
            put("_st { ")
            put_ctype(types[r.state_y].elem)
            put(r.op == 7 ? " at, end, step; bool go; };\n" : " at, end; bool go; };\n")
        }
        if heads && (r.op == 3 || r.op == 4) {           // x.prefix(n)'s state (#372)
            put("struct _kv_iter")
            put_int(i + 1)
            put("_st { ")
            put_ctype(r.state_y)
            put(" base; int64_t left; bool done; };\n")
        }
        put("static void _kv_iter")
        put_int(i + 1)
        put("_next(void *_kv_s, void *_kv_out)")
        if heads {
            put(";\n")
        } else if r.op == 5 || r.op == 6 || r.op == 7 {  // a Range's (#373): where it is, then a step short of its end, as kelvinc's; down (#378); by n (#379)
            let out_y:int64 = optional_of(types[r.state_y].elem)
            put("\n{\n    struct _kv_iter")
            put_int(i + 1)
            put("_st *_kv_p = _kv_s;\n    if (!_kv_p->go) {\n        *(")
            put_ctype(out_y)
            put(" *)_kv_out = _kv_")
            put_tok(types[out_y].name)
            put("_make_none();\n        return;\n    }\n    *(")
            put_ctype(out_y)
            put(" *)_kv_out = _kv_")
            put_tok(types[out_y].name)
            put("_make_some(_kv_p->at);\n")
            if r.op == 7 && range_unsigned(types[r.state_y].elem) {   // r.stride(n) (#379): on while a whole step is left, as a __int128
                put("    _kv_p->go = (__int128)_kv_p->end - _kv_p->at >= _kv_p->step;\n    if (_kv_p->go)\n        _kv_p->at += _kv_p->step;\n}\n\n")
            } else if r.op == 7 {
                put("    _kv_p->go = _kv_p->step > 0 ? (__int128)_kv_p->end - _kv_p->at >= _kv_p->step : (__int128)_kv_p->at - _kv_p->end >= -(__int128)_kv_p->step;\n    if (_kv_p->go)\n        _kv_p->at += _kv_p->step;\n}\n\n")
            } else {
                put("    _kv_p->go = _kv_p->at != _kv_p->end;\n    _kv_p->at ")
                put(r.op == 6 ? "-" : "+")
                put("= _kv_p->go;\n}\n\n")
            }
        } else if r.op == 3 || r.op == 4 {               // x.prefix(n), x.prefix(f) (#372), as kelvinc's
            let ey:int64 = types[r.iter_y].elem
            let out_y:int64 = optional_of(ey)
            let in_y:int64 = types[r.state_y].kind == Y_ITER ? out_y : nodes[iterator_next(r.state_y)].ty
            put("\n{\n    struct _kv_iter")
            put_int(i + 1)
            put("_st *_kv_p = _kv_s;\n    if (")
            put(r.op == 3 ? "_kv_p->left <= 0" : "_kv_p->done")
            put(") {\n        *(")
            put_ctype(out_y)
            put(" *)_kv_out = _kv_")
            put_tok(types[out_y].name)
            put("_make_none();\n        return;\n    }\n")
            if r.op == 3 { put("    _kv_p->left--;\n") }
            put("    ")
            put_ctype(in_y)
            if types[r.state_y].kind == Y_ITER {
                put(" _kv_o;\n    kv_iter_next(&_kv_p->base, &_kv_o);\n")
            } else {
                put(" _kv_o = ")
                put_tok(nodes[iterator_next(r.state_y)].c)
                put("__next(&_kv_p->base);\n")
            }
            if r.op == 4 {
                put("    if (_kv_o.tag == ")
                put_int(some_tag(in_y))
                put(" && !")
                put_fn_name(r.fn)
                put("(")
                if is_owner(ey) {
                    put_owner_prefix(ey)
                    put("_copy(&_kv_o.u.some)")
                } else {
                    put("_kv_o.u.some")
                }
                put(")) {\n        _kv_p->done = true;\n")
                if is_owner(ey) {
                    put("        ")
                    put_free(ey)
                    put("(&_kv_o.u.some);\n")
                }
                put("        _kv_o = _kv_")
                put_tok(types[out_y].name)
                put("_make_none();\n    }\n")
            }
            put("    *(")
            put_ctype(out_y)
            put(" *)_kv_out = _kv_o;\n}\n\n")
        } else if r.op != 0 {                         // it.lazy.map(f), .filter(f) (#328), as kelvinc's #327
            let ey:int64 = types[r.state_y].elem
            let in_y:int64 = optional_of(ey)
            let out_y:int64 = optional_of(types[r.iter_y].elem)
            put("\n{\n    for (;;) {\n        ")
            put_ctype(in_y)
            put(" _kv_o;\n        kv_iter_next((kv_iter *)_kv_s, &_kv_o);\n        if (_kv_o.tag != ")
            put_int(some_tag(in_y))
            put(") {\n            *(")
            put_ctype(out_y)
            put(" *)_kv_out = _kv_")
            put_tok(types[out_y].name)
            put("_make_none();\n            return;\n        }\n        ")
            if r.op == 1 {
                put_ctype(types[r.iter_y].elem)
                put(" _kv_v = ")
            } else {
                put("if (")
            }
            put_fn_name(r.fn)
            put("(")
            if is_owner(ey) {
                put_owner_prefix(ey)
                put("_copy(&_kv_o.u.some)")
            } else {
                put("_kv_o.u.some")
            }
            put(r.op == 1 ? ");\n" : ")) {\n            *(")
            if r.op == 2 {
                put_ctype(out_y)
                put(" *)_kv_out = _kv_o;\n            return;\n        }\n")
            }
            if is_owner(ey) {
                put("        ")
                put_free(ey)
                put("(&_kv_o.u.some);\n")
            }
            if r.op == 1 {
                put("        *(")
                put_ctype(out_y)
                put(" *)_kv_out = _kv_")
                put_tok(types[out_y].name)
                put("_make_some(_kv_v);\n        return;\n")
            }
            put("    }\n}\n\n")
        } else {
            put("\n{\n    *(")
            put_ctype(nodes[r.fn].ty)
            put(" *)_kv_out = ")
            put_fn_name(r.fn)
            put("((")
            put_ctype(r.state_y)
            put(" *)_kv_s);\n}\n\n")
        }
        if is_owner(r.state_y) {
            put("static void _kv_iter")
            put_int(i + 1)
            put("_drop(void *_kv_s)")
            if heads {
                put(";\n")
            } else if r.op == 3 || r.op == 4 {
                put("\n{\n    ")
                put_free(r.state_y)
                put("(&((struct _kv_iter")
                put_int(i + 1)
                put("_st *)_kv_s)->base);\n}\n\n")
            } else {
                put("\n{\n    ")
                put_free(r.state_y)
                put("((")
                put_ctype(r.state_y)
                put(" *)_kv_s);\n}\n\n")
            }
        }
    }
}

// ---------- eager map, filter, reduce, flatMap (#329) ----------

// xs.map(f), .filter(f), .reduce(init, f), .flatMap(f) of an Array, as
// kelvinc's #182, #184 and #308, or of an iterator, a Sequence or an
// Iterator<T>, whose values kelvinc gathers into an Array first (#319,
// #321, #325)
struct eager_rec {
    node: int64
    kind: int64             // 1 map, 2 filter, 3 reduce, 4 flatMap
    src: int64              // the receiver
    src_y: int64            // its type
    elem_y: int64           // what each element or value is
    fn: int64               // the function, of the program or made of { ... }
    out_y: int64            // what it gives
    with_key: bool          // mapWithKey and the rest of a Dictionary (#331): the key before the value
}

var eagers:$[eager_rec]
var eager_at:Dictionary<int64, int64>

// what each value of y gives where y walks: an Array's element, an
// Iterator<T>'s T, an iterator's or a Sequence's next's some; -1 else
let walked_elem(y:int64):int64 {
    if y < 0 { return 0 - 1 }
    if types[y].kind == Y_ARRAY || types[y].kind == Y_ITER || types[y].kind == Y_RANGE { return types[y].elem }   // a Range's (#373)
    let mk = sequence_maker(y)
    if mk >= 0 {
        let nx = iterator_next(nodes[mk].ty)
        return nx >= 0 ? some_type(nodes[nx].ty) : 0 - 1
    }
    let nx = iterator_next(y)
    return nx >= 0 ? some_type(nodes[nx].ty) : 0 - 1
}

// the eager method n calls, by its place in eagers; -1 where n is none
let eager_of(n:int64):int64 {
    if nodes[n].kind != N_METHOD { return 0 - 1 }
    let t:int64 = nodes[n].t
    var kind:int64 = 0
    var with_key = false
    if tok_is(t, "map") { kind = 1 }
    if tok_is(t, "filter") { kind = 2 }
    if tok_is(t, "reduce") { kind = 3 }
    if tok_is(t, "flatMap") { kind = 4 }
    if tok_is(t, "mapWithKey") || tok_is(t, "filterWithKey") || tok_is(t, "reduceWithKey") || tok_is(t, "flatMapWithKey") {   // (#331, #332)
        with_key = true
        kind = tok_is(t, "mapWithKey") ? 1 : tok_is(t, "filterWithKey") ? 2 : tok_is(t, "reduceWithKey") ? 3 : 4
    }
    if kind == 0 { return 0 - 1 }
    let seen = eager_at.get(n, -1)
    if seen >= 0 { return seen }
    let a:int64 = nodes[n].a
    if nodes[a].kind == N_FIELD && tok_is(nodes[a].t, "lazy") { return 0 - 1 }
    if names_type(a) || method_of(n) >= 0 { return 0 - 1 }      // a method of its own wins
    let y:int64 = type_of(a)
    if y < 0 || is_lazy_type(y) && kind <= 2 { return 0 - 1 }    // a lazy Sequence's map and filter are lazy (#324)
    let yk:ykind = types[y].kind
    if with_key && yk != Y_DICT { return 0 - 1 }        // a Dictionary's alone
    if yk == Y_RANGE && nodes[a].kind == N_RANGE && nodes[a].flag == 2 {   // lo... has no end to walk to, as kelvinc says it (#373)
        let lo:int64 = nodes[a].a
        var m = $"'."
        m += tok_text(t)
        m += "' walks a Range to its end, and "
        if nodes[lo].kind == N_NUM { m += tok_text(nodes[lo].t) } else { m += "lo" }
        m += "... has none: take the first few, as in '.prefix(10)."
        m += tok_text(t)
        m += "', or walk it lazily, '.lazy.map'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let ey:int64 = yk == Y_DICT || yk == Y_SET ? types[y].elem : walked_elem(y)   // a Dictionary's values, a Set's elements (#330)
    if ey < 0 { return 0 - 1 }
    let each = yk == Y_DICT ? $"value" : $"element"     // as kelvinc names it
    let kt:int64 = !with_key ? 0 - 1 : types[types[y].name].kind == Y_STRING ? base_type(Y_CSTR) : types[y].name   // a String key's text, lent (#331)
    var me = $"'."
    me += tok_text(t)
    me += "'"
    var f:int64 = nodes[n].b
    var init:int64 = 0 - 1
    var acc:int64 = 0 - 1
    if kind == 3 {
        init = f
        if init < 0 || nodes[init].next < 0 {
            var m = me.copy()
            m += " takes the value to start from, then a function: '.reduce(0) { $0 + $1 }'"
            gen_error(n, m.cstr)
            return 0 - 1
        }
        f = nodes[init].next
        acc = type_of(init)
        if acc < 0 { return 0 - 1 }
    }
    if f < 0 || nodes[f].next >= 0 {
        var m = me.copy()
        m += " takes one function"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    var ps:$[int64] = $[]
    if kind == 3 { ps += acc }
    if with_key { ps += kt }
    ps += ey
    var fn:int64 = 0 - 1
    if nodes[f].kind == N_ANON {
        fn = anon_function_of(f, &ps, kind == 3 ? acc : 0 - 1, &me)
        if fn < 0 { return 0 - 1 }
    } else if nodes[f].kind == N_ID && var_type(nodes[f].t) < 0 {
        fn = decl_named(nodes[f].t, D_FN)
    }
    var count:int64 = 0
    var p:int64 = fn >= 0 ? nodes[fn].a : 0 - 1
    while p >= 0 {
        count += 1
        p = nodes[p].next
    }
    if fn < 0 || count != ps.count as int64 || nodes[fn].ty < 0 || types[nodes[fn].ty].kind == Y_VOID {
        var m = me.copy()
        let article = yk == Y_DICT ? $"a " : $"an "
        if kind == 3 && with_key {
            m += " takes a function of three parameters, the value so far, a key and its value, with a result"
        } else if with_key {
            m += " takes a function of two parameters, a key and its value, with a result"
        } else if kind == 3 {
            m += " takes a function of two parameters, the value so far and "
            m += &article
            m += &each
            m += ", with a result"
        } else {
            m += " takes a function of one parameter, "
            m += &article
            m += &each
            m += ", with a result"
        }
        gen_error(n, m.cstr)
        return 0 - 1
    }
    var last_p:int64 = nodes[fn].a
    while nodes[last_p].next >= 0 { last_p = nodes[last_p].next }
    if with_key {                                       // as kelvinc's (#331)
        var key_p:int64 = nodes[fn].a
        if kind == 3 { key_p = nodes[key_p].next }
        if nodes[key_p].ty != kt {
            var m = me.copy()
            m += " calls its function with each key, "
            let kw:String = kelvin_type_text(kt)
            m += &kw
            m += ", and this takes "
            let pw:String = kelvin_type_text(nodes[key_p].ty)
            m += &pw
            gen_error(n, m.cstr)
            return 0 - 1
        }
    }
    if nodes[last_p].ty != ey {
        var m = me.copy()
        m += " calls its function with each "
        m += &each
        m += ", "
        let ew:String = kelvin_type_text(ey)
        m += &ew
        m += ", and this takes "
        let pw:String = kelvin_type_text(nodes[last_p].ty)
        m += &pw
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let ry:int64 = nodes[fn].ty
    if kind == 2 && types[ry].kind != Y_BOOL {
        var m = me.copy()
        if nodes[f].kind == N_ANON && nodes[f].flag != 0 {      // as kelvinc's (#239), named too (#330)
            let e:int64 = nodes[nodes[nodes[f].b].a].a
            m += " keeps what its function says true for, a bool, and this "
            if nodes[e].kind == N_NUM {
                m += "is a number: write 'true' or 'false'"
            } else {
                m += "gives "
                if nodes[e].kind == N_BIN {
                    m += "a number"
                } else {
                    let rw:String = kelvin_type_text(ry)
                    m += &rw
                }
                m += ": compare it, as in 'x != 0'"
            }
        } else {
            m += " takes a function that says whether to keep an element, a bool, and this gives "
            let rw:String = kelvin_type_text(ry)
            m += &rw
        }
        gen_error(n, m.cstr)
        return 0 - 1
    }
    if kind == 3 && (nodes[nodes[fn].a].ty != acc || ry != acc) {
        var m = me.copy()
        m += " calls its function with the value so far, "
        let aw:String = kelvin_type_text(acc)
        m += &aw
        m += ", and keeps what it gives"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let whole:ykind = yk == Y_DICT || yk == Y_SET ? yk : Y_ARRAY   // what flatMap's function gives, and joins
    if kind == 4 && types[ry].kind != whole {
        var m = me.copy()
        let what = whole == Y_DICT ? $"a Dictionary" : whole == Y_SET ? $"a Set" : $"an Array"
        m += " of "
        m += &what
        m += " takes a function that gives "
        m += &what
        m += ", and joins them into one; this gives "
        let rw:String = kelvin_type_text(ry)
        m += &rw
        m += with_key ? $", which '.mapWithKey' takes" : $", which '.map' takes"   // as kelvinc's (#332)
        gen_error(n, m.cstr)
        return 0 - 1
    }
    if kind == 1 && yk == Y_SET && types[ry].kind != Y_STRING && types[ry].kind != Y_I64 && types[ry].kind != Y_I32 && types[ry].kind != Y_U8 && types[ry].kind != Y_U32 {
        var m = $"'.map' of a Set makes a Set, whose elements are integers or Strings, and this gives "   // as kelvinc's (#307)
        let rw:String = kelvin_type_text(ry)
        m += &rw
        m += ": map its elements, 's.elements.map'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    var out:int64 = ry
    if kind == 1 { out = yk == Y_DICT ? type_of_kind(Y_DICT, ry, types[y].name) : yk == Y_SET ? type_of_kind(Y_SET, ry, -1) : type_of_kind(Y_ARRAY, ry, -1) }
    if kind == 2 { out = yk == Y_DICT || yk == Y_SET ? y : type_of_kind(Y_ARRAY, ey, -1) }
    let r:eager_rec = {n, kind, a, y, ey, fn, out, with_key}
    eagers += r
    eager_at[n] = eagers.count as int64 - 1
    return eagers.count as int64 - 1
}

let eager_type_of(n:int64):int64 {
    return eagers[eager_of(n)].out_y
}

// the values of an iterator, a Sequence or an Iterator<T>, src of type y,
// gathered into an Array of ey, walked to none, as kelvinc's (#319)
let gen_gathered(src:int64, y:int64, ey:int64) {
    let ay:int64 = type_of_kind(Y_ARRAY, ey, -1)
    var iy:int64 = y
    var walk:int64 = src
    let mk = sequence_maker(y)
    if mk >= 0 {                                         // a Sequence's fresh iterator, s.makeIterator()
        iy = nodes[mk].ty
        walk = make_node(N_METHOD, nodes[mk].t)
        nodes[walk].a = src
    }
    let oy:int64 = types[iy].kind == Y_ITER ? optional_of(ey) : nodes[iterator_next(iy)].ty
    put("({ ")
    put_array_name(ay)
    put(" _kv_ga = {0}; ")
    if changeable_place(walk) {
        put_ctype(iy)
        put(" *_kv_gp = &(")
        gen_expr(walk)
        put("); ")
    } else {
        if is_owner(iy) {
            put("__attribute__((cleanup(")
            put_free(iy)
            put("))) ")
        }
        put_ctype(iy)
        put(" _kv_gv = ")
        gen_expr(walk)
        put("; ")
        put_ctype(iy)
        put(" *_kv_gp = &_kv_gv; ")
    }
    put("for (;;) { ")
    put_ctype(oy)
    if types[iy].kind == Y_ITER {
        put(" _kv_go; kv_iter_next(_kv_gp, &_kv_go); ")
    } else {
        put(" _kv_go = ")
        let nx = iterator_next(iy)
        put_tok(nodes[nx].c)
        put("__next(_kv_gp); ")
    }
    put("if (_kv_go.tag != ")
    put_int(some_tag(oy))
    put(") break; ")
    put_array_name(ay)
    put("_append(&_kv_ga, _kv_go.u.some); } _kv_ga; })")
}

// the values of a Range, src of type y, gathered into an Array, as
// kelvinc's (#373): one without an end has none to walk to, and the
// program ends, as kelvinc says it, of the method t
let gen_range_gathered(src:int64, y:int64, t:int64) {
    let ey:int64 = types[y].elem
    let ay:int64 = type_of_kind(Y_ARRAY, ey, -1)
    put("({ ")
    put_array_name(ay)
    put(" _kv_ga = {0}; ")
    put_ctype(y)
    put(" _kv_gr = (")
    gen_expr(src)
    put("); if (_kv_gr.kind == 2) kv_array_fail(\"this Range has no end, and '.")
    put_tok(t)
    put("' walks one to its end: take its first few, '.prefix(n)'\"); for (")
    put_range_walk(ey, "_kv_gr", "_kv_g")
    put("; _kv_g_go; _kv_g_go = _kv_g_lo != _kv_g_end, _kv_g_lo += _kv_g_go) ")
    put_array_name(ay)
    put("_append(&_kv_ga, _kv_g_lo); _kv_ga; })")
}

// an element for the function: a copy of one that owns, which it owns (#329)
let put_eager_arg(ey:int64) {
    if is_owner(ey) {
        put_owner_prefix(ey)
        put("_copy(&_kv_ms->at[_kv_mi])")
    } else {
        put("_kv_ms->at[_kv_mi]")
    }
}

// xs.map(f) and the rest (#329): a loop over the elements in a statement
// expression, as kelvinc's; an Array an expression gives, or the values
// of an iterator, held in _kv_mt and freed
let gen_eager_keyed(n:int64)    // a prototype: a Dictionary's and a Set's (#330)

let gen_eager(n:int64) {
    let r:eager_rec = eagers[eager_of(n)]
    if types[r.src_y].kind == Y_DICT || types[r.src_y].kind == Y_SET {
        gen_eager_keyed(n)
        return
    }
    let ay:int64 = types[r.src_y].kind == Y_ARRAY ? r.src_y : type_of_kind(Y_ARRAY, r.elem_y, -1)
    if types[r.src_y].kind != Y_ARRAY && types[r.src_y].kind != Y_RANGE && sequence_maker(r.src_y) < 0 && changeable_place(r.src) {   // walking an iterator changes it; a Sequence's walk is a fresh one, a Range's too (#373)
        let lead = $"walking an iterator changes it, as its var next() does, and this changes "
        if !changes_var(r.src, &lead) { return }
    }
    put("({ ")
    if types[r.src_y].kind == Y_ARRAY && is_place(r.src) {
        put("__auto_type _kv_ms = &(")
        gen_expr(r.src)
        put("); ")
    } else {
        put("__attribute__((cleanup(")
        put_free(ay)
        put("))) ")
        put_array_name(ay)
        put(" _kv_mt = ")
        if types[r.src_y].kind == Y_ARRAY {
            gen_expr(r.src)
        } else if types[r.src_y].kind == Y_RANGE {      // a Range's values, which end (#373)
            gen_range_gathered(r.src, r.src_y, nodes[n].t)
        } else {
            gen_gathered(r.src, r.src_y, r.elem_y)
        }
        put("; ")
        put_array_name(ay)
        put(" *_kv_ms = &_kv_mt; ")
    }
    if r.kind == 3 {
        let init:int64 = nodes[n].b
        put_ctype(r.out_y)
        put(" _kv_acc = ")
        if is_owner(r.out_y) && nodes[init].kind == N_ID && var_type(nodes[init].t) >= 0 {   // a var's moves in
            put_owner_prefix(r.out_y)
            put("_take(&")
            put_tok(nodes[init].t)
            put(")")
        } else {
            gen_expr(init)
        }
        put("; ")
    } else {
        put_array_name(r.kind == 4 ? r.out_y : r.out_y)
        put(" _kv_mo = {0}; ")
    }
    put("for (size_t _kv_mi = 0; _kv_mi < _kv_ms->count; _kv_mi++) ")
    if r.kind == 1 {
        put_array_name(r.out_y)
        put("_append(&_kv_mo, ")
        put_fn_name(r.fn)
        put("(")
        put_eager_arg(r.elem_y)
        put(")); _kv_mo; })")
    } else if r.kind == 2 {
        put("if (")
        put_fn_name(r.fn)
        put("(")
        put_eager_arg(r.elem_y)
        put(")) ")
        put_array_name(r.out_y)
        put("_append(&_kv_mo, ")
        put_eager_arg(r.elem_y)
        put("); _kv_mo; })")
    } else if r.kind == 3 {
        put("_kv_acc = ")
        put_fn_name(r.fn)
        put("(_kv_acc, ")
        put_eager_arg(r.elem_y)
        put("); _kv_acc; })")
    } else {
        put("{ ")
        put_array_name(r.out_y)
        put(" _kv_mr = ")
        put_fn_name(r.fn)
        put("(")
        put_eager_arg(r.elem_y)
        put("); for (size_t _kv_mj = 0; _kv_mj < _kv_mr.count; _kv_mj++) ")
        put_array_name(r.out_y)
        put("_append(&_kv_mo, _kv_mr.at[_kv_mj]); _kv_mr.count = 0; ")
        put_array_name(r.out_y)
        put("_free(&_kv_mr); } _kv_mo; })")
    }
}

// the key of a Dictionary's entry, or a Set's element, at expression at,
// as its _set and _insert take it: a String's text, an integer itself
let put_key_text(ky:int64, at:cstr) {
    put(types[ky].kind == Y_STRING ? "KV_LK_TEXT(&" : "KV_LK_INT(&")
    put(at)
    put(")")
}

// d.map(f) and the rest of a Dictionary, s.map(f) and the rest of a Set
// (#330), as kelvinc's #238, #307 and #308: a loop over the live entries,
// in the order added, f given a copy of each value or element that owns;
// one an expression gives held in _kv_mt and freed
let gen_eager_keyed(n:int64) {
    let r:eager_rec = eagers[eager_of(n)]
    let y:int64 = r.src_y
    let dict = types[y].kind == Y_DICT
    let ky:int64 = dict ? types[y].name : types[y].elem
    let at:cstr := dict ? "_kv_ms->at[_kv_mi].value" : "_kv_ms->at[_kv_mi].key"
    put("({ ")
    if is_place(r.src) {
        put("__auto_type _kv_ms = &(")
        gen_expr(r.src)
        put("); ")
    } else {
        put("__attribute__((cleanup(")
        put_free(y)
        put("))) ")
        put_ctype(y)
        put(" _kv_mt = ")
        gen_expr(r.src)
        put("; ")
        put_ctype(y)
        put(" *_kv_ms = &_kv_mt; ")
    }
    if r.kind == 3 {
        let init:int64 = nodes[n].b
        put_ctype(r.out_y)
        put(" _kv_acc = ")
        if is_owner(r.out_y) && nodes[init].kind == N_ID && var_type(nodes[init].t) >= 0 {
            put_owner_prefix(r.out_y)
            put("_take(&")
            put_tok(nodes[init].t)
            put(")")
        } else {
            gen_expr(init)
        }
        put("; ")
    } else {
        put_ctype(r.out_y)
        put(" _kv_mo = {0}; ")
        if r.kind == 1 {
            put_owner_prefix(r.out_y)
            put("_reserve(&_kv_mo, _kv_ms->count); ")
        }
    }
    put("for (size_t _kv_mi = 0; _kv_mi < _kv_ms->len; _kv_mi++) if (_kv_ms->at[_kv_mi].live) { ")
    if r.kind == 3 {
        put("_kv_acc = ")
    } else if r.kind == 1 {
        put_ctype(types[r.out_y].elem)
        put(" _kv_mv = ")
    } else if r.kind == 2 {
        put("if (")
    } else {
        put_ctype(r.out_y)
        put(" _kv_mr = ")
    }
    put_fn_name(r.fn)
    put(r.kind == 3 ? "(_kv_acc, " : "(")
    if r.with_key {                                      // the key first, a String's text, lent (#331)
        if types[ky].kind == Y_STRING {
            put("KV_LK_TEXT(&_kv_ms->at[_kv_mi].key)")
        } else {
            put("_kv_ms->at[_kv_mi].key")
        }
        put(", ")
    }
    if is_owner(r.elem_y) {
        put_owner_prefix(r.elem_y)
        put("_copy(&")
        put(at)
        put(")")
    } else {
        put(at)
    }
    put(r.kind == 2 ? ")) " : "); ")
    if r.kind == 1 && dict {                             // the same key, f's value
        put_owner_prefix(r.out_y)
        put("_set(&_kv_mo, ")
        put_key_text(ky, "_kv_ms->at[_kv_mi].key")
        put(", _kv_mv); ")
    } else if r.kind == 1 {                              // what f gives, a new Set's element, a String's text
        put_owner_prefix(r.out_y)
        put("_insert(&_kv_mo, ")
        put_key_text(types[r.out_y].elem, "_kv_mv")
        put(types[types[r.out_y].elem].kind == Y_STRING ? "); kv_string_free(&_kv_mv); " : "); ")
    } else if r.kind == 2 && dict {                      // the entry f keeps, its value a copy
        put_owner_prefix(y)
        put("_set(&_kv_mo, ")
        put_key_text(ky, "_kv_ms->at[_kv_mi].key")
        put(", ")
        if is_owner(r.elem_y) {
            put_owner_prefix(r.elem_y)
            put("_copy(&")
            put(at)
            put(")")
        } else {
            put(at)
        }
        put("); ")
    } else if r.kind == 2 {
        put_owner_prefix(y)
        put("_insert(&_kv_mo, ")
        put_key_text(ky, "_kv_ms->at[_kv_mi].key")
        put("); ")
    } else if r.kind == 4 && dict {                      // each Dictionary f gives merged in, a later entry winning
        let rv:int64 = types[r.out_y].elem
        put("for (size_t _kv_mj = 0; _kv_mj < _kv_mr.len; _kv_mj++) if (_kv_mr.at[_kv_mj].live) ")
        put_owner_prefix(r.out_y)
        put("_set(&_kv_mo, ")
        put_key_text(types[r.out_y].name, "_kv_mr.at[_kv_mj].key")
        put(", ")
        if is_owner(rv) {
            put_owner_prefix(rv)
            put("_copy(&_kv_mr.at[_kv_mj].value)")
        } else {
            put("_kv_mr.at[_kv_mj].value")
        }
        put("); ")
        put_free(r.out_y)
        put("(&_kv_mr); ")
    } else if r.kind == 4 {                              // each Set f gives unioned in
        put("for (size_t _kv_mj = 0; _kv_mj < _kv_mr.len; _kv_mj++) if (_kv_mr.at[_kv_mj].live) ")
        put_owner_prefix(r.out_y)
        put("_insert(&_kv_mo, ")
        put_key_text(types[r.out_y].elem, "_kv_mr.at[_kv_mj].key")
        put("); ")
        put_free(r.out_y)
        put("(&_kv_mr); ")
    }
    put(r.kind == 3 ? "} _kv_acc; })" : "} _kv_mo; })")
}

// ---------- prefix (#372) ----------

// xs.prefix(n) or xs.prefix { ... } of an Array, a String, a Dictionary
// or a Set, as kelvinc's #372: a new one of its kind, of the first n, or
// of those before the first the function says false for
struct prefix_rec {
    node: int64
    src_y: int64
    elem_y: int64           // what the function is given: an element, a value, a uchr
    fn: int64               // the function; -1 of a count
}

var prefixes:$[prefix_rec]
var prefix_at:Dictionary<int64, int64>

// the prefix n takes, by its place in prefixes; -1 where n is none
let prefix_of(n:int64):int64 {
    if nodes[n].kind != N_METHOD || !tok_is(nodes[n].t, "prefix") { return 0 - 1 }
    let seen = prefix_at.get(n, -1)
    if seen >= 0 { return seen }
    let a:int64 = nodes[n].a
    if names_type(a) || method_of(n) >= 0 { return 0 - 1 }      // a method of its own wins
    let y:int64 = type_of(a)
    if y < 0 { return 0 - 1 }
    let yk:ykind = types[y].kind
    if yk != Y_ARRAY && yk != Y_STRING && yk != Y_DICT && yk != Y_SET && yk != Y_RANGE { return 0 - 1 }   // r.prefix(n), a Range (#373)
    let ey:int64 = yk == Y_STRING ? base_type(Y_UCHR) : types[y].elem
    let fn:int64 = prefix_arg(n, ey)
    if fn == 0 - 1 { return 0 - 1 }
    let r:prefix_rec = {n, y, ey, fn < 0 ? 0 - 1 : fn}
    prefixes += r
    prefix_at[n] = prefixes.count as int64 - 1
    return prefixes.count as int64 - 1
}

// an element, a value or a key for the function, at expression at: a
// copy of one that owns, which it owns, as kc's eager ones give it (#329)
let put_prefix_arg(ey:int64, at:cstr) {
    if is_owner(ey) {
        put_owner_prefix(ey)
        put("_copy(&")
        put(at)
        put(")")
    } else {
        put(at)
    }
}

// xs.prefix(n), xs.prefix { ... } (#372): a statement expression, as
// kelvinc's; one an expression gives held in _kv_mt and freed
let gen_prefix(n:int64) {
    let r:prefix_rec = prefixes[prefix_of(n)]
    let y:int64 = r.src_y
    let yk:ykind = types[y].kind
    let a:int64 = nodes[n].a
    if yk == Y_RANGE {                                  // r.prefix(n) (#373): the Range of its first n, as kelvinc's
        let ey:int64 = types[y].elem
        put("({ ")
        put_ctype(y)
        put(" _kv_rp = (")
        gen_expr(a)
        put("); int64_t _kv_pn = (")
        gen_expr(nodes[n].b)
        put("); ")
        put_range_walk(ey, "_kv_rp", "_kv_p")
        put(", _kv_pl = _kv_p_lo; bool _kv_pt = _kv_p_go && _kv_pn > 0; if (_kv_pt) _kv_pl = (uint64_t)(_kv_pn - 1) >= (uint64_t)_kv_p_end - (uint64_t)_kv_p_lo ? _kv_p_end : (")
        put_ctype(ey)
        put(")((uint64_t)_kv_p_lo + (uint64_t)(_kv_pn - 1)); (")
        put_ctype(y)
        put("){_kv_p_lo, !_kv_pt ? _kv_p_lo : _kv_pl < ")
        put(range_max(ey))
        put(" ? (")
        put_ctype(ey)
        put(")(_kv_pl + 1) : _kv_pl, _kv_pt && _kv_pl == ")
        put(range_max(ey))
        put("}; })")
        return
    }
    put("({ ")
    if is_place(a) {
        put("__auto_type _kv_ms = &(")
        gen_expr(a)
        put("); ")
    } else {
        put("__attribute__((cleanup(")
        put_free(y)
        put("))) ")
        put_ctype(y)
        put(" _kv_mt = ")
        gen_expr(a)
        put("; ")
        put_ctype(y)
        put(" *_kv_ms = &_kv_mt; ")
    }
    if r.fn < 0 {
        put("int64_t _kv_pn = (")
        gen_expr(nodes[n].b)
        put("); ")
    }
    if (yk == Y_ARRAY || yk == Y_STRING) && r.fn < 0 {      // the first n, a slice
        put("size_t _kv_pc = _kv_pn <= 0 ? 0 : (uint64_t)_kv_pn < _kv_ms->count ? (size_t)_kv_pn : _kv_ms->count; ")
        if yk == Y_STRING {
            put("kv_string_slice")
        } else {
            put_ctype(y)
            put("_slice")
        }
        put("(_kv_ms, 0, _kv_pc); })")
        return
    }
    if yk == Y_STRING {                                  // the codepoints before the first f says false for
        put("const uint8_t *_kv_pp = _kv_ms->b.at, *_kv_pe = _kv_pp ? _kv_pp + _kv_ms->b.count : _kv_pp; size_t _kv_pc = 0; while (_kv_pp < _kv_pe) { kv_uchr _kv_pu = {kv_utf8_next(&_kv_pp)}; if (!")
        put_fn_name(r.fn)
        put("(_kv_pu)) break; _kv_pc++; } kv_string_slice(_kv_ms, 0, _kv_pc); })")
        return
    }
    put_ctype(y)
    put(" _kv_mo = {0}; ")
    if yk == Y_ARRAY {
        put("for (size_t _kv_mi = 0; _kv_mi < _kv_ms->count; _kv_mi++) { if (!")
        put_fn_name(r.fn)
        put("(")
        put_prefix_arg(r.elem_y, "_kv_ms->at[_kv_mi]")
        put(")) break; ")
        put_ctype(y)
        put("_append(&_kv_mo, ")
        put_prefix_arg(r.elem_y, "_kv_ms->at[_kv_mi]")
        put("); } _kv_mo; })")
        return
    }
    let dict = yk == Y_DICT
    let ky:int64 = dict ? types[y].name : types[y].elem
    let at:cstr := dict ? "_kv_ms->at[_kv_mi].value" : "_kv_ms->at[_kv_mi].key"
    if r.fn < 0 { put("int64_t _kv_pk = 0; ") }
    put("for (size_t _kv_mi = 0; _kv_mi < _kv_ms->len; _kv_mi++) if (_kv_ms->at[_kv_mi].live) { ")
    if r.fn < 0 {
        put("if (_kv_pk >= _kv_pn) break; _kv_pk++; ")
    } else {
        put("if (!")
        put_fn_name(r.fn)
        put("(")
        put_prefix_arg(r.elem_y, at)
        put(")) break; ")
    }
    put_owner_prefix(y)
    put(dict ? "_set(&_kv_mo, " : "_insert(&_kv_mo, ")
    put_key_text(ky, "_kv_ms->at[_kv_mi].key")
    if dict {
        put(", ")
        put_prefix_arg(r.elem_y, at)
    }
    put("); } _kv_mo; })")
}

// ---------- a Dictionary's merge and merging (#338) ----------

// d.merge(&e) in place and d.merging(&e) a new Dictionary, as kelvinc's
// #236: e's entries added, each value copied; where d has the key, f of
// d's value and the copy, which f owns both of, else the copy wins
struct merge_rec {
    node: int64
    fn: int64               // f, or -1
    lent: bool              // e by a borrow, &e, else by value, moved in
}

var merges:$[merge_rec]
var merge_at:Dictionary<int64, int64>

let merge_of(n:int64):int64 {
    let seen = merge_at.get(n, -1)
    if seen >= 0 { return seen }
    let a:int64 = nodes[n].a
    let dy:int64 = type_of(a)
    if dy < 0 || types[dy].kind != Y_DICT { return 0 - 1 }
    let in_place = tok_is(nodes[n].t, "merge")
    var me = $"'."
    me += tok_text(nodes[n].t)
    me += "'"
    if in_place && !is_place(a) {                       // as kelvinc's
        gen_error(n, "'.merge' changes a Dictionary in place, and this one an expression gives would be lost: bind it, or write '.merging(...)'")
        return 0 - 1
    }
    if in_place && changed_root(a) >= 0 && how_declared(nodes[changed_root(a)].t) != 0 {
        var m = $"'"
        m += tok_text(nodes[changed_root(a)].t)
        m += "' is a let and cannot change; declare it with var, or write '.merging(...)'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let other:int64 = nodes[n].b
    if other < 0 {
        var m = me.copy()
        m += " takes the Dictionary to merge: '"
        m += &me
        m += "(&e)', and a function where keys meet, '"
        m += &me
        m += "(&e) { a, b in ... }'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let lent = nodes[other].kind == N_ADDR
    let oy:int64 = type_of(lent ? nodes[other].a : other)
    if oy != dy {
        var m = me.copy()
        m += " takes a Dictionary of the same key and value types, "
        let dw:String = kelvin_type_text(dy)
        m += &dw
        m += ", or a borrow of one, and this is "
        let ow:String = oy >= 0 ? kelvin_type_text(oy) : $"not one"
        m += &ow
        if lent && oy >= 0 { m += "^" }                  // a borrow's, as kelvinc names it
        gen_error(other, m.cstr)
        return 0 - 1
    }
    let vy:int64 = types[dy].elem
    let f:int64 = nodes[other].next
    var fn:int64 = 0 - 1
    if f >= 0 {
        if nodes[f].kind == N_ANON {
            var ps:$[int64] = $[]
            ps += vy
            ps += vy
            fn = anon_function_of(f, &ps, vy, &me)
            if fn < 0 { return 0 - 1 }
        } else if nodes[f].kind == N_ID && var_type(nodes[f].t) < 0 {
            fn = decl_named(nodes[f].t, D_FN)
        }
        let p:int64 = fn >= 0 ? nodes[fn].a : 0 - 1
        if fn < 0 || p < 0 || nodes[p].next < 0 || nodes[nodes[p].next].next >= 0 || nodes[p].ty != vy || nodes[nodes[p].next].ty != vy || nodes[fn].ty != vy {
            var m = me.copy()
            m += " calls its function with the two values of a key in both, "
            let vw:String = kelvin_type_text(vy)
            m += &vw
            m += ", and keeps what it gives"
            gen_error(f, m.cstr)
            return 0 - 1
        }
    }
    let r:merge_rec = {n, fn, lent}
    merges += r
    merge_at[n] = merges.count as int64 - 1
    return merges.count as int64 - 1
}

let gen_merge(n:int64) {
    let r:merge_rec = merges[merge_of(n)]
    let a:int64 = nodes[n].a
    let dy:int64 = type_of(a)
    let vy:int64 = types[dy].elem
    let other:int64 = nodes[n].b
    let in_place = tok_is(nodes[n].t, "merge")
    let lk:cstr := types[types[dy].name].kind == Y_STRING ? "KV_LK_TEXT" : "KV_LK_INT"
    put("({ ")
    put_ctype(dy)
    if in_place {
        put(" *_kv_md = &(")
        gen_expr(a)
        put("); ")
    } else if is_place(a) {                              // merging: a copy of d, or d an expression gives, taken
        put(" _kv_mm = ")
        put_owner_prefix(dy)
        put("_copy(&(")
        gen_expr(a)
        put(")); ")
        put_ctype(dy)
        put(" *_kv_md = &_kv_mm; ")
    } else {
        put(" _kv_mm = ")
        gen_expr(a)
        put("; ")
        put_ctype(dy)
        put(" *_kv_md = &_kv_mm; ")
    }
    if r.lent {
        put("const ")
        put_ctype(dy)
        put(" *_kv_me = ")
        gen_expr(other)
        put("; ")
    } else {                                             // e by value: held, and freed after
        put("__attribute__((cleanup(")
        put_free(dy)
        put("))) ")
        put_ctype(dy)
        put(" _kv_mo = ")
        if nodes[other].kind == N_ID && var_type(nodes[other].t) >= 0 {
            put_owner_prefix(dy)
            put("_take(&")
            put_tok(nodes[other].t)
            put(")")
        } else {
            gen_expr(other)
        }
        put("; const ")
        put_ctype(dy)
        put(" *_kv_me = &_kv_mo; ")
    }
    put("for (size_t _kv_mi = 0; _kv_mi < _kv_me->len; _kv_mi++) { if (!_kv_me->at[_kv_mi].live) continue; ")
    put_owner_prefix(dy)
    put("_entry *_kv_mx = ")
    put_owner_prefix(dy)
    put("_lookup(_kv_md, ")
    put(lk)
    put("(&_kv_me->at[_kv_mi].key), _kv_me->at[_kv_mi].hash); if (!_kv_mx) { ")
    put_owner_prefix(dy)
    put("_set(_kv_md, ")
    put(lk)
    put("(&_kv_me->at[_kv_mi].key), ")
    put_merge_value(vy)
    put("); continue; } ")
    if r.fn >= 0 {                                       // where d has the key: f's value
        put("_kv_mx->value = ")
        put_fn_name(r.fn)
        put("(_kv_mx->value, ")
        put_merge_value(vy)
        put(");")
    } else if is_owner(vy) {                             // else the copy, the old one freed
        put("{ ")
        put_ctype(vy)
        put(" _kv_mv = ")
        put_merge_value(vy)
        put("; ")
        put_free(vy)
        put("(&_kv_mx->value); _kv_mx->value = _kv_mv; }")
    } else {
        put("_kv_mx->value = ")
        put_merge_value(vy)
        put(";")
    }
    put(in_place ? " } (void)0; })" : " } _kv_mm; })")
}

// an entry's value of e, a copy where it owns
let put_merge_value(vy:int64) {
    if is_owner(vy) {
        put_owner_prefix(vy)
        put("_copy(&_kv_me->at[_kv_mi].value)")
    } else {
        put("_kv_me->at[_kv_mi].value")
    }
}

// ---------- searching an Array or a Dictionary (#339, #342) ----------

// d.contains(v), d.firstKey(v), d.lastKey(v), as kelvinc's #249: whether
// v is among the values, by their ==, and the key of the first or the
// last in the order added, a K?; of a function, the values it says true
// for, and WithKey of each key and its value. xs.contains(x),
// xs.firstIndex(x), xs.lastIndex(x), as kelvinc's #248, the same of an
// Array's elements, the index an i64? (#342)
struct search_rec {
    node: int64
    fn: int64               // the function, or -1 of a value v
    with_key: bool
}

var searches:$[search_rec]
var search_at:Dictionary<int64, int64>

let is_search_name(t:int64):bool {
    return tok_is(t, "contains") || tok_is(t, "firstKey") || tok_is(t, "lastKey") || tok_is(t, "containsWithKey") || tok_is(t, "firstKeyWithKey") || tok_is(t, "lastKeyWithKey") || tok_is(t, "firstIndex") || tok_is(t, "lastIndex")
}

// a function's type as kelvinc writes it, (i64, i64):bool
let fn_type_text(fn:int64):String {
    var w = $"("
    var p:int64 = nodes[fn].a
    while p >= 0 {
        let pw:String = kelvin_type_text(nodes[p].ty)
        w += &pw
        if nodes[p].next >= 0 { w += ", " }
        p = nodes[p].next
    }
    w += "):"
    let rw:String = nodes[fn].ty >= 0 ? kelvin_type_text(nodes[fn].ty) : $"void"
    w += &rw
    return w
}

// what v is where a value of type vy goes and v is not one, as kelvinc's
// check_typed_value says it: text and numbers by what they are, else its
// type; "" where it is one, or what only C sees (#339, #340)
let value_mismatch_text(v:int64, vy:int64):String {
    let k:nkind = nodes[v].kind
    let vk:ykind = types[vy].kind
    let number = k == N_NUM || k == N_CHAR || k == N_BOOL || (k == N_UNARY && tok_is(nodes[v].t, "-") && nodes[nodes[v].a].kind == N_NUM)
    if is_case_word(v) { return $"" }                   // none, ok(v), err(e): gen_value reads them by the type (#343)
    let inner:int64 = wrap_type(vy)
    if inner >= 0 {                                     // an Optional, or the T it holds, wrapped (#343); a Result's ok (#344)
        if k != N_STR && !number {
            let y:int64 = type_of(v)
            if y == vy { return $"" }
            if tagged_of(y) >= 0 { return eq_type_text(y) }   // struct J, as kelvinc names it (#345)
        }
        return value_mismatch_text(v, inner)
    }
    if k == N_STR { return vk == Y_STRING || vk == Y_CSTR ? $"" : $"text" }
    if number { return is_number_kind(vk) ? $"" : $"a number" }
    let y:int64 = type_of(v)
    if y < 0 || y == vy || (is_number_kind(types[y].kind) && is_number_kind(vk)) { return $"" }
    if types[y].kind == Y_CSTR { return vk == Y_STRING ? $"" : $"text" }
    return kelvin_type_text(y)
}

let search_of(n:int64):int64 {
    let seen = search_at.get(n, -1)
    if seen >= 0 { return seen }
    let t:int64 = nodes[n].t
    if !is_search_name(t) { return 0 - 1 }
    let a:int64 = nodes[n].a
    let dy:int64 = type_of(a)
    if dy < 0 || (types[dy].kind != Y_DICT && types[dy].kind != Y_ARRAY) { return 0 - 1 }
    let dict = types[dy].kind == Y_DICT
    let with_key = tok_is(t, "containsWithKey") || tok_is(t, "firstKeyWithKey") || tok_is(t, "lastKeyWithKey")
    let index_name = tok_is(t, "firstIndex") || tok_is(t, "lastIndex")
    if dict ? index_name : !index_name && !tok_is(t, "contains") {   // the other's name, as kelvinc's
        var m = dict ? $"a Dictionary has no '." : $"an Array has no '."
        m += tok_text(t)
        m += dict ? $"': its values are found by key, '." : $"': it is a Dictionary's; an Array's is '."
        let first = tok_is(t, "firstKey") || tok_is(t, "firstKeyWithKey") || tok_is(t, "firstIndex")
        if tok_is(t, "containsWithKey") {
            m += "contains"
        } else if dict {
            m += first ? $"firstKey" : $"lastKey"
        } else {
            m += first ? $"firstIndex" : $"lastIndex"
        }
        m += "'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    let each = dict ? $"value" : $"element"
    let an_each = dict ? $"a value" : $"an element"
    let vy:int64 = types[dy].elem
    let ky:int64 = dict ? types[dy].name : 0 - 1
    let kt:int64 = !dict ? 0 - 1 : types[ky].kind == Y_STRING ? base_type(Y_CSTR) : ky   // a String key's text, lent, as #331's
    var me = $"'."
    me += tok_text(t)
    me += "'"
    let f:int64 = nodes[n].b
    if f < 0 {                                          // as kelvinc's
        var m = me.copy()
        if with_key {
            m += " takes a function of a key and its value: '."
            m += tok_text(t)
            m += " { k, v in ... }'"
        } else {
            m += " takes the "
            m += &each
            m += " to look for, '."
            m += tok_text(t)
            m += "(x)', or a function that says which, '."
            m += tok_text(t)
            m += " { $0 > 0 }'"
        }
        gen_error(n, m.cstr)
        return 0 - 1
    }
    if nodes[f].next >= 0 {
        var m = me.copy()
        if nodes[nodes[f].next].kind == N_ANON {
            m += " takes one function, and this would be a second"
        } else {
            m += " takes one "
            m += &each
            m += " to look for, or one function"
        }
        gen_error(n, m.cstr)
        return 0 - 1
    }
    var fn:int64 = 0 - 1
    var ps:$[int64] = $[]
    if with_key { ps += kt }
    ps += vy
    if nodes[f].kind == N_ANON {
        fn = anon_function_of(f, &ps, 0 - 1, &me)
        if fn < 0 { return 0 - 1 }
    } else if nodes[f].kind == N_ID && var_type(nodes[f].t) < 0 && decl_named(nodes[f].t, D_FN) >= 0 {
        fn = decl_named(nodes[f].t, D_FN)
    }
    if fn < 0 && with_key {
        var m = me.copy()
        m += " takes a function of two parameters, a key and its value, with a result, and this is "
        let y:int64 = nodes[f].kind == N_NUM || nodes[f].kind == N_STR ? 0 - 1 : type_of(f)
        let w:String = y >= 0 ? kelvin_type_text(y) : $"not one"
        m += &w
        gen_error(f, m.cstr)
        return 0 - 1
    }
    if fn < 0 {                                         // a value, compared by the values' ==
        if !eq_type(vy) {
            var m = me.copy()
            let vw:String = kelvin_type_text(vy)
            if dict {
                m += " of Dictionary<"                   // a struct's tagged, as kelvinc names it
                let kw:String = kelvin_type_text(ky)
                m += &kw
                m += types[vy].kind == Y_STRUCT && !is_variant(vy) ? $", struct " : $", "
            } else {
                m += types[vy].kind == Y_STRUCT && !is_variant(vy) ? $" of Array<struct " : $" of Array<"
            }
            m += &vw
            m += "> compares the "
            m += &each
            m += "s, and "
            m += &vw
            m += " has no '==': give a function that says which, '."
            m += tok_text(t)
            m += " { ... }'"
            gen_error(f, m.cstr)
            return 0 - 1
        }
        let bad:String = value_mismatch_text(f, vy)
        if bad.count > 0 {
            var m = me.copy()
            m += " of "
            let dw:String = kelvin_type_text(dy)
            m += &dw
            m += " looks for "
            let vw:String = kelvin_type_text(vy)
            m += article_of(&vw)
            m += " "
            m += &vw
            m += ", and this is "
            m += &bad
            gen_error(f, m.cstr)
            return 0 - 1
        }
        if has_eq_fn(vy) { need_eq(vy) }
    } else {
        var count:int64 = 0
        var p:int64 = nodes[fn].a
        while p >= 0 {
            count += 1
            p = nodes[p].next
        }
        if count != ps.count as int64 || nodes[fn].ty < 0 || types[nodes[fn].ty].kind == Y_VOID {
            var m = me.copy()
            if with_key {
                m += " takes a function of two parameters, a key and its value, with a result, and this is "
            } else {
                m += " takes a function of one parameter, "
                m += &an_each
                m += ", with a result, and this is "
            }
            let w:String = fn_type_text(fn)
            m += &w
            gen_error(f, m.cstr)
            return 0 - 1
        }
        let first_p:int64 = nodes[fn].a
        if with_key && nodes[first_p].ty != kt {
            var m = me.copy()
            m += " calls its function with each key, "
            let kw:String = kelvin_type_text(kt)
            m += &kw
            m += ", and this takes "
            let pw:String = kelvin_type_text(nodes[first_p].ty)
            m += &pw
            gen_error(f, m.cstr)
            return 0 - 1
        }
        let last_p:int64 = with_key ? nodes[first_p].next : first_p
        if nodes[last_p].ty != vy {
            var m = me.copy()
            m += " calls its function with each "
            m += &each
            m += ", "
            let vw:String = kelvin_type_text(vy)
            m += &vw
            m += ", and this takes "
            let pw:String = kelvin_type_text(nodes[last_p].ty)
            m += &pw
            gen_error(f, m.cstr)
            return 0 - 1
        }
        let ry:int64 = nodes[fn].ty
        if types[ry].kind != Y_BOOL {
            var m = me.copy()
            if nodes[f].kind == N_ANON && nodes[f].flag != 0 {   // as kelvinc's, of what its one expression gives
                let e:int64 = nodes[nodes[nodes[f].b].a].a
                m += " looks for what its function says true for, a bool, and this "
                if nodes[e].kind == N_NUM {
                    m += "is a number: write 'true' or 'false'"
                } else {
                    m += "gives "
                    if nodes[e].kind == N_BIN {
                        m += "a number"
                    } else {
                        let rw:String = kelvin_type_text(ry)
                        m += &rw
                    }
                    m += ": compare it, as in 'x != 0'"
                }
            } else {
                if with_key {
                    m += " takes a function that says whether a key and its value is the one, a bool, and this gives "
                } else {
                    m += " takes a function that says whether "
                    m += &an_each
                    m += " is the one, a bool, and this gives "
                }
                let rw:String = kelvin_type_text(ry)
                m += &rw
            }
            gen_error(f, m.cstr)
            return 0 - 1
        }
    }
    let r:search_rec = {n, fn, with_key}
    searches += r
    search_at[n] = searches.count as int64 - 1
    return searches.count as int64 - 1
}

let search_type_of(n:int64):int64 {
    let t:int64 = nodes[n].t
    if tok_is(t, "contains") || tok_is(t, "containsWithKey") { return base_type(Y_BOOL) }
    let dy:int64 = type_of(nodes[n].a)
    return optional_of(types[dy].kind == Y_DICT ? types[dy].name : base_type(Y_I64))   // an Array's index, an i64? (#342)
}

// a loop over the live entries, in the order added or from the last, to
// the first value equal to v, or that f says true for, given a copy of
// one that owns; contains gives a bool, the others some of a copy of the
// key or none. A Dictionary an expression gives is held in _kv_mt, and v
// an owner an expression gives is held too, both freed after. An Array's
// the same over its elements, some of the index (#342)
let gen_search(n:int64) {
    let r:search_rec = searches[search_of(n)]
    let t:int64 = nodes[n].t
    let a:int64 = nodes[n].a
    let dy:int64 = type_of(a)
    let dict = types[dy].kind == Y_DICT
    let vy:int64 = types[dy].elem
    let ky:int64 = dict ? types[dy].name : 0 - 1
    let v:int64 = nodes[n].b
    let contains = tok_is(t, "contains") || tok_is(t, "containsWithKey")
    let last = tok_is(t, "lastKey") || tok_is(t, "lastKeyWithKey") || tok_is(t, "lastIndex")
    let at:cstr := dict ? "_kv_ms->at[_kv_mi].value" : "_kv_ms->at[_kv_mi]"
    let opt = is_variant(vy)                             // an Optional's v, wrapped (#343), a Result's (#344)
    let hold = r.fn < 0 && !opt && needs_hold(v)
    if hold { hold_open(v) }
    put("({ ")
    if is_place(a) {
        put("__auto_type _kv_ms = &(")
        gen_expr(a)
        put("); ")
    } else {
        put("__attribute__((cleanup(")
        put_free(dy)
        put("))) ")
        put_ctype(dy)
        put(" _kv_mt = ")
        gen_expr(a)
        put("; ")
        put_ctype(dy)
        put(" *_kv_ms = &_kv_mt; ")
    }
    if r.fn < 0 {
        let made = opt ? opt_operand_owns(v, vy) : is_owner(vy) && !is_place(v) && !hold
        if made {                                        // a String of text made here, freed after
            put("__attribute__((cleanup(")
            put_free(vy)
            put("))) ")
        }
        put_ctype(vy)
        put(" _kv_cx = ")
        if opt {
            gen_opt_operand(v, vy)
        } else if hold {
            gen_expr(v)                                  // the held one by its name
        } else {
            gen_value(v, vy)
        }
        put("; ")
    }
    let ry:int64 = contains ? 0 - 1 : search_type_of(n)
    if contains {
        put("bool _kv_r = false; ")
    } else {
        put_ctype(ry)
        put(" _kv_r = _kv_")
        put_tok(types[ry].name)
        put("_make_none(); ")
    }
    if dict {
        put(last ? "for (size_t _kv_mi = _kv_ms->len; _kv_mi-- > 0;)" : "for (size_t _kv_mi = 0; _kv_mi < _kv_ms->len; _kv_mi++)")
        put(" if (_kv_ms->at[_kv_mi].live) if (")
    } else {
        put(last ? "for (size_t _kv_mi = _kv_ms->count; _kv_mi-- > 0;)" : "for (size_t _kv_mi = 0; _kv_mi < _kv_ms->count; _kv_mi++)")
        put(" if (")
    }
    if r.fn < 0 {
        put_eq_code(vy, at, "_kv_cx")
    } else {
        put_fn_name(r.fn)
        put("(")
        if r.with_key {                                  // the key first, a String's text, lent
            if types[ky].kind == Y_STRING {
                put("KV_LK_TEXT(&_kv_ms->at[_kv_mi].key)")
            } else {
                put("_kv_ms->at[_kv_mi].key")
            }
            put(", ")
        }
        if is_owner(vy) {
            put_owner_prefix(vy)
            put("_copy(&")
            put(at)
            put(")")
        } else {
            put(at)
        }
        put(")")
    }
    if contains {
        put(") { _kv_r = true; break; } _kv_r; })")
    } else {
        put(") { _kv_r = _kv_")
        put_tok(types[ry].name)
        put("_make_some(")
        if !dict {
            put("(int64_t)_kv_mi")
        } else if is_owner(ky) {
            put_owner_prefix(ky)
            put("_copy(&_kv_ms->at[_kv_mi].key)")
        } else {
            put("_kv_ms->at[_kv_mi].key")
        }
        put("); break; } _kv_r; })")
    }
    if hold { hold_close(v) }
}

// for x in it (#320), as kelvinc's #318: next() into a hidden Optional
// each pass, freed where it owns, x its some, up to none; the iterator
// changes, a place by its address, and one an expression gives is held;
// src, what it walks, the loop's own or a Sequence's makeIterator() (#322)
let gen_iter_each(n:int64, depth:int64, y:int64, f:int64, src:int64) {
    let builtin = f < 0                                // an Iterator<T>'s, kv_iter_next (#326)
    let tn:String = builtin ? $"Iterator" : tok_text(types[y].name)
    let oy:int64 = builtin ? optional_of(types[y].elem) : nodes[f].ty
    let ey:int64 = some_type(oy)
    if !builtin && nodes[f].flag != 2 {
        var m = $"for walks an iterator by its next(), which changes it, and '"
        m += &tn
        m += ".next' is a let method, which reads it: write 'var "
        m += &tn
        m += ".next():T?'"
        gen_error(nodes[n].a, m.cstr)
        return
    }
    if !builtin && (nodes[f].a >= 0 || ey < 0) {
        var m = $"for walks an iterator by its next(), which takes nothing and gives each value, then none: write 'var "
        m += &tn
        m += ".next():T?'"
        gen_error(nodes[n].a, m.cstr)
        return
    }
    if nodes[n].b >= 0 {
        gen_error(n, "two loop variables walk a Dictionary's entries; an iterator's values take one")
        return
    }
    let place = changeable_place(src)
    let lead = $"for walks an iterator by its var next(), which changes "
    if place && !changes_var(src, &lead) { return }
    let d = tagged_of(oy)
    var some:int64 = 0 - 1
    var c:int64 = nodes[d].a
    while c >= 0 {
        if tok_is(nodes[c].t, "some") { some = c }
        c = nodes[c].next
    }
    serial += 1
    let s = serial
    put("{\n")
    indent(depth + 1)
    if !place {                                       // for x in from(3): held, and freed where it owns
        if is_owner(y) {
            put("__attribute__((cleanup(")
            put_free(y)
            put("))) ")
        }
        put_ctype(y)
        put(" _kv_it")
        put_int(s)
        put(" = ")
        gen_expr(src)
        put(";\n")
        indent(depth + 1)
    }
    put("for (;;)\n")
    indent(depth + 1)
    put("{\n")
    indent(depth + 2)
    if is_owner(oy) {
        put("__attribute__((cleanup(")
        put_free(oy)
        put("))) ")
    }
    put_ctype(oy)
    put(" _kv_o")
    put_int(s)
    if builtin {
        put("; kv_iter_next(")
    } else {
        put(" = ")
        put_tok(nodes[f].c)
        put("__next(")
    }
    if place {
        gen_place(src)
    } else {
        put("&_kv_it")
        put_int(s)
    }
    if builtin {
        put(", &_kv_o")
        put_int(s)
    }
    put(");\n")
    indent(depth + 2)
    put("if (_kv_o")
    put_int(s)
    put(".tag != ")
    put_int(case_tag(d, some))
    put(") break;\n")
    indent(depth + 2)
    put_ctype(ey)
    put(" ")
    put_tok(nodes[n].t)
    put(" = _kv_o")
    put_int(s)
    put(".u.some;\n")
    open_scope()
    declare_each(nodes[n].t, ey, 3)                     // each value, a let (#271)
    indent(depth + 2)
    gen_block(nodes[n].c, depth + 2)
    close_scope()
    indent(depth + 1)
    put("}\n")
    indent(depth)
    put("}\n")
}

let gen_each(n:int64, depth:int64) {
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return }
    if types[y].kind == Y_RANGE {                      // a Range's values (#373), its kind read at run time, as kelvinc's
        if nodes[n].b >= 0 {
            gen_error(n, "two loop variables walk a Dictionary's entries, 'for k, v in d': a Range counts with one")
            return
        }
        let ey:int64 = types[y].elem
        serial += 1
        var r = $"_kv_range"
        r += String(serial)
        put("{\n")
        indent(depth + 1)
        put_ctype(y)
        put(" ")
        put(r.cstr)
        put(" = ")
        gen_expr(nodes[n].a)
        put(";\n")
        indent(depth + 1)
        put("for (")
        put_ctype(ey)
        put(" ")
        put_tok(nodes[n].t)
        put(" = (")
        put(r.cstr)
        put(").lo, _kv_go")
        put_int(serial)
        put(" = (")
        put(r.cstr)
        put(").kind ? ")
        put_tok(nodes[n].t)
        put(" <= (")
        put(r.cstr)
        put(").hi : ")
        put_tok(nodes[n].t)
        put(" < (")
        put(r.cstr)
        put(").hi, _kv_end")
        put_int(serial)
        put(" = (")
        put(r.cstr)
        put(").kind || !_kv_go")
        put_int(serial)
        put(" ? (")
        put(r.cstr)
        put(").hi : (")
        put(r.cstr)
        put(").hi - 1; _kv_go")
        put_int(serial)
        put("; _kv_go")
        put_int(serial)
        put(" = ")
        put_tok(nodes[n].t)
        put(" != _kv_end")
        put_int(serial)
        put(", ")
        put_tok(nodes[n].t)
        put(" += _kv_go")
        put_int(serial)
        put(")\n")
        open_scope()
        declare_each(nodes[n].t, ey, 4)                  // a let, as a range's count (#271)
        indent(depth + 1)
        gen_block(nodes[n].c, depth + 1)
        close_scope()
        indent(depth)
        put("}\n")
        return
    }
    if types[y].kind == Y_ITER {                       // an Iterator<T> (#326)
        gen_iter_each(n, depth, y, 0 - 1, nodes[n].a)
        return
    }
    let mk = sequence_maker(y)
    if mk >= 0 {                                       // a Sequence (#322), as kelvinc's #321
        if nodes[n].b >= 0 {
            gen_error(n, "two loop variables walk a Dictionary's entries; a Sequence's values take one")
            return
        }
        let iy:int64 = nodes[mk].ty
        if nodes[mk].flag == 2 || nodes[mk].a >= 0 || iterator_next(iy) < 0 {
            var m = $"a Sequence gives a fresh iterator by its makeIterator(), a let method that takes nothing and gives a value whose 'var next():T?' gives each value: write 'let "
            m += tok_text(types[y].name)
            m += ".makeIterator():I'"
            gen_error(nodes[n].a, m.cstr)
            return
        }
        let call:int64 = make_node(N_METHOD, nodes[mk].t)   // s.makeIterator(), a fresh iterator, held
        nodes[call].a = nodes[n].a
        gen_iter_each(n, depth, iy, iterator_next(iy), call)
        return
    }
    let f = iterator_next(y)
    if f >= 0 {                                        // an iterator (#320)
        gen_iter_each(n, depth, y, f, nodes[n].a)
        return
    }
    if types[y].kind == Y_FIXED && types[y].name == 0 - 1 {   // q^ of a [T]^, as kelvinc refuses it (#363)
        gen_error(nodes[n].a, "an array of no count has no length to walk: walk 0..<n, and index it, q^[i]")
        return
    }
    if types[y].kind == Y_FIXED && (types[y].name == 0 - 2 || types[y].name == 0 - 4) {   // a parameter's, where kelvinc's link fails (#357)
        gen_error(nodes[n].a, "a parameter's array is a pointer, of no count: walk 0..<n, and index it, a[i]")
        return
    }
    if types[y].kind == Y_FIXED && !is_number_kind(types[types[y].elem].kind) && types[types[y].elem].kind != Y_BOOL && types[types[y].elem].kind != Y_CSTR {
        var m = $"kc walks a fixed array of numbers, bools or text, to its count or a zero; not yet of "
        let ew:String = type_text(types[y].elem)
        m += &ew
        m += ": index it, a[i]"
        gen_error(nodes[n].a, m.cstr)                    // (#354)
        return
    }
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
        declare_each(nodes[n].t, keyed, 3)                  // (#271)
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
            declare_each(nodes[nodes[n].b].t, types[y].elem, 3)
        }
    } else if types[y].kind == Y_FIXED {               // as kelvinc's #30: each element to its count, a zero the terminator (#354)
        put("for (size_t _kv_i")
        put_int(serial)
        put(" = 0; _kv_i")
        put_int(serial)
        put(" < sizeof(")
        gen_expr(nodes[n].a)
        put(") / sizeof((")
        gen_expr(nodes[n].a)
        put(")[0]) && (")
        gen_expr(nodes[n].a)
        put(")[_kv_i")
        put_int(serial)
        put("] != 0; _kv_i")
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
        put(")[_kv_i")
        put_int(serial)
        put("];\n")
        open_scope()
        declare_each(nodes[n].t, types[y].elem, 3)
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
        declare_each(nodes[n].t, base_type(Y_UCHR), 3)      // (#271)
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
        declare_each(nodes[n].t, types[y].elem, 3)          // (#271)
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
    if fixed_case(m) {                                   // a copy of the elements, a local's array (#360)
        put_fixed_decl(nodes[m].ty, nodes[n].flag)
        put("; memcpy(")
        put_tok(nodes[n].flag)
        put(", _kv_l")
        put_int(s)
        put("->u.")
        put_tok(nodes[m].t)
        put(", sizeof ")
        put_tok(nodes[n].flag)
        put(");\n")
    } else {
        put_ctype(nodes[m].ty)
        put(" ")
        put_tok(nodes[n].flag)
        put(" = _kv_l")
        put_int(s)
        put("->u.")
        put_tok(nodes[m].t)
        put(";\n")
    }
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

// the case a fallthrough goes on into (#386): -1 in a switch's last case,
// -2 outside a switch; and the fallthrough that does, or -1
var fall_to:int64 = 0 - 2
var fall_from:int64 = 0 - 1

// whether s leaves its case: a return, a break, a continue, a fallthrough
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
    let outer_to = fall_to
    let outer_from = fall_from
    fall_from = 0 - 1
    var c:int64 = nodes[n].b
    while c >= 0 && !failed {
        let fell = fall_from
        fall_to = nodes[c].next
        fall_from = 0 - 1
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
        let first = nodes[c].a
        if fell >= 0 {                                   // the case before falls through to here (#386)
            if td >= 0 && first >= 0 && nodes[first].kind == N_CALL {
                var m = $"'fallthrough' cannot go on into a case that binds a value, 'case "
                m += tok_text(case_word(first))
                m += "("
                m += tok_text(nodes[nodes[first].b].t)
                m += "):'"
                gen_error(fell, m.cstr)
            }
            indent(depth)
            put("_kv_fall")
            put_int(c)
            put(":\n")
        }
        indent(depth + 1)
        put("{\n")
        open_scope()
        if td >= 0 && first >= 0 && nodes[first].kind == N_CALL && !failed {
            let m = case_named(td, case_word(first)) ?? 0 - 1    // case n(x): x is the case's value, the enum's still
            let x = nodes[first].b
            indent(depth + 2)
            if fixed_case(m) {                           // a copy of the elements, a local's array (#360)
                put_fixed_decl(nodes[m].ty, nodes[x].t)
                put("; memcpy(")
                put_tok(nodes[x].t)
                put(", (")
                gen_expr(nodes[n].a)
                put(").u.")
                put_tok(case_word(first))
                put(", sizeof ")
                put_tok(nodes[x].t)
                put(");\n")
            } else {
                put_ctype(nodes[m].ty)
                put(" ")
                put_tok(nodes[x].t)
                put(" = (")
                gen_expr(nodes[n].a)
                put(").u.")
                put_tok(case_word(first))
                put(";\n")
            }
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
    fall_to = outer_to
    fall_from = outer_from
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
        let vy = type_of(v)
        if vy >= 0 && types[vy].kind == Y_TASK && !is_place(v) {     // as kelvinc's (#313)
            gen_error(v, "a Task dropped here would be awaited at once: bind it, 'let t = async f(x)', and await it when its value is wanted")
            return
        }
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
        if nodes[n].a >= 0 { gen_expr(nodes[n].a) } else { put("0") }      // ..<n, ...n from 0 (#373)
        put(", _kv_end")
        put_int(serial)
        put(" = ")
        if nodes[n].b >= 0 {
            gen_expr(nodes[n].b)
        } else {                                         // lo... up to its type's largest (#373)
            put(range_max(nodes[n].a >= 0 ? type_of(nodes[n].a) : 0 - 1))
        }
        if nodes[n].flag == 0 {
            put("; ")
            put_tok(nodes[n].t)
            put(" < _kv_end")
            put_int(serial)
            put("; ")
            put_tok(nodes[n].t)
            put("++)\n")
        } else {                                         // a...b stops at b, never past it, as kelvinc's (#373)
            put(", _kv_go")
            put_int(serial)
            put(" = ")
            put_tok(nodes[n].t)
            put(" <= _kv_end")
            put_int(serial)
            put("; _kv_go")
            put_int(serial)
            put("; _kv_go")
            put_int(serial)
            put(" = ")
            put_tok(nodes[n].t)
            put(" != _kv_end")
            put_int(serial)
            put(", ")
            put_tok(nodes[n].t)
            put(" += _kv_go")
            put_int(serial)
            put(")\n")
        }
        open_scope()
        declare_each(nodes[n].t, base_type(Y_I64), 4)        // the range's count (#271)
        indent(depth)
        gen_block(nodes[n].c, depth)
        close_scope()
    case S_EACH: gen_each(n, depth)
    case S_SWITCH: gen_switch(n, depth)
    case S_IFLET: gen_iflet(n, depth)
    case S_RETURN: gen_return(n)
    case S_BREAK: put("break;\n")
    case S_CONTINUE: put("continue;\n")
    case S_FALL:                                                 // on into the next case's body, past its label (#386)
        if fall_to == 0 - 2 { gen_error(n, "'fallthrough' outside a switch") }
        if fall_to == 0 - 1 { gen_error(n, "'fallthrough' in the last case of a switch, which has no next case to go on into") }
        fall_from = n
        put("goto _kv_fall")
        put_int(fall_to)
        put(";\n")
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
        put(nodes[d].flag == 2 ? " *_kv_selfp" : " self")   // a var method's, the caller's var, as kelvinc's (#320)
    }
    if p < 0 && !takes_self { put("void") }
    while p >= 0 {
        if p != nodes[d].a || takes_self { put(", ") }
        put_ctype(nodes[p].ty)
        if nodes[p].flag == 3 {                         // an Iterator's state itself, by its address (#326)
            put(" *")
            put_tok(nodes[p].t)
            put("_ref")
        } else {
            put(" ")
            if is_owner(nodes[p].ty) { put("_kv_") }    // an owner taken by value: _kv_x_in, bound to x (#226)
            put_tok(nodes[p].t)
            if is_owner(nodes[p].ty) { put("_in") }
        }
        p = nodes[p].next
    }
    put(")")
}

// whether the function d takes an owner by value, which it frees (#226)
let takes_owner(d:int64):bool {
    var p:int64 = nodes[d].a
    while p >= 0 {
        if is_owner(nodes[p].ty) && nodes[p].flag != 3 { return true }
        p = nodes[p].next
    }
    return false
}

// ---------- a body's value (#286) ----------

// whether the built-in method m of an owner of kind k has no value, as
// kelvinc's builtin_no_value (#317): an Array's append, insert and
// remove(i, n), any one's clear, reserve and compact, an IO's write,
// flush, close, print, println and rewind
let builtin_no_value(k:ykind, m:int64):bool {
    if tok_is(m, "append") || tok_is(m, "clear") || tok_is(m, "reserve") || tok_is(m, "compact") { return true }
    if tok_is(m, "insert") || tok_is(m, "remove") { return k == Y_ARRAY }
    if k != Y_IO { return false }
    return tok_is(m, "write") || tok_is(m, "flush") || tok_is(m, "close") || tok_is(m, "print") || tok_is(m, "println") || tok_is(m, "rewind")
}

// whether e, a statement, has no value: println, print, a call of a
// function or method kc sees has no result, or of a built-in method with
// none (#317), as kelvinc's no_value
let no_value(e:int64):bool {
    let k = nodes[e].kind
    if k == N_COND { return no_value(nodes[e].b) || no_value(nodes[e].c) }
    if k == N_METHOD {
        let a:int64 = nodes[e].a
        if nodes[a].kind == N_TYPE { return false }
        let f:int64 = method_of(e)
        if f >= 0 { return nodes[f].ty < 0 || types[nodes[f].ty].kind == Y_VOID }
        if tagged_named(a) >= 0 { return false }
        let y:int64 = type_of(a)
        if y < 0 { return false }
        let yk:ykind = types[y].kind
        if yk != Y_ARRAY && yk != Y_STRING && yk != Y_DICT && yk != Y_SET && yk != Y_IO { return false }
        return builtin_no_value(yk, nodes[e].t)
    }
    if k != N_CALL && k != N_AWAIT { return false }       // await of a Task of none (#313)
    let y:int64 = type_of(e)
    return y >= 0 && types[y].kind == Y_VOID
}

// where the expression n starts: a call's or a method's at its callee or
// receiver, as kelvinc points
let start_of(n:int64):int64 {
    var s = n
    while nodes[s].kind == N_CALL || nodes[s].kind == N_METHOD {
        s = nodes[s].a
    }
    return s
}

// an argument of the call or method n that kc sees has no value is an
// error, as kelvinc's (#316, #317); true where one is
let refuse_valueless_args(n:int64):bool {
    var a:int64 = nodes[n].b
    var k = 1
    while a >= 0 {
        if no_value(a) {
            var m = $""
            if nodes[a].kind == N_AWAIT {
                m += "this Task has no value, as its function has no result, so it cannot be argument "
            } else {
                m += "this has no value, so it cannot be argument "
            }
            m += String(k)
            m += " of '"
            if nodes[n].kind == N_METHOD { m += "." }
            m += tok_text(nodes[n].kind == N_METHOD ? nodes[n].t : nodes[nodes[n].a].t)
            m += nodes[a].kind == N_AWAIT ? $"': await it alone, as a line of its own" : $"': make the call alone, as a line of its own"
            gen_error(start_of(a), m.cstr)
            return true
        }
        k += 1
        a = nodes[a].next
    }
    return false
}

// whether e, a statement, leaves a value behind: one with no effect, or,
// with calls, a call of a function kc sees has a result, as kelvinc's
// drops_value; a call of C's, or of a type, has an effect
let drops_value(e:int64, calls:bool):bool {
    let k = nodes[e].kind
    if k == N_COND { return drops_value(nodes[e].b, calls) || drops_value(nodes[e].c, calls) }
    if k == N_ASYNC || k == N_AWAIT {                   // each has its effect, as a call (#313)
        if !calls { return false }
        let y:int64 = type_of(e)
        return y >= 0 && types[y].kind != Y_VOID
    }
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
    if nodes[d].c >= 0 && nodes[d].flag == 2 && decl_named(nodes[d].c, D_STRUCT) < 0 {   // as kelvinc's (#320)
        gen_error(d, "a var method changes the caller's var, which a built-in type's method cannot: declare it on a struct or a union of the program")
        return
    }
    if nodes[d].ty >= 0 && types[nodes[d].ty].kind == Y_FIXED {   // as C has it, which kelvinc leaves to it (#358)
        gen_error(d, "a function cannot return an array, as C cannot: return a struct that holds one, or take one as a parameter and fill it")
        return
    }
    if fixed_inside(nodes[d].ty) {                       // (#354)
        refuse_fixed(d, nodes[d].ty)
        return
    }
    open_scope()
    var p:int64 = nodes[d].a
    while p >= 0 {
        let pty:int64 = nodes[p].ty
        let as_param = pty >= 0 && types[pty].kind == Y_FIXED && (types[pty].name == 0 - 2 || types[pty].name == 0 - 4)
        let pe:int64 = as_param ? types[pty].elem : 0 - 1
        var inner:int64 = pe                             // of fixed arrays, each counted, its rows (#370)
        var counted = true
        while inner >= 0 && types[inner].kind == Y_FIXED {
            if types[inner].name < 0 { counted = false }
            inner = types[inner].elem
        }
        if as_param && !counted {
            gen_error(p, "a parameter's array of arrays counts the inner ones, as C must: [[T](N)]")
            return
        }
        let owners = inner >= 0 && is_owner(inner) && !fixed_inside(inner)   // a String, an Array, a struct that owns: lent, its caller's (#365)
        if as_param && !fixed_elem_ok(pe) && !owners {
            fixed_refused(p)
            return
        }
        if !as_param && fixed_inside(pty) {
            refuse_fixed(p, pty)
            return
        }
        declare_as(nodes[p].t, nodes[p].ty, nodes[p].flag == 1 ? 2 : 0)   // a parameter, a let unless var (#271)
        p = nodes[p].next
    }
    implicit_return(d)                                   // which sees the parameters, as await t asks t's type (#313)
    if failed { return }
    gen_signature(d)
    put("\n")
    let var_method = nodes[d].c >= 0 && nodes[d].flag == 2
    if var_method { put("#define self (*_kv_selfp)\n") }   // self is the caller's var (#320)
    var rp:int64 = nodes[d].a
    while rp >= 0 {                                      // an Iterator's state itself (#326)
        if nodes[rp].flag == 3 {
            put("#define ")
            put_tok(nodes[rp].t)
            put(" (*")
            put_tok(nodes[rp].t)
            put("_ref)\n")
        }
        rp = nodes[rp].next
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
            if is_owner(nodes[p].ty) && nodes[p].flag != 3 {
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
    if var_method { put("#undef self\n") }
    rp = nodes[d].a
    while rp >= 0 {
        if nodes[rp].flag == 3 {
            put("#undef ")
            put_tok(nodes[rp].t)
            put("\n")
        }
        rp = nodes[rp].next
    }
    close_scope()
    put("\n")
}

// struct T, written for an enum with values
let put_struct(name:int64) {
    put("struct ")
    put_tok(name)
}

var held_arrays:$[int64]                 // the Arrays and Dictionaries of a struct written in it, their functions after it (#346, #347)

// what KV_DICT and KV_DICT_FUNCS take of the Dictionary y, after the
// macro's name: its key's and value's types, its name, and their
// functions (#211, #347)
let put_dict_args(y:int64) {
    let key:int64 = types[y].name
    let value:int64 = types[y].elem
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
}

// the functions of the Arrays and the Dictionaries of y that y holds,
// after y, as kelvinc's emit_arrays_after: the prototypes of y's free
// and copy, which they call, then KV_ARRAY_FUNCS (#346) and
// KV_DICT_FUNCS (#347)
let write_held_arrays(y:int64) {
    var first = true
    for i in 0..<held_arrays.count as int64 {
        let a:int64 = held_arrays[i]
        if types[a].elem == y {
            if first && is_owner(y) {
                put("__attribute__((unused)) static inline void ")
                put_owner_prefix(y)
                put("_free(")
                put_ctype(y)
                put(" *self);\n__attribute__((unused)) static inline ")
                put_ctype(y)
                put(" ")
                put_owner_prefix(y)
                put("_copy(const ")
                put_ctype(y)
                put(" *self);\n")
            }
            first = false
            if types[a].kind == Y_DICT {
                put("KV_DICT_FUNCS(")
                put_dict_args(a)
            } else {
                put("KV_ARRAY_FUNCS(")
                put_ctype(y)
                put(", ")
                put_array_name(a)
                put(", ")
                put_free_copy(y)
                put(")\n")
            }
        }
    }
}

// an enum with values as kelvinc writes it (#215): a struct of a tag and
// a union; its cases' names; _free, _take and _copy where a case owns;
// and for each case, _make and _set, and _at, checked, of one with a value
// the name of a fixed array case's C type, _kv_e_v_t, a typedef (#360)
let put_case_tname(name:int64, m:int64) {
    put("_kv_")
    put_tok(name)
    put("_")
    put_tok(nodes[m].t)
    put("_t")
}

// whether case m holds a fixed array (#360)
let fixed_case(m:int64):bool {
    return nodes[m].ty >= 0 && types[nodes[m].ty].kind == Y_FIXED
}

let gen_tagged(d:int64) {
    let name = nodes[d].t
    var m = nodes[d].a
    while m >= 0 {                                       // a fixed array case's type, typedef int64_t _kv_e_v_t[2] (#360)
        if fixed_case(m) {
            put("typedef ")
            put_fixed_base(nodes[m].ty)
            put(" ")
            put_case_tname(name, m)
            put_fixed_counts(nodes[m].ty)
            put(";\n")
        }
        m = nodes[m].next
    }
    put_struct(name)
    put("\n{\n    uint8_t tag;\n    union\n    {\n")
    m = nodes[d].a
    while m >= 0 {
        if nodes[m].ty >= 0 {
            put("        ")
            if fixed_case(m) {
                put_case_tname(name, m)
            } else {
                put_ctype(nodes[m].ty)
            }
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
    write_held_arrays(type_of_kind(Y_STRUCT, -1, name))    // an Array of it it holds (#346)
    let owns = tagged_owns(d)
    if owns {
        put("__attribute__((unused)) static inline void _kv_")
        put_tok(name)
        put("_free(")
        put_struct(name)
        put(" *self)\n{\n    switch (self->tag)\n    {\n")
        m = nodes[d].a
        while m >= 0 {
            if nodes[m].ty >= 0 && is_owner(nodes[m].ty) && fixed_case(m) {   // each element (#364)
                put("    case ")
                put_int(case_tag(d, m))
                put(": ")
                var path = $"self->u."
                path += tok_text(nodes[m].t)
                put_fixed_free(nodes[m].ty, path.cstr)
                put(" break;\n")
            } else if nodes[m].ty >= 0 && is_owner(nodes[m].ty) {
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
            if nodes[m].ty >= 0 && is_owner(nodes[m].ty) && fixed_case(m) {   // each element (#364)
                put("    case ")
                put_int(case_tag(d, m))
                put(": ")
                var to = $"_kv_v.u."
                to += tok_text(nodes[m].t)
                var from = $"self->u."
                from += tok_text(nodes[m].t)
                put_fixed_copy(nodes[m].ty, to.cstr, from.cstr)
                put(" break;\n")
            } else if nodes[m].ty >= 0 && is_owner(nodes[m].ty) {
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
            if fixed_case(m) { put_case_tname(name, m) } else { put_ctype(v) }   // a pointer to the array (#360)
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
            if fixed_case(m) { put_case_tname(name, m) } else { put_ctype(v) }
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
            if fixed_case(m) {                         // the elements, which C passes by their address (#360)
                put("const ")
                put_case_tname(name, m)
            } else {
                put_ctype(v)
            }
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
        if v >= 0 && fixed_case(m) {                   // copied in, as C assigns no array (#360)
            put("    memcpy(self->u.")
            put_tok(nodes[m].t)
            put(", v, sizeof self->u.")
            put_tok(nodes[m].t)
            put(");\n")
        } else if v >= 0 {
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
        if v >= 0 && fixed_case(m) {
            put("const ")
            put_case_tname(name, m)
            put(" v")
        } else if v >= 0 {
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
        if v >= 0 && fixed_case(m) {
            put("    memcpy(_kv_v.u.")
            put_tok(nodes[m].t)
            put(", v, sizeof _kv_v.u.")
            put_tok(nodes[m].t)
            put(");\n")
        } else if v >= 0 {
            put("    _kv_v.u.")
            put_tok(nodes[m].t)
            put(" = v;\n")
        }
        put("    return _kv_v;\n}\n")
        m = nodes[m].next
    }
    put("\n")
}

// each element of a fixed array of owners freed, or copied, at path, as
// kelvinc's loops: one loop of its innermost elements, whatever its counts
// (#364)
let put_fixed_free(y:int64, path:cstr) {
    var e:int64 = y
    while types[e].kind == Y_FIXED { e = types[e].elem }
    put("for (size_t _kv_i = 0; _kv_i < sizeof ")
    put(path)
    put(" / sizeof(")
    put_ctype(e)
    put("); _kv_i++) ")
    put_free(e)
    put("(&((")
    put_ctype(e)
    put(" *)")
    put(path)
    put(")[_kv_i]);")
}

let put_fixed_copy(y:int64, to:cstr, from:cstr) {
    var e:int64 = y
    while types[e].kind == Y_FIXED { e = types[e].elem }
    put("for (size_t _kv_i = 0; _kv_i < sizeof ")
    put(from)
    put(" / sizeof(")
    put_ctype(e)
    put("); _kv_i++) ((")
    put_ctype(e)
    put(" *)")
    put(to)
    put(")[_kv_i] = ")
    put_owner_prefix(e)
    put("_copy(&((const ")
    put_ctype(e)
    put(" *)")
    put(from)
    put(")[_kv_i]);")
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
        if is_owner(nodes[f].ty) && types[nodes[f].ty].kind == Y_FIXED {   // each element (#364)
            var path = $"self->"
            path += tok_text(nodes[f].t)
            put("    ")
            put_fixed_free(nodes[f].ty, path.cstr)
            put("\n")
        } else if is_owner(nodes[f].ty) {
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
        if is_owner(nodes[f].ty) && types[nodes[f].ty].kind == Y_FIXED {   // each element (#364)
            var to = $"_kv_v."
            to += tok_text(nodes[f].t)
            var from = $"self->"
            from += tok_text(nodes[f].t)
            put("    ")
            put_fixed_copy(nodes[f].ty, to.cstr, from.cstr)
            put("\n")
        } else if is_owner(nodes[f].ty) {
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

var written:Dictionary<int64, int64>     // the types whose C is written (#225), 2 of a struct while it is (#346)

// the C of type y once, after the types it holds by value: an Array's
// element before the Array, a struct's members before the struct, an
// enum's values before the enum (#225); a pointer needs no more than C's
// name of what it points to. An Array of a struct that holds it is a
// type before the struct, its functions after (#346), and a Dictionary
// of one (#347)
let write_type(y:int64) {
    if y < 0 || written.has(y) { return }
    written[y] = 1
    let k:ykind = types[y].kind
    if k == Y_ARRAY {
        write_type(types[y].elem)
        if written.get(types[y].elem, 0) == 2 {          // node of enum node { kids: $[node] }
            put("KV_ARRAY_TYPE(")
            put_ctype(types[y].elem)
            put(", ")
            put_array_name(y)
            put(")\n")
            held_arrays += y
            return
        }
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
        if written.get(value, 0) == 2 {                  // j of enum j { obj: Dictionary<String, j> } (#347)
            put("KV_DICT_TYPE(")
            put_dict_name(y)
            put(")\n")
            held_arrays += y
            return
        }
        put("KV_DICT(")
        put_dict_args(y)
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
    } else if k == Y_FIXED {                            // a member's, after its element's type (#356)
        write_type(types[y].elem)
    } else if k == Y_STRUCT {
        written[y] = 2                                   // while what it holds is written (#346)
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
                if types[nodes[f].ty].kind == Y_FIXED {
                    put_fixed_decl(nodes[f].ty, nodes[f].t)   // int64_t xs[3] (#356)
                } else {
                    put_ctype(nodes[f].ty)
                    put(" ")
                    put_tok(nodes[f].t)
                }
                put(";\n")
                f = nodes[f].next
            }
            put("};\n\n")
            written[y] = 1
            write_held_arrays(y)
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
            written[y] = 1
            gen_tagged(e)
        }
        written[y] = 1
    }
}

// a parameter's [T] or [T](N) is a pointer, as kelvinc's #49 and C have
// it: its type the parameter kind, -2, or -4 of [const T], before any
// signature is written (#357)
let fixed_params() {
    for i in 0..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind == D_FN {
            var p:int64 = nodes[d].a
            while p >= 0 {
                let y:int64 = nodes[p].ty
                if y >= 0 && types[y].kind == Y_FIXED {
                    set_ty(p, type_of_kind(Y_FIXED, types[y].elem, types[y].name == 0 - 3 ? 0 - 4 : 0 - 2))
                }
                p = nodes[p].next
            }
        }
    }
}

let gen_program() {
    index_names()
    count_overloads()
    fixed_params()
    put("/* generated by kc, selfhost/kc.k */\n")
    put("#if !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)\n")
    put("#ifndef _XOPEN_SOURCE\n#define _XOPEN_SOURCE 700\n#endif\n")
    put("#ifndef _DEFAULT_SOURCE\n#define _DEFAULT_SOURCE 1\n#endif\n")
    put("#endif\n")
    put("#ifndef _DARWIN_C_SOURCE\n#define _DARWIN_C_SOURCE\n#endif\n")
    put("#include <stdbool.h>\n#include <stdint.h>\n#include <string.h>\n#include <kelvin_prelude.h>\n")
    put_range_types()                                    // (#373)
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
    for i in 0..<decls.count as int64 {                  // no fixed array in a struct or an enum yet (#354)
        let d:int64 = decls[i]
        let made = nodes[d].kind == D_ENUM && nodes[d].t > eof_pos   // an Optional's, a Result's: refused where it is used (#368)
        if nodes[d].kind == D_STRUCT || (nodes[d].kind == D_ENUM && nodes[d].flag == 1 && !made) {
            var f:int64 = nodes[d].a
            while f >= 0 {
                let fy:int64 = nodes[f].ty
                let user_enum = nodes[d].kind == D_ENUM && nodes[d].t < eof_pos   // not an Optional's, a Result's (#360)
                if (nodes[d].kind == D_STRUCT || user_enum) && fy >= 0 && types[fy].kind == Y_FIXED {   // a struct's member (#356), a case's value (#360)
                    if !member_fixed_ok(f, fy, user_enum ? "a case" : "a member") { return }
                } else if fixed_inside(fy) {
                    refuse_fixed(f, fy)
                    return
                }
                f = nodes[f].next
            }
        }
        if nodes[d].kind == D_GLOBAL && fixed_inside(nodes[d].ty) && types[nodes[d].ty].kind != Y_FIXED {   // a global's own is kc's (#359)
            refuse_fixed(d, nodes[d].ty)
            return
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
            if nodes[d].a >= 0 && nodes[nodes[d].a].kind == N_ASYNC {      // as kelvinc's (#313)
                gen_error(nodes[d].a, "'async' starts a call on a thread of its own, in a function: write it in one")
                return
            }
            if nodes[d].ty < 0 { set_ty(d, inferred(d)) }       // (#214)
            if failed { return }
            if types[nodes[d].ty].kind == Y_ARGV && nodes[d].a >= 0 && nodes[nodes[d].a].kind == N_LIST {   // let names:[cstr] = ["a"] (#359)
                set_ty(d, type_of_kind(Y_FIXED, base_type(Y_CSTR), 0 - 1))
            }
            if types[nodes[d].ty].kind == Y_FIXED {      // a global fixed array, as a local's, const of a let (#359)
                fixed_const = nodes[d].flag == 1
                gen_fixed_var(d)
                fixed_const = false
                if failed { return }
                continue
            }
            if nodes[d].a >= 0 && !assigns_as(d, nodes[d].t, nodes[d].ty, nodes[d].c == 1) { return }   // (#233)
            if nodes[d].flag == 1 { put("const ") }
            put_ctype(nodes[d].ty)
            put(" ")
            put_tok(nodes[d].t)
            put(" = ")
            if nodes[d].a >= 0 {
                gen_written(nodes[d].a, nodes[d].ty)    // ${:} (#348)
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
    var k:int64 = 0
    while k < anon_fns.count as int64 && !failed {       // those kc makes of { ... }, which may make more (#324)
        gen_function(anon_fns[k])
        k += 1
    }
    if !failed { put_lazy_bodies() }
    if !failed { put_iter_adapters(false) }
    var body:String = out.copy()
    out = head.copy()
    for i in 0..<arrays.count as int64 { write_type(arrays[i]) }   // the Arrays a $[a, b] in a function makes (#266)
    for i in 0..<dicts.count as int64 { write_type(dicts[i]) }     // and the Dictionaries of ${k: v} (#267)
    for i in 0..<sets.count as int64 { write_type(sets[i]) }       // and the Sets of ${a, b} (#274)
    for i in made..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind == D_ENUM && nodes[d].flag == 1 { write_type(type_of_kind(Y_STRUCT, -1, nodes[d].t)) }
        if nodes[d].kind == D_STRUCT { write_type(type_of_kind(Y_STRUCT, -1, nodes[d].t)) }   // a lazy Sequence's (#324)
    }
    for i in 0..<shown.count as int64 {                 // the printers print needs, after the functions (#229)
        put("static void ")
        put_show_name(shown[i])
        put("(kv_out *, const void *, int);\n")
    }
    for i in 0..<compared.count as int64 {              // and the == of Arrays and Dictionaries (#288)
        if tagged_of(compared[i]) >= 0 {                // an enum with values': an Optional's (#343), a Result's (#344), any (#345)
            put_eq_head(compared[i])
            put(";\n")
        } else {
            put("__attribute__((unused)) static inline bool ")
            put_eq_name(compared[i])
            put("(const ")
            put_owner_prefix(compared[i])
            put(" *a, const ")
            put_owner_prefix(compared[i])
            put(" *b);\n")
        }
    }
    put_async_heads()                                   // async f(x)'s (#313)
    put_lazy_heads()                                    // and the functions kc makes (#324)
    put_iter_adapters(true)                             // and an Iterator's adapters (#326)
    out += &body
    put_async_bodies()
    for i in 0..<shown.count as int64 { gen_show(shown[i]) }
    for i in 0..<compared.count as int64 { gen_eq(compared[i]) }
}
