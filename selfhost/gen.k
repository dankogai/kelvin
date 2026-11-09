// gen.k - the C of the program, for kc (selfhost/kc.k), as kelvinc
// writes it: the same runtime, kelvin_prelude.h and libkelvin, and the
// same names for what it makes, so that the two can be compared.

struct sym {
    t: int64           // the token of its name
    ty: int64
    how: int64         // 0 a var; 1 a let; 2 a parameter; 3 each element in turn; 4 a range's count (#271)
    moved: bool        // an owner moved out, dead until assigned anew (#441)
}

var out:String             // the C
var locals:$[sym]          // the variables in scope, the innermost last
var marks:$[int64]         // where each block's variables begin
var serial:int64           // for the names kc makes
var current:int64          // the function being written
var uses_io:bool           // #import <IO>, whose kOS.h has kv_sys_init
var uses_sys:bool          // SYS.name read, or #import <OS>: main gives kv_sys_init its arguments, as kelvinc's (#302, #463)
var os_imported:bool       // #import <OS> (#463)
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

// whether token t names a type kc makes, an Optional's or a Result's, and
// not one nested in a struct, whose name kc makes too (#389)
let kc_made(t:int64):bool {
    return t > eof_pos && !is_nested(t) && !anon_decls.has(tok_text(t))   // a type with no tag is the program's (#476)
}

// the spelling of the type with no tag d, as kelvinc's: {x: f64, y: f64},
// union{i: i32, f: f32}, enum{none, i: i32} (#476)
let kelvin_type_text(y:int64):String    // a prototype: its members' types are named so
let anon_spelling(d:int64):String {
    var s = nodes[d].kind == D_ENUM ? $"enum{" : nodes[d].flag == 1 ? $"union{" : $"{"
    var m:int64 = nodes[d].a
    while m >= 0 {
        if m != nodes[d].a { s += ", " }
        s += tok_text(nodes[m].t)
        if nodes[m].ty >= 0 {
            s += ": "
            let w:String = kelvin_type_text(nodes[m].ty)
            s += &w
        }
        m = nodes[m].next
    }
    s += "}"
    return s
}

// /* {x: f64, y: f64} */ before the C of a type with no tag named by token
// t, as kelvinc writes it (#476)
let put_spelling(t:int64) {
    let d:int64 = anon_decls.get(tok_text(t), -1)
    if d < 0 { return }
    put("/* ")
    let w:String = anon_spelling(d)
    put(w.cstr)
    put(" */\n")
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
    case Y_BYTES: put("kv_bytes")
    case Y_IO: put("kv_io")
    case Y_TASK: put("kv_task")                    // (#313)
    case Y_ITER: put("kv_iter")                    // (#326)
    case Y_BITS: put("kv_bits")                    // (#455)
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
let put_record_word(y:int64)    // and C's word of a struct, union of a union (#453)
let bit_of_bits(n:int64):bool    // and whether n is a Bits's bit, whose .flip() is the Bits's (#456)
let gen_bit_method(n:int64):bool    // and a bool's flip, an integer's bit and flip (#457)
let gen_int_bit_set(n:int64)

let put_ctype(y:int64) {
    switch types[y].kind {                                       // every kind of type (#210)
    case Y_VOID, Y_C, Y_TYPEOF, Y_PARAM: put("void")
    case Y_FN:                                                   // _kv_fnN, a typedef of the pointer write_type writes (#428)
        put("_kv_fn")
        put_int(y)
    case Y_I64: put("int64_t")
    case Y_I32: put("int32_t")
    case Y_U8: put("uint8_t")
    case Y_U32: put("uint32_t")
    case Y_I8: put("int8_t")
    case Y_I16: put("int16_t")
    case Y_U16: put("uint16_t")
    case Y_U64: put("uint64_t")
    case Y_I128: put("__int128")
    case Y_U128: put("unsigned __int128")
    case Y_F64: put("double")
    case Y_F32: put("float")
    case Y_BOOL: put("bool")
    case Y_CSTR: put("const uint8_t *")
    case Y_STRING: put("kv_string")
    case Y_BYTES: put("kv_bytes")                                // (#439)
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
        if types[y].elem == 0 - 2 || types[y].elem == 0 - 3 || types[y].elem == 0 - 4 {   // a C header's struct tm (#453)
            put(types[y].elem == 0 - 2 ? "struct " : types[y].elem == 0 - 3 ? "union " : "enum ")
        } else if decl_named(types[y].name, D_STRUCT) >= 0 || tagged_of(y) >= 0 {
            put_record_word(y)                                   // an enum with values too (#215), a union (#453)
        } else if decl_named(types[y].name, D_ENUM) >= 0 {
            put("enum ")                                         // (#210)
        }                                                        // else a C header's typedef (#207)
        put_tok(types[y].name)
    case Y_PTR:
        if ptr_const(y) && types[types[y].elem].kind != Y_CSTR { put("const ") }   // const T^ (#272)
        put_ctype(types[y].elem)
        put(ptr_const(y) && types[types[y].elem].kind == Y_CSTR ? " const *" : " *")   // const cstr^, whose text is const already (#470)
        if ptr_restrict(y) { put("restrict") }          // T^ restrict (#393)
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
    let s:sym = {t, y, how, false}
    locals += s
}

let declare(t:int64, y:int64) { declare_as(t, y, 0) }

// a loop's variable: `for _ in` names none, as kelvinc's (#388)
let declare_each(t:int64, y:int64, how:int64) {
    if !tok_is(t, "_") { declare_as(t, y, how) }
}

// the locals an owner moves out of in what is being written, dead when
// its call or its statement ends, as kelvinc marks them after a call's
// arguments: f(t, t) gives t twice, as kelvinc's does (#441)
var moving:$[int64]
var anew:int64 = -1            // the name t of t = v, which may be moved out (#441)

// the innermost local named t, its index in locals, or -1
let local_at(t:int64):int64 {
    var i:int64 = locals.count as int64 - 1
    while i >= 0 {
        if same_text(locals[i].t, t) { return i }
        i -= 1
    }
    return -1
}

// kelvinc's error of a name n read after its owner moved out; whether
// it is one (#441)
let moved_error(n:int64):bool {
    let i:int64 = local_at(nodes[n].t)
    if i < 0 || !locals[i].moved { return false }
    var m = $"'"
    m += tok_text(nodes[n].t)
    m += "' was moved out and holds nothing now: assign it anew before using it"
    gen_error(n, m.cstr)
    return true
}

// an owner named v given by value moves into what, as kelvinc's
// move_argument: a local is dead after it; a global, and each element
// of a for or an if let's value, which another owns, are its errors.
// False where it is an error (#441)
let move_out(v:int64, what:const String^):bool {
    if moved_error(v) { return false }
    let i:int64 = local_at(nodes[v].t)
    var m = $"'"
    m += tok_text(nodes[v].t)
    if i >= 0 && locals[i].how == 3 {
        m += "' is a value its Array, Dictionary, Optional or Result still owns: pass a borrow, '&"
    } else if i < 0 {
        m += "' is a global owner, which cannot move into "
        m += what
        m += ": pass a borrow, '&"
    } else {
        moving += i
        return true
    }
    m += tok_text(nodes[v].t)
    m += "', or a copy"
    gen_error(v, m.cstr)
    return false
}

// an owner named v that return or await moves out, as kelvinc's: a
// local is dead after it; a global stays as kelvinc leaves it; a return
// of each element is its error. False where it is an error (#441)
let move_back(v:int64, returned:bool):bool {
    if moved_error(v) { return false }
    let i:int64 = local_at(nodes[v].t)
    if i >= 0 && locals[i].how == 3 && returned {
        var m = $"'"
        m += tok_text(nodes[v].t)
        m += "' is a value its Array, Dictionary, Optional or Result still owns: return a copy, '"
        m += tok_text(nodes[v].t)
        m += ".copy()'"
        gen_error(v, m.cstr)
        return false
    }
    if i >= 0 { moving += i }
    return true
}

// the moves of what was just written, made (#441)
let moves_done() {
    for k in 0..<moving.count as int64 {
        if moving[k] < locals.count as int64 { locals[moving[k]].moved = true }
    }
    moving.clear()
}

// what an owner moves into, in kelvinc's words: 'f', '.m', case 'c' (#441)
let into_words(lead:cstr, dot:cstr, t:int64):String {
    var s = String(lead)
    s += "'"
    s += dot
    s += tok_text(t)
    s += "'"
    return s
}

let enum_constant_changed(n:int64):bool
let may_change(n:int64):bool    // a prototype: assignments and pop and remove ask it (#271)
let fixed_inside(y:int64):bool    // a prototype: type_of and gen_array ask it of an Array of a fixed array (#355)
let owner_part(v:int64):bool    // a prototype: let, = and return refuse what it says (#365)
let owner_name(v:int64):bool    // and their names and the words said of them (#440)
let owner_assign_error(v:int64)
let fixed_elem_ok(y:int64):bool    // prototypes: a member's fixed array is written by gen_written (#356)
let fixed_list_fits(v:int64, y:int64):bool
let gen_fixed_list(v:int64, y:int64)
let fixed_refused(n:int64)
let counted(y:int64, v:int64):int64    // prototypes: type_of and gen_expr ask them of ([T])[a, b] (#419)
let gen_array_literal(n:int64)
let fixed_computed(y:int64):bool
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
    if e >= 0 && tok_is(nodes[e].t, "enum") { return base_type(Y_I32) }   // of an enum with no name, C's int, as kelvinc's i32 (#451)
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
let resolve_op(n:int64)           // and a + b, a struct's operator, as the call of it (#471)
let is_operator(d:int64):bool     // and whether a function is such an operator
let gen_generic_call(n:int64)     // and a call only C's _Generic chooses for (#41)
let lazy_of(n:int64):int64    // prototypes: a lazy Sequence's (#324)
let lazy_type_of(n:int64):int64
let is_lazy_type(y:int64):bool
let empty_kind(n:int64):int64    // prototypes: x.isEmpty (#435)
let gen_is_empty(n:int64)
let member_unknown(n:int64, y:int64)    // a prototype: kelvinc's error of a member not known (#497)
let bytes_field_type(n:int64):int64    // prototypes: a Bytes's (#439)
let bytes_method_type(n:int64, y:int64):int64
let gen_bytes_make(n:int64)
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
let gen_fill(t:int64, a:int64, b:int64, in_place:bool)    // prototypes: d0 ?? d1, d[k] ??= v (#460)
let gen_fill_assign(n:int64)
let entry_fits(v:int64, dy:int64):bool
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
let enum_int(y:int64):bool
let int_view(y:int64):int64
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

// the type of x, a side of a binary operator, or -1 where it is a case
// word, none, ok(v) or err(e), which has no type to ask until the other
// side gives one (#413): r == err("x")
let side_type(x:int64):int64 {
    return is_case_word(x) ? 0 - 1 : type_of(x)
}

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

var sub_targets:Dictionary<int64, int64>   // the v[i] that read a subscript: nodes now, calls of its getter

// the method or the function of a type that x.m(...) or T.f(...) calls, or -1 (#213)
let method_of(n:int64):int64 {
    let chosen:int64 = sub_targets.get(n, 0 - 1)        // v[i], its subscript (#136)
    if chosen >= 0 { return chosen }
    let a:int64 = nodes[n].a
    if names_type(a) { return method_named(nodes[a].t, nodes[n].t) }
    let y:int64 = type_of(a)
    if y < 0 || types[y].kind != Y_STRUCT { return -1 }
    let f:int64 = method_named(types[y].name, nodes[n].t)
    if f >= 0 && (attributes.get(f, 0) == 3 || subscripts.get(f, 0) != 0) { return -1 }   // called by assigning, or by v[i] (#132, #136)
    return f
}

var attr_settled:Dictionary<int64, bool>   // the x.y and v[i] asked once whether they read an attribute or a subscript

let type_text(y:int64):String    // a prototype: index_fits names the types

// the count of the arguments from a on
let count_args(first:int64):int64 {
    var n:int64 = 0
    var a:int64 = first
    while a >= 0 {
        n += 1
        a = nodes[a].next
    }
    return n
}

// the count of the parameters of d
let count_params(d:int64):int64 {
    return count_args(nodes[d].a)
}

// whether index a fits index type t, as kelvinc's choose_subscript: first
// (strict) a literal as the type it infers to, then as any of its kind
let index_fits(a:int64, t:int64, strict:bool):bool {
    let k:nkind = nodes[a].kind
    let tk:ykind = types[t].kind
    if k == N_STR { return strict ? tk == Y_CSTR : tk == Y_CSTR || tk == Y_STRING }
    if k == N_NUM || (k == N_UNARY && tok_is(nodes[a].t, "-") && nodes[nodes[a].a].kind == N_NUM) {
        let ay:int64 = type_of(a)
        if strict { return ay == t }
        let float_lit = ay >= 0 && (types[ay].kind == Y_F64 || types[ay].kind == Y_F32)
        return float_lit ? tk == Y_F64 || tk == Y_F32 : is_int_kind(tk)
    }
    if k == N_CHAR { return false }
    let ay:int64 = type_of(a)
    if ay < 0 { return false }
    if ay == t { return true }
    let x:String = type_text(ay)
    let y:String = type_text(t)
    return x == y
}

// the subscript of the type named as token recv that v[i] reads, by the
// count of its indices and their types, else kelvinc's error and -1
let choose_subscript(n:int64, recv:int64):int64 {
    let nargs:int64 = count_args(nodes[n].b)
    var fit:$[int64] = $[]
    for d in sub_getters {
        if same_text(nodes[d].c, recv) && count_params(d) == nargs { fit += d }
    }
    if fit.count == 0 {
        var m = $"no subscript of "
        m += tok_text(recv)
        m += " takes "
        m += `${nargs}`
        m += nargs == 1 ? " index" : " indices"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    if fit.count == 1 { return fit[0] }
    var found:int64 = 0 - 1
    var many:int64 = 0
    var strict = true
    while many == 0 {
        for d in fit {
            var same = true
            var a:int64 = nodes[n].b
            var p:int64 = nodes[d].a
            while same && a >= 0 {
                same = index_fits(a, nodes[p].ty, strict)
                a = nodes[a].next
                p = nodes[p].next
            }
            if same {
                found = d
                many += 1
            }
        }
        if !strict { break }
        strict = false
    }
    if many != 1 {
        var m = $"the indices fit "
        m += many > 0 ? "more than one" : "no"
        m += " subscript of "
        m += tok_text(recv)
        m += ": write their types, as in 'v[i as i64]'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    return found
}

// v[i] of a type with a subscript (#136) is the call of its getter, which
// wins over #117's indexing of an enum with values; else as it was
let resolve_subscript(n:int64) {
    if sub_getters.count == 0 || attr_settled.has(n) { return }
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return }                                 // asked again where more is known
    attr_settled[n] = true
    if types[y].kind != Y_STRUCT { return }
    var has = false
    for d in sub_getters {
        if same_text(nodes[d].c, types[y].name) { has = true }
    }
    if !has { return }
    let first:int64 = nodes[n].b
    if first >= 0 && (nodes[first].kind == N_RANGE || (type_of(first) >= 0 && types[type_of(first)].kind == Y_RANGE)) {
        var m = $"a slice is no subscript of "
        m += tok_text(types[y].name)
        m += ": index it with v[i]"
        gen_error(n, m.cstr)
        return
    }
    let f:int64 = choose_subscript(n, types[y].name)
    if f < 0 { return }
    nodes[n].kind = N_METHOD
    nodes[n].flag = 0
    sub_targets[n] = f
}

var attr_reads:Dictionary<int64, bool>     // the x.y that do: nodes now, calls of its getter

// x.y of a computed attribute (#131) is the call of its getter, as a + b
// of an operator is the call of it (#471); else as it was
let resolve_attr(n:int64) {
    if nodes[n].kind == N_INDEX {
        resolve_subscript(n)
        return
    }
    if nodes[n].kind != N_FIELD || attr_settled.has(n) { return }
    let nm:String = tok_text(nodes[n].t)
    if !attribute_names.has(nm) { return }
    let a:int64 = nodes[n].a
    if names_type(a) {                                  // T.x, a type attribute (#133): the global T__x
        attr_settled[n] = true
        var key:String = tok_text(nodes[a].t)
        key += "."
        key += &nm
        let g:int64 = type_attrs.get(key, 0 - 1)
        if g >= 0 {
            var word:String = tok_text(g)
            let u:int64 = made_token(&word)              // T__x, where it is read, for an error's line
            toks[u].line = toks[nodes[n].t].line
            toks[u].file = toks[nodes[n].t].file
            nodes[n].kind = N_ID
            nodes[n].t = u
            nodes[n].a = 0 - 1
        }
        return
    }
    let y:int64 = type_of(a)
    if y < 0 { return }                                 // asked again where more is known
    attr_settled[n] = true
    if types[y].kind != Y_STRUCT { return }
    let f:int64 = method_named(types[y].name, nodes[n].t)
    if f < 0 || attributes.get(f, 0) == 0 { return }
    nodes[n].kind = N_METHOD
    nodes[n].b = 0 - 1
    attr_reads[n] = true
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
    return d >= 0 && nodes[d].c != 1 && kc_made(types[y].name) && tok_is(nodes[nodes[d].a].t, "ok")
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
    if n > 1 && codes[at] == '0' && (codes[at + 1] == 'x' || codes[at + 1] == 'X') {   // 0x1p4, a hex float (#472)
        for i in 0..<n {
            let c:uint32 = codes[at + i]
            if c == 'p' || c == 'P' || c == '.' { return true }
        }
        return false
    }
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

// whether n is x.align (#395), a value's alignment, as kelvinc's: not a
// struct's field of the name, nor a case of an enum
let value_align(n:int64):bool {
    if nodes[n].kind != N_FIELD || !tok_is(nodes[n].t, "align") || tagged_named(nodes[n].a) >= 0 { return false }
    let y:int64 = type_of(nodes[n].a)
    return y >= 0 && !(types[y].kind == Y_STRUCT && (field_type(y, nodes[n].t) >= 0 || tagged_of(y) >= 0))
}

let coalesces_whole(n:int64):bool    // a prototype: x ?? y of the whole x's type (#408, #409)
let type_member(f:int64):bool    // and x.type, which is no value (#422)
let typename_member(f:int64):bool    // and x.typename, its type's name (#426)
let gen_typename(n:int64)    // which gen_field writes (#426)
let function_named(a:int64):bool    // a function's name, whose typename it has (#426)
let told(y:int64):int64    // and an x.type told, $0.type of a function's one expression (#424)
let void_return(a:int64):bool    // and a value returned without a result (#427)
let callee_type(f:int64):int64    // and the function type a call calls through (#428)
let named_fn_type(n:int64):int64    // and a function's name, a value of its type
let anon_type(n:int64):int64    // and an anonymous function's, as a value
let number_text_size(n:int64):int64    // and x.hex's and the rest's text (#447)
let shown_cstr(n:int64):bool          // and v.cstr's of what print shows (#450)
let scalar_cstr(n:int64):bool         // and x.cstr's of a number, a bool, a uchr or a pointer (#462)
let pointer_property(n:int64):int64   // x.size, x.addr, p.next and p.prev (#462)
let os_call(n:int64):bool     // prototypes: OS.name(args) and SYS.name (#463)
let os_type(n:int64):int64
let gen_os(n:int64)
let os_struct(g:const String^):int64
let io_field_type(n:int64):int64      // prototypes: an IO's members (#464)
let io_method_type(n:int64):int64
let gen_io_field(n:int64, a:int64)
let gen_io_method(n:int64, a:int64)
let gen_string_method(n:int64, a:int64, y:int64)
let owner_copy_error(v:int64, what:cstr)
let std_io(n:int64):int64             // and IO.stdout's (#452)
let pretty_value(n:int64):bool        // and v.pretty's (#452)
let io_int_member(t:int64):bool       // and an IO's int members (#452)
let number_text_refused(n:int64, k:ykind):bool
let fn_named(t:int64):int64    // and the function a name names
let gen_fn_value(n:int64, y:int64)    // and a function where one of type y goes
let gen_fn_call(n:int64, fy:int64)    // and a call through a function value
let member_fn_type(n:int64):int64    // and s.f(x) of a member f of a function type
let converter_of(n:int64):int64    // and T(v), a converter's type (#429)
let uchr_call(n:int64):bool    // and uchr(x), a codepoint (#478)
let uchr_typed(n:int64):bool    // and c == d of a uchr (#478)
let gen_uchr_compare(n:int64)
let is_number_kind(k:ykind):bool    // and .utf32 of a number (#478)

// whether the literal t, of decimal digits, is above an i64's largest (#472)
let above_i64(t:int64):bool {
    let at:int64 = toks[t].at
    let n:int64 = toks[t].len
    if n < 19 || codes[at] == '0' { return false }
    let most:cstr := "9223372036854775807"
    var over = n > 19
    var told = false
    for i in 0..<n {
        let c:uint32 = codes[at + i]
        if c < '0' || c > '9' { return false }
        if n == 19 && !told && c != most[i] as uint32 {
            told = true
            over = c > most[i] as uint32
        }
    }
    return over
}

// y as C promotes it: an integer narrower than an int is an int (#472)
let promoted_int(y:int64):int64 {
    if y < 0 { return y }
    let k:ykind = types[y].kind
    return k == Y_I8 || k == Y_U8 || k == Y_I16 || k == Y_U16 ? base_type(Y_I32) : y
}

// of two integers promoted, C's usual conversion: the wider, of two as
// wide the unsigned
let usual_int(a:int64, b:int64):int64 {
    let ak:ykind = types[a].kind
    let bk:ykind = types[b].kind
    if ak == Y_U128 || bk == Y_U128 { return base_type(Y_U128) }
    if ak == Y_I128 || bk == Y_I128 { return base_type(Y_I128) }
    if ak == Y_U64 || bk == Y_U64 { return base_type(Y_U64) }
    if ak == Y_I64 || bk == Y_I64 { return base_type(Y_I64) }
    if ak == Y_U32 || bk == Y_U32 { return base_type(Y_U32) }
    return base_type(Y_I32)
}

// a op b's type, of numbers as kelvinc has it (#472): C's, an integer
// literal taking the other's type and a floating one being an f64; else a's
let arith_type(n:int64):int64 {
    let a:int64 = nodes[n].a
    let b:int64 = nodes[n].b
    let ya:int64 = type_of(a)
    let yb:int64 = type_of(b)
    if ya < 0 || yb < 0 { return ya }
    let ak:ykind = types[ya].kind
    let bk:ykind = types[yb].kind
    let af = ak == Y_F64 || ak == Y_F32
    let bf = bk == Y_F64 || bk == Y_F32
    if !(is_int_kind(ak) || af) || !(is_int_kind(bk) || bf) { return ya }
    if af || bf { return ak == Y_F64 || bk == Y_F64 ? base_type(Y_F64) : base_type(Y_F32) }
    let t:int64 = nodes[n].t
    if tok_is(t, "<<") || tok_is(t, ">>") { return promoted_int(ya) }
    let la = nodes[a].kind == N_NUM || nodes[a].kind == N_CHAR
    let lb = nodes[b].kind == N_NUM || nodes[b].kind == N_CHAR
    if la && lb { return ya }
    if la { return promoted_int(yb) }
    if lb { return promoted_int(ya) }
    return usual_int(promoted_int(ya), promoted_int(yb))
}

let type_of(n:int64):int64 {
    resolve_op(n)                                        // a + b, a struct's operator, is the call of it (#471)
    resolve_attr(n)                                      // x.y, an attribute, of its getter (#131)
    let k:nkind = nodes[n].kind
    if k == N_CHAIN { return chain_type(n) }
    if os_call(n) { return os_type(n) }                  // OS.cwd, OS.name(args), SYS.argv (#463)
    if (k == N_ID || k == N_CALL) && nodes[n].ty >= 0 && is_case_word(n) { return nodes[n].ty }   // Result<T, E>.err(e) (#449)
    if k == N_TRY {                                      // try r, r's ok, some's (#449)
        let ry:int64 = type_of(nodes[n].a)
        return ry >= 0 ? wrap_type(ry) : 0 - 1
    }
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
    if k == N_TPL { return base_type(nodes[n].flag == 1 ? Y_STRING : Y_CSTR) }   // `a${x}b`, $`a${x}b` a String (#445)
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
        if y < 0 && fn_named(t) >= 0 { return named_fn_type(n) }   // a function's name, a value of its type (#428)
        if y < 0 && (tok_is(t, "OS") || tok_is(t, "SYS")) { return -1 }   // of OS.name, whose type os_type tells (#463)
        if y < 0 && c_headers { return base_type(Y_C) }      // a C header's (#207)
        if y < 0 { gen_error(n, "this name is not known") }
        return y
    }
    if k == N_CALL {
        let f:int64 = nodes[n].a
        if nodes[f].kind == N_TYPE {
            if tok_is(nodes[f].t, "IO") { return base_type(Y_IO) }
            if tok_is(nodes[f].t, "Bits") { return base_type(Y_BITS) }      // Bits(n) (#387)
            if tok_is(nodes[f].t, "Bytes") { return base_type(Y_BYTES) }    // Bytes(x) (#439)
            return base_type(Y_STRING)
        }
        let cy:int64 = converter_of(n)                   // int64(v), int64(text, base) (#429)
        if cy >= 0 { return cy }
        if uchr_call(n) { return base_type(Y_UCHR) }     // uchr(x) (#478)
        let fy:int64 = callee_type(f)                    // through a function value (#428)
        if fy >= 0 { return types[fy].elem >= 0 ? types[fy].elem : base_type(Y_VOID) }
        if failed { return 0 - 1 }
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
    if k == N_ANON { return nodes[n].flag != 0 ? 0 - 1 : anon_type(n) }   // a value of its function type (#428); of $0, as where it goes
    if k == N_ITER { return iter_type_of(n) }           // Iterator(state) { ... } (#326)
    if k == N_LIST && nodes[n].flag == 0 && nodes[n].ty >= 0 { return counted(nodes[n].ty, n) }   // ([T])[a, b] (#419)
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
        let e:int64 = nodes[nodes[n].b].kind == N_CHAR ? base_type(Y_U8) : type_of(nodes[n].b)   // Array(['a', 'b']) of u8, as kelvinc's (#451)
        if e < 0 { return -1 }
        return type_of_kind(Y_ARRAY, e, -1)
    }
    if k == N_MAKE { return nodes[n].ty }               // Array<T>(), Dictionary<K, V>() (#349)
    if k == N_METHOD {                                  // s.f(x) through a member of a function type (#428)
        let my:int64 = member_fn_type(n)
        if my >= 0 { return types[my].elem >= 0 ? types[my].elem : base_type(Y_VOID) }
    }
    if k == N_METHOD && tok_is(t, "next") {             // it.next() of an Iterator: a T? (#326)
        let iy:int64 = type_of(nodes[n].a)
        if iy >= 0 && types[iy].kind == Y_ITER { return optional_of(types[iy].elem) }
    }
    if k == N_ALIGN { return base_type(Y_I64) }         // alignof(T) (#395)
    if k == N_SIZEOF { return base_type(Y_I64) }        // sizeof(T), sizeof x (#420)
    if k == N_FIELD && type_member(n) {                 // as kelvinc says it (#422)
        gen_error(n, "'.type' is a type, not a value: use it where a type goes, as in 'var w:v.type' or 'x as v.type'")
        return -1
    }
    if k == N_FIELD && typename_member(n) { return base_type(Y_CSTR) }   // x.typename, its type's name (#426)
    if k == N_INIT && nodes[n].ty >= 0 { return nodes[n].ty }   // (T){a, b} (#418)
    if k == N_FIELD && value_align(n) { return base_type(Y_I64) }      // x.align (#395)
    if k == N_FIELD && tok_is(t, "lazy") {             // s.lazy, before its map or filter (#324)
        let ly = lazy_field_type(n)
        if ly != 0 - 2 { return ly }
    }
    if k == N_FIELD {
        if std_io(n) >= 0 { return base_type(Y_IO) }                     // IO.stdout and the rest (#452)
        let e = tagged_named(nodes[n].a)
        if e >= 0 { return type_of_kind(Y_STRUCT, -1, nodes[e].t) }      // T.none (#215)
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        if shown_cstr(n) { return base_type(Y_CSTR) }                   // its text, as print shows it (#450)
        if scalar_cstr(n) { return base_type(Y_CSTR) }                  // a number's text and the rest (#462)
        if tok_is(t, "cstr") && (types[y].kind == Y_FN || types[y].kind == Y_FIXED) {   // as kelvinc says it (#462)
            gen_error(n, types[y].kind == Y_FN ? "'.cstr' of a function: a function has no text" : "'.cstr' of an array: C arrays are not values; index it, or put it in a struct")
            return -1
        }
        let pp:int64 = pointer_property(n)
        if pp == 1 { return base_type(Y_U64) }                          // x.size, sizeof x, C's size (#462, #472)
        if pp == 2 { return base_type(Y_C) }                            // p.addr, a uintptr_t
        if pp == 3 { return y }                                         // p.next, p.prev, of its type
        if pp < 0 { return -1 }
        if pretty_value(n) { return base_type(Y_STRING) }               // its text indented, a new String (#336, #337, #452)
        if types[y].kind == Y_IO && tok_is(t, "lines") {               // as kelvinc's #406, read by for alone
            gen_error(n, "kc reads an IO's lines by for, 'for r in f.lines', each a Result<String, i64>; not yet as a value")
            return -1
        }
        let d = tagged_of(y)
        if d >= 0 && tok_is(t, "case") { return base_type(Y_U8) }        // v.case, its tag, a u8 as kelvinc's (#477)
        if d >= 0 {                                                      // v.c, the case's value
            if let some(m) = case_named(d, t) {
                if nodes[m].ty >= 0 { return nodes[m].ty }
            }
            gen_error(n, "this is no case of a value of this enum")
            return -1
        }
        let yk:ykind = types[y].kind
        if yk == Y_BITS && (tok_is(t, "count") || tok_is(t, "capacity")) { return base_type(Y_I64) }   // in bits, an i64 as kc's counts are (#456)
        if yk == Y_BITS && tok_is(t, "isEmpty") { return base_type(Y_BOOL) }
        if yk == Y_BITS && tok_is(t, "bin") { return type_of_kind(Y_ARRAY, base_type(Y_STRING), -1) }   // each u64's "0b..." (#456)
        if yk == Y_BITS && tok_is(t, "u64s") { return type_of_kind(Y_ARRAY, base_type(Y_U64), -1) }     // its u64s, a new Array (#472)
        if yk == Y_BITS {
            var m = $"a Bits has count, capacity, isEmpty, u64s, bin, append, flip, copy, cstr, size, type and typename, and '."
            m += tok_text(t)
            m += "' is none of them: a bit is 'bv[n]'"
            if tok_is(t, "value") { m = $"a Bits holds u64s, '.u64s', and grows past 64 bits (#455): '.value' is gone" }
            gen_error(n, m.cstr)
            return -1
        }
        if tok_is(t, "sign") && (yk == Y_F64 || yk == Y_F32) { return optional_of(base_type(Y_BOOL)) }   // a floating-point x.sign, a bool? (#383)
        if (tok_is(t, "exponent") || tok_is(t, "significand")) && (yk == Y_F64 || yk == Y_F32) { return base_type(Y_I64) }   // its fields (#383)
        if (tok_is(t, "abs") || tok_is(t, "sign")) && (is_signed_kind(yk) || yk == Y_F64 || yk == Y_F32 || enum_int(y)) { return int_view(y) }   // x.abs, x.sign, of its type (#381, #382), an enum's an i32 (#469)
        if (tok_is(t, "isNaN") || tok_is(t, "isInfinite") || tok_is(t, "isFinite")) && (yk == Y_F64 || yk == Y_F32) { return base_type(Y_BOOL) }   // x.isNaN (#382), x.isInfinite, x.isFinite (#384)
        if tok_is(t, "isEmpty") && empty_kind(n) != 0 {  // x.isEmpty (#435), a bool, or kelvinc's error
            if empty_kind(n) > 0 { return base_type(Y_BOOL) }
            gen_is_empty(n)
            return -1
        }
        if yk == Y_BYTES { return bytes_field_type(n) }                 // b.count and the rest (#439)
        if yk == Y_RANGE && tok_is(t, "count") { return base_type(Y_U64) }   // r.count, a u64, as kelvinc's (#374, #472)
        if yk == Y_RANGE && (tok_is(t, "lowerBound") || tok_is(t, "upperBound")) { return types[y].elem }   // its bounds, of T (#375)
        if yk == Y_RANGE {                                               // as kelvinc's (#373)
            range_member_error(n)
            return -1
        }
        if tok_is(t, "count") && (yk == Y_STRING || yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET) { return base_type(Y_I64) }
        if (tok_is(t, "count") || tok_is(t, "size")) && yk == Y_FIXED { return base_type(Y_I64) }   // (#354)
        if (tok_is(t, "count") || tok_is(t, "size")) && yk == Y_PTR && types[types[y].elem].kind == Y_FIXED { return base_type(Y_I64) }   // gen_field's error (#362)
        if yk == Y_ARRAY && (tok_is(t, "join") || tok_is(t, "joined")) {   // as kelvinc says it (#461)
            var m = $"'."
            m += tok_text(t)
            m += "' is a method, which makes a String: call it, as in '."
            m += tok_text(t)
            m += "(\", \")', or '."
            m += tok_text(t)
            m += "()' with nothing between"
            gen_error(n, m.cstr)
            return -1
        }
        if yk == Y_SET && tok_is(t, "elements") { return type_of_kind(Y_ARRAY, types[y].elem, -1) }   // an Array of copies (#278)
        if yk == Y_DICT && tok_is(t, "keys") { return type_of_kind(Y_ARRAY, types[y].name, -1) }      // (#285)
        if yk == Y_DICT && tok_is(t, "values") { return type_of_kind(Y_ARRAY, types[y].elem, -1) }
        if yk == Y_IO && tok_is(t, "string") { return result_of(base_type(Y_STRING), base_type(Y_I64)) }   // or where its UTF-8 breaks (#406)
        if yk == Y_IO && io_int_member(t) { return base_type(Y_I32) }   // where kc had read any member as the status (#452)
        if yk == Y_IO { return io_field_type(n) }                       // f.bytes, f.stat and the rest (#464)
        if yk == Y_STRING && tok_is(t, "bytes") { return type_of_kind(Y_PTR, base_type(Y_BYTES), 1) }   // its own bytes, a const Bytes^ (#464)
        if yk == Y_STRING && tok_is(t, "cstr") { return base_type(Y_CSTR) }
        if yk == Y_CSTR && tok_is(t, "count") { return base_type(Y_I64) }   // its strlen, an i64 as kc's counts are (#447)
        if number_text_size(n) > 0 && (yk != Y_STRUCT || enum_int(y)) && yk != Y_C {    // x.hex and the rest, text (#447), an enum's value's too (#469)
            if number_text_refused(n, types[int_view(y)].kind) { return -1 }
            return base_type(Y_CSTR)
        }
        if tok_is(t, "uchr") && (yk == Y_F64 || yk == Y_F32 || yk == Y_BOOL || yk == Y_STRING || yk == Y_CSTR || yk == Y_UCHR) {   // as kelvinc says it (#478)
            var m = $"'.uchr' converts an integer to a codepoint, and this is "
            let w:String = kelvin_type_text(y)
            m += &w
            gen_error(n, m.cstr)
            return -1
        }
        if tok_is(t, "uchr") { return base_type(Y_UCHR) }
        if (tok_is(t, "utf32") || tok_is(t, "codepoint")) && is_number_kind(yk) {   // as kelvinc says it (#478)
            var m = $"'."
            m += tok_text(t)
            m += "' is a uchr's codepoint, and this is a number, one already: '.uchr' makes a uchr of an integer (#297)"
            gen_error(n, m.cstr)
            return -1
        }
        if tok_is(t, "utf32") || (yk == Y_UCHR && tok_is(t, "codepoint")) { return base_type(Y_U32) }   // c.codepoint too (#478)
        if tok_is(t, "isNull") && (yk == Y_PTR || yk == Y_FN || yk == Y_CSTR) { return base_type(Y_BOOL) }   // p == nowhere (#460), as kelvinc's #50
        if tok_is(t, "isNull") && yk == Y_FIXED {
            gen_error(n, "'.isNull' of an array: an array is never null; '&a[0]' is a pointer")
            return -1
        }
        if tok_is(t, "isNull") && yk != Y_STRUCT && yk != Y_C {
            var m = $"'.isNull' is a property of pointers and functions, and this is "
            let w:String = kelvin_type_text(y)
            m += &w
            gen_error(n, m.cstr)
            return -1
        }
        if yk == Y_STRUCT && !enum_int(y) && decl_named(types[y].name, D_STRUCT) >= 0 {
            let fy:int64 = field_type(y, t)
            if fy < 0 { member_unknown(n, y) }               // kelvinc's words, where C's error came (#497)
            return fy
        }
        if enum_int(y) {                                     // a plain enum's value has no members (#497)
            member_unknown(n, y)
            return -1
        }
        if yk == Y_STRUCT || yk == Y_C { return base_type(Y_C) }      // of what only C sees (#207)
        if yk == Y_FIXED && tok_is(t, "pretty") {                   // kelvinc's #481
            gen_error(n, "kc reads '.pretty' of a struct, an enum with values, an Array, a Dictionary, a Set or a Range; not yet of a fixed array: print it, println(a)")
            return -1
        }
        member_unknown(n, y)
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
        if nodes[nodes[n].a].kind == N_TYPE && tok_is(t, "pipe") {           // IO.pipe(), {reader: IO, writer: IO} straight (#464)
            let g = $"pipe"
            return os_struct(&g)
        }
        if nodes[nodes[n].a].kind == N_TYPE { return base_type(Y_IO) }       // IO.exec(args, mode)
        let f:int64 = method_of(n)
        if f >= 0 { return nodes[f].ty }                                     // (#213)
        let e = tagged_named(nodes[n].a)
        if e >= 0 { return type_of_kind(Y_STRUCT, -1, nodes[e].t) }      // T.c(v) (#215)
        if tok_is(t, "is") { return base_type(Y_BOOL) }
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        if types[y].kind == Y_ARRAY && (tok_is(t, "join") || tok_is(t, "joined")) { return base_type(Y_STRING) }   // xs.join(sep) (#461)
        if types[y].kind == Y_ARRAY && (tok_is(t, "sort") || tok_is(t, "reverse")) { return base_type(Y_VOID) }   // in place (#470)
        if types[y].kind == Y_ARRAY && (tok_is(t, "sorted") || tok_is(t, "reversed")) { return y }   // a new Array (#470)
        if types[y].kind == Y_RANGE && tok_is(t, "contains") { return base_type(Y_BOOL) }   // r.contains(x) (#374)
        if types[y].kind == Y_RANGE && tok_is(t, "reversed") { return type_of_kind(Y_ITER, types[y].elem, -1) }   // r.reversed(), down (#378)
        if types[y].kind == Y_RANGE && tok_is(t, "stride") { return type_of_kind(Y_ITER, types[y].elem, -1) }     // r.stride(n) (#379)
        if tok_is(t, "pow") && power_int(y) { return pow_method_type(n) }   // b.pow(e), b.pow(e, m) (#380)
        if types[y].kind == Y_BITS && (tok_is(t, "flip") || tok_is(t, "append") || tok_is(t, "capacity")) { return base_type(Y_VOID) }   // bv.flip(n) (#387), bv.append(x), bv.capacity(n) (#456)
        if types[y].kind == Y_BITS && tok_is(t, "copy") { return y }
        if types[y].kind == Y_BITS {
            var m = $"a Bits has count, capacity, isEmpty, u64s, bin, append, flip, copy, cstr, size, type and typename, and '."
            m += tok_text(t)
            m += "()' is none of them: a bit is 'bv[n]'"
            gen_error(n, m.cstr)
            return -1
        }
        if tok_is(t, "flip") && bit_of_bits(nodes[n].a) { return base_type(Y_VOID) }   // bv[n].flip(), bv.flip(n) (#456)
        if tok_is(t, "flip") && (types[y].kind == Y_BOOL || power_int(y)) { return base_type(Y_VOID) }   // b.flip(), x.flip(n) (#457)
        if tok_is(t, "bit") && power_int(y) { return base_type(Y_BOOL) }   // x.bit(n), a bool (#457)
        if types[y].kind == Y_RANGE {                                    // as kelvinc's (#373)
            range_member_error(n)
            return -1
        }
        if types[y].kind == Y_BYTES { return bytes_method_type(n, y) }   // b.append(x) and the rest (#439)
        if tok_is(t, "copy") { return y }
        if tok_is(t, "pop") || tok_is(t, "get") { return types[y].elem }
        if tok_is(t, "has") { return base_type(Y_BOOL) }
        if tok_is(t, "remove") && types[y].kind == Y_DICT { return base_type(Y_BOOL) }   // true if it was there (#270)
        if tok_is(t, "find") && types[y].kind == Y_DICT {   // a V^ to the value, or nowhere; a const V^ of a let (#337)
            let r:int64 = changed_root(nodes[n].a)
            let fixed = r >= 0 && how_declared(nodes[r].t) != 0
            return type_of_kind(Y_PTR, types[y].elem, fixed ? 1 : 0 - 1)
        }
        if (tok_is(t, "remove") || tok_is(t, "insert")) && types[y].kind == Y_SET { return base_type(Y_BOOL) }   // (#274)
        if (tok_is(t, "union") || tok_is(t, "intersection") || tok_is(t, "difference")) && types[y].kind == Y_SET { return y }   // a new Set (#275)
        if (tok_is(t, "escape") || tok_is(t, "unescape")) && types[y].kind == Y_STRING { return y }   // a new String (#300)
        if types[y].kind == Y_STRING && tok_is(t, "find") { return base_type(Y_I64) }   // where, or -1 (#464)
        if types[y].kind == Y_STRING && (tok_is(t, "has") || tok_is(t, "starts") || tok_is(t, "ends")) { return base_type(Y_BOOL) }
        if types[y].kind == Y_STRING && tok_is(t, "trim") { return y }                 // a new String
        if types[y].kind == Y_IO { return io_method_type(n) }                          // f.glob(p), f.chmod(m)... (#464)
        return base_type(Y_VOID)
    }
    if k == N_INDEX {
        let y:int64 = type_of(nodes[n].a)
        if y < 0 { return -1 }
        let yk:ykind = types[y].kind
        let iy:int64 = nodes[n].b >= 0 ? type_of(nodes[n].b) : 0 - 1
        if iy >= 0 && types[iy].kind == Y_RANGE {                    // xs[r], a slice, a new one (#377)
            if yk == Y_BYTES {                                       // not yet kc's (#439)
                gen_error(n, "kc reads no slice of a Bytes yet: index its bytes, b[i]")
                return -1
            }
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
        if tok_is(t, "!") || tok_is(t, "!!") { return base_type(Y_BOOL) }   // !!n too, a bit's bool (#387)
        return promoted_int(type_of(nodes[n].a))         // -x, ~x of a small one, C's int (#472)
    }
    if k == N_BIN {
        if is_comparison(t) { return base_type(Y_BOOL) }
        if tok_is(t, "??") {                                            // (#217), a Result's ok (#407)
            let ly = type_of(nodes[n].a)
            if ly >= 0 && types[ly].kind == Y_DICT { return ly }       // d0 ?? d1, a new Dictionary (#460)
            if coalesces_whole(n) { return ly }                         // r ?? r2, a Result (#408); a ?? b, an Optional (#409)
            return wrap_type(ly)
        }
        if is_string_plus(n) { return base_type(Y_STRING) }            // s + t, a new String (#284)
        if uchr_typed(nodes[n].a) || uchr_typed(nodes[n].b) {          // as kelvinc says it (#478)
            var m = $"a uchr has no operator '"
            m += tok_text(t)
            m += "': its codepoint is 'c.utf32', a u32"
            gen_error(n, m.cstr)
            return -1
        }
        if tok_is(t, "**") { return power_type(nodes[n].a, nodes[n].b) }   // b ** e (#380)
        return arith_type(n)
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

// the kind of a built-in owner y is, a String, a Bytes (#439), an Array,
// a Dictionary, a Set or an IO, else Y_VOID
let builtin_kind(y:int64):ykind {
    if y < 0 { return Y_VOID }
    let k = types[y].kind
    if k == Y_STRING || k == Y_BYTES || k == Y_ARRAY || k == Y_DICT || k == Y_SET || k == Y_IO { return k }
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
let gen_assert(n:int64)    // a prototype: a block's static_assert asks it (#394)
let declaration_shaped(e:int64):bool    // a prototype: a statement asks it (#402)

let gen_value(n:int64, y:int64)
let case_value_fits(v:int64, m:int64, whole:int64):bool    // a prototype: T.c(v) and == ask it (#413)
let bare_init(n:int64):bool    // a prototype: T.c({a, b}) asks it (#477)

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
    if at < 0 || t < 0 || types[at].kind != Y_PTR || !ptr_const(at) || types[t].kind != Y_PTR || ptr_const(t) {
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
    let let_s = types[ay].name == 0 - 4 || types[ay].konst == 1 || (r >= 0 && how_declared(nodes[r].t) != 0)
    if !let_s { return true }
    var m = who^.copy()
    m += " is "
    m += article_of(&pw)
    m += " "
    m += &pw
    m += ", which may change its elements, and this is "
    let aw:String = type_text(ay)
    m += &aw
    m += types[ay].name == 0 - 4 ? ", which reads them alone: write [const T] in the type taken" : types[ay].konst == 1 ? ", whose elements are const: write [const T] in the type taken" : ", a let's: write [const T] in the type taken, or pass a var's"
    gen_error(a, m.cstr)
    return false
}

// whether a goes where py, a [T](N)^, goes: a pointer to an array of its
// elements and count, nowhere, where kelvinc's C warns; not a let's where
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
    if ptr_const(ay) && !ptr_const(py) {
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
        let what = into_words("", nodes[d].c >= 0 && nodes[d].flag != 1 ? "." : "", nodes[d].t)
        if !move_out(a, &what) { return false }          // dead after the call, as kelvinc's (#441)
        put_owner_prefix(nodes[p].ty)
        put("_take(&")
        put_tok(nodes[a].t)
        put(")")
        return true
    }
    if is_owner(nodes[p].ty) && is_place(a) {
        var m = $"an owner moves into "                  // as kelvinc says it (#471)
        let what = into_words("", nodes[d].c >= 0 && nodes[d].flag != 1 ? "." : "", nodes[d].t)
        m += &what
        m += " only as a whole variable: pass a borrow, '&...', or a copy"
        gen_error(a, m.cstr)
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
// n, an N_FIELD of the type y whose member kc does not know: kelvinc's
// error (#497), a built-in type's documents named, its runtime field's
// spelling, a pointer's 'p^.x', a struct's fields; else kc's own words
let member_unknown(n:int64, y:int64) {
    let t:int64 = nodes[n].t
    let k = types[y].kind
    var m = $"'."
    if k == Y_PTR && types[y].elem >= 0 {
        let ek = types[types[y].elem].kind
        if ek == Y_STRUCT || ek == Y_C || ek == Y_STRING || ek == Y_BYTES || ek == Y_ARRAY || ek == Y_DICT || ek == Y_SET || ek == Y_IO || ek == Y_UCHR || ek == Y_BITS {
            let w:String = kelvin_type_text(y)
            m += tok_text(t)
            m += "' of "
            m += &w
            m += ", a pointer: its member is '"
            let a:int64 = nodes[n].a
            if nodes[a].kind == N_ID { m += tok_text(nodes[a].t) } else { m += "p" }
            m += "^."
            m += tok_text(t)
            m += "'"
            gen_error(n, m.cstr)
            return
        }
    }
    let kind = k == Y_STRING ? $"a String" : k == Y_BYTES ? $"a Bytes" : k == Y_ARRAY ? $"an Array" : k == Y_DICT ? $"a Dictionary" : k == Y_SET ? $"a Set" : k == Y_UCHR ? $"a uchr" : k == Y_IO ? $"an IO" : $""
    if kind.count > 0 {
        let runtime:bool = tok_is(t, "cap") || tok_is(t, "cp") || tok_is(t, "b") || tok_is(t, "len") || tok_is(t, "head") || tok_is(t, "hcap") || tok_is(t, "fp") || tok_is(t, "kind") || tok_is(t, "named")
        if runtime {
            m += tok_text(t)
            m += "' is the runtime's C field of "
            m += &kind
            m += ", no member of Kelvin's"
            if tok_is(t, "cap") && (k == Y_BYTES || k == Y_ARRAY) { m += ": its spelling is '.capacity'" }
            if tok_is(t, "cp") && k == Y_UCHR { m += ": its spelling is '.utf32'" }
            if tok_is(t, "b") && k == Y_STRING { m += ": its spelling is '.bytes'" }
            gen_error(n, m.cstr)
            return
        }
        var e = kind.copy()
        e += " has no member '"
        e += tok_text(t)
        e += "': see its properties and methods in documents/"
        e += k == Y_STRING || k == Y_UCHR ? "strings.md" : k == Y_BYTES ? "bytes.md" : k == Y_ARRAY ? "arrays.md" : k == Y_IO ? "io.md" : k == Y_SET ? "sets.md" : "dictionaries.md"
        gen_error(n, e.cstr)
        return
    }
    let sd:int64 = k == Y_STRUCT && !enum_int(y) ? decl_named(types[y].name, D_STRUCT) : 0 - 1
    if sd >= 0 {
        var e = tok_text(types[y].name)
        e += " has no member '"
        e += tok_text(t)
        var f:int64 = nodes[sd].a
        if f < 0 {
            e += "': it has no fields"
        } else {
            e += nodes[f].next >= 0 ? "': its fields are " : "': its field is "
        }
        while f >= 0 {
            e += tok_text(nodes[f].t)
            let g:int64 = nodes[f].next
            if g >= 0 { e += nodes[g].next >= 0 ? ", " : " and " }
            f = g
        }
        gen_error(n, e.cstr)
        return
    }
    if is_number_kind(k) || k == Y_BOOL || k == Y_CSTR || k == Y_FIXED || k == Y_PTR || enum_int(y) {
        var e = kelvin_type_text(y)
        e += " has no member '"
        e += tok_text(t)
        e += "'"
        gen_error(n, e.cstr)
        return
    }
    gen_error(n, "this member is not known")
}

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
        return var_type(nodes[f].t) < 0 && decl_named(nodes[f].t, D_FN) < 0 && converter_of(n) < 0 && !uchr_call(n)   // int64(x), uchr(x) are no case (#479)
    }
    return false
}

// ---------- temporaries (#227) ----------

var held:Dictionary<int64, int64>    // an expression held in a temporary, by its node: the temporary's number

// whether n gives an owner that no variable holds: a call's, a String
// literal's, a member of one, which reading it holds in a temporary
let needs_hold(n:int64):bool {
    if n < 0 || is_case_word(n) || is_place(n) || std_io(n) >= 0 { return false }   // IO.stdout is never freed, as kelvinc's (#452)
    return is_owner(type_of(n))
}

// ({ T _kv_tmpN = n; ... : n held where it is read, freed once the
// expression is done, as kelvinc holds it; gen_expr of n names it
let hold_decl(n:int64)    // a prototype: hold_open writes n held by it (#445)

let hold_open(n:int64) {
    put("({ ")
    hold_decl(n)
}

// T _kv_tmpN = n; with its cleanup, which gen_expr of n names (#445)
let hold_decl(n:int64) {
    serial += 1
    let s = serial                                   // its own: n may hold temporaries too
    let y = type_of(n)
    put("__attribute__((cleanup(")
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
    case Y_I8: return $"i8"
    case Y_I16: return $"i16"
    case Y_U16: return $"u16"
    case Y_U64: return $"u64"
    case Y_I128: return $"i128"
    case Y_U128: return $"u128"
    case Y_F64: return $"f64"
    case Y_F32: return $"f32"
    case Y_BOOL: return $"bool"
    case Y_CSTR: return $"cstr"
    case Y_STRING: return $"String"
    case Y_BYTES: return $"Bytes"
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
        if d >= 0 && kc_made(types[y].name) {          // a Result, made by kc
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

// whether y is a value a Kelvin struct's operators take: a struct or a
// union of the program's, an enum with values
let op_record(y:int64):bool {
    return y >= 0 && types[y].kind == Y_STRUCT && (decl_named(types[y].name, D_STRUCT) >= 0 || tagged_of(y) >= 0)
}

// an operator takes one value or two, one of them a Kelvin struct's or
// union's, and gives a value, else kelvinc's error (#42)
let operator_fits(d:int64):bool {
    let t:int64 = nodes[d].t
    let minus = tok_is(t, "-")
    var count = 0
    var record = false
    var p:int64 = nodes[d].a
    while p >= 0 {
        count += 1
        if op_record(nodes[p].ty) { record = true }
        p = nodes[p].next
    }
    var variadic = false
    for v in variadic_fns {
        if v == d { variadic = true }
    }
    if (count != 2 && !(count == 1 && minus)) || variadic {
        var m = $"operator "
        m += tok_text(t)
        m += minus ? " takes one or two values" : " takes two values"
        gen_error(d, m.cstr)
        return false
    }
    if !record {
        gen_error(d, "an operator is for a Kelvin struct or union: at least one of its values must be one")
        return false
    }
    if nodes[d].ty < 0 || types[nodes[d].ty].kind == Y_VOID {
        var m = $"operator "
        m += tok_text(t)
        m += " has no result: write its type, as in 'let "
        m += tok_text(t)
        m += "(...):T'"
        gen_error(d, m.cstr)
        return false
    }
    return true
}

// the signatures of each name: a prototype and its definition are one
// a C name of its own for each subscript of a type that has several, as
// kelvinc's: T__subscript__i64__i64
let name_subscripts(list:const $[int64]^) {
    for i in 0..<list^.count as int64 {
        let d:int64 = list^[i]
        var many = false
        for j in 0..<list^.count as int64 {
            if j != i && same_text(nodes[list^[j]].c, nodes[d].c) { many = true }
        }
        if many {
            var word:String = tok_text(nodes[d].t)
            var key:String = params_key(d)
            word += &key
            let t:int64 = made_token(&word)
            toks[t].line = toks[nodes[d].t].line
            toks[t].file = toks[nodes[d].t].file
            nodes[d].t = t
        }
    }
}

let count_overloads() {
    name_subscripts(&sub_getters)
    name_subscripts(&sub_setters)
    for i in 0..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind != D_FN || nodes[d].c >= 0 { continue }
        if is_operator(d) && !operator_fits(d) { return }
        var key = sig_key(d)
        if !fn_sigs.has(key) {
            fn_sigs[key] = d
            var name = tok_text(nodes[d].t)
            fn_overloads[name] = fn_overloads.get(name, 0) + 1
        }
        if nodes[d].b >= 0 { fn_bodies[key] = 1 }
    }
    for d in variadic_fns {                              // kc's error: kelvinc tells them apart by _Generic (#453)
        if nodes[d].c < 0 && fn_overloads.get(tok_text(nodes[d].t), 0) > 1 {
            gen_error(d, "kc reads a variadic function of a name of its own; not yet one of several overloads")
            return
        }
    }
}

// whether d is an operator of the program's, let +(a:T, b:T):T (#42)
let is_operator(d:int64):bool {
    return nodes[d].kind == D_FN && toks[nodes[d].t].kind == T_PUNCT
}

// the word of an operator in its C name, as kelvinc's: _kv_add_op, and
// _kv_neg_op of the unary -
let operator_word(d:int64):cstr {
    let t:int64 = nodes[d].t
    if tok_is(t, "+") { return "_kv_add_op" }
    if tok_is(t, "-") { return nodes[d].a >= 0 && nodes[nodes[d].a].next < 0 ? "_kv_neg_op" : "_kv_sub_op" }
    if tok_is(t, "*") { return "_kv_mul_op" }
    if tok_is(t, "/") { return "_kv_div_op" }
    if tok_is(t, "%") { return "_kv_mod_op" }
    if tok_is(t, "==") { return "_kv_eq_op" }
    if tok_is(t, "!=") { return "_kv_ne_op" }
    if tok_is(t, "**") { return "_kv_pow_op" }
    if tok_is(t, "<") { return "_kv_lt_op" }
    if tok_is(t, "<=") { return "_kv_le_op" }
    if tok_is(t, ">") { return "_kv_gt_op" }
    return "_kv_ge_op"
}

// what names what a function makes, _kv_f_fn1: its name, of an operator
// a word C reads (#471)
let maker_name(d:int64):String {
    return is_operator(d) ? $"op" : tok_text(nodes[d].t)
}

// a function's C name, as kelvinc's: a defined overload by its
// parameters' types, twice__i64; one declared and never defined is C's;
// an operator by its word and its parameters' types (#471)
let put_fn_name(d:int64) {
    if is_operator(d) {
        put(operator_word(d))
        var types_of = params_key(d)
        out += &types_of
        return
    }
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
    return is_int_kind(k) || k == Y_F64 || k == Y_F32 || k == Y_BOOL
}

// whether x is a word with no type of its own, none, ok(v) or err(e): not
// a call of a function a C header declares, whose type C sees
let is_word_value(x:int64):bool {
    if !is_case_word(x) { return false }
    if nodes[x].kind != N_CALL || !c_headers { return true }
    let w:int64 = nodes[nodes[x].a].t
    return tok_is(w, "ok") || tok_is(w, "err") || tok_is(w, "some")
}

// how a call's argument a fits a parameter of type t, as kelvinc's fit:
// 2 its very type, 1 one it converts to, 0 none; a T fits a T? only
// where wraps is, the second look (#222)
let arg_fit(a:int64, t:int64, wraps:bool):int64 {
    if t < 0 { return 0 }
    let k:nkind = nodes[a].kind
    let tk:ykind = types[t].kind
    if is_word_value(a) {                                // none, ok(v), err(e): of the type that takes them
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

var tied_cands:$[int64]                  // the overloads a call fits alike (#471)

// the overload of name that call n's arguments fit best: exactly, or as
// well on each argument as any other and better on one; -2 a tie, -1 none
let choose_overload(n:int64, name:String^, wraps:bool):int64 {
    while tied_cands.count > 0 { tied_cands.pop() }
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
            tied_cands += cands[i]
        }
    }
    if ties > 0 { return 0 - 2 }
    return best
}

var generic_at:Dictionary<int64, int64>  // a call only C's _Generic chooses for: where its overloads are in
var generic_sets:$[int64]                 // these, their count first

// whether an argument of call n is of a type only C sees
let sees_c_arg(n:int64):bool {
    var a:int64 = nodes[n].b
    while a >= 0 {
        let y:int64 = is_word_value(a) ? 0 - 1 : type_of(a)
        if y >= 0 && types[y].kind == Y_C { return true }
        a = nodes[a].next
    }
    return false
}

// call n fits tied_cands alike: where only C sees an argument's type,
// _Generic chooses, as kelvinc's dispatch_call (#41), and the first gives
// its type; else kelvinc's error of an operator (#42)
let tied_call(n:int64, name:const String^, op:bool):bool {
    if !sees_c_arg(n) {
        if op {
            var m = $"'"
            m += name
            m += "' fits more than one of its overloads equally: convert an argument, as in 'x as f64'"
            gen_error(n, m.cstr)
        }
        return false
    }
    generic_at[n] = generic_sets.count as int64
    generic_sets += tied_cands.count as int64
    for d in tied_cands { generic_sets += d }
    targets[n] = tied_cands[0]
    return true
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
    if d == -2 && tied_call(n, &name, false) { return targets.get(n, -1) }
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

// ---------- a struct's operators (#42, #471) ----------

let has_call(n:int64):bool
let compound_op(t:int64):cstr

var op_settled:Dictionary<int64, bool>   // the a op b found to be C's own, or a type's

// how an operand shows in a message about operators, as kelvinc's
let operand_text(x:int64, y:int64):String {
    if nodes[x].kind == N_NULL { return $"nowhere" }
    if nodes[x].kind == N_STR || (y >= 0 && types[y].kind == Y_CSTR) { return $"text" }
    if y < 0 { return $"a value kelvinc cannot see" }
    return kelvin_type_text(y)
}

// the parameter that takes what operand_text says, as kelvinc suggests it
let operand_param(x:int64, y:int64):String {
    if nodes[x].kind == N_NULL || nodes[x].kind == N_STR || (y >= 0 && types[y].kind == Y_CSTR) { return $"u8^" }
    if y < 0 { return $"T" }
    return kelvin_type_text(y)
}

// the program's operator t with a parameter of type y (#121)?
let user_operator_on(t:int64, y:int64):bool {
    for d in decls {
        if !is_operator(d) || !same_text(nodes[d].t, t) { continue }
        var p:int64 = nodes[d].a
        while p >= 0 {
            if nodes[p].ty == y { return true }
            p = nodes[p].next
        }
    }
    return false
}

// a op b and -a where a Kelvin struct, a union or an enum with values
// that defines one is an operand: from here on the call of the operator
// chosen, as kelvinc's resolve_operator; else as it was, C's own or a
// type's own
let resolve_op(n:int64) {
    let k:nkind = nodes[n].kind
    if k != N_BIN && k != N_UNARY { return }
    if op_settled.has(n) { return }
    let t:int64 = nodes[n].t
    let unary = k == N_UNARY
    if unary ? !tok_is(t, "-") : !overloadable_tok(t) { return }
    let a:int64 = nodes[n].a
    let b:int64 = unary ? 0 - 1 : nodes[n].b
    let ya:int64 = is_word_value(a) ? 0 - 1 : type_of(a)
    let yb:int64 = b < 0 || is_word_value(b) ? 0 - 1 : type_of(b)
    if failed { return }
    if builtin_kind(ya) != Y_VOID || builtin_kind(yb) != Y_VOID { // a String's, an Array's: their own, or their errors
        op_settled[n] = true
        return
    }
    let side:int64 = tagged_of(ya) >= 0 ? ya : tagged_of(yb) >= 0 ? yb : 0 - 1
    if side >= 0 && !user_operator_on(t, side) {         // an enum with values has == and != of its own (#79)
        op_settled[n] = true
        return
    }
    if side < 0 && !op_record(ya) && !op_record(yb) {
        if ya >= 0 && (unary || yb >= 0) { op_settled[n] = true }   // else asked again where more is known
        return
    }
    if (ya < 0 && !is_word_value(a)) || (!unary && yb < 0 && !is_word_value(b)) { return }   // what kc does not see yet
    let f:int64 = make_node(N_ID, t)
    nodes[n].kind = N_CALL
    nodes[n].a = f
    nodes[n].b = a
    nodes[a].next = b
    if b >= 0 { nodes[b].next = 0 - 1 }
    var name = tok_text(t)
    var d = choose_overload(n, &name, false)
    if d == 0 - 1 { d = choose_overload(n, &name, true) }
    if d == 0 - 2 {
        tied_call(n, &name, true)
        return
    }
    if d < 0 {
        var m = $"no operator "
        m += &name
        m += " takes "
        let sa:String = operand_text(a, ya)
        m += &sa
        if b >= 0 {
            let sb:String = operand_text(b, yb)
            m += " and "
            m += &sb
            m += ": define one, as in 'let "
            m += &name
            m += "(a:"
            m += operand_param(a, ya)
            m += ", b:"
            m += operand_param(b, yb)
            m += "):... { ... }'"
        } else {
            m += ": define one, as in 'let "
            m += &name
            m += "(a:"
            m += operand_param(a, ya)
            m += "):... { ... }'"
        }
        gen_error(n, m.cstr)
        return
    }
    targets[n] = d
}

// x op= y where a struct's operator takes them is x = x op y (#42): false
// where it is C's own, or kelvinc's error of an x that holds a call
let compound_by_operator(n:int64):bool {
    resolve_attr(nodes[n].a)
    if attr_reads.has(nodes[n].a) || sub_targets.has(nodes[n].a) { return false }   // its setter's, gen_assign's (#132, #136)
    let t:int64 = nodes[n].t
    if !(tok_is(t, "+=") || tok_is(t, "-=") || tok_is(t, "*=") || tok_is(t, "/=") || tok_is(t, "%=") || tok_is(t, "**=")) { return false }
    let lhs:int64 = nodes[n].a
    let ya:int64 = type_of(lhs)
    let yb:int64 = is_word_value(nodes[n].b) ? 0 - 1 : type_of(nodes[n].b)
    if failed || builtin_kind(ya) != Y_VOID || builtin_kind(yb) != Y_VOID { return false }
    if !op_record(ya) && !op_record(yb) { return false }
    if tok_is(t, "**=") && !op_record(ya) { return false }
    let tagged = tagged_of(ya) >= 0
    var word = String(compound_op(t))
    let op_tok:int64 = made_token(&word)
    toks[op_tok].kind = T_PUNCT
    toks[op_tok].line = toks[t].line
    toks[op_tok].file = toks[t].file
    if tagged && !user_operator_on(op_tok, ya) { return false }  // and its error, the assignment's
    if has_call(lhs) {
        var m = $"with an operator a struct defines, 'x "
        m += tok_text(t)
        m += " y' is 'x = x "
        m += &word
        m += " y', which evaluates x twice, so x may not hold a call"
        gen_error(n, m.cstr)
        return true
    }
    let bin:int64 = make_node(N_BIN, op_tok)
    nodes[bin].a = lhs
    nodes[bin].b = nodes[n].b
    resolve_op(bin)
    if failed { return true }
    if nodes[bin].kind != N_CALL { return false }
    var eq = $"="
    let eq_tok:int64 = made_token(&eq)
    toks[eq_tok].kind = T_PUNCT
    toks[eq_tok].line = toks[t].line
    toks[eq_tok].file = toks[t].file
    nodes[n].t = eq_tok
    nodes[n].b = bin
    return false
}

// ---------- printing an enum with values, a struct (#229) and an Array (#230) ----------

var shown:$[int64]                       // the types whose _kv_show_T is written, in order
var shown_types:Dictionary<int64, int64>

// the struct a type names, or -1
let struct_of(y:int64):int64 {
    if y < 0 || types[y].kind != Y_STRUCT { return -1 }
    return decl_named(types[y].name, D_STRUCT)
}

// C's word of y, a struct or an enum with values: union of a union (#453)
let put_record_word(y:int64) {
    let s:int64 = struct_of(y)
    put(s >= 0 && nodes[s].flag == 1 ? "union " : "struct ")
}

// whether print shows v as it is: a number, a bool, text
let plain_shown(v:int64):bool {
    let k:ykind = types[v].kind
    return is_int_kind(k) || k == Y_F64 || k == Y_F32 || k == Y_BOOL || k == Y_STRING || k == Y_BYTES || k == Y_CSTR || k == Y_BITS
}

// whether print shows v inside a value as it is: plain_shown's, and a
// uchr, as uchr("x") (#479)
let elem_shown(v:int64):bool {
    return plain_shown(v) || types[v].kind == Y_UCHR
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
        if !elem_shown(v) && !shown_by_type(v) {
            gen_error(n, "kc prints a number, a bool, text, an Array, a Dictionary, an enum with values or a struct of them; not yet what this holds")
            return false
        }
        if !elem_shown(v) && !need_show(v, n) { return false }
        shown += y
        return true
    }
    let d = tagged_of(y)
    if d < 0 && nodes[struct_of(y)].flag == 1 {          // <union bits>, by its name (#453)
        shown += y
        return true
    }
    var m:int64 = d >= 0 ? nodes[d].a : nodes[struct_of(y)].a
    while m >= 0 {
        var v = nodes[m].ty
        while v >= 0 && types[v].kind == Y_FIXED { v = types[v].elem }   // a member's fixed array, by its elements (#356)
        if v >= 0 && !elem_shown(v) {
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
    } else if k == Y_BYTES {                            // quoted, as kelvinc's: its bytes, escaped where not text (#439)
        put("kv_out_quoted(o, (")
        put_self(path, t)
        put(").at, (")
        put_self(path, t)
        put(").count, true);\n")
    } else if k == Y_CSTR {
        put("kv_out_quoted_text(o, (const void *)(")
        put_self(path, t)
        put("));\n")
    } else if k == Y_UCHR {                             // uchr("x"), which pastes back (#479)
        put("{ uint8_t _kv_b[256]; kv_cstr_quoted_uchr(")
        put_self(path, t)
        put(", _kv_b); kv_out_put(o, _kv_b); }\n")
    } else if !plain_shown(v) {
        put_show_name(v)
        put("(o, &(")
        put_self(path, t)
        put("), ")
        put(level)
        put(");\n")
    } else {
        put("{ uint8_t _kv_b[256]; ")
        put(k == Y_BOOL ? "kv_cstr_bool" : k == Y_BITS ? "kv_cstr_bits" : k == Y_I128 ? "kv_cstr_i128" : k == Y_U128 ? "kv_cstr_u128" : is_unsigned_kind(k) ? "kv_cstr_u64" : k == Y_F64 ? "kv_cstr_f64" : k == Y_F32 ? "kv_cstr_f32" : "kv_cstr_i64")
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
    if k == Y_STRING || k == Y_BYTES {
        put(k == Y_STRING ? "kv_string_eq(&" : "kv_bytes_eq(&")
        put(x)
        put(", &")
        put(z)
        put(")")
    } else if k == Y_UCHR {
        put(x)
        put(".cp == ")
        put(z)
        put(".cp")
    } else if k == Y_BITS {                          // by its count and bits (#455)
        put("kv_bits_eq(&")
        put(x)
        put(", &")
        put(z)
        put(")")
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
    if !case_value_fits(v, m, rt) { return }             // of what the case holds (#413)
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

// whether x, a side of == of the Optional or the Result rt, is what its
// case holds where it is wrapped, as kelvinc's: a T of the value case,
// ok(v) and err(e) of theirs; one of an enum with values is not (#413)
let eq_side_fits(x:int64, rt:int64):bool {
    if is_case_word(x) {
        let m:int64 = case_word_of(x, tagged_of(rt))
        return m < 0 || nodes[x].kind != N_CALL || nodes[x].b < 0 || case_value_fits(nodes[x].b, m, rt)
    }
    let y:int64 = type_of(x)
    if y >= 0 && tagged_of(y) >= 0 { return true }
    return case_value_fits(x, value_case(rt), rt)
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
        if !is_variant(rt) {                         // or one of its own (#121)
            m += ", or define one, as in 'let "
            m += tok_text(t)
            m += "(a:T, b:T):T { ... }' (#121)"
        }
        gen_error(n, m.cstr)
        return
    }
    if is_variant(rt) && (!eq_side_fits(a, rt) || !eq_side_fits(b, rt)) { return }   // wrapped first, as kelvinc's (#413)
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
    put_record_word(y)
    put_tok(types[y].name)
    put(" *self = _kv_v;\n")
    let d = tagged_of(y)
    if d < 0 && nodes[struct_of(y)].flag == 1 {         // <union bits>, as kelvinc shows one (#453)
        put("    (void)self;\n    (void)level;\n    kv_out_put(o, \"<")
        if !anon_decls.has(tok_text(types[y].name)) { put("union ") }   // <union{i: i32, f: f32}>, of one with no tag (#476)
        let w:String = kelvin_name(types[y].name)
        put(w.cstr)
        put(">\");\n}\n\n")
        return
    }
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
let gen_print_args_to(first:int64, sink:cstr)    // a prototype: print's values go to stdout by it (#452)

let gen_print_args(first:int64) {
    gen_print_args_to(first, "NULL")
}

// print's values, those of a printer written into the sink, a FILE * in
// C: NULL for stdout, kv_io_fp(f) of an IO's print (#452)
let gen_print_args_to(first:int64, sink:cstr) {
    var a:int64 = first
    while a >= 0 {
        if a != first { put(", ") }
        let y = type_of(a)
        if y >= 0 && types[y].kind == Y_FIXED && nodes[a].kind != N_LIST && types[types[y].elem].kind != Y_U8 && types[types[y].elem].kind != Y_I8 {   // [a, b], as kelvinc's (#481); bytes are text
            if types[y].name < 0 {
                gen_error(a, "kc prints a fixed array of its own count; not yet a parameter's: print its elements, a[i]")
                return
            }
            var v = types[y].elem
            while types[v].kind == Y_FIXED { v = types[v].elem }
            if !elem_shown(v) && !shown_by_type(v) {
                gen_error(a, "kc prints a number, a bool, text, an Array, a Dictionary, an enum with values or a struct of them; not yet what this holds")
                return
            }
            if !elem_shown(v) && !need_show(v, a) { return }
            put("({ const struct { __typeof__(")         // the array as a struct's one member, self->a, as a member's is printed
            gen_expr(a)
            put(") a; } *self = (const void *)&(")
            gen_expr(a)
            put("); kv_out *o = &(kv_out){.fp = ")
            put(sink)
            put(", .width = 2}; ")
            show_value(y, "a", 0 - 1, "-1")
            put(" (const uint8_t *)\"\"; })")
            a = nodes[a].next
            continue
        }
        if y >= 0 && types[y].kind == Y_TASK {                   // as kelvinc's (#313)
            var m = $"a Task has no text: print its value, 'await "
            m += nodes[a].kind == N_ID ? tok_text(nodes[a].t) : $"t"
            m += "'"
            gen_error(a, m.cstr)
            return
        }
        let pr:int64 = nodes[a].kind == N_FIELD && tok_is(nodes[a].t, "pretty") ? type_of(nodes[a].a) : 0 - 1
        if pr >= 0 && pretty_value(a) && need_show(pr, a) {   // v.pretty where print shows it, written in place (#336, #337); of any printed value (#452)
            put("({ __auto_type _kv_sv = (")
            gen_expr(nodes[a].a)
            put("); ")
            put_show_name(pr)
            put("(&(kv_out){.fp = ")
            put(sink)
            put(", .width = 2}, &_kv_sv, 0); (const uint8_t *)\"\"; })")
        } else if !is_case_word(a) && shown_by_type(y) && need_show(y, a) {
            put("({ __auto_type _kv_sv = (")
            gen_expr(a)
            put("); ")
            put_show_name(y)
            put("(&(kv_out){.fp = ")
            put(sink)
            put(", .width = 2}, &_kv_sv, -1); (const uint8_t *)\"\"; })")
        } else {
            gen_expr(a)
        }
        a = nodes[a].next
    }
}

// ---------- try (#449) ----------

// the case of the variant d that is not m: an Optional's none, a
// Result's err
let other_case(d:int64, m:int64):int64 {
    let first:int64 = nodes[d].a
    return m == first ? nodes[first].next : first
}

// whether try takes a, a variable or a member of one, by its address,
// as kelvinc's c_lvalue: not what a built-in type's member gives, as an
// IO's f^.string, which is made when it is read
let try_place(a:int64):bool {
    if !is_place(a) { return false }
    if nodes[a].kind != N_FIELD { return true }
    let ry:int64 = type_of(nodes[a].a)
    return ry >= 0 && struct_of(ry) >= 0 && try_place(nodes[a].a)
}

// whether try n is kelvinc's error, as its #76 says them: of what is no
// Result or Optional, in a function of no result, of another kind, or of
// another err's type; of a place whose value owns, which it would move
// out. Where it is, the error
let try_refused(n:int64):bool {
    let a:int64 = nodes[n].a
    let y:int64 = type_of(a)
    if failed { return true }
    let m:int64 = y >= 0 ? value_case(y) : 0 - 1
    if m < 0 {
        var e = $"'try' takes a Result or an Optional, and this is "
        if y >= 0 {
            let w:String = kelvin_type_text(y)
            e += &w
        } else {
            e += "not one"
        }
        gen_error(a, e.cstr)
        return true
    }
    let o:int64 = other_case(tagged_of(y), m)
    let fy:int64 = nodes[current].ty
    if fy < 0 || types[fy].kind == Y_VOID {
        var e = $"'try' passes the '"
        e += tok_text(nodes[o].t)
        e += "' up, and this function has no result: give it "
        let w:String = kelvin_type_text(y)
        e += &w
        gen_error(n, e.cstr)
        return true
    }
    let fm:int64 = value_case(fy)
    let fo:int64 = fm >= 0 ? other_case(tagged_of(fy), fm) : 0 - 1
    if fo < 0 || !same_text(nodes[fo].t, nodes[o].t) {
        var e = $"'try' passes the '"
        e += tok_text(nodes[o].t)
        e += "' up, and this function returns "
        let w:String = kelvin_type_text(fy)
        e += &w
        e += tok_is(nodes[o].t, "err") ? ", not a Result" : ", not an Optional"
        e += ": switch on it, or 'if let'"
        gen_error(n, e.cstr)
        return true
    }
    if nodes[o].ty >= 0 && nodes[o].ty != nodes[fo].ty {
        var e = $"'try' passes the 'err' up as it is, and it is "
        let w:String = kelvin_type_text(nodes[o].ty)
        e += &w
        e += " where this function's is "
        let fw:String = kelvin_type_text(nodes[fo].ty)
        e += &fw
        gen_error(n, e.cstr)
        return true
    }
    if is_owner(nodes[m].ty) && try_place(a) {
        let name:String = nodes[a].kind == N_ID ? tok_text(nodes[a].t) : $""
        var e = $"'try' would move the "
        let w:String = kelvin_type_text(nodes[m].ty)
        e += &w
        e += " out of "
        if nodes[a].kind == N_ID {
            e += "'"
            e += &name
            e += "'"
        } else {
            e += "it"
        }
        e += ", which keeps it: try the call itself, 'try "
        if nodes[a].kind == N_ID { e += &name } else { e += "..." }
        e += ".copy()', or 'if let'"
        gen_error(a, e.cstr)
        return true
    }
    return false
}

// try r, as kelvinc's try_code (#76): r's value where its case is ok
// (some), else a return of its err (none) from the function, passed up
// as it is. The err moves out, so that the place, or the temporary's
// cleanup, frees nothing of it; so does an owner value, when it is
// wanted, and where it is not the cleanup frees it
let gen_try(n:int64, value:bool) {
    if try_refused(n) { return }
    let a:int64 = nodes[n].a
    let y:int64 = type_of(a)
    let d:int64 = tagged_of(y)
    let m:int64 = value_case(y)
    let o:int64 = other_case(d, m)
    let fy:int64 = nodes[current].ty
    let fd:int64 = tagged_of(fy)
    let fo:int64 = other_case(fd, value_case(fy))
    let place = try_place(a)
    let owns = is_owner(y)
    put("({ ")
    if place {
        put_ctype(y)
        put(" *_kv_p = ")
        gen_place(a)
        put("; if (_kv_p->tag != ")
    } else {
        if owns {
            put("__attribute__((cleanup(")
            put_free(y)
            put("))) ")
        }
        put_ctype(y)
        put(" _kv_t = ")
        gen_expr(a)
        put("; if (_kv_t.tag != ")
    }
    put_int(case_tag(d, m))
    put(") return _kv_")
    put_tok(nodes[fd].t)
    put("_make_")
    put_tok(nodes[fo].t)
    put("(")
    if nodes[fo].ty >= 0 {                               // the err, taken
        if owns {
            put_owner_prefix(y)
            put(place ? "_take(_kv_p).u." : "_take(&_kv_t).u.")
        } else {
            put(place ? "_kv_p->u." : "_kv_t.u.")
        }
        put_tok(nodes[o].t)
    }
    put(");")
    if value {
        if place {
            put(" _kv_p->u.")
        } else if owns {
            put(" ")
            put_owner_prefix(y)
            put("_take(&_kv_t).u.")
        } else {
            put(" _kv_t.u.")
        }
        put_tok(nodes[m].t)
        put(";")
    }
    put(" })")
}

// ---------- an IO's print (#452) ----------

// whether n is v.pretty of what print shows by a printer, its text
// indented, as kelvinc's #124: a Set, a Dictionary, an Array, a Range,
// a struct with no member of that name, an enum with values with no case
let pretty_value(n:int64):bool {
    if nodes[n].kind != N_FIELD || !tok_is(nodes[n].t, "pretty") || tagged_named(nodes[n].a) >= 0 { return false }
    let y:int64 = type_of(nodes[n].a)
    if y < 0 || !shown_by_type(y) { return false }
    let d = tagged_of(y)
    if d >= 0 { return case_named(d, nodes[n].t) == none }
    let sd = struct_of(y)
    if sd < 0 { return true }
    var m:int64 = nodes[sd].a
    while m >= 0 {
        if same_text(nodes[m].t, nodes[n].t) { return false }
        m = nodes[m].next
    }
    return true
}

// whether t names an IO's int member: error, status, signal, pid, fd
let io_int_member(t:int64):bool {
    return tok_is(t, "error") || tok_is(t, "status") || tok_is(t, "signal") || tok_is(t, "pid") || tok_is(t, "fd")
}

// which of IO.stdin, IO.stdout and IO.stderr n is, 0 to 2, or -1
let std_io(n:int64):int64 {
    if nodes[n].kind != N_FIELD { return 0 - 1 }
    let a:int64 = nodes[n].a
    if nodes[a].kind != N_TYPE || !tok_is(nodes[a].t, "IO") { return 0 - 1 }
    let t:int64 = nodes[n].t
    return tok_is(t, "stdin") ? 0 : tok_is(t, "stdout") ? 1 : tok_is(t, "stderr") ? 2 : 0 - 1
}

// ---------- an IO's members and a String's methods (#464) ----------

// the type of f.name, a property of an IO, as kelvinc's #82 and on; -1
// where it has none, kc's error
let io_field_type(n:int64):int64 {
    let t:int64 = nodes[n].t
    if tok_is(t, "bytes") { return base_type(Y_BYTES) }                 // the rest of the file, straight (#107)
    if tok_is(t, "byte") { return optional_of(base_type(Y_U8)) }        // the next byte, or none at the end (#85)
    if tok_is(t, "eof") || tok_is(t, "isatty") || tok_is(t, "isdir") || tok_is(t, "isfile") || tok_is(t, "islink") || tok_is(t, "exists") { return base_type(Y_BOOL) }
    if tok_is(t, "position") || tok_is(t, "count") { return base_type(Y_I64) }
    if tok_is(t, "abspath") || tok_is(t, "basename") || tok_is(t, "dirname") { return base_type(Y_STRING) }
    if tok_is(t, "path") { return base_type(Y_CSTR) }
    if tok_is(t, "listdir") || tok_is(t, "walk") { return array_type(base_type(Y_STRING)) }   // an Array straight (#106)
    if tok_is(t, "stat") || tok_is(t, "lstat") {                        // a Stat straight, no Result (#104)
        let g = $"stat"
        return os_struct(&g)
    }
    member_unknown(n, type_of(nodes[n].a))               // kelvinc's words (#497)
    return 0 - 1
}

// the receiver of an IO's member, as kelvinc writes it: (kv_io *)&f
let put_io_recv(a:int64) {
    put("(kv_io *)")
    gen_place(a)
}

// f.name of an IO, as kelvinc writes it: kv_io_name((kv_io *)&f), an
// Array, a u8? or a Stat made of what it fills
let gen_io_field(n:int64, a:int64) {
    let t:int64 = nodes[n].t
    let y:int64 = io_field_type(n)
    if y < 0 { return }
    if tok_is(t, "bytes") {
        put("kv_io_read_all(")
        put_io_recv(a)
        put(")")
    } else if tok_is(t, "byte") {
        put("({ uint8_t _kv_v = 0; kv_io_read_byte(")
        put_io_recv(a)
        put(", &_kv_v) ? _kv_")
        put_tok(types[y].name)
        put("_make_some(_kv_v) : _kv_")
        put_tok(types[y].name)
        put("_make_none(); })")
    } else if tok_is(t, "listdir") || tok_is(t, "walk") {
        put("({ kv_string *_kv_at = NULL; size_t _kv_n = 0; kv_io_")
        put_tok(t)
        put("(")
        put_io_recv(a)
        put(", &_kv_at, &_kv_n); ")
        put_array_name(y)
        put(" _kv_a = ")
        put_array_name(y)
        put("_from(_kv_at, _kv_n); free(_kv_at); _kv_a; })")
    } else if tok_is(t, "stat") || tok_is(t, "lstat") {
        put("({ kv_stat _kv_st = kv_io_")
        put_tok(t)
        put("(")
        put_io_recv(a)
        put("); (")
        put_ctype(y)
        put("){")
        var f:int64 = nodes[struct_of(y)].a
        while f >= 0 {
            put(".")
            put_tok(nodes[f].t)
            put(" = _kv_st.")
            put_tok(nodes[f].t)
            f = nodes[f].next
            if f >= 0 { put(", ") }
        }
        put("}; })")
    } else {
        put("kv_io_")
        put_tok(t)
        put("(")
        put_io_recv(a)
        put(")")
    }
}

// what f.name(args) of an IO gives, as kelvinc's ops (#101, #106, #108):
// its arguments' letters, t text, i an integer, f a number; -1 of none
let io_method_args(t:int64):cstr {
    if tok_is(t, "glob") || tok_is(t, "join") || tok_is(t, "rename") { return "t" }
    if tok_is(t, "chmod") || tok_is(t, "truncate") || tok_is(t, "seek") || tok_is(t, "kill") { return "i" }
    if tok_is(t, "chown") { return "ii" }
    if tok_is(t, "utime") { return "ff" }
    if tok_is(t, "remove") || tok_is(t, "touch") { return "" }
    return "-"
}

let io_method_type(n:int64):int64 {
    let t:int64 = nodes[n].t
    let args:String = String(io_method_args(t))
    if args == $"-" { return 0 - 1 }
    if tok_is(t, "glob") { return array_type(base_type(Y_STRING)) }
    if tok_is(t, "join") { return base_type(Y_STRING) }
    return base_type(Y_BOOL)
}

// f.glob(p), f.join(name), f.chmod(m) and the rest, as kelvinc writes
// them: kv_io_name((kv_io *)&f, args), the arguments checked as OS's
let gen_io_method(n:int64, a:int64) {
    let t:int64 = nodes[n].t
    let args:String = String(io_method_args(t))
    let name:String = tok_text(t)
    var count:int64 = 0
    var x:int64 = nodes[n].b
    while x >= 0 {
        count += 1
        x = nodes[x].next
    }
    if count != args.count {                             // as kelvinc says it
        var e = $"'."
        e += &name
        e += "' takes "
        e += String(args.count)
        e += args.count == 1 ? " argument" : " arguments"
        gen_error(n, e.cstr)
        return
    }
    let glob = tok_is(t, "glob")
    let y:int64 = io_method_type(n)
    if glob { put("({ kv_string *_kv_at = NULL; size_t _kv_n = 0; ") }
    put("kv_io_")
    put_tok(t)
    put("(")
    put_io_recv(a)
    x = nodes[n].b
    var i:int64 = 0
    while x >= 0 && !failed {
        put(", ")
        let letter:uint8 = args.cstr[i]
        let xy:int64 = type_of(x)
        let k:ykind = xy >= 0 ? types[xy].kind : Y_C
        let text = nodes[x].kind == N_STR || nodes[x].kind == N_TPL || k == Y_CSTR
        if letter == 'i' || letter == 'f' {
            let ok = k == Y_C || (letter == 'f' ? is_number_kind(k) : (is_number_kind(k) && k != Y_F64 && k != Y_F32))
            if !ok || text {
                var e = $"argument "
                e += String(i + 1)
                e += " of '."
                e += &name
                e += letter == 'f' ? "' is a number, and this is " : "' is an integer, and this is "
                let w:String = xy >= 0 && nodes[x].kind != N_STR && nodes[x].kind != N_TPL ? kelvin_type_text(xy) : $"not one"
                e += &w
                gen_error(x, e.cstr)
                return
            }
            gen_expr(x)
        } else if (k == Y_STRING || k == Y_BYTES) && is_place(x) {
            put("kv_bytes_cstr(&(")
            gen_expr(x)
            put(k == Y_STRING ? ").b)" : "))")
        } else if !text && k != Y_C {
            var e = $"an argument of '."
            e += &name
            e += "' is text, a String or a Bytes, and this is "
            let w:String = xy >= 0 && nodes[x].kind != N_NUM && nodes[x].kind != N_CHAR ? kelvin_type_text(xy) : $"a number"
            e += &w
            gen_error(x, e.cstr)
            return
        } else {
            gen_expr(x)
        }
        i += 1
        x = nodes[x].next
    }
    if glob {
        put(", &_kv_at, &_kv_n); ")
        put_array_name(y)
        put(" _kv_a = ")
        put_array_name(y)
        put("_from(_kv_at, _kv_n); free(_kv_at); _kv_a; })")
    } else {
        put(")")
    }
}

// s.find(x), s.has(x), s.starts(x), s.ends(x), s.trim(), s.append(x),
// s.clear(), s.compact() and s.reserve(n) of a String, as kelvinc's #55
// and #177: KV_STRING_TEXT_OR_REF of the searches, text, a cstr or a
// String borrowed; KV_STRING_APPEND of text, &t, a uchr or a codepoint;
// a String an expression gives held around the statement, as escape's
let gen_string_method(n:int64, a:int64, y:int64) {
    let t:int64 = nodes[n].t
    let x:int64 = nodes[n].b
    let name:String = tok_text(t)
    let search = tok_is(t, "find") || tok_is(t, "has") || tok_is(t, "starts") || tok_is(t, "ends")
    let one = search || tok_is(t, "append") || tok_is(t, "reserve")
    var count:int64 = 0
    var c:int64 = x
    while c >= 0 {
        count += 1
        c = nodes[c].next
    }
    if count != (one ? 1 : 0) {                         // as kelvinc says it
        var e = $"'."
        e += &name
        e += one ? "' takes 1 argument" : "' takes 0 arguments"
        gen_error(n, e.cstr)
        return
    }
    let changes = tok_is(t, "append") || tok_is(t, "clear") || tok_is(t, "compact") || tok_is(t, "reserve")
    if changes && !may_change(a) { return }
    if changes && !is_place(a) {
        var e = $"'."
        e += &name
        e += "' changes a String, and this one an expression gives would be lost: bind it to a variable first"
        gen_error(n, e.cstr)
        return
    }
    if search {
        let xy:int64 = type_of(x)
        let borrow = nodes[x].kind == N_ADDR && type_of(nodes[x].a) >= 0 && types[type_of(nodes[x].a)].kind == Y_STRING
        let text = nodes[x].kind == N_STR || nodes[x].kind == N_TPL || (xy >= 0 && types[xy].kind == Y_CSTR)
        if !borrow && !text {
            var e = $"'."
            e += &name
            e += "' takes text, a cstr, or a String borrowed, '&t', and this is "
            let literal = nodes[x].kind == N_NUM || nodes[x].kind == N_CHAR || nodes[x].kind == N_BOOL   // no type to kelvinc
            let w:String = xy >= 0 && types[xy].kind == Y_STRING ? $"a String: write '&'" : xy >= 0 && !literal ? kelvin_type_text(xy) : $"not text"
            e += &w
            gen_error(x, e.cstr)
            return
        }
    }
    if tok_is(t, "append") && (owner_name(x) || owner_part(x)) {   // s.append(t) would take t's bytes, freed twice, as s += t (#440)
        owner_copy_error(x, "append")
        return
    }
    if search {
        put("KV_STRING_TEXT_OR_REF(")
        put_tok(t)
        put(", ")
        gen_place(a)
        put(", ")
        gen_expr(x)
        put(")")
    } else if tok_is(t, "append") {
        put("KV_STRING_APPEND(")
        gen_place(a)
        put(", ")
        gen_expr(x)
        put(")")
    } else {
        put("kv_string_")
        put_tok(t)
        put("(")
        gen_place(a)
        if x >= 0 {
            put(", ")
            gen_expr(x)
        }
        put(")")
    }
}

// ---------- OS and SYS (#463) ----------

// OS.name(args) and SYS.name, as kelvinc's #94: the system around the
// program, and the program itself, by the runtime's kv_os_name and
// kv_sys_name. Each member: its arguments, - of a property, a letter of
// each, t text, i an integer, f a number; and what it gives, as
// kelvinc's members table says it
var os_table:Dictionary<String, String>

let os_spec():cstr {
    return "SYS.argv - argv;SYS.exit i void;SYS.platform - cstr;OS.cwd - res_string;OS.chdir t i32;OS.env t opt_cstr;OS.setenv tt i32;OS.unsetenv t i32;OS.exists t bool;OS.isdir t bool;OS.isfile t bool;OS.islink t bool;OS.remove t i32;OS.unlink t i32;OS.rename tt i32;OS.mkdir t i32;OS.makedirs t i32;OS.rmdir t i32;OS.listdir t listdir;OS.stat t stat;OS.lstat t stat;OS.symlink tt i32;OS.readlink t res_string;OS.link tt i32;OS.chmod ti i32;OS.truncate ti i32;OS.realpath t res_string;OS.basename t string;OS.dirname t string;OS.join tt string;OS.system t i32;OS.kill ii i32;OS.umask i i32;OS.pid - i32;OS.ppid - i32;OS.uid - i32;OS.gid - i32;OS.user - opt_string;OS.host - res_string;OS.time - f64;OS.sleep f void;OS.tmpdir - cstr;OS.walk t listdir;OS.glob t listdir;OS.mkstemp t temp;OS.mkdtemp t res_string;OS.utime tff i32;OS.touch t i32;OS.chown tii i32;OS.lchown tii i32;OS.username i opt_string;OS.groupname i opt_string;OS.strerror i string;OS.environ - listdir;OS.euid - i32;OS.egid - i32;OS.groups - ints;OS.uname - uname;OS.readable t bool;OS.writable t bool;OS.executable t bool;OS.isabs t bool;OS.splitext t splitext;OS.normpath t string;OS.relpath tt string;OS.expanduser t string;OS.samefile tt bool;OS.mkfifo t i32;OS.sync . void;OS.cpus - i32;OS.loadavg - loadavg;OS.urandom i res_bytes;OS.isatty i bool;OS.sep - cstr;OS.linesep - cstr;OS.devnull - cstr;OS.name - cstr;OS.terminalsize - terminalsize;OS.diskusage t diskusage;"
}

// "args gives" of OS.name or SYS.name n, "" where there is none
let os_member(n:int64):String {
    if os_table.count == 0 {
        let all:String = String(os_spec())
        var entry = $""
        for c in all {
            if c.utf32 == ';' {
                var name = $""
                var rest = $""
                var at_rest = false
                for e in entry {
                    if !at_rest && e.utf32 == ' ' {
                        at_rest = true
                    } else if at_rest {
                        rest += e
                    } else {
                        name += e
                    }
                }
                os_table[name.copy()] = rest.copy()
                entry = $""
            } else {
                entry += c
            }
        }
    }
    var key = tok_text(nodes[nodes[n].a].t)
    key += "."
    key += tok_text(nodes[n].t)
    return os_table[key] ?? $""
}

// whether n is OS.name or SYS.name, of no variable of the name
let os_call(n:int64):bool {
    let k = nodes[n].kind
    if k != N_FIELD && k != N_METHOD { return false }
    let a:int64 = nodes[n].a
    if nodes[a].kind != N_ID || var_type(nodes[a].t) >= 0 { return false }
    return tok_is(nodes[a].t, "OS") || tok_is(nodes[a].t, "SYS")
}

// the part of spec m after its arguments, what it gives
let os_gives(m:const String^):String {
    var g = $""
    var seen = false
    for c in m^ {
        if seen { g += c }
        if c.utf32 == ' ' { seen = true }
    }
    return g
}

// the arguments' letters of spec m, "-" of a property, "." of none
let os_args(m:const String^):String {
    var a = $""
    for c in m^ {
        if c.utf32 == ' ' { break }
        a += c
    }
    return a
}

// the type of OS.name or SYS.name n, as kelvinc's; its errors in
// kelvinc's words, where it is no member, wants an import, is called
// wrongly, or gives what kc does not make yet
let os_type(n:int64):int64 {
    let sys = tok_is(nodes[nodes[n].a].t, "SYS")
    let ns:cstr := sys ? "SYS" : "OS"
    if !sys && !os_imported {
        gen_error(n, "OS is a module: write '#import <OS>' at the top of the file")
        return 0 - 1
    }
    let m:String = os_member(n)
    let name:String = tok_text(nodes[n].t)
    if m.count == 0 {
        var e = $""
        if sys {
            e = $"SYS has argv, exit(code) and platform, not '"
            e += &name
            e += "'"
        } else {
            e = $"OS has no '"
            e += &name
            e += "': see documents/os.md for cwd, chdir, env, setenv, unsetenv, exists, isdir, isfile, islink, remove, unlink, rename, mkdir, makedirs, rmdir, listdir, stat, lstat, symlink, readlink, link, chmod, truncate, realpath, basename, dirname, join, system, kill, umask, pid, ppid, uid, gid, user, host, time, sleep, tmpdir, walk, glob, mkstemp, mkdtemp, utime, touch, chown, lchown, username, groupname, strerror, environ, euid, egid, groups, uname, readable, writable, executable, isabs, splitext, normpath, relpath, expanduser, samefile, mkfifo, sync, cpus, loadavg, urandom, isatty, sep, linesep, devnull, name, terminalsize and diskusage"
        }
        gen_error(n, e.cstr)
        return 0 - 1
    }
    let args:String = os_args(&m)
    let arity:int64 = args == $"-" ? 0 - 1 : args == $"." ? 0 : args.count
    if arity >= 0 && nodes[n].kind == N_FIELD {
        var e = String(ns)
        e += "."
        e += &name
        e += " takes "
        e += String(arity)
        e += arity == 1 ? " argument: write " : " arguments: write "
        e += ns
        e += "."
        e += &name
        e += "(...)"
        gen_error(n, e.cstr)
        return 0 - 1
    }
    if nodes[n].kind == N_METHOD {
        var count:int64 = 0
        var x:int64 = nodes[n].b
        while x >= 0 {
            count += 1
            x = nodes[x].next
        }
        if count != (arity < 0 ? 0 : arity) {
            var e = String(ns)
            e += "."
            e += &name
            e += " takes "
            e += String(arity < 0 ? 0 : arity)
            e += arity == 1 ? " argument" : " arguments"
            gen_error(n, e.cstr)
            return 0 - 1
        }
    }
    let g:String = os_gives(&m)
    if g == $"i32" { return base_type(Y_I32) }
    if g == $"f64" { return base_type(Y_F64) }
    if g == $"bool" { return base_type(Y_BOOL) }
    if g == $"cstr" { return base_type(Y_CSTR) }
    if g == $"string" { return base_type(Y_STRING) }
    if g == $"void" { return base_type(Y_VOID) }
    if g == $"argv" { return array_type(base_type(Y_CSTR)) }
    if g == $"res_string" { return result_of(base_type(Y_STRING), base_type(Y_I32)) }
    if g == $"opt_cstr" { return optional_of(base_type(Y_CSTR)) }
    if g == $"opt_string" { return optional_of(base_type(Y_STRING)) }
    if g == $"listdir" { return result_of(array_type(base_type(Y_STRING)), base_type(Y_I32)) }
    if g == $"ints" { return result_of(array_type(base_type(Y_I32)), base_type(Y_I32)) }
    if g == $"res_bytes" { return result_of(base_type(Y_BYTES), base_type(Y_I32)) }
    if g == $"temp" && !uses_io {                        // as kelvinc says it
        gen_error(n, "OS.mkstemp gives an IO, a module: write '#import <IO>' at the top of the file")
        return 0 - 1
    }
    return result_of(os_struct(&g), base_type(Y_I32))  // OS.stat and the rest, a struct of their own (#95, #102)
}

// the spelling of each struct an OS member gives, by its C name, which
// its typename is, as kelvinc spells it: {root: String, ext: String}
var os_spellings:Dictionary<String, String>
var os_structs:Dictionary<String, int64>

// the members of the struct OS's member that gives g gives, as kelvinc's
// struct_spec (#95, #102), and OS.mkstemp's IO and path (#97)
let os_struct_spec(g:const String^):cstr {
    if g^ == $"stat" { return "dev: i64, ino: i64, mode: i32, nlink: i64, uid: i32, gid: i32, size: i64, atime: f64, mtime: f64, ctime: f64, isdir: bool, isfile: bool, islink: bool" }
    if g^ == $"uname" { return "sysname: String, nodename: String, release: String, version: String, machine: String" }
    if g^ == $"splitext" { return "root: String, ext: String" }
    if g^ == $"loadavg" { return "one: f64, five: f64, fifteen: f64" }
    if g^ == $"terminalsize" { return "columns: i64, lines: i64" }
    if g^ == $"diskusage" { return "total: i64, used: i64, free: i64" }
    if g^ == $"pipe" { return "reader: IO, writer: IO" }  // IO.pipe()'s (#464)
    return "io: IO, path: String"                       // temp, OS.mkstemp's
}

// the struct of spec g, made once, as kelvinc's anon_struct: a struct of
// kc's own, its members of the spec's types
let os_struct(g:const String^):int64 {
    let seen:int64 = os_structs.get(g^, -1)
    if seen >= 0 { return seen }
    var cname = $"_kv_anon_"
    cname += g
    let d = make_node(D_STRUCT, made_token(&cname))
    let spec:String = String(os_struct_spec(g))
    var spelled = $"{"
    spelled += &spec
    spelled += "}"
    var last:int64 = 0 - 1
    var word = $""
    var name = $""
    var key = $"{"                                       // as parse_anon_record keys one (#476)
    var spaced = $""
    spaced += &spec
    spaced += ","
    for c in spaced {
        if c.utf32 == ':' {
            name = word.copy()
            word = $""
        } else if c.utf32 == ',' {
            let m = make_node(S_VAR, made_token(&name))
            let y:int64 = word == $"i64" ? base_type(Y_I64) : word == $"i32" ? base_type(Y_I32) : word == $"f64" ? base_type(Y_F64) : word == $"bool" ? base_type(Y_BOOL) : word == $"IO" ? base_type(Y_IO) : base_type(Y_STRING)
            set_ty(m, y)
            key += &name
            key += ":"
            key += String(y)
            key += ","
            if last < 0 { nodes[d].a = m } else { nodes[last].next = m }
            last = m
            word = $""
        } else if c.utf32 != ' ' {
            word += c
        }
    }
    let written:int64 = anon_keys.get(key, -1)          // the program's own, written alike, as kelvinc's one of each spelling (#476)
    if written >= 0 {
        os_structs[g^.copy()] = written
        return written
    }
    decls += d
    let sy:int64 = type_of_kind(Y_STRUCT, -1, nodes[d].t)
    os_structs[g^.copy()] = sy
    os_spellings[cname.copy()] = spelled.copy()
    return sy
}

// the arguments of OS.name(args) n, each checked as kelvinc checks it:
// text as a cstr, a String's or a Bytes's its own, an integer or a number
let put_os_args(n:int64, args:const String^):bool {
    let ns:cstr := tok_is(nodes[nodes[n].a].t, "SYS") ? "SYS" : "OS"
    let name:String = tok_text(nodes[n].t)
    var x:int64 = nodes[n].kind == N_METHOD ? nodes[n].b : 0 - 1
    var i:int64 = 0
    while x >= 0 && !failed {
        let letter:uint8 = args^.cstr[i]
        let y:int64 = type_of(x)
        let k:ykind = y >= 0 ? types[y].kind : Y_C
        let text = nodes[x].kind == N_STR || nodes[x].kind == N_TPL || k == Y_CSTR
        if i > 0 { put(", ") }
        if letter == 'i' || letter == 'f' {
            let ok = k == Y_C || (letter == 'f' ? is_number_kind(k) : (is_number_kind(k) && k != Y_F64 && k != Y_F32))
            if !ok || text {
                var e = $"argument "
                e += String(i + 1)
                e += " of "
                e += ns
                e += "."
                e += &name
                e += letter == 'f' ? " is a number, and this is " : " is an integer, and this is "
                let w:String = y >= 0 && nodes[x].kind != N_STR && nodes[x].kind != N_TPL ? kelvin_type_text(y) : $"not one"   // a literal has no type to kelvinc
                e += &w
                gen_error(x, e.cstr)
                return false
            }
            gen_expr(x)
        } else if k == Y_STRING || k == Y_BYTES {
            if !is_place(x) {
                var e = $"an argument of "
                e += ns
                e += "."
                e += &name
                e += k == Y_STRING ? " is a String that an expression gives: bind it to a variable first" : " is a Bytes that an expression gives: bind it to a variable first"
                gen_error(x, e.cstr)
                return false
            }
            put(k == Y_STRING ? "kv_bytes_cstr(&(" : "kv_bytes_cstr(&")
            gen_expr(x)
            put(k == Y_STRING ? ").b)" : ")")
        } else if !text && k != Y_C {
            var e = $"an argument of "
            e += ns
            e += "."
            e += &name
            e += " is text, a String or a Bytes, and this is "
            let w:String = y >= 0 && nodes[x].kind != N_NUM && nodes[x].kind != N_CHAR ? kelvin_type_text(y) : $"a number"
            e += &w
            gen_error(x, e.cstr)
            return false
        } else {
            gen_expr(x)
        }
        i += 1
        x = nodes[x].next
    }
    return true
}

// OS.name(args) and SYS.name, as kelvinc writes them: kv_os_name(args)
// of most; of a Result or an Optional, what the runtime fills, made into
// it; of SYS.argv an Array of the arguments
let gen_os(n:int64) {
    let y:int64 = os_type(n)
    if y < 0 { return }
    let m:String = os_member(n)
    let args:String = os_args(&m)
    let g:String = os_gives(&m)
    let fname = tok_is(nodes[nodes[n].a].t, "SYS") ? $"kv_sys_" : $"kv_os_"
    let has_args = args != $"-" && args != $"."
    if g == $"argv" {
        put_array_name(y)
        put("_from((const uint8_t *const *)kv_sys_argv_p(), (size_t)kv_sys_argc_n())")
        return
    }
    let made:bool = g == $"res_string" || g == $"opt_string" || g == $"opt_cstr" || g == $"listdir" || g == $"ints" || g == $"res_bytes"
    let sy:int64 = wrap_type(y)
    if g == $"temp" {                                    // OS.mkstemp (#97): {io, path}, or errno
        put("({ ")
        put_ctype(sy)
        put(" _kv_t = {0}; int _kv_e = kv_os_mkstemp(")
        if !put_os_args(n, &args) { return }
        put(", &_kv_t.io, &_kv_t.path); _kv_e ? _kv_")
        put_tok(types[y].name)
        put("_make_err(_kv_e) : _kv_")
        put_tok(types[y].name)
        put("_make_ok(_kv_t); })")
        return
    }
    if !made && os_structs.get(g, -1) >= 0 {    // the runtime's kv_<g> copied into kc's struct, member by member (#95, #102)
        put("({ kv_")
        put(g.cstr)
        put(" _kv_st = {0}; int _kv_e = kv_os_")
        put_tok(nodes[n].t)
        put("(")
        if !put_os_args(n, &args) { return }
        if has_args { put(", ") }
        put("&_kv_st); _kv_e ? _kv_")
        put_tok(types[y].name)
        put("_make_err(_kv_e) : _kv_")
        put_tok(types[y].name)
        put("_make_ok((")
        put_ctype(sy)
        put("){")
        var f:int64 = nodes[struct_of(sy)].a
        while f >= 0 {
            put(".")
            put_tok(nodes[f].t)
            put(" = _kv_st.")
            put_tok(nodes[f].t)
            f = nodes[f].next
            if f >= 0 { put(", ") }
        }
        put("}); })")
        return
    }
    if !made {
        put(fname.cstr)
        put_tok(nodes[n].t)
        put("(")
        if !put_os_args(n, &args) { return }
        put(")")
        return
    }
    put("({ ")
    if g == $"res_string" || g == $"opt_string" { put("kv_string _kv_s = {0}; ") }
    if g == $"res_bytes" { put("kv_bytes _kv_b = {0}; ") }
    if g == $"listdir" { put("kv_string *_kv_at = NULL; size_t _kv_n = 0; ") }
    if g == $"ints" { put("int32_t *_kv_at = NULL; size_t _kv_n = 0; ") }
    if g == $"opt_cstr" {
        put("const uint8_t *_kv_v = ")
    } else if g == $"opt_string" {
        put("bool _kv_some = ")
    } else {
        put("int _kv_e = ")
    }
    put(fname.cstr)
    put_tok(nodes[n].t)
    put("(")
    if !put_os_args(n, &args) { return }
    if g != $"opt_cstr" {
        if has_args { put(", ") }
        put(g == $"res_bytes" ? "&_kv_b" : g == $"listdir" || g == $"ints" ? "&_kv_at, &_kv_n" : "&_kv_s")
    }
    put("); ")
    if g == $"listdir" || g == $"ints" {
        let ay:int64 = wrap_type(y)                      // the Array of the ok
        put_array_name(ay)
        put(" _kv_a = ")
        put_array_name(ay)
        put("_from(_kv_at, _kv_n); free(_kv_at); ")
    }
    if g == $"opt_cstr" || g == $"opt_string" {
        put(g == $"opt_cstr" ? "_kv_v ? _kv_" : "_kv_some ? _kv_")
        put_tok(types[y].name)
        put(g == $"opt_cstr" ? "_make_some(_kv_v) : _kv_" : "_make_some(_kv_s) : _kv_")
        put_tok(types[y].name)
        put("_make_none(); })")
        return
    }
    put("_kv_e ? _kv_")
    put_tok(types[y].name)
    put("_make_err(_kv_e) : _kv_")
    put_tok(types[y].name)
    put(g == $"res_bytes" ? "_make_ok(_kv_b); })" : g == $"res_string" ? "_make_ok(_kv_s); })" : "_make_ok(_kv_a); })")
}

// ---------- a number's text (#447) ----------

var block_store:$[String]   // the storage the statement being written makes, a template's or a number's text, declared before it (#445, #447)
var anon_fns:$[int64]                     // the functions kc makes of { ... }, written after the others

// whether n is v.cstr of what print shows by its printer, an enum with
// values, an Optional, a Result or a struct with no member of that name:
// its text, as kelvinc's .cstr (#53, #122), in its block's storage (#450)
let shown_cstr(n:int64):bool {
    if nodes[n].kind != N_FIELD || !tok_is(nodes[n].t, "cstr") || tagged_named(nodes[n].a) >= 0 { return false }
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return false }
    let d = tagged_of(y)
    if d >= 0 { return case_named(d, nodes[n].t) == none }
    let sd = struct_of(y)
    if sd < 0 { return false }
    var m:int64 = nodes[sd].a
    while m >= 0 {
        if same_text(nodes[m].t, nodes[n].t) { return false }
        m = nodes[m].next
    }
    return true
}

// v.cstr, as `${v}` writes it: by its printer into a String, then into
// storage the statement declares before it; cut past KV_TEMPLATE_STR,
// where kelvinc sizes it by the type (#450)
let gen_shown_cstr(n:int64, a:int64, y:int64) {
    if current >= 0 && nodes[current].kind == D_GLOBAL {
        gen_error(n, "kc makes a value's text in a function: not yet in a global's initializer")
        return
    }
    if !need_show(y, n) { return }
    serial += 1
    let s = serial
    put("({ KV_TEMPLATE_BUILD(_kv_build")
    put_int(s)
    put(", _kv_template")
    put_int(s)
    put("); kv_string _kv_value")
    put_int(s)
    put(" = kv_string_new(); { __auto_type _kv_sv = (")
    gen_expr(a)
    put("); ")
    put_show_name(y)
    put("(&(kv_out){.s = &_kv_value")
    put_int(s)
    put(", .width = 2}, &_kv_sv, -1); } KV_TEMPLATE_VALUE(_kv_build")
    put_int(s)
    put(", KV_TEMPLATE_STR, _kv_value")
    put_int(s)
    put("); kv_string_free(&_kv_value")
    put_int(s)
    put("); KV_TEMPLATE_TAKE(_kv_template")
    put_int(s)
    put(", _kv_build")
    put_int(s)
    put("); })")
    var d = $"char _kv_template"
    d += String(s)
    d += "[1 + KV_TEMPLATE_STR]"
    block_store += &d
}

// whether n is x.cstr of a number, a bool, a uchr, a cstr or another
// pointer, as kelvinc's (#22, #462): its text in its block's storage, a
// cstr's itself, another pointer's address, nowhere of a null one
let scalar_cstr(n:int64):bool {
    if nodes[n].kind != N_FIELD || !tok_is(nodes[n].t, "cstr") { return false }
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return false }
    let k = types[y].kind
    return is_number_kind(k) || k == Y_BOOL || k == Y_UCHR || k == Y_CSTR || k == Y_PTR
}

// x.cstr, as kelvinc writes it: by the prelude's KV_PROPERTY_cstr of x's
// type into a buffer the statement declares before it, KV_CSTR_SCALAR
// long; a bool as one, where C's < gives an int (#462)
let gen_scalar_cstr(n:int64) {
    if current >= 0 && nodes[current].kind == D_GLOBAL {
        gen_error(n, "kc makes a value's text in a function: not yet in a global's initializer")
        return
    }
    serial += 1
    let s = serial
    var d = $"uint8_t _kv_text"
    d += String(s)
    d += "[KV_CSTR_SCALAR]"
    block_store += &d
    let a:int64 = nodes[n].a
    let flag = types[type_of(a)].kind == Y_BOOL
    put("({ __auto_type _kv_nt = ((void)0, (")
    if flag { put("(bool)(") }
    gen_expr(a)
    if flag { put(")") }
    put(")); _Generic((_kv_nt), KV_PROPERTY_cstr default: kv_cstr_ptr)(_kv_nt, _kv_text")
    put_int(s)
    put("); })")
}

// what n is of x.size, p.addr, p.next and p.prev, as kelvinc's (#26,
// #37, #462): 1 of x.size, sizeof x, of what has no member of the name;
// 2 of the address of a pointer or a function; 3 of a pointer stepped;
// 0 of none of them, -1 where it is kelvinc's error
let pointer_property(n:int64):int64 {
    if nodes[n].kind != N_FIELD { return 0 }
    let t:int64 = nodes[n].t
    let size = tok_is(t, "size")
    let addr = tok_is(t, "addr")
    let step = tok_is(t, "next") || tok_is(t, "prev")
    if !size && !addr && !step { return 0 }
    if tagged_named(nodes[n].a) >= 0 { return 0 }
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return 0 }
    let k = types[y].kind
    if k == Y_C { return 0 }                            // what only C sees has its own
    let sd = struct_of(y)
    if sd >= 0 {                                         // a field of the name wins; a struct's size is sizeof
        var m:int64 = nodes[sd].a
        while m >= 0 {
            if same_text(nodes[m].t, t) { return 0 }
            m = nodes[m].next
        }
        if !size { return 0 }
    }
    let d = tagged_of(y)
    if d >= 0 && case_named(d, t) != none { return 0 }  // v.c of an enum with values, its case's
    if size {
        if k == Y_FIXED || (k == Y_PTR && types[types[y].elem].kind == Y_FIXED) { return 0 }   // as before (#354, #362)
        return 1
    }
    if addr {
        if k == Y_PTR || k == Y_CSTR || k == Y_FN { return 2 }
        gen_error(n, k == Y_FIXED ? "'.addr' of an array: an array is no pointer; write '(&a[0]).addr'" : "'.addr' is a property of pointers and functions")
        return 0 - 1
    }
    if k == Y_PTR { return 3 }
    if k == Y_CSTR {
        gen_error(n, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a 'var p:u8^ := s'")
        return 0 - 1
    }
    if k == Y_FIXED {
        var m = $"'."
        m += tok_text(t)
        m += tok_is(t, "next") ? "' is a property of pointers: for an array, write '&a[1]'" : "' is a property of pointers: for an array, write '&a[-1]'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    return 0
}

// x.size, p.addr, p.next and p.prev, as kelvinc writes them (#462):
// sizeof x, a function's a pointer's; (uintptr_t)(p); (p + 1), (p - 1)
let gen_pointer_property(n:int64) {
    let a:int64 = nodes[n].a
    let p = pointer_property(n)
    if p == 1 && types[type_of(a)].kind == Y_FN {
        put("((uint64_t)sizeof(void *))")                // C's size, a u64 (#472)
    } else if p == 1 {
        put("((uint64_t)sizeof(")
        gen_expr(a)
        put("))")
    } else if p == 2 {
        put("((uintptr_t)(")
        gen_expr(a)
        put("))")
    } else {
        put("((")
        gen_expr(a)
        put(tok_is(nodes[n].t, "next") ? ") + 1)" : ") - 1)")
    }
}

// the size of the buffer x.dec, x.hex, x.oct or x.bin writes into, its
// NUL included, as kelvinc's number_text_size (#21); 0 of another member
let number_text_size(n:int64):int64 {
    if nodes[n].kind != N_FIELD { return 0 }
    let t:int64 = nodes[n].t
    if tok_is(t, "dec") { return 41 }                   // an i128's, the longest
    if tok_is(t, "hex") { return 36 }
    if tok_is(t, "oct") { return 47 }
    if tok_is(t, "bin") { return 132 }
    return 0
}

// whether n is x.dec, x.hex, x.oct or x.bin of a number, or x.hex of a
// pointer, text in its block's storage
let number_text(n:int64):bool {
    if number_text_size(n) == 0 { return false }
    let y:int64 = int_view(type_of(nodes[n].a))
    if y < 0 { return false }
    let k = types[y].kind
    return is_int_kind(k) || k == Y_F64 || k == Y_F32 || ((k == Y_PTR || k == Y_CSTR) && tok_is(nodes[n].t, "hex"))
}

// whether x.dec and the rest of a receiver of kind k are refused, as
// kelvinc refuses them: .oct and .bin of a float, any of what is no
// number, .hex of a pointer aside; where they are, the error
let number_text_refused(n:int64, k:ykind):bool {
    let t:int64 = nodes[n].t
    let w:String = tok_text(t)
    let floating = k == Y_F64 || k == Y_F32
    if is_int_kind(k) || (floating && (tok_is(t, "dec") || tok_is(t, "hex"))) || ((k == Y_PTR || k == Y_CSTR) && tok_is(t, "hex")) { return false }
    var m = $"'."
    m += &w
    if floating {
        m += "' is a property of integers; f32 and f64 have .dec and .hex"
    } else {
        m += "' is a property of integers"
        m += tok_is(t, "hex") ? ", of f32/f64, and of pointers and functions" : tok_is(t, "dec") ? " and of f32/f64" : ""
    }
    gen_error(n, m.cstr)
    return true
}

// x.dec, x.hex, x.oct or x.bin, as kelvinc writes it: by the prelude's
// writer of x's type, into a buffer the statement declares before it,
// which lives until the block ends; x.hex of a pointer its address
let gen_number_text(n:int64, y:int64) {
    if current >= 0 && nodes[current].kind == D_GLOBAL {
        gen_error(n, "kc makes a number's text in a function: not yet in a global's initializer")
        return
    }
    serial += 1
    let s = serial
    var d = $"uint8_t _kv_text"
    d += String(s)
    d += "["
    d += String(number_text_size(n))
    d += "]"
    block_store += &d
    let a:int64 = nodes[n].a
    if types[y].kind == Y_PTR || types[y].kind == Y_CSTR {
        put("kv_hex_addr((uintptr_t)(")
        gen_expr(a)
        put(")")
    } else {
        put("({ __auto_type _kv_nt = ((void)0, (")
        gen_expr(a)
        put(")); _Generic((_kv_nt), KV_PROPERTY_")
        put_tok(nodes[n].t)
        put(" default: kv_no_such_property)(_kv_nt")
    }
    put(", _kv_text")
    put_int(s)
    put(types[y].kind == Y_PTR || types[y].kind == Y_CSTR ? ")" : "); })")
}

// ---------- template literals (#445) ----------


// whether v, a value of a template, is v.pretty or v.pretty(n) of what
// print shows by a _kv_show_T, as kelvinc's ${v.pretty} (#126, #127)
let tpl_pretty(v:int64):bool {
    let k = nodes[v].kind
    if (k != N_FIELD && k != N_METHOD) || !tok_is(nodes[v].t, "pretty") { return false }
    if k == N_METHOD && (nodes[v].b < 0 || nodes[nodes[v].b].next >= 0) { return false }
    return shown_by_type(type_of(nodes[v].a))
}

// what of v a template shows: its receiver where it is v.pretty
let tpl_shown(v:int64):int64 {
    return tpl_pretty(v) ? nodes[v].a : v
}

// the room of a part's text, its bytes: each escape as long as it is
// written, which is no shorter than what it gives
let tpl_room(t:int64):int64 {
    var r:int64 = 0
    for i in 1..<toks[t].len - 1 {
        let c = codes[toks[t].at + i]
        r += c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
    }
    return r
}

// the longest text of the value v, as kelvinc's template_bound: a number
// 24 at most, as C may promote it, a bool 5, a uchr 4, a Bits 72, a
// nested template its storage, and KV_TEMPLATE_STR, at least 64, for the
// rest, a string's cut at that
let tpl_bound(v:int64):String {
    if nodes[v].kind == N_TPL && nodes[v].flag == 0 {
        var b = $"(sizeof _kv_template"
        b += String(nodes[v].c)
        b += " - 1)"
        return b
    }
    if nodes[v].kind == N_NUM || nodes[v].kind == N_CHAR { return $"24" }
    let y = type_of(v)
    if y < 0 { return $"KV_TEMPLATE_STR" }
    let k = types[y].kind
    if k == Y_I128 { return $"40" }                      // the longest, as kelvinc's (#472)
    if k == Y_U128 { return $"39" }
    if is_number_kind(k) { return $"24" }
    if k == Y_BOOL { return $"5" }
    if k == Y_UCHR { return $"4" }
    return $"KV_TEMPLATE_STR"                            // a Bits too, cut as a string is (#455)
}

// whether a template can show v, as kelvinc's parse_template: not a
// function, a Task or a fixed array but of bytes; where it cannot, an error
let tpl_value_ok(v:int64):bool {
    if nodes[v].kind == N_ID && fn_named(nodes[v].t) >= 0 && local_at(nodes[v].t) < 0 {
        gen_error(v, "a template cannot show a function: a function has no text")
        return false
    }
    let w = tpl_shown(v)
    let y = type_of(w)
    if failed { return false }
    if y < 0 { return true }
    let k = types[y].kind
    if k == Y_FN {
        gen_error(v, "a template cannot show a function: a function has no text")
        return false
    }
    if k == Y_TASK {
        gen_error(v, "a Task has no text: show its value, as in ${await t}")
        return false
    }
    if k == Y_FIXED && types[types[y].elem].kind != Y_U8 {
        gen_error(v, "kc shows a fixed array by print, as kelvinc's [a, b]; not yet in a template: show its elements, a[i]")
        return false
    }
    if shown_by_type(y) && !need_show(y, v) { return false }
    return true
}

// _kv_show_T(&(kv_out){.s = &s, .width = w}, &_kv_sv, level) of the
// value v, which print shows by its printer, into the String named s
let tpl_show(v:int64, s:cstr) {
    let w = tpl_shown(v)
    let y = type_of(w)
    put("{ __auto_type _kv_sv = (")
    gen_expr(w)
    put("); ")
    put_show_name(y)
    put("(&(kv_out){.s = &")
    put(s)
    put(", .width = ")
    if tpl_pretty(v) && nodes[v].kind == N_METHOD {      // v.pretty(n): n spaces a level (#127)
        let n:int64 = nodes[v].b
        if nodes[n].kind == N_NUM {
            gen_expr(n)
        } else {
            put("kv_out_width(")
            gen_expr(n)
            put(")")
        }
    } else {
        put("2")
    }
    put("}, &_kv_sv, ")
    put(tpl_pretty(v) ? "0" : "-1")
    put("); } ")
}

let gen_array_sort(n:int64)    // prototypes: xs.sort(), xs.sorted(), xs.reverse(), xs.reversed() (#470)
let gen_array_reverse(n:int64)
let gen_join(n:int64)    // prototypes: xs.join(sep) (#461)
let put_string_part(y:int64, v:cstr)
let gen_text_template(n:int64)    // prototypes: gen_template writes the two by them
let gen_string_template(n:int64)

// `a${x}b`, as kelvinc writes it (#39, #44): built in a buffer of a
// statement expression from the parts and each value in turn, then
// copied into its storage, `char _kv_templateN[...]`, which the statement
// declares before it, so the text lives until the block ends; an owner
// an expression gives held in it, freed once the text is made; $`a${x}b`
// (#67) appended to a String
let gen_template(n:int64) {
    if current >= 0 && nodes[current].kind == D_GLOBAL {
        gen_error(n, "a template literal with ${...} is made at run time, and a global's initializer must be constant: make it in a function")
        return
    }
    var x:int64 = nodes[n].b
    var value = false
    var holds:$[int64] = $[]
    while x >= 0 {                                       // each value, checked, and held where it gives an owner
        if value {
            if !tpl_value_ok(x) { return }
            if needs_hold(tpl_shown(x)) { holds += tpl_shown(x) }
        }
        value = !value
        x = nodes[x].next
    }
    put("({ ")
    for i in 0..<holds.count as int64 { hold_decl(holds[i]) }
    if nodes[n].flag == 1 {
        gen_string_template(n)
    } else {
        gen_text_template(n)
    }
    for i in 0..<holds.count as int64 { held[holds[i]] = 0 - 1 }
    put(" })")
}

let gen_text_template(n:int64) {
    serial += 1
    let s = serial
    nodes[n].c = s
    var b = $"_kv_build"
    b += String(s)
    var room:int64 = 1                                   // its NUL
    var bounds = $""
    put("KV_TEMPLATE_BUILD(")
    put(b.cstr)
    put(", _kv_template")
    put_int(s)
    put("); ")
    var x:int64 = nodes[n].b
    var value = false
    while x >= 0 && !failed {
        if !value {
            if toks[nodes[x].t].len > 2 {
                put("KV_TEMPLATE_PART(")
                put(b.cstr)
                put(", ")
                put_text(nodes[x].t, 0)
                put("); ")
                room += tpl_room(nodes[x].t)
            }
        } else {
            let y = type_of(tpl_shown(x))
            if y >= 0 && (tpl_pretty(x) || shown_by_type(y)) {   // ${xs} (#125): by its printer, cut as a string is
                serial += 1
                var v = $"_kv_value"
                v += String(serial)
                put("kv_string ")
                put(v.cstr)
                put(" = kv_string_new(); ")
                tpl_show(x, v.cstr)
                put("KV_TEMPLATE_VALUE(")
                put(b.cstr)
                put(", KV_TEMPLATE_STR, ")
                put(v.cstr)
                put("); kv_string_free(&")
                put(v.cstr)
                put("); ")
                bounds += " + KV_TEMPLATE_STR"
            } else if y >= 0 && types[y].kind == Y_FIXED {   // a byte array, up to a NUL or its end
                put("KV_TEMPLATE_BYTES(")
                put(b.cstr)
                put(", KV_TEMPLATE_STR, sizeof (")
                gen_expr(x)
                put("), (")
                gen_expr(x)
                put(")); ")
                bounds += " + KV_TEMPLATE_STR"
            } else {
                serial += 1
                let v = serial
                put("__auto_type _kv_value")
                put_int(v)
                put(" = ((void)0, (")
                if y >= 0 && types[y].kind == Y_BOOL { put("(bool)") }   // true, not 1, as kelvinc casts it
                gen_expr(x)
                let bound:String = tpl_bound(x)          // a nested template's storage, named once it is written
                put(")); KV_TEMPLATE_VALUE(")
                put(b.cstr)
                put(", ")
                put(bound.cstr)
                put(", _kv_value")
                put_int(v)
                put("); ")
                bounds += " + "
                bounds += &bound
            }
        }
        value = !value
        x = nodes[x].next
    }
    put("KV_TEMPLATE_TAKE(_kv_template")
    put_int(s)
    put(", ")
    put(b.cstr)
    put(");")
    var d = $"char _kv_template"
    d += String(s)
    d += "["
    d += String(room)
    d += &bounds
    d += "]"
    block_store += &d
}

let gen_string_template(n:int64) {
    put("kv_string _kv_s = kv_string_new(); ")
    var x:int64 = nodes[n].b
    var value = false
    while x >= 0 && !failed {
        if !value {
            if toks[nodes[x].t].len > 2 {
                put("kv_string_append_text(&_kv_s, ")
                put_text(nodes[x].t, 0)
                put("); ")
            }
        } else {
            let y = type_of(tpl_shown(x))
            let k:ykind = y >= 0 ? types[y].kind : Y_C
            if y >= 0 && (tpl_pretty(x) || shown_by_type(y)) {   // ${xs} (#125): its text, whole
                tpl_show(x, "_kv_s")
            } else if k == Y_STRING {                    // a String's by reference
                put("kv_string_append_ref(&_kv_s, &(")
                gen_expr(x)
                put(")); ")
            } else if k == Y_BYTES {
                put("kv_string_append_text(&_kv_s, kv_bytes_cstr(&(")
                gen_expr(x)
                put("))); ")
            } else if k == Y_UCHR {                      // a uchr as its character
                put("kv_string_append_uchr(&_kv_s, ")
                gen_expr(x)
                put("); ")
            } else if nodes[x].kind == N_STR || nodes[x].kind == N_TPL || k == Y_CSTR {
                put("kv_string_append_text(&_kv_s, ")
                gen_expr(x)
                put("); ")
            } else if k == Y_FIXED {                     // a byte array, up to a NUL or its end
                put("{ uint8_t _kv_t[sizeof (")
                gen_expr(x)
                put(") + 1] = {0}; memcpy(_kv_t, ")
                gen_expr(x)
                put(", sizeof (")
                gen_expr(x)
                put(")); kv_string_append_text(&_kv_s, _kv_t); } ")
            } else {                                     // a number's text, as .cstr writes it
                put("{ uint8_t _kv_t[256]; __auto_type _kv_v = ((void)0, (")
                if k == Y_BOOL { put("(bool)") }
                gen_expr(x)
                put(")); kv_string_append_text(&_kv_s, _Generic((_kv_v), KV_PROPERTY_cstr default: kv_cstr_ptr)(_kv_v, _kv_t)); } ")
            }
        }
        value = !value
        x = nodes[x].next
    }
    put("_kv_s;")
}

// xs.join(sep) and xs.joined(sep), one method, as kelvinc's #461: a new
// String of the elements, each appended as $`${x}` appends it, sep
// before all but the first, read once; sep a cstr, a String in a
// variable or a uchr, none of none; an Array an expression gives held
let gen_join(n:int64) {
    let t:int64 = nodes[n].t
    let a:int64 = nodes[n].a
    let y:int64 = type_of(a)
    let ey:int64 = types[y].elem
    let sep:int64 = nodes[n].b
    if sep >= 0 && nodes[sep].next >= 0 {
        var m = $"'."
        m += tok_text(t)
        m += "' takes the text between the elements, or none: '."
        m += tok_text(t)
        m += "(\", \")'"
        gen_error(nodes[sep].next, m.cstr)
        return
    }
    var sy:int64 = 0 - 1
    if sep >= 0 {
        sy = type_of(sep)
        if failed { return }
        let sk:ykind = sy >= 0 ? types[sy].kind : Y_C
        if !(nodes[sep].kind == N_STR || nodes[sep].kind == N_TPL || sk == Y_CSTR || sk == Y_STRING || sk == Y_UCHR) {
            var m = $"'."
            m += tok_text(t)
            m += "' puts text between the elements: a cstr, a String or a uchr, and this is "
            let w:String = nodes[sep].kind == N_NUM || nodes[sep].kind == N_CHAR || sy < 0 ? $"a number" : kelvin_type_text(sy)
            m += &w
            gen_error(sep, m.cstr)
            return
        }
        if sk == Y_STRING && !is_place(sep) {
            var m = $"'."
            m += tok_text(t)
            m += "' takes a String that an expression gives, which nothing would free: bind it to a variable first"
            gen_error(sep, m.cstr)
            return
        }
    }
    let ek:ykind = types[ey].kind
    if ek == Y_FN || ek == Y_TASK || ek == Y_FIXED {     // as a template has them
        gen_error(n, ek == Y_TASK ? "a Task has no text: show its value, as in ${await t}" : ek == Y_FN ? "a template cannot show a function: a function has no text" : "kc shows a fixed array by print, as kelvinc's [a, b]; not yet in a template: show its elements, a[i]")
        return
    }
    if shown_by_type(ey) && !need_show(ey, n) { return }
    let h = needs_hold(a)                                // one an expression gives, held and freed after
    if h { hold_open(a) }
    put("({ const ")
    put_ctype(y)
    put(" *_kv_ja = ")
    gen_place(a)
    put("; ")
    if sep >= 0 {
        put("__auto_type _kv_jsep = ((void)0, (")
        gen_expr(sep)
        put(")); ")
    }
    put("kv_string _kv_js = kv_string_new(); for (size_t _kv_ji = 0; _kv_ji < _kv_ja->count; _kv_ji++) { __auto_type _kv_je = _kv_ja->at[_kv_ji]; ")
    if sep >= 0 {
        put("if (_kv_ji) { ")
        put_string_part(sy, "_kv_jsep")
        put("} ")
    }
    put_string_part(ey, "_kv_je")
    put("} _kv_js; })")
    if h { hold_close(a) }
}

// the value v, a C name of type y, appended to the String _kv_js as
// $`${x}` appends it (#461): by its printer, a String by reference, a
// uchr as its character, text as it is, a number's or a bool's text
let put_string_part(y:int64, v:cstr) {
    let k:ykind = types[y].kind
    if shown_by_type(y) {
        put("{ __auto_type _kv_sv = (")
        put(v)
        put("); ")
        put_show_name(y)
        put("(&(kv_out){.s = &_kv_js, .width = 2}, &_kv_sv, -1); } ")
    } else if k == Y_STRING {
        put("kv_string_append_ref(&_kv_js, &(")
        put(v)
        put(")); ")
    } else if k == Y_BYTES {
        put("kv_string_append_text(&_kv_js, kv_bytes_cstr(&(")
        put(v)
        put("))); ")
    } else if k == Y_UCHR {
        put("kv_string_append_uchr(&_kv_js, ")
        put(v)
        put("); ")
    } else if k == Y_CSTR {
        put("kv_string_append_text(&_kv_js, ")
        put(v)
        put("); ")
    } else {
        put("{ uint8_t _kv_t[256]; __auto_type _kv_v = ((void)0, (")
        if k == Y_BOOL { put("(bool)") }
        put(v)
        put(")); kv_string_append_text(&_kv_js, _Generic((_kv_v), KV_PROPERTY_cstr default: kv_cstr_ptr)(_kv_v, _kv_t)); } ")
    }
}

// the text in its block's storage that e is, through ?: and a cast, as
// kelvinc's text_in_buffer: a template, `a${x}b`, not $`...` (#445), or
// a number's .dec, .hex, .oct or .bin (#447); or -1
let text_in_buffer(e:int64):int64 {
    let k = nodes[e].kind
    if k == N_TPL { return nodes[e].flag == 0 ? e : 0 - 1 }
    if number_text(e) || shown_cstr(e) || scalar_cstr(e) { return e }   // .cstr of what print shows too (#450), of a number (#462)
    if k == N_CAST { return text_in_buffer(nodes[e].a) }
    if k == N_COND {
        let b = text_in_buffer(nodes[e].b)
        return b >= 0 ? b : text_in_buffer(nodes[e].c)
    }
    return 0 - 1
}

// the words for the text in a buffer, x: "a template's text", or
// "'.hex' text"
let buffer_text_words(x:int64):String {
    if nodes[x].kind == N_TPL { return $"a template's text" }
    var w = $"'."
    w += tok_text(nodes[x].t)
    w += "' text"
    return w
}

// whether the assignment n gives text in its block's storage to a
// variable of an outer block, or a global, which would keep it after
// its block ends, as kelvinc's reject_template_escape of a template; the
// function's own parameters end with its body. Where it does, the error
// (#445); of a number's text too, which kelvinc lets go (#447)
let text_outlived(n:int64):bool {
    let lhs:int64 = nodes[n].a
    let x:int64 = nodes[lhs].kind == N_ID ? text_in_buffer(nodes[n].b) : 0 - 1
    if x < 0 { return false }
    let i = local_at(nodes[lhs].t)
    let here:int64 = marks.count > 0 ? marks[marks.count - 1] : 0
    if i >= here || (i >= 0 && marks.count == 2 && i >= marks[0]) { return false }
    var m = buffer_text_words(x)
    m += " lives until this block ends, and '"
    let name:String = tok_text(nodes[lhs].t)
    m += &name
    m += "' outlives it: make the text in the block of '"
    m += &name
    m += "', or copy it, as in '"
    m += &name
    m += " := strdup(...)'"
    gen_error(n, m.cstr)
    return true
}

// the storage the statement at `at` made, declared just before it, in
// its block, where kelvinc declares it at the top of the block: the text
// lives until the block ends (#445, #447)
let place_storage(at:int64, made:int64, depth:int64) {
    var line = $""
    for i in made..<block_store.count as int64 {
        for _ in 0..<depth { line += "    " }
        let d:String = block_store[i].copy()
        line += &d
        line += ";\n"
    }
    while block_store.count as int64 > made { block_store.pop() }
    var placed:String = out[0..<at]
    placed += &line
    let rest:String = out[at..<out.count as int64]
    placed += &rest
    out = placed.copy()
}

let refuse_valueless_args(n:int64):bool    // a prototype: each call asks it (#317)

// whether String(...) of the call n is refused, as kelvinc's converter
// refuses it (#412, #414): more than one value; an owner a place holds,
// which would be copied; an owner an expression gives, which C took for
// text: a String one already, else what String takes and what this is
let string_args_refused(n:int64):bool {
    let x:int64 = nodes[n].b
    let takes:cstr := "String takes nothing, text, or a borrow of a Bytes, '&b'"
    if x >= 0 && nodes[x].next >= 0 {
        gen_error(n, takes)
        return true
    }
    if x < 0 || is_case_word(x) { return false }
    let y:int64 = type_of(x)
    if !is_owner(y) { return false }
    if is_place(x) {
        gen_error(n, "String(x) would copy an owner: write x.copy(), String(&b) of a Bytes, or b.string() for a Result")
        return true
    }
    if types[y].kind == Y_STRING {
        gen_error(n, "String(x) of a String is one already: leave out String(...)")
        return true
    }
    var m = $""
    m += takes
    m += ", and this is "
    let w:String = kelvin_type_text(y)
    m += &w
    gen_error(n, m.cstr)
    return true
}

// the type of the converter T(v) the call n is, as kelvinc's #36: a
// number type's or bool's name called, no function's or variable's; or -1
let converter_of(n:int64):int64 {
    let f:int64 = nodes[n].a
    if nodes[f].kind != N_ID { return 0 - 1 }
    let t:int64 = nodes[f].t
    if var_type(t) >= 0 || fn_named(t) >= 0 { return 0 - 1 }
    if number_word(t) >= 0 { return number_word(t) }    // int64 or i64 (#430)
    if tok_is(t, "bool") { return base_type(Y_BOOL) }
    return 0 - 1
}

// whether the call n is uchr(x), a codepoint of a number or of text, as
// kelvinc's #56: no function's or variable's (#478)
let uchr_call(n:int64):bool {
    let f:int64 = nodes[n].a
    if nodes[f].kind != N_ID || !tok_is(nodes[f].t, "uchr") { return false }
    return var_type(nodes[f].t) < 0 && fn_named(nodes[f].t) < 0
}

// whether n is a uchr (#478)
let uchr_typed(n:int64):bool {
    let y:int64 = type_of(n)
    return y >= 0 && types[y].kind == Y_UCHR
}

// a comparison of a uchr, with a uchr or a number, by its codepoint, as
// kelvinc's #56; it has no arithmetic (#478)
let gen_uchr_compare(n:int64) {
    let t:int64 = nodes[n].t
    if !is_comparison(t) {
        var m = $"a uchr has no operator '"
        m += tok_text(t)
        m += "': its codepoint is 'c.utf32', a u32"
        gen_error(n, m.cstr)
        return
    }
    put("((bool)((")
    gen_expr(nodes[n].a)
    put(uchr_typed(nodes[n].a) ? ").cp " : ") ")
    put_tok(t)
    put(" (")
    gen_expr(nodes[n].b)
    put(uchr_typed(nodes[n].b) ? ").cp))" : ")))")
}

// whether y is a String or a Bytes by reference, String^ or Bytes^, whose
// text a converter reads (#495)
let owner_text_ref(y:int64):bool {
    let e:int64 = types[y].elem
    return types[y].kind == Y_PTR && e >= 0 && (types[e].kind == Y_STRING || types[e].kind == Y_BYTES)
}

// whether a converter reads v as text (#429): a cstr, a String, a u8^,
// an array of u8, or a ?: of them
let converter_text(v:int64):bool {
    if nodes[v].kind == N_COND { return converter_text(nodes[v].b) && converter_text(nodes[v].c) }
    let y:int64 = type_of(v)
    if y < 0 { return false }
    let k = types[y].kind
    if k == Y_CSTR || k == Y_STRING || k == Y_BYTES { return true }   // a Bytes too, as kelvinc's #88
    if k == Y_PTR && owner_text_ref(y) { return true }   // a String or a Bytes by reference, as kelvinc's #495
    return (k == Y_PTR || k == Y_FIXED) && types[y].elem >= 0 && types[types[y].elem].kind == Y_U8
}

// v as the runtime's readers take text (#429), as kelvinc's text_arg: a
// String's bytes, and a ?: of texts of arms of C types that differ
let put_text_arg(v:int64) {
    if nodes[v].kind == N_COND {
        put("(")
        gen_expr(nodes[v].a)
        put(" ? (const void *)")
        put_text_arg(nodes[v].b)
        put(" : (const void *)")
        put_text_arg(nodes[v].c)
        put(")")
        return
    }
    let y:int64 = type_of(v)
    if y >= 0 && owner_text_ref(y) {                     // &s is s, r is r^, as kelvinc's #495
        let string:bool = types[types[y].elem].kind == Y_STRING
        if nodes[v].kind == N_ADDR {
            put_text_arg(nodes[v].a)
            return
        }
        put(string ? "kv_bytes_cstr(&((*" : "kv_bytes_cstr(&(*")
        gen_expr(v)
        put(string ? ")).b)" : "))")
        return
    }
    if y >= 0 && types[y].kind == Y_STRING {
        put("kv_bytes_cstr(&(")
        gen_expr(v)
        put(").b)")
        return
    }
    if y >= 0 && types[y].kind == Y_BYTES {              // as kelvinc writes a Bytes' .cstr
        put("kv_bytes_cstr(&")
        gen_expr(v)
        put(")")
        return
    }
    put("(")
    gen_expr(v)
    put(")")
}

// uchr(x) (#478), as kelvinc writes it: KV_UCHR_OF, C's _Generic of an
// integer or of text; a uchr as it is; the rest an error in words, as
// kelvinc's (#494)
let gen_uchr(n:int64) {
    let v:int64 = nodes[n].b
    if v < 0 || nodes[v].next >= 0 {
        gen_error(n, "uchr(x) takes one value: a number, or text")
        return
    }
    let vy:int64 = type_of(v)
    if failed || vy < 0 { return }
    let k = types[vy].kind
    if k == Y_UCHR {                                     // uchr(c) is c
        gen_expr(v)
        return
    }
    // of a String or a Bytes, or one by reference, the first codepoint
    // of its text, as kelvinc's #494
    let pe:int64 = k == Y_PTR ? types[vy].elem : 0 - 1
    let ref:bool = pe >= 0 && (types[pe].kind == Y_STRING || types[pe].kind == Y_BYTES)
    if ref || k == Y_BYTES || k == Y_STRING {
        let w:int64 = ref && nodes[v].kind == N_ADDR ? nodes[v].a : v
        let bytes:bool = (ref ? types[pe].kind : k) == Y_BYTES
        var opened = hold_args(w, 0 - 1)
        put("(KV_UCHR_OF(kv_bytes_cstr(&")                 // as kelvinc writes .cstr: &s.b's, a Bytes itself
        if !bytes { put("(") }
        if ref && nodes[v].kind != N_ADDR {
            put("(*")
            gen_expr(v)
            put(")")
        } else {
            gen_expr(w)
        }
        put(bytes ? ")))" : ").b)))")
        close_holds(&opened)
        return
    }
    let unseen:bool = k == Y_C || (k == Y_STRUCT && struct_of(vy) < 0 && tagged_of(vy) < 0)
    let text:bool = converter_text(v)
    if !(text || unseen || is_int_kind(k)) {
        var m = $"uchr(x) takes an integer, a uchr or text, and this is "
        let w:String = k == Y_BOOL ? $"a bool" : kelvin_type_text(vy)
        m += &w
        if k == Y_F64 || k == Y_F32 { m += ": convert it to an integer first, uchr(i64(x))" }
        gen_error(v, m.cstr)
        return
    }
    put("(KV_UCHR_OF(")
    if text { put_text_arg(v) } else { gen_expr(v) }
    put("))")
}

// the reader of the converter of type y, and what follows its text, as
// kelvinc's text_number: an integer's base and limits, clamped to them
let put_text_read(y:int64) {
    let k = types[y].kind
    if k == Y_F64 || k == Y_F32 {
        put(k == Y_F64 ? "kv_text_f64" : "kv_text_f32")
        return
    }
    put(k == Y_I128 ? "kv_text_i128" : k == Y_U128 ? "kv_text_u128" : is_unsigned_kind(k) ? "kv_text_uint" : "kv_text_int")
}

let put_text_rest(y:int64, base:int64) {
    let k = types[y].kind
    if k == Y_F64 || k == Y_F32 {
        put(")")
        return
    }
    put(", ")
    if base >= 0 {
        put("(")
        gen_expr(base)
        put(")")
    } else {
        put("10")
    }
    if k == Y_I64 { put(", INT64_MIN, INT64_MAX)") }
    if k == Y_I32 { put(", INT32_MIN, INT32_MAX)") }
    if k == Y_I16 { put(", INT16_MIN, INT16_MAX)") }
    if k == Y_I8 { put(", INT8_MIN, INT8_MAX)") }
    if k == Y_U8 { put(", UINT8_MAX)") }
    if k == Y_U16 { put(", UINT16_MAX)") }
    if k == Y_U32 { put(", UINT32_MAX)") }
    if k == Y_U64 { put(", UINT64_MAX)") }
    if k == Y_I128 || k == Y_U128 { put(")") }
}

// T(v) and T(text, base), the converter n (#429), as kelvinc's #36: a
// number C's cast, text the number in it, read as strtol and strtod
// read it; what only C sees, C's _Generic chooses, as kelvinc's KV_TEXT
let gen_converter(n:int64) {
    let y:int64 = converter_of(n)
    let name:String = type_text(y)
    let v:int64 = nodes[n].b
    let base:int64 = v >= 0 ? nodes[v].next : 0 - 1
    let k = types[y].kind
    if base >= 0 && nodes[base].next < 0 && k == Y_BOOL {   // as kelvinc says it
        gen_error(base, "a base is for reading an integer from text; bool(...) takes one value")
        return
    }
    if v < 0 || (base >= 0 && nodes[base].next >= 0) {
        var m = $"a converter takes one value, and an integer type a base for text after it: "
        m += &name
        m += "(v) or "
        m += &name
        m += "(text, base)"
        gen_error(n, m.cstr)
        return
    }
    let vy:int64 = type_of(v)
    if failed { return }
    let text:bool = converter_text(v)
    if base >= 0 && (k == Y_F64 || k == Y_F32) {
        var m = $"a base is for reading an integer from text; "
        m += &name
        m += "(text) reads decimal, or C's hex floats as in \"0x1.8p1\""
        gen_error(base, m.cstr)
        return
    }
    let unseen = vy < 0 || types[vy].kind == Y_C || (types[vy].kind == Y_STRUCT && struct_of(vy) < 0 && tagged_of(vy) < 0)   // a C typedef too, size_t, whose kind C knows (#472)
    if base >= 0 && !text && !unseen {
        var m = $"a base is for reading text, as in "
        m += &name
        m += "(\"755\", 8); "
        m += &name
        m += " converts a number"
        gen_error(base, m.cstr)
        return
    }
    let number = !unseen && (is_number_kind(types[vy].kind) || types[vy].kind == Y_UCHR)
    if !text && !unseen && !number && !(k == Y_BOOL && (types[vy].kind == Y_PTR || types[vy].kind == Y_CSTR)) {
        var m = name.copy()
        m += " converts a number, or reads one from text, and this is "
        let w:String = kelvin_type_text(vy)
        m += &w
        gen_error(v, m.cstr)
        return
    }
    var opened = hold_args(v, 0 - 1)
    put("((")
    put_ctype(y)
    put(")")
    if text && k != Y_BOOL {
        put_text_read(y)
        put("(")
        put_text_arg(v)
        put_text_rest(y, base)
    } else if unseen && k != Y_BOOL {                    // text or a number, as C's _Generic sees it
        put("({ __auto_type _kv_conv = ((void)0, (")
        gen_expr(v)
        put(")); ")
        if base >= 0 {                                   // only text compiles, as kelvinc's
            put("(")
            put_ctype(y)
            put(")_Generic(KV_TEXT_TAG(_kv_conv), kv_text_tag *: ")
            put_text_read(y)
            put(", default: kv_base_needs_text)(KV_TEXT_PTR(_kv_conv)")
        } else {
            put("KV_TEXT(")
            put_ctype(y)
            put(", _kv_conv, ")
            put_text_read(y)
            put("(KV_TEXT_PTR(_kv_conv)")
        }
        put_text_rest(y, base)
        if base >= 0 {
            put("; })")
        } else {
            put("); })")
        }
    } else {
        put("(")
        gen_expr(v)
        put(types[vy].kind == Y_UCHR ? ").cp" : ")")   // i64(c) is i64(c.utf32), as kelvinc's (#478)
    }
    put(")")
    close_holds(&opened)
}

let gen_call(n:int64) {
    let f:int64 = nodes[n].a
    let args:int64 = nodes[n].b
    if refuse_valueless_args(n) { return }
    if nodes[f].kind == N_TYPE {
        if tok_is(nodes[f].t, "IO") {
            let fy:int64 = type_of(args)
            let by_fd = fy >= 0 && is_number_kind(types[fy].kind) && types[fy].kind != Y_F64 && types[fy].kind != Y_F32
            put(by_fd ? "kv_io_fdopen(" : "kv_io_open(")     // IO(fd, mode), a descriptor's, as kelvinc's #86 (#452)
            if fy >= 0 && types[fy].kind == Y_STRING && is_place(args) {   // a String's text, as kelvinc's .cstr of it (#463)
                put("kv_bytes_cstr(&(")
                gen_expr(args)
                put(").b)")
            } else {
                gen_expr(args)
            }
            put(", ")
            if nodes[args].next >= 0 {
                gen_expr(nodes[args].next)
            } else {
                put("\"r\"")                         // IO(path), to read, as kelvinc's (#449)
            }
            put(")")
        } else if tok_is(nodes[f].t, "Bytes") {
            gen_bytes_make(n)                      // (#439)
        } else {
            if string_args_refused(n) { return }
            if args < 0 {                          // String(), an empty one, as kelvinc's (#414)
                put("kv_string_new()")
                return
            }
            if nodes[args].kind == N_STR { put("KV_STRING_LIT(") } else { put("KV_STRING_OF(") }   // (#299)
            gen_expr(args)
            put(")")
        }
        return
    }
    if converter_of(n) >= 0 {                       // int64(v), int64(text, base) (#429)
        gen_converter(n)
        return
    }
    if uchr_call(n) {                               // uchr(x) (#478)
        gen_uchr(n)
        return
    }
    if tok_is(nodes[f].t, "println") || tok_is(nodes[f].t, "print") {
        var each:int64 = args
        while each >= 0 {                          // a lazy Sequence has no text, as kelvinc's (#324)
            let ey:int64 = type_of(each)
            if ey >= 0 && types[ey].kind == Y_FN {        // as kelvinc's (#428)
                var m = tok_text(nodes[f].t)
                m += " cannot show a function: a function has no text"
                gen_error(each, m.cstr)
                return
            }
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
    let fy:int64 = callee_type(f)                   // through a function value (#428)
    if fy >= 0 {
        gen_fn_call(n, fy)
        return
    }
    if failed { return }
    if nodes[f].kind == N_ID && var_type(nodes[f].t) >= 0 {   // a variable of no function type
        gen_error(n, "this calls a variable, which hides the function of its name here: rename one of them")
        return
    }
    let d = call_target(n)                          // the overload its arguments fit (#234)
    if generic_at.has(n) {                          // what only C sees chooses (#41)
        gen_generic_call(n)
        return
    }
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

// the type of parameter k of d
let param_at(d:int64, k:int64):int64 {
    var p:int64 = nodes[d].a
    var i = 0
    while p >= 0 && i < k {
        p = nodes[p].next
        i += 1
    }
    return p >= 0 ? nodes[p].ty : 0 - 1
}

// KV_NUMBER's code of a number's type, or nothing
let number_code(y:int64):cstr {
    switch types[y].kind {
    case Y_BOOL: return "KV_N_BOOL"
    case Y_U8: return "KV_N_U8"
    case Y_I32: return "KV_N_I32"
    case Y_U32: return "KV_N_U32"
    case Y_I8: return "KV_N_I8"
    case Y_I16: return "KV_N_I16"
    case Y_U16: return "KV_N_U16"
    case Y_U64: return "KV_N_U64"
    case Y_I128: return "KV_N_I128"
    case Y_U128: return "KV_N_U128"
    case Y_I64: return "KV_N_I64"
    case Y_F32: return "KV_N_F32"
    case Y_F64: return "KV_N_F64"
    default: return ""
    }
}

let put_generic_arg(base:int64, k:int64) {
    put("_kv_ga")
    put_int(base)
    put("_")
    put_int(k)
}

// the overloads of those cands whose parameter k is of type y
let overloads_taking(cands:const $[int64]^, k:int64, y:int64):$[int64] {
    var out_of:$[int64] = $[]
    for d in cands^ {
        if param_at(d, k) == y { out_of += d }
    }
    return out_of
}

// the choice among cands from argument k on, as kelvinc's generic_tree:
// over each argument only C sees where they differ; structs, pointers and
// C's types by their C types, numbers by KV_NUMBER, a number of another
// type to the one that takes a number, a pointer to the one that takes a
// pointer; with none, or with several, a name C reports (#41)
let put_generic_tree(cands:const $[int64]^, first:int64, base:int64, from:int64, nargs:int64, none:cstr) {
    if cands^.count == 1 {
        put_fn_name(cands^[0])
        return
    }
    var k:int64 = from
    while k < nargs {
        var a:int64 = first
        for _ in 0..<k { a = nodes[a].next }
        let ay:int64 = is_word_value(a) ? 0 - 1 : type_of(a)
        var differ = false
        for d in cands^ {
            if param_at(d, k) != param_at(cands^[0], k) { differ = true }
        }
        if differ && ay >= 0 && types[ay].kind == Y_C { break }
        k += 1
    }
    if k >= nargs {
        put(none)
        return
    }
    var kinds:$[int64] = $[]
    for d in cands^ {
        let y:int64 = param_at(d, k)
        var seen = false
        for x in kinds {
            if x == y { seen = true }
        }
        if !seen { kinds += y }
    }
    var closes = 0
    for y in kinds {
        if number_code(y)[0] != 0 { continue }
        put("_Generic((")
        put_generic_arg(base, k)
        put("), ")
        put_ctype(y)
        put(": ")
        let some:$[int64] = overloads_taking(cands, k, y)
        put_generic_tree(&some, first, base, k + 1, nargs, none)
        put(", default: ")
        closes += 1
    }
    var numbers = 0
    var pointers = 0
    var one_number:int64 = 0 - 1
    var one_pointer:int64 = 0 - 1
    for y in kinds {
        if number_code(y)[0] != 0 {
            numbers += 1
            one_number = y
            put("__builtin_choose_expr(KV_NUMBER(")
            put_generic_arg(base, k)
            put(") == ")
            put(number_code(y))
            put(", ")
            let some:$[int64] = overloads_taking(cands, k, y)
            put_generic_tree(&some, first, base, k + 1, nargs, none)
            put(", ")
            closes += 1
        } else if types[y].kind == Y_PTR || types[y].kind == Y_CSTR || types[y].kind == Y_FN {
            pointers += 1
            one_pointer = y
        }
    }
    if numbers > 0 {
        put("__builtin_choose_expr(KV_NUMBER(")
        put_generic_arg(base, k)
        put(") != 0, ")
        if numbers == 1 {
            let some:$[int64] = overloads_taking(cands, k, one_number)
            put_generic_tree(&some, first, base, k + 1, nargs, none)
        } else {
            put(none)
        }
        put(", ")
        closes += 1
    }
    if pointers > 0 {
        put("__builtin_choose_expr(KV_POINTER(")
        put_generic_arg(base, k)
        put("), ")
        if pointers == 1 {
            let some:$[int64] = overloads_taking(cands, k, one_pointer)
            put_generic_tree(&some, first, base, k + 1, nargs, none)
        } else {
            put(none)
        }
        put(", ")
        closes += 1
    }
    put(none)
    for _ in 0..<closes { put(")") }
}

var generic_serial:int64 = 0

// a call only C's _Generic chooses for (#41): its arguments in
// temporaries, a literal as the type kelvinc reads it, then the choice
let gen_generic_call(n:int64) {
    let first:int64 = nodes[n].b
    let at:int64 = generic_at.get(n, 0)
    var cands:$[int64] = $[]
    for i in 0..<generic_sets[at] { cands += generic_sets[at + 1 + i] }
    generic_serial += 1
    let base:int64 = generic_serial
    put("({ ")
    var a:int64 = first
    var nargs:int64 = 0
    while a >= 0 {
        put("__auto_type ")
        put_generic_arg(base, nargs)
        put(" = ((void)0, (")
        let k:nkind = nodes[a].kind
        let num:int64 = k == N_UNARY && tok_is(nodes[a].t, "-") ? nodes[a].a : a
        if nodes[num].kind == N_NUM && !float_tok(nodes[num].t) { put("(int64_t)") }
        gen_expr(a)
        put(")); ")
        nargs += 1
        a = nodes[a].next
    }
    put_generic_tree(&cands, first, base, 0, nargs, toks[nodes[nodes[n].a].t].kind == T_PUNCT ? "kv_no_such_operator" : "kv_no_such_overload")
    put("(")
    for i in 0..<nargs {
        if i > 0 { put(", ") }
        put_generic_arg(base, i)
    }
    put("); })")
}

let gen_member(n:int64)         // prototypes: the reading of a member and of a method, held or not (#227)
let gen_method_of(n:int64)

// a.t of what an expression gives (#227): a held, a member that owns
// copied out of it, as kelvinc does; a pointer into it an error
let is_made_array(n:int64):bool    // a prototype: gen_field asks it (#285)

let gen_field(n:int64) {
    if typename_member(n) {                              // (#426)
        gen_typename(n)
        return
    }
    let a:int64 = nodes[n].a
    if !needs_hold(a) || held.get(a, 0 - 1) >= 0 {     // held for the call around it (#245)
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
    if pretty_value(n) { return true }                  // a new String too (#336, #452)
    if types[y].kind == Y_SET { return tok_is(t, "elements") }
    if types[y].kind == Y_BITS { return tok_is(t, "bin") || tok_is(t, "u64s") }   // a new Array<String> (#456), Array<u64> (#472)
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
    if std_io(n) >= 0 {                                  // IO.stdout, never closed, as kelvinc's (#452)
        put("(*kv_io_std(")
        put_int(std_io(n))
        put("))")
        return
    }
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
    if shown_cstr(n) {                                   // v.cstr, its text (#450)
        gen_shown_cstr(n, a, y)
        return
    }
    let lent = is_place(a) || held.get(a, 0 - 1) >= 0    // a place, or one held in a temporary (#227)
    if tagged_of(y) >= 0 && tok_is(t, "case") {        // v.case, its tag (#477)
        if lent || !is_owner(y) {
            put("((")
            gen_expr(a)
            put(").tag)")
        } else {                                       // of a call's enum that owns: held, read and freed, as kelvinc's
            put("({ ")
            put_ctype(y)
            put(" _kv_t = ")
            gen_expr(a)
            put("; uint8_t _kv_c = _kv_t.tag; ")
            put_free(y)
            put("(&_kv_t); _kv_c; })")
        }
        return
    }
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
    if yk == Y_CSTR && tok_is(t, "count") {              // its strlen, measured each time, where kelvinc keeps it (#52, #447)
        put("((int64_t)strlen((const char *)(")
        gen_expr(a)
        put(")))")
        return
    }
    if number_text(n) {                                  // x.hex and the rest (#447)
        gen_number_text(n, y)
        return
    }
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
    } else if (tok_is(t, "count") && (yk == Y_STRING || yk == Y_BYTES || yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET)) || (yk == Y_BYTES && tok_is(t, "capacity")) {
        put("((int64_t)(")
        gen_expr(a)
        put(tok_is(t, "count") ? ").count)" : ").cap)")     // a Bytes's room (#439)
    } else if yk == Y_SET && tok_is(t, "elements") {     // s.elements (#278): an Array of copies, in the order added
        gen_slots_array(a, y, types[y].elem, false)
    } else if pretty_value(n) {                         // v.pretty (#336, #337), as kelvinc's #124: its text indented, a new String; of any printed value (#452)
        if !need_show(y, n) { return }
        put("({ kv_string _kv_ps = kv_string_new(); __auto_type _kv_sv = (")
        gen_expr(a)
        put("); ")
        put_show_name(y)
        put("(&(kv_out){.s = &_kv_ps, .width = 2}, &_kv_sv, 0); _kv_ps; })")
    } else if yk == Y_DICT && (tok_is(t, "keys") || tok_is(t, "values")) {   // d.keys, d.values (#285)
        gen_slots_array(a, y, tok_is(t, "keys") ? types[y].name : types[y].elem, tok_is(t, "values"))
    } else if yk == Y_IO && tok_is(t, "string") {        // f.string, a Result: err where its UTF-8 breaks (#406)
        let r:int64 = result_of(base_type(Y_STRING), base_type(Y_I64))
        put("({ kv_string _kv_s = {0}; int64_t _kv_e = kv_io_try_string(")
        gen_place(a)
        put(", &_kv_s); _kv_e >= 0 ? _kv_")
        put_tok(types[r].name)
        put("_make_err(_kv_e) : _kv_")
        put_tok(types[r].name)
        put("_make_ok(_kv_s); })")
    } else if yk == Y_IO && io_int_member(t) {          // f.error, f.status, f.signal, f.pid, f.fd, each its own (#452)
        put("kv_io_")
        put_tok(t)
        put("(")
        gen_place(a)
        put(")")
    } else if yk == Y_IO {
        gen_io_field(n, a)                              // f.bytes, f.stat and the rest (#464)
    } else if yk == Y_STRING && tok_is(t, "bytes") {    // its own bytes, borrowed (#464), as kelvinc's
        put("((const kv_bytes *)&(")
        gen_expr(a)
        put(").b)")
    } else if yk == Y_BYTES && tok_is(t, "isUTF8") {   // as kelvinc writes it (#464)
        put("kv_bytes_is_utf8(")
        gen_place(a)
        put(")")
    } else if (yk == Y_STRING || yk == Y_BYTES) && tok_is(t, "cstr") {
        put("kv_bytes_cstr(&(")
        gen_expr(a)
        put(yk == Y_STRING ? ").b)" : "))")                 // a Bytes's own, NUL-ended (#439)
    } else if tok_is(t, "uchr") {
        put("kv_uchr_of(")
        gen_expr(a)
        put(")")
    } else if tok_is(t, "utf32") || (yk == Y_UCHR && tok_is(t, "codepoint")) {
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
    let my:int64 = member_fn_type(n)
    if my >= 0 {                                        // s.f(x) through a member of a function type (#428)
        gen_fn_call(n, my)
        return
    }
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

// ---------- an Array's methods (#438) ----------

// kelvinc's error of v, an owner's place given to what, which would copy it
let owner_copy_error(v:int64, what:cstr) {
    var m = $"'"
    m += what
    if nodes[v].kind == N_ID {
        m += "' of an owner would copy it: give a borrow, '&"
        m += tok_text(nodes[v].t)
        m += "', or a copy, '"
        m += tok_text(nodes[v].t)
        m += ".copy()'"
    } else {
        m += "' of an owner would copy it: give a borrow, '&...', or a copy, '....copy()'"
    }
    gen_error(v, m.cstr)
}

// v added to the Array of type y, by xs += v, append, or insert after
// its index, what: an element's value, a borrow's copy, or what an
// expression gives, moved in; a place that owns would be copied, which
// is kelvinc's error, and so is a value of another type
let gen_array_add(y:int64, v:int64, what:cstr) {
    let ey:int64 = types[y].elem
    let vy:int64 = type_of(v)
    if failed { return }
    if is_owner(ey) && nodes[v].kind == N_ADDR && type_of(nodes[v].a) == ey {   // a borrow, copied in
        put_owner_prefix(ey)
        put("_copy(")
        gen_expr(v)
        put(")")
        return
    }
    if vy >= 0 && vy != ey && (is_owner(vy) || is_owner(ey)) {
        var m = $"an element of "
        let w:String = type_text(y)
        m += &w
        m += " is "
        let ew:String = type_text(ey)
        m += article_of(&ew)
        m += " "
        m += &ew
        m += ", and this is "
        let vw:String = type_text(vy)
        m += &vw
        gen_error(v, m.cstr)
        return
    }
    if is_owner(ey) && is_place(v) {
        owner_copy_error(v, what)
        return
    }
    gen_value(v, ey)
}

// how many arguments the list from a has
let arg_count(a:int64):int64 {
    var k:int64 = 0
    var e:int64 = a
    while e >= 0 {
        k += 1
        e = nodes[e].next
    }
    return k
}

// whether the method n of an Array or a Bytes has as many arguments as
// it takes, append and reserve 1, insert and remove 2, the rest 0; else
// kelvinc's error
let takes_args(n:int64):bool {
    let t:int64 = nodes[n].t
    let want:int64 = tok_is(t, "append") || tok_is(t, "reserve") ? 1 : tok_is(t, "insert") || tok_is(t, "remove") ? 2 : 0
    if arg_count(nodes[n].b) == want { return true }
    var m = $"'."
    m += tok_text(t)
    m += "' takes "
    m += String(want)
    m += want == 1 ? " argument" : " arguments"
    gen_error(n, m.cstr)
    return false
}

// xs.append(v), xs.insert(i, v), xs.remove(i, n), xs.clear(),
// xs.reserve(n) and xs.compact() of the Array a of type y, in place, as
// kelvinc's: its own C functions, the arguments counted in its words
let gen_array_method(n:int64, a:int64, y:int64) {
    let t:int64 = nodes[n].t
    let b:int64 = nodes[n].b
    if !takes_args(n) { return }
    if !may_change(a) { return }                        // (#271)
    put_array_name(y)
    put("_")
    put_tok(t)
    put("(")
    gen_place(a)
    if tok_is(t, "append") {
        put(", ")
        gen_array_add(y, b, "append")
    } else if tok_is(t, "insert") {
        put(", ")
        gen_expr(b)
        put(", ")
        gen_array_add(y, nodes[b].next, "insert")
    } else if b >= 0 {
        put(", ")
        gen_args(b)
    }
    put(")")
}

// ---------- Bytes (#439) ----------

// whether y is a Bytes
let is_bytes(y:int64):bool {
    return y >= 0 && types[y].kind == Y_BYTES
}

// the type of b.x, the N_FIELD n of a Bytes: its count and capacity,
// i64s as kc's counts are, its cstr; kc's error of what it has not yet,
// and of what is not a Bytes's
let bytes_field_type(n:int64):int64 {
    let t:int64 = nodes[n].t
    if tok_is(t, "count") || tok_is(t, "capacity") { return base_type(Y_I64) }
    if tok_is(t, "cstr") { return base_type(Y_CSTR) }
    if tok_is(t, "isUTF8") { return base_type(Y_BOOL) }  // whether it is UTF-8 (#464)
    if tok_is(t, "at") {
        var m = $"kc reads a Bytes's count, capacity, isEmpty, isUTF8 and cstr; not yet '."
        m += tok_text(t)
        m += "'"
        gen_error(n, m.cstr)
        return -1
    }
    member_unknown(n, type_of(nodes[n].a))               // kelvinc's words (#497)
    return -1
}

// the type of b.m(...), the N_METHOD n of the Bytes y: a copy, a String
// or where its UTF-8 breaks, or nothing of those that change it in
// place; kc's error of what it has not yet, and kelvinc's of the rest
let bytes_method_type(n:int64, y:int64):int64 {
    let t:int64 = nodes[n].t
    if tok_is(t, "copy") { return y }
    if tok_is(t, "string") { return result_of(base_type(Y_STRING), base_type(Y_I64)) }
    if tok_is(t, "append") || tok_is(t, "insert") || tok_is(t, "remove") || tok_is(t, "clear") || tok_is(t, "reserve") || tok_is(t, "compact") || tok_is(t, "isEmpty") { return base_type(Y_VOID) }
    if tok_is(t, "escape") || tok_is(t, "toBase64") {
        var m = $"kc reads no '."
        m += tok_text(t)
        m += "()' of a Bytes yet"
        gen_error(n, m.cstr)
        return -1
    }
    var m = $"a Bytes has no method '"
    m += tok_text(t)
    m += "': append, insert, remove, clear, reserve, escape, compact, copy, string and toBase64, and the properties count, isEmpty, capacity, at, cstr and isUTF8"
    gen_error(n, m.cstr)
    return -1
}

// Bytes(...), the call n, as kelvinc's #54 and #172: none, a count of
// zeros, text, a borrow of a Bytes or of a String, bytes in brackets, or
// bytes and their count; an owner refused, which would be copied or was
// one already
let gen_bytes_make(n:int64) {
    let x:int64 = nodes[n].b
    let takes:cstr := "Bytes takes nothing, a count, text, a borrow of a Bytes or of a String, bytes in brackets, or bytes and their count"
    if x < 0 {
        put("kv_bytes_new()")
        return
    }
    let more:int64 = nodes[x].next
    if more >= 0 && nodes[more].next >= 0 {
        gen_error(n, takes)
        return
    }
    if more >= 0 {                                       // bytes and their count
        put("kv_bytes_from(")
        gen_expr(x)
        put(", ")
        gen_expr(more)
        put(")")
        return
    }
    if nodes[x].kind == N_LIST && nodes[x].flag == 0 && nodes[x].ty < 0 {   // Bytes([0, 1, 255]), each a byte's value
        var e:int64 = nodes[x].b
        while e >= 0 {
            let neg = nodes[e].kind == N_UNARY && tok_is(nodes[e].t, "-")
            let lit:int64 = neg ? nodes[e].a : e
            if nodes[lit].kind == N_NUM && (neg || tok_count(nodes[lit].t) > 255) {
                var m = $"a byte of Bytes([...]) is 0 to 255, and this is "
                if neg { m += "-" }
                m += tok_text(nodes[lit].t)
                gen_error(e, m.cstr)
                return
            }
            e = nodes[e].next
        }
        put("kv_bytes_from((const uint8_t[]){")
        e = nodes[x].b
        while e >= 0 {
            gen_expr(e)
            if nodes[e].next >= 0 { put(", ") }
            e = nodes[e].next
        }
        put("}, ")
        put_int(arg_count(nodes[x].b))
        put(")")
        return
    }
    let y:int64 = type_of(x)
    if failed { return }
    if is_owner(y) {
        if types[y].kind == Y_STRING {
            gen_error(n, "Bytes(s) of a String is written Bytes(&s), a copy of its bytes (#291)")
        } else if is_place(x) {
            gen_error(n, "Bytes(x) would copy an owner: write x.copy(), or Bytes(&b)")
        } else if types[y].kind == Y_BYTES {
            gen_error(n, "Bytes(x) of a Bytes is one already: leave out Bytes(...)")
        } else {
            var m = String(takes)
            m += ", and this is "
            let w:String = kelvin_type_text(y)
            m += &w
            gen_error(n, m.cstr)
        }
        return
    }
    let held_one = nodes[x].kind == N_ADDR && needs_hold(nodes[x].a)   // Bytes(&$"text"), Bytes(&mk()): held, as kelvinc holds it (#450)
    if held_one { hold_open(nodes[x].a) }
    put("KV_BYTES_OF(")
    gen_expr(x)
    put(")")
    if held_one { hold_close(nodes[x].a) }
}

// v appended to a Bytes, or inserted, by what, as kelvinc's #54: a byte,
// text, a borrow of a Bytes, or a Bytes an expression gives, moved in; a
// place that owns would be copied, and a String's bytes are its .bytes
let gen_bytes_add(v:int64, what:cstr) {
    let vy:int64 = type_of(v)
    if failed { return }
    if is_owner(vy) && is_place(v) {
        owner_copy_error(v, what)
        return
    }
    if vy >= 0 && types[vy].kind == Y_PTR && types[types[vy].elem].kind == Y_STRING {
        gen_error(v, "a Bytes takes bytes: give the String's bytes, 's.bytes'")
        return
    }
    gen_expr(v)
}

// b.append(x), b.insert(i, x), b.remove(i, n), b.clear(), b.reserve(n),
// b.compact() of the Bytes a, in place, and b.string(), a Result: a new
// String, or the offset where its UTF-8 breaks (#405)
let gen_bytes_method(n:int64, a:int64, y:int64) {
    let t:int64 = nodes[n].t
    let b:int64 = nodes[n].b
    if type_of(n) < 0 || !takes_args(n) { return }     // kelvinc's errors, or kc's
    if tok_is(t, "string") {
        let r:int64 = result_of(base_type(Y_STRING), base_type(Y_I64))
        put("({ kv_string _kv_s = {0}; int64_t _kv_e = kv_string_try_bytes(")
        gen_place(a)
        put(", &_kv_s); _kv_e >= 0 ? _kv_")
        put_tok(types[r].name)
        put("_make_err(_kv_e) : _kv_")
        put_tok(types[r].name)
        put("_make_ok(_kv_s); })")
        return
    }
    if !may_change(a) { return }
    if tok_is(t, "append") {
        put("KV_BYTES_APPEND(")
        gen_place(a)
        put(", ")
        gen_bytes_add(b, "append")
    } else if tok_is(t, "insert") {
        put("KV_BYTES_INSERT(")
        gen_place(a)
        put(", ")
        gen_expr(b)
        put(", ")
        gen_bytes_add(nodes[b].next, "insert")
    } else {
        put("kv_bytes_")
        put_tok(t)
        put("(")
        gen_place(a)
        if b >= 0 {
            put(", ")
            gen_args(b)
        }
    }
    put(")")
}

// the operator n where a side is a Bytes, as kelvinc's #185: == and !=,
// and < <= > >= by the bytes, of two Bytes, each an expression gives
// held; b + c not yet kc's, and the rest kelvinc's error
let gen_bytes_bin(n:int64) {
    let t:int64 = nodes[n].t
    let a:int64 = nodes[n].a
    let b:int64 = nodes[n].b
    if tok_is(t, "+") {
        gen_error(n, "kc reads no '+' of a Bytes yet: append with .append or +=")
        return
    }
    if !is_comparison(t) {
        var m = $"a Bytes has no operator '"
        m += tok_text(t)
        m += "': compare with == and !=, append with .append or +="
        gen_error(n, m.cstr)
        return
    }
    if !is_bytes(type_of(a)) || !is_bytes(type_of(b)) {
        gen_error(n, "a Bytes compares with another Bytes")
        return
    }
    let ha = needs_hold(a)
    let hb = needs_hold(b)
    if ha { hold_open(a) }
    if hb { hold_open(b) }
    let eq = tok_is(t, "==") || tok_is(t, "!=")
    if tok_is(t, "!=") { put("((bool)!") } else if !eq { put("((bool)(") }
    put(eq ? "kv_bytes_eq(" : "kv_bytes_cmp(")
    gen_place(a)
    put(", ")
    gen_place(b)
    put(")")
    if !eq {
        put(" ")
        put_tok(t)
        put(" 0)")
    }
    if !eq || tok_is(t, "!=") { put(")") }
    if hb { hold_close(b) }
    if ha { hold_close(a) }
}

let gen_method_of(n:int64) {
    let a:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    if refuse_valueless_args(n) { return }
    let f:int64 = method_of(n)
    if f >= 0 && attributes.get(f, 0) != 0 && !attr_reads.has(n) {   // as kelvinc says it (#131)
        var m = $"'"
        m += tok_text(t)
        m += "' is an attribute of "
        m += tok_text(nodes[f].c)
        m += ": read it as '."
        m += tok_text(t)
        m += "', with no parentheses"
        gen_error(n, m.cstr)
        return
    }
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
        } else if nodes[f].flag == 3 {                                // a subscript's getter, by a const pointer (#136):
            if is_place(a) {                                          // what no variable holds, in a literal of its own
                gen_place(a)
            } else {
                put("(const ")
                put_ctype(type_of(a))
                put("[]){")
                gen_expr(a)
                put("}")
            }
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
        let v = nodes[n].b
        let cm:int64 = case_named(e, t) ?? 0 - 1
        if v >= 0 && cm >= 0 && !case_value_fits(v, cm, type_of(n)) { return }   // of what the case holds (#413)
        put("_kv_")
        put_tok(nodes[e].t)
        put("_make_")
        put_tok(t)
        put("(")
        if v >= 0 && nodes[v].kind == N_ID && !is_case_word(v) && is_owner(type_of(v)) {   // a local owner moves in
            let what = into_words("case ", "", t)
            if !move_out(v, &what) { return }            // dead after it (#441)
            put_owner_prefix(type_of(v))
            put("_take(&")
            put_tok(nodes[v].t)
            put(")")
        } else if v >= 0 && cm >= 0 && fixed_case(cm) {   // a fixed array's elements, by their type (#360)
            gen_value(v, nodes[cm].ty)
        } else if v >= 0 && cm >= 0 && bare_init(v) && struct_of(nodes[cm].ty) >= 0 {   // {a, b} of a struct case, C's compound literal (#477)
            put("(")
            put_ctype(nodes[cm].ty)
            put(")")
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
    if nodes[a].kind == N_TYPE && tok_is(t, "pipe") {                 // IO.pipe() (#464), as kelvinc writes it: its two ends filled
        if nodes[n].b >= 0 {
            gen_error(n, "IO.pipe takes nothing")
            return
        }
        put("({ ")
        put_ctype(type_of(n))
        put(" _kv_p = {0}; kv_io_pipe(&_kv_p.reader, &_kv_p.writer); _kv_p; })")
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
    if y < 0 {
        if !failed { gen_error(a, "kc does not see the type of this value, whose method this calls") }   // never dropped unwritten (#452)
        return
    }
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
    } else if yk == Y_ARRAY && (tok_is(t, "append") || tok_is(t, "insert") || tok_is(t, "remove") || tok_is(t, "clear") || tok_is(t, "reserve") || tok_is(t, "compact")) {
        gen_array_method(n, a, y)                       // (#438)
    } else if yk == Y_BYTES && !tok_is(t, "isEmpty") {
        gen_bytes_method(n, a, y)                       // (#439)
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
    } else if yk == Y_IO && tok_is(t, "write") {       // by what it writes, as kelvinc's: text, &s, &b, a String^ (#450)
        let v:int64 = nodes[n].b
        let vy:int64 = type_of(v)
        if failed { return }
        let vk:ykind = vy >= 0 ? types[vy].kind : Y_C
        let by:int64 = nodes[v].kind == N_ADDR ? type_of(nodes[v].a) : vk == Y_PTR ? types[vy].elem : 0 - 1
        let bk:ykind = by >= 0 ? types[by].kind : Y_C
        if bk == Y_STRING || bk == Y_BYTES {
            put(bk == Y_STRING ? "kv_io_write_string(" : "kv_io_write_bytes(")
        } else if (vk == Y_STRING || vk == Y_BYTES) && !is_place(v) {   // an owner an expression gives, written and freed
            put(vk == Y_STRING ? "kv_io_write_owned_string(" : "kv_io_write_owned_bytes(")
        } else if vk == Y_STRING || vk == Y_BYTES {
            var m = $"'.write' takes a borrow of a "
            m += vk == Y_STRING ? "String, '&" : "Bytes, '&"
            if nodes[v].kind == N_ID { m += tok_text(nodes[v].t) } else { m += "..." }
            m += "'"
            gen_error(v, m.cstr)
            return
        } else if vk == Y_C || vk == Y_CSTR || nodes[v].kind == N_STR || nodes[v].kind == N_TPL {
            put("kv_io_write_text(")
        } else {
            var m = $"'.write' takes text, a borrow of a String or a Bytes ('&s'), or one an expression gives, and this is "
            let w:String = kelvin_type_text(vy)
            m += &w
            gen_error(v, m.cstr)
            return
        }
        gen_place(a)
        put(", ")
        gen_expr(v)
        put(")")
    } else if yk == Y_IO && tok_is(t, "close") {
        put("kv_io_close(")
        gen_place(a)
        put(")")
    } else if yk == Y_IO && (tok_is(t, "print") || tok_is(t, "println")) {   // f.print(...), f.println(...), as print's into f (#452)
        let args:int64 = nodes[n].b
        var opened = hold_args(args, 0 - 1)
        serial += 1
        let s = serial
        var sink = $"kv_io_fp(_kv_f"
        sink += String(s)
        sink += ")"
        put("({ kv_io *const _kv_f")
        put_int(s)
        put(" = ")
        gen_place(a)
        put(tok_is(t, "println") ? "; KV_FPRINTLN(_kv_f" : "; KV_FPRINT(_kv_f")
        put_int(s)
        if args >= 0 {
            put(", ")
            gen_print_args_to(args, sink.cstr)
        }
        put("); })")
        close_holds(&opened)
    } else if yk == Y_IO && tok_is(t, "flush") {       // (#452)
        put("kv_io_flush(")
        gen_place(a)
        put(")")
    } else if yk == Y_IO && tok_is(t, "rewind") {      // to read it again (#450)
        put("kv_io_rewind(")
        gen_place(a)
        put(")")
    } else if yk == Y_IO && io_method_type(n) >= 0 {
        gen_io_method(n, a)                             // f.glob(p), f.chmod(m)... (#464)
    } else if yk == Y_STRING && (tok_is(t, "find") || tok_is(t, "has") || tok_is(t, "starts") || tok_is(t, "ends") || tok_is(t, "trim") || tok_is(t, "append") || tok_is(t, "clear") || tok_is(t, "compact") || tok_is(t, "reserve")) {
        gen_string_method(n, a, y)                      // (#464)
    } else if tok_is(t, "isEmpty") && (yk == Y_STRING || yk == Y_BYTES || yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET) {
        gen_error(n, "'.isEmpty' is a property: read it with no parentheses, as 'x.isEmpty'")   // as kelvinc's (#434)
    } else {
        gen_error(n, "this method is not known")
    }
}

// whether n names a place, whose address is taken as it is
let is_place(n:int64):bool {
    resolve_attr(n)
    let k:nkind = nodes[n].kind
    if k == N_INDEX && nodes[n].flag == 1 {                  // d[k] read whole is a value (#219)
        let y = type_of(nodes[n].a)
        if y >= 0 && types[y].kind == Y_DICT { return false }
    }
    if k == N_FIELD && tagged_named(nodes[n].a) >= 0 { return false }   // T.none, a case made here (#345)
    if k == N_FIELD && typename_member(n) { return false }   // x.typename, text (#426)
    if k == N_FIELD && os_call(n) { return false }          // OS.cwd, a value (#463)
    if k == N_FIELD && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_IO { return false }   // f.abspath and the rest, values (#464)
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

// a < b, a <= b, a > b, a >= b of Strings, in codepoint order, as
// kelvinc's #185; one an expression gives held, as gen_string_eq's (#470)
let gen_string_order(n:int64) {
    let a:int64 = nodes[n].a
    let b:int64 = nodes[n].b
    if builtin_kind(type_of(b)) != Y_STRING {
        gen_error(n, "a String compares with another String")
        return
    }
    let ha = needs_hold(a)
    let hb = needs_hold(b)
    if ha { hold_open(a) }
    if hb { hold_open(b) }
    put("((bool)(kv_string_cmp(")
    gen_place(a)
    put(", ")
    gen_place(b)
    put(") ")
    put_tok(nodes[n].t)
    put(" 0))")
    if hb { hold_close(b) }
    if ha { hold_close(a) }
}

// a condition: a comparison without the parentheses C would warn of
let gen_cond(n:int64) {
    resolve_op(n)
    resolve_attr(n)
    if is_range_eq(n) {                                  // (#376)
        gen_range_eq(n)
        return
    }
    if range_operand_error(n) { return }                 // a Range has no operators (#373) but == and != (#376)
    if nodes[n].kind == N_BIN && is_comparison(nodes[n].t) {
        let y:int64 = type_of(nodes[n].a)
        let owners = tagged_side(n) >= 0 || builtin_kind(y) != Y_VOID || builtin_kind(type_of(nodes[n].b)) != Y_VOID   // an Optional's == (#343), String ==, xs == ys (#288), refusals (#287)
        if !owners && !uchr_typed(nodes[n].a) && !uchr_typed(nodes[n].b) {   // a uchr's by its codepoint (#478)
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
let gen_set(n:int64, first:int64, given:int64)   // and Set<T>({a, b}) ${a, b} of T (#460)

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

// Set<T>(), Set<T>({a, b}) and Set<T>(&s), as kelvinc's #71 (#460): the
// elements as ${a, b} of y, its errors as kelvinc says them; a copy of
// the Set &s lends, by _copy
let gen_make_set(n:int64, y:int64, w:const String^) {
    let x:int64 = nodes[n].a
    if nodes[n].flag == 6 {
        var m = $"expected ')', found '"
        m += tok_text(nodes[n].c)
        m += "'"
        gen_error(n, m.cstr)
        return
    }
    if nodes[n].flag == 3 && nodes[x].kind == N_EMPTY && nodes[x].flag != 1 {
        gen_error(x, "an empty Set is written ${}; ${:} is an empty Dictionary")
        return
    }
    if nodes[n].flag == 0 || (nodes[n].flag == 3 && nodes[x].kind == N_EMPTY) {
        put("(")
        put_ctype(y)
        put("){0}")
        return
    }
    if nodes[n].flag == 3 && nodes[x].kind == N_DICT {
        gen_error(x, "a Set holds elements, not entries: ${a, b, c}; a Dictionary's are ${k: v}")
        return
    }
    if nodes[n].flag == 3 {
        gen_set(x, nodes[x].b, y)
        return
    }
    let p:int64 = nodes[n].flag == 4 ? nodes[x].a : 0 - 1
    if p < 0 || type_of(p) != y {
        var m = w^.copy()
        m += " takes nothing, the elements in {a, b, c}, or a borrow of another, '&s'"
        gen_error(x, m.cstr)
        return
    }
    let h = needs_hold(p)                                // one an expression gives, held and freed after
    if h { hold_open(p) }
    put_set_name(y)
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
    if types[y].kind == Y_SET {                          // (#460)
        gen_make_set(n, y, &w)
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
        let c_named = xy >= 0 && types[xy].kind == Y_STRUCT && decl_named(types[xy].name, D_STRUCT) < 0 && decl_named(types[xy].name, D_ENUM) < 0   // a C header's size_t (#470)
        if k == N_STR || (xy >= 0 && !is_number_kind(types[xy].kind) && types[xy].kind != Y_BOOL && types[xy].kind != Y_C && !c_named) {
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
    if tok_is(nodes[v].t, "$[") || tok_is(nodes[v].t, "[") { return k == Y_ARRAY }   // [] inside Array([...]) too (#451)
    if nodes[v].flag == 1 { return k == Y_SET }
    return k == Y_DICT
}

// $[], ${:} or ${} where no type of its kind is written, as kelvinc says
// it (#348)
let empty_error(v:int64) {
    if tok_is(nodes[v].t, "$[") || tok_is(nodes[v].t, "[") {
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
        var v:int64 = a
        if nodes[a].kind == N_DESIG {                    // .name = v, and on from that member, as C's (#418)
            f = nodes[s].a
            while f >= 0 && !same_text(nodes[f].t, nodes[a].t) { f = nodes[f].next }
            if f < 0 {
                var e = $"'"
                e += tok_text(nodes[a].t)
                e += "' is no member of "
                e += tok_text(nodes[s].t)
                gen_error(a, e.cstr)
                return
            }
            put(".")
            put_tok(nodes[a].t)
            put(" = ")
            v = nodes[a].a
        }
        if f < 0 {
            gen_error(a, "this struct has fewer members")
            return
        }
        if nodes[v].kind == N_ID && var_type(nodes[v].t) >= 0 && is_owner(type_of(v)) {
            owner_assign_error(v)
            return
        }
        gen_written(v, nodes[f].ty)                      // ${:} of a member (#348)
        a = nodes[a].next
        f = nodes[f].next
    }
    put("}")
}

// whether n is {a, b} of no type of its own, which takes the type it
// goes to; (T){a, b} has its own (#418)
let bare_init(n:int64):bool {
    return nodes[n].kind == N_INIT && nodes[n].ty < 0
}

// a case's value made where an enum with values is expected (#217): none,
// ok(v), err(e) by the type that takes them, and a T where a T? goes as
// some(T), where a Result goes as ok(T) (#344), as kelvinc has them, whose some(v) is a pattern alone; a local
// owner moves in; else the expression as it is
// whether n is a value that t takes, as some(n) where a t? goes: a t; a
// number literal of any number; {a, b} of a struct; one a t of a t? takes
// (#217, #229); a bool or any number where a number goes (#415)
let fits_value(n:int64, t:int64):bool {
    if t < 0 { return false }
    let k:nkind = nodes[n].kind
    let tk:ykind = types[t].kind
    let literal = k == N_NUM || k == N_CHAR || k == N_BOOL || (k == N_UNARY && tok_is(nodes[n].t, "-") && nodes[nodes[n].a].kind == N_NUM)
    let number = is_int_kind(tk) || tk == Y_F64 || tk == Y_F32
    if literal && number { return true }
    let y:int64 = number && !literal ? type_of(n) : 0 - 1
    if y >= 0 && is_number_kind(types[y].kind) { return true }   // a bool or a number of another kind, as kelvinc converts it; none of a bool? (#415)
    if k == N_STR && tk == Y_STRING { return true }     // text a String, some("lit") of a String? (#413)
    if bare_init(n) { return struct_of(t) >= 0 || (some_type(t) >= 0 && fits_value(n, some_type(t))) }
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
            owner_assign_error(e)
            return
        }
        if given >= 0 && nodes[e].kind != N_EMPTY {      // of the type written, as kelvinc says it (#350); [] fits any (#451)
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
        if bare_init(e) || nodes[e].kind == N_EMPTY {   // {a, b} of a struct, $[], ${:}: C's compound literal there
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
            let integer = (kk == N_NUM && !float_tok(nodes[k].t)) || is_int_kind(kind)
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
            owner_assign_error(v)
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
        if bare_init(v) || nodes[v].kind == N_EMPTY {   // {a, b} of a struct, ${:}, $[]: C's compound literal there
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

// whether v is what case m of the type whole holds, as kelvinc's
// check_case_value says it (#411, #413): "case 'ok' of Result<i64,
// String> holds an i64, and this is String"; where m holds an Optional or
// a Result, of the case v becomes there, as kelvinc wraps it
let case_value_fits(v:int64, m:int64, whole:int64):bool {
    var cm:int64 = m
    var w:int64 = whole
    while nodes[cm].ty >= 0 && !is_case_word(v) && type_of(v) != nodes[cm].ty && value_case(nodes[cm].ty) >= 0 {
        w = nodes[cm].ty
        cm = value_case(w)
    }
    let c:int64 = nodes[cm].ty
    if c < 0 || is_case_word(v) || types[c].kind == Y_FIXED { return true }   // a fixed array's, fixed_list_fits's
    let vy:int64 = type_of(v)
    if vy >= 0 && vy != c && some_type(vy) >= 0 {        // as kelvinc's reject_record_mismatch says them, first
        var e = $"this is "
        let vw:String = kelvin_type_text(vy)
        e += &vw
        e += ", an Optional, where "
        let cw:String = kelvin_type_text(c)
        e += &cw
        e += " goes: unwrap it with '!', or give a default with '??'"
        gen_error(v, e.cstr)
        return false
    }
    if vy >= 0 && vy != c && struct_of(vy) >= 0 && struct_of(c) >= 0 {
        let vw:String = kelvin_type_text(vy)
        var e = vw.copy()
        e += " is not "
        let cw:String = kelvin_type_text(c)
        e += &cw
        e += ": a struct takes a value of its own type"
        if anon_decls.has(tok_text(types[vy].name)) || anon_decls.has(tok_text(types[c].name)) {   // as kelvinc says it (#476)
            e += ", and two structs with no tag are one type only when their members are written alike"
        }
        gen_error(v, e.cstr)
        return false
    }
    let bad:String = value_mismatch_text(v, c)
    if bad.count == 0 { return true }
    var msg = $"case '"
    msg += tok_text(nodes[cm].t)
    msg += "' of "
    let ww:String = kelvin_type_text(w)
    msg += &ww
    msg += " holds "
    let cw:String = kelvin_type_text(c)
    msg += article_of(&cw)
    msg += " "
    msg += &cw
    msg += ", and this is "
    msg += &bad
    gen_error(v, msg.cstr)
    return false
}

let gen_value_of(n:int64, y:int64)    // a prototype: gen_value writes n by it

// n as a value of type y, and the owners its call moved out dead after
// it, ok(t) as f(t) (#441)
// {.some = v} and {.none} where an enum with values y goes (#121): from
// here on y's case of that name, as T.some(v) and T.none are; else as it was
let init_as_case(n:int64, y:int64) {
    if !bare_init(n) || tagged_of(y) < 0 { return }
    let x:int64 = nodes[n].b
    if x < 0 || nodes[x].next >= 0 { return }
    let d:int64 = tagged_of(y)
    if nodes[x].kind == N_DESIG && case_named(d, nodes[x].t).is(some) {
        let f:int64 = make_node(N_ID, nodes[x].t)
        nodes[n].kind = N_CALL
        nodes[n].a = f
        nodes[n].b = nodes[x].a
        nodes[n].ty = y
    } else if nodes[x].kind == N_FIELD && nodes[nodes[x].a].kind == N_SELF && case_named(d, nodes[x].t).is(some) {
        nodes[n].kind = N_ID
        nodes[n].t = nodes[x].t
        nodes[n].ty = y
    } else if value_case(y) >= 0 && nodes[x].kind != N_DESIG && struct_of(nodes[value_case(y)].ty) < 0 {
        let f:int64 = make_node(N_ID, nodes[value_case(y)].t)   // {1} of an int64? or a Result, the value wrapped (#77)
        nodes[n].kind = N_CALL
        nodes[n].a = f
        nodes[n].b = x
        nodes[n].ty = y
    }
}

let gen_value(n:int64, y:int64) {
    init_as_case(n, y)
    gen_value_of(n, y)
    if nodes[n].kind == N_CALL || nodes[n].kind == N_METHOD { moves_done() }
}

let gen_value_of(n:int64, y:int64) {
    if y >= 0 && types[y].kind == Y_FN && nodes[n].kind != N_COND {   // a function where a function type goes (#428)
        gen_fn_value(n, y)
        return
    }
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
    if nodes[n].kind == N_DICT && tok_is(nodes[n].t, "{") && y >= 0 && types[y].kind == Y_SET {   // as kelvinc says it (#460)
        gen_error(n, "a Set holds elements, not entries: ${a, b, c}; a Dictionary's are ${k: v}")
        return
    }
    if bare_init(n) && y >= 0 && types[y].kind == Y_DICT && nodes[n].b >= 0 {
        gen_error(n, "an entry of a Dictionary is written key: value")
        return
    }
    if (nodes[n].kind == N_SET || bare_init(n)) && y >= 0 && types[y].kind == Y_SET {   // ${a, b}, {a, b} (#274)
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
            owner_assign_error(n)
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
    if bare_init(n) && y >= 0 && types[y].kind == Y_STRUCT && decl_named(types[y].name, D_STRUCT) >= 0 {
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
    if m >= 0 && nodes[d].c == 1 && nodes[n].kind == N_CALL && nodes[n].ty < 0 {   // Optional<T>.some(v) makes one (#449)
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
    if v >= 0 && !case_value_fits(v, m, y) { return }     // ok(v), err(e) of what the case holds (#413)
    if m < 0 && value_case(y) >= 0 && fits_value(n, wrap_type(y)) {   // a T as some(T), and as ok(T) of a Result (#344)
        m = value_case(y)
        v = n
    }
    if m < 0 && value_case(y) >= 0 && type_of(n) >= 0 && type_of(n) != y && !case_value_fits(n, value_case(y), y) { return }   // a T where a T? goes (#413)
    if m < 0 {
        gen_expr(n)
        return
    }
    put("_kv_")
    put_tok(nodes[d].t)
    put("_make_")
    put_tok(nodes[m].t)
    put("(")
    if v >= 0 && nodes[v].kind == N_ID && !is_case_word(v) && is_owner(type_of(v)) {   // ok(none) of a Result<T?, E> (#413)
        let what = into_words(v == n ? "" : "case ", "", nodes[m].t)   // t where a T? goes, into 'some' (#441)
        if !move_out(v, &what) { return }
        put_owner_prefix(type_of(v))
        put("_take(&")
        put_tok(nodes[v].t)
        put(")")
    } else if v >= 0 && nodes[m].ty >= 0 {             // what the case holds, by its type: a T?? of a T (#229)
        if bare_init(v) && struct_of(nodes[m].ty) >= 0 {
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

// whether x ?? y gives the whole of x: r ?? r2 of two Results of a type
// (#408); a ?? b of two Optionals of a type, and a ?? none (#409), as
// kelvinc's #252, where none is no value a T?? holds; r ?? ok(v) and
// r ?? err(e) (#410), as kelvinc's #254, where neither is what r holds
let coalesces_whole(n:int64):bool {
    let y = type_of(nodes[n].a)
    let b:int64 = nodes[n].b
    if !is_result(y) && some_type(y) < 0 { return false }
    if is_case_word(b) {                             // a word, which has no type
        let w:int64 = nodes[b].kind == N_ID ? nodes[b].t : nodes[nodes[b].a].t
        let word = (nodes[b].kind == N_ID && tok_is(w, "none")) || (is_result(y) && nodes[b].kind == N_CALL && (tok_is(w, "ok") || tok_is(w, "err")))
        return word && !is_variant(wrap_type(y))
    }
    return type_of(b) == y
}

// r ?? r2 of two Results of y, as kelvinc's #253 (#408), and a ?? b of
// two Optionals, #252's (#409): r where it is ok or some, else r2, r
// read once; where y owns, r a copy where it is a place, else taken,
// and freed where it has no value; r2 a copy where it is a place, else
// taken, made only where r has no value
let gen_coalesce_whole(n:int64, y:int64) {
    let a:int64 = nodes[n].a
    let b:int64 = nodes[n].b
    let tag:cstr := some_type(y) >= 0 ? ".tag == 1" : ".tag == 0"
    serial += 1
    let s = serial                                   // its own: r may make names too (#221)
    put("({ ")
    put_ctype(y)
    put(" _kv_o")
    put_int(s)
    put(" = ")
    gen_expr(a)
    if !is_owner(y) {
        put("; _kv_o")
        put_int(s)
        put(tag)
        put(" ? _kv_o")
        put_int(s)
        put(" : (")
        gen_value(b, y)
        put("); })")
        return
    }
    put("; ")
    put_ctype(y)
    put(" _kv_r")
    put_int(s)
    put("; if (_kv_o")
    put_int(s)
    put(tag)
    put(") _kv_r")
    put_int(s)
    put(" = ")
    if is_place(a) {
        put_owner_prefix(y)
        put("_copy(&_kv_o")
        put_int(s)
        put(")")
    } else {
        put("_kv_o")
        put_int(s)
    }
    put("; else { ")
    if !is_place(a) {
        put_owner_prefix(y)
        put("_free(&_kv_o")
        put_int(s)
        put("); ")
    }
    put("_kv_r")
    put_int(s)
    put(" = ")
    if is_place(b) && !is_case_word(b) {             // none no place (#409)
        put_owner_prefix(y)
        put("_copy(&(")
        gen_expr(b)
        put("))")
    } else {
        gen_value(b, y)
    }
    put("; } _kv_r")
    put_int(s)
    put("; })")
}

// x ?? d: what the Optional x holds, else d, x read once (#217); what
// the Result x holds where it is ok, else d (#407)
let gen_coalesce(n:int64) {
    let y = type_of(nodes[n].a)
    let inner = wrap_type(y)
    if inner < 0 {
        var m = $"'??' takes an Optional or a Result on its left, and this is "
        if y < 0 {
            m += "not one"
        } else {
            let w:String = kelvin_type_text(y)
            m += &w
        }
        gen_error(n, m.cstr)
        return
    }
    let b:int64 = nodes[n].b
    if coalesces_whole(n) {                          // r ?? r2, as kelvinc's #253 (#408); a ?? b, #252's (#409)
        gen_coalesce_whole(n, y)
        return
    }
    if nodes[b].kind == N_CALL && is_case_word(b) && tagged_of(inner) < 0 {   // a case word that makes no T, in kelvinc's words (#410)
        let w:int64 = nodes[nodes[b].a].t
        if tok_is(w, "some") {
            gen_error(b, "some(v) makes no Optional: give v itself where a T? goes, which becomes some(v), or write Optional<T>(v); some(v) is a pattern, as in 'if let some(v) = x' (#224)")
            return
        }
        if tok_is(w, "ok") || tok_is(w, "err") {
            let word:String = tok_text(w)
            var m = word.copy()
            m += "(...) is a Result's case only where a Result is expected, as by a return of a function that gives one: elsewhere write Result<T, E>."
            m += &word
            m += "(...) (#224)"
            gen_error(b, m.cstr)
            return
        }
    }
    if !is_case_word(b) && type_of(b) != y {         // y's type in Kelvin's words, as kelvinc's (#340); none of a T?? is its T? (#409)
        let bad:String = value_mismatch_text(b, inner)
        if bad.count > 0 {
            var m = $"'??' of "
            let ow:String = kelvin_type_text(y)
            m += &ow
            m += " falls back to "
            let iw:String = kelvin_type_text(inner)
            m += article_of(&ow)                     // the Result's own, as kelvinc's (#408)
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
    let tag:cstr := some_type(y) >= 0 ? ".tag == 1" : ".tag == 0"   // some's, ok's (#407)
    let field:cstr := some_type(y) >= 0 ? ".u.some" : ".u.ok"
    let taken = !is_place(nodes[n].a)
    serial += 1
    let s = serial                                   // its own: x may make names too (#221)
    put("({ ")
    if taken && is_owner(y) && !is_owner(inner) {    // a Result's err that owns, freed as kelvinc's (#407)
        put("__attribute__((cleanup(")
        put_owner_prefix(y)
        put("_free))) ")
    }
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
        put(tag)
        put(") _kv_r")
        put_int(s)
        put(" = ")
        if !taken {
            put_owner_prefix(inner)
            put("_copy(&_kv_o")
            put_int(s)
            put(field)
            put(")")
        } else {
            put("_kv_o")
            put_int(s)
            put(field)
        }
        put("; else ")
        if taken && is_result(y) {                   // x taken, its err freed (#407)
            put("{ ")
            put_owner_prefix(y)
            put("_free(&_kv_o")
            put_int(s)
            put("); ")
        }
        put("_kv_r")
        put_int(s)
        put(" = ")
        if !is_case_word(b) && is_owner(type_of(b)) && is_place(b) {
            put_owner_prefix(inner)
            put("_copy(&(")
            gen_expr(b)
            put("))")
        } else {
            gen_value(b, inner)
        }
        put(taken && is_result(y) ? "; } _kv_r" : "; _kv_r")
        put_int(s)
        put("; })")
        return
    }
    let flag = types[inner].kind == Y_BOOL               // b ?? false a bool, which prints true, as kelvinc's (#383)
    put(flag ? "; (bool)(_kv_o" : "; _kv_o")
    put_int(s)
    put(tag)
    put(" ? _kv_o")
    put_int(s)
    put(field)
    put(" : (")
    if types[inner].kind == Y_CSTR { put("(const uint8_t *)") }   // x ?? "text" of a cstr?, which C's ?: would make a void * of (#461), as kelvinc casts it
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
    } else if y >= 0 && types[y].kind == Y_BYTES {   // b[i], checked, assignable (#439)
        put("(*kv_bytes_at(")
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
        if !move_back(n, true) { return }                // (#441)
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
    base += maker_name(current)
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
    if nodes[x].kind == N_ID && !move_back(x, false) { return }   // dead after it, as kelvinc's (#441)
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
// integer, or an enum's value, by which flags are named; 0 or more where
// it is a literal and a place, a bit's or a shift's (#455); what names it
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
    if place && neg && v > 0 {                           // past the count the program ends (#455)
        var m = String(what)
        m += " is 0 or more, and this is -"
        m += tok_text(nodes[lit].t)
        gen_error(x, m.cstr)
        return false
    }
    return true
}

var bits_held_n:int64 = 0               // the temporaries that hold a Bits an expression gives (#455)

// a temporary that holds the Bits x, where it is no place, declared and
// freed where its statement expression ends (#455), as kelvinc's bits_ref:
// its number, or -1 of a place
let bits_hold(x:int64):int64 {
    if is_place(x) { return 0 - 1 }
    bits_held_n += 1
    let h:int64 = bits_held_n
    put("__attribute__((cleanup(kv_bits_free))) kv_bits _kv_bt")
    put_int(h)
    put(" = ")
    gen_expr(x)
    put("; ")
    return h
}

// a pointer to the Bits x, the temporary bits_hold made, or &(x)
let put_bits_ref(x:int64, held:int64) {
    if held >= 0 {
        put("&_kv_bt")
        put_int(held)
        return
    }
    put("&(")
    gen_expr(x)
    put(")")
}

// the bits of the integer type y, as kelvinc's int_width, and the C
// type of as many bits unsigned (#457)
let int_width(y:int64):int64 {
    let k:ykind = types[y].kind
    return k == Y_U8 || k == Y_I8 ? 8 : k == Y_I16 || k == Y_U16 ? 16 : k == Y_I32 || k == Y_U32 || enum_int(y) ? 32 : k == Y_I128 || k == Y_U128 ? 128 : 64
}

let put_uint_of(w:int64) {
    put(w == 8 ? "uint8_t" : w == 16 ? "uint16_t" : w == 32 ? "uint32_t" : w == 128 ? "unsigned __int128" : "uint64_t")
}

// whether x, a bit's place in an integer of type y, is one, as kelvinc's
// bit_method: an integer of 64 bits or fewer, or an enum's value; 0 to
// the width less 1 where it is a literal (#457)
let int_place_ok(x:int64, y:int64):bool {
    if !bit_number(x, "a bit's place in an integer", false) { return false }
    let neg = nodes[x].kind == N_UNARY && tok_is(nodes[x].t, "-")
    let lit:int64 = neg ? nodes[x].a : x
    let v:int64 = nodes[lit].kind == N_NUM ? tok_count(nodes[lit].t) : 0 - 1
    if (neg && v > 0) || v >= int_width(y) {
        var m = $"a bit's place in "
        let w:String = kelvin_type_text(int_view(y))
        m += &w
        m += " is 0 to "
        m += String(int_width(y) - 1)
        m += ", and this is "
        if neg { m += "-" }
        m += tok_text(nodes[lit].t)
        gen_error(x, m.cstr)
        return false
    }
    return true
}

// b.flip() of a bool, b = !b; x.flip(n) and x.bit(n) of an integer, as
// kelvinc's #454 writes them, through the unsigned type of its width;
// false where n is none of them (#457)
let gen_bit_method(n:int64):bool {
    let a:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let y:int64 = type_of(a)
    if y < 0 { return false }
    let flag = types[y].kind == Y_BOOL
    if !flag && (types[y].kind == Y_F64 || types[y].kind == Y_F32) {
        var m = $"'."
        m += tok_text(t)
        m += tok_is(t, "bit") ? "' is an integer's bit, '.bit(n)', and this is " : "' is a bool's, '.flip()', or an integer's, '.flip(n)', and this is "
        let w:String = kelvin_type_text(y)
        m += &w
        gen_error(n, m.cstr)
        return true
    }
    if !flag && !power_int(y) { return false }
    let v:int64 = nodes[n].b
    if flag {
        if tok_is(t, "bit") {
            gen_error(n, "'.bit(n)' is an integer's bit, and this is a bool: a bool flips with '.flip()'")
            return true
        }
        if v >= 0 {
            gen_error(n, "'.flip()' of a bool takes nothing: it is b = !b")
            return true
        }
    } else {
        if v < 0 || nodes[v].next >= 0 {
            var m = $"'."
            m += tok_text(t)
            m += "(n)' takes one bit's place, 0 to "
            m += String(int_width(y) - 1)
            gen_error(n, m.cstr)
            return true
        }
        if !int_place_ok(v, y) { return true }
    }
    if tok_is(t, "flip") {
        let lead = $"'.flip' is a var method, which changes "
        if !changes_var(a, &lead) { return true }
        if !changeable_place(a) {
            gen_error(n, "'.flip' is a var method, which changes the value it is called on, so that value is a variable")
            return true
        }
    }
    if flag {
        put("({ bool *_kv_fp = &(")
        gen_expr(a)
        put("); *_kv_fp = !*_kv_fp; (void)0; })")
        return true
    }
    let w:int64 = int_width(y)
    if tok_is(t, "bit") {
        put("((bool)((")
        put_uint_of(w)
        put(")(")
        gen_expr(a)
        put(") >> kv_int_place((uint64_t)(")
        gen_expr(v)
        put("), ")
        put_int(w)
        put(") & 1))")
        return true
    }
    put("({ __auto_type _kv_ip = &(")
    gen_expr(a)
    put("); unsigned _kv_p = kv_int_place((uint64_t)(")
    gen_expr(v)
    put("), ")
    put_int(w)
    put("); *_kv_ip = (__typeof__(*_kv_ip))((")
    put_uint_of(w)
    put(")*_kv_ip ^ (")
    put_uint_of(w)
    put(")((")
    put_uint_of(w)
    put(")1 << _kv_p)); (void)0; })")
    return true
}

// x.bit(n) = b, |=, &= and ~= of a bool, in the var that holds x, as
// kelvinc's #454 (#457)
let gen_int_bit_set(n:int64) {
    let lhs:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let v:int64 = nodes[n].b
    let x:int64 = nodes[lhs].a
    let y:int64 = type_of(x)
    if tok_is(t, ":=") {
        gen_error(n, "':=' sets a reference: a bit of an integer is set with '='")
        return
    }
    if !tok_is(t, "=") && !tok_is(t, "|=") && !tok_is(t, "&=") && !tok_is(t, "~=") {
        var m = $"a bit of an integer is set with '=', '|=', '&=' or '~=', and a bool, and has no '"
        m += tok_text(t)
        m += "'"
        gen_error(n, m.cstr)
        return
    }
    let p:int64 = nodes[lhs].b
    if p < 0 || nodes[p].next >= 0 {
        var m = $"'.bit(n)' takes one bit's place, 0 to "
        m += String(int_width(y) - 1)
        gen_error(lhs, m.cstr)
        return
    }
    if !int_place_ok(p, y) { return }
    if !is_place(x) {
        gen_error(n, "setting a bit of an integer changes it, so that integer is a variable")
        return
    }
    if !may_change(x) { return }
    let vy:int64 = type_of(v)
    if vy >= 0 && types[vy].kind != Y_BOOL {
        var m = $"a bit of an integer is set with a bool, and this is "
        let w:String = kelvin_type_text(vy)
        m += &w
        m += ": '!!n' makes one of an integer 0 or 1"
        gen_error(v, m.cstr)
        return
    }
    let w:int64 = int_width(y)
    put("({ __auto_type _kv_ip = &(")
    gen_expr(x)
    put("); unsigned _kv_p = kv_int_place((uint64_t)(")
    gen_expr(p)
    put("), ")
    put_int(w)
    put("); bool _kv_bv = (")
    gen_expr(v)
    put("); ")
    put_uint_of(w)
    put(" _kv_u = (")
    put_uint_of(w)
    put(")*_kv_ip; ")
    put_uint_of(w)
    put(" _kv_m = (")
    put_uint_of(w)
    put(")((")
    put_uint_of(w)
    put(")1 << _kv_p); *_kv_ip = (__typeof__(*_kv_ip))(")
    put_uint_of(w)
    put(")(")
    if tok_is(t, "=") {
        put("(_kv_u & (")
        put_uint_of(w)
        put(")~_kv_m) | (_kv_bv ? _kv_m : 0)")
    } else if tok_is(t, "|=") {
        put("_kv_bv ? _kv_u | _kv_m : _kv_u")
    } else if tok_is(t, "&=") {
        put("_kv_bv ? _kv_u : _kv_u & (")
        put_uint_of(w)
        put(")~_kv_m")
    } else {
        put("_kv_bv ? _kv_u ^ _kv_m : _kv_u")
    }
    put("); (void)0; });\n")
}

// whether n is b[i] of a Bits b, a bit whose .flip() is b.flip(i) (#456)
let bit_of_bits(n:int64):bool {
    return nodes[n].kind == N_INDEX && is_bits(type_of(nodes[n].a))
}

// whether x is what Bits(x, ...) and b.append(x) take (#456), as kelvinc's
// bits_part: a bool, a [bool], an integer or text "0b...", a literal's
// checked; what names the taker in an error
let bits_part_ok(x:int64, what:cstr):bool {
    let y:int64 = type_of(x)
    if failed { return false }
    let k:ykind = y >= 0 ? types[y].kind : Y_C
    if nodes[x].kind == N_STR {                          // its text: 0b and binary digits
        let tx:String = tok_text(nodes[x].t)
        var ok = tx.count >= 4
        var i:int64 = 0
        for c in tx.cstr {
            if i == 1 && c != '0' { ok = false }
            if i == 2 && c != 'b' { ok = false }
            if i >= 3 && i + 1 < tx.count as int64 && c != '0' && c != '1' { ok = false }
            i += 1
        }
        if !ok {
            var m = String(what)
            m += " takes text of 0b and binary digits, as \"0b101\""
            gen_error(x, m.cstr)
            return false
        }
        return true
    }
    if nodes[x].kind == N_LIST && nodes[x].flag == 0 && nodes[x].ty < 0 {   // [true, false]
        var e:int64 = nodes[x].b
        while e >= 0 {
            let ey:int64 = type_of(e)
            if ey >= 0 && types[ey].kind != Y_BOOL {
                var m = String(what)
                m += " takes bools, [bool]s, integers and text \"0b...\", and this is "
                let w:String = kelvin_type_text(ey)
                m += &w
                gen_error(e, m.cstr)
                return false
            }
            e = nodes[e].next
        }
        return true
    }
    if k == Y_BOOL || k == Y_CSTR || k == Y_STRING || is_int_kind(k) || k == Y_C { return true }
    if k == Y_PTR && types[types[y].elem].kind == Y_STRING { return true }   // &s
    if (k == Y_FIXED || k == Y_ARRAY) && types[types[y].elem].kind == Y_BOOL { return true }
    if k == Y_STRUCT && decl_named(types[y].name, D_ENUM) >= 0 { return true }   // an enum's value
    var m = String(what)
    m += " takes bools, [bool]s, integers and text \"0b...\", and this is "
    let w:String = kelvin_type_text(y)
    m += &w
    gen_error(x, m.cstr)
    return false
}

// what Bits(x, ...) and b.append(x) push of x into the kv_bits that the C
// expression b points to (#456), as kelvinc's bits_push: an integer its
// type's width, a literal's 64, one of what only C sees C's sizeof
let put_bits_push(b:cstr, x:int64) {
    let y:int64 = type_of(x)
    let k:ykind = y >= 0 ? types[y].kind : Y_C
    if nodes[x].kind == N_LIST {
        var count:int64 = 0
        var e:int64 = nodes[x].b
        put("kv_bits_push_bools(")
        put(b)
        put(", (bool[]){")
        while e >= 0 {
            if count > 0 { put(", ") }
            gen_expr(e)
            count += 1
            e = nodes[e].next
        }
        if count == 0 { put("0") }
        put("}, ")
        put_int(count)
        put(")")
        return
    }
    if k == Y_BOOL {
        put("kv_bits_push(")
        put(b)
        put(", ")
        gen_expr(x)
        put(")")
    } else if nodes[x].kind == N_STR || k == Y_CSTR {
        put("kv_bits_push_cstr(")
        put(b)
        put(", ")
        gen_expr(x)
        put(")")
    } else if k == Y_STRING || k == Y_PTR {
        put("({ ")
        if k == Y_STRING && !is_place(x) {               // a String an expression gives, freed
            put("__attribute__((cleanup(kv_string_free))) kv_string _kv_bs = ")
            gen_expr(x)
            put("; const kv_string *_kv_bsp = &_kv_bs; ")
        } else {
            put("const kv_string *_kv_bsp = ")
            if k == Y_STRING { gen_place(x) } else { gen_expr(x) }
            put("; ")
        }
        put("kv_bits_push_text(")
        put(b)
        put(", _kv_bsp->b.at, _kv_bsp->b.count); })")
    } else if k == Y_ARRAY {
        if is_place(x) {
            put("kv_bits_push_bools(")
            put(b)
            put(", (")
            gen_expr(x)
            put(").at, (")
            gen_expr(x)
            put(").count)")
        } else {                                         // an Array an expression gives, freed
            put("({ __auto_type _kv_ba = ")
            gen_expr(x)
            put("; kv_bits_push_bools(")
            put(b)
            put(", _kv_ba.at, _kv_ba.count); free(_kv_ba.at); })")
        }
    } else if k == Y_FIXED {
        put("kv_bits_push_bools(")
        put(b)
        put(", ")
        gen_expr(x)
        put(", sizeof(")
        gen_expr(x)
        put(") / sizeof((")
        gen_expr(x)
        put(")[0]))")
    } else {
        let w:cstr := k == Y_I32 || k == Y_U32 ? "32" : k == Y_U8 || k == Y_I8 ? "8" : k == Y_I16 || k == Y_U16 ? "16" : k == Y_I128 || k == Y_U128 ? "128" : k == Y_C ? "sizeof _kv_bv * 8" : "64"
        put("({ __auto_type _kv_bv = ")
        gen_expr(x)
        put("; kv_bits_push_int(")
        put(b)
        put(", (unsigned __int128)_kv_bv, ")
        put(w)
        put("); })")
    }
}

// Bits() and Bits(n), !!n, ~b, b[n], b.flip(n) and the operators of a
// Bits, as kelvinc writes them, through runtime/bits.c's kv_bits_
// functions (#387, #455); false where n is none of them
let gen_bits(n:int64):bool {
    let k:nkind = nodes[n].kind
    let t:int64 = nodes[n].t
    let a:int64 = nodes[n].a
    if k == N_FIELD && tagged_named(a) >= 0 { return false }   // T.none, a case made here
    if k == N_CALL && nodes[a].kind == N_TYPE && tok_is(nodes[a].t, "Bits") {      // Bits(x, ...), each in turn from place 0 (#456)
        var x:int64 = nodes[n].b
        if x < 0 {
            put("kv_bits_new()")
            return true
        }
        while x >= 0 {
            if !bits_part_ok(x, "Bits(x, ...)") { return true }
            x = nodes[x].next
        }
        put("({ kv_bits _kv_bm = kv_bits_new();")
        x = nodes[n].b
        while x >= 0 {
            put(" ")
            put_bits_push("&_kv_bm", x)
            put(";")
            x = nodes[x].next
        }
        put(" _kv_bm; })")
        return true
    }
    if k == N_METHOD && (tok_is(t, "flip") || tok_is(t, "bit")) && !bit_of_bits(a) && gen_bit_method(n) { return true }   // (#457)
    if k == N_METHOD && tok_is(t, "flip") && bit_of_bits(a) {     // bv[n].flip(), bv.flip(n) (#456)
        if nodes[n].b >= 0 {
            gen_error(n, "'.flip()' of a bool takes nothing: it is b = !b")
            return true
        }
        let bv:int64 = nodes[a].a
        let lead = $"'.flip' is a var method, which changes "
        if !changes_var(bv, &lead) { return true }
        if !changeable_place(bv) {
            gen_error(n, "'.flip' is a var method, which changes the value it is called on, so that value is a variable")
            return true
        }
        put("kv_bits_flip(&(")
        gen_expr(bv)
        put("), (int64_t)(")
        gen_expr(nodes[a].b)
        put("))")
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
    if k == N_UNARY && is_bits(type_of(a)) {             // ~b, each bit flipped, a new Bits
        if !tok_is(t, "~") {
            var m = $"a Bits has the prefix '~', which flips each bit, and no prefix '"
            m += tok_text(t)
            m += "'"
            gen_error(n, m.cstr)
            return true
        }
        put("({ ")
        let ha:int64 = bits_hold(a)
        put("kv_bits_not(")
        put_bits_ref(a, ha)
        put("); })")
        return true
    }
    if k == N_INDEX && is_bits(type_of(a)) {             // b[n], a bit
        if !bit_number(nodes[n].b, "a bit's place in a Bits", true) { return true }
        put("({ ")
        let ha:int64 = bits_hold(a)
        put("kv_bits_at(")
        put_bits_ref(a, ha)
        put(", (int64_t)(")
        gen_expr(nodes[n].b)
        put(")); })")
        return true
    }
    if k == N_FIELD && is_bits(type_of(a)) && (tok_is(t, "count") || tok_is(t, "capacity") || tok_is(t, "isEmpty") || tok_is(t, "bin") || tok_is(t, "u64s")) {
        put("({ ")                                       // its count and room in bits, whether it has none,
        let ha:int64 = bits_hold(a)                      // each u64's "0b..." (#456)
        if tok_is(t, "bin") || tok_is(t, "u64s") {
            let ay:int64 = type_of(n)
            put("const kv_bits *_kv_bq = ")
            put_bits_ref(a, ha)
            put("; ")
            put_array_name(ay)
            put(" _kv_bs = {0}; for (size_t _kv_bi = 0; _kv_bi < (_kv_bq->count + 63) / 64; _kv_bi++) ")
            put_array_name(ay)
            put(tok_is(t, "bin") ? "_append(&_kv_bs, kv_bits_word_bin(_kv_bq, _kv_bi)); _kv_bs; })" : "_append(&_kv_bs, _kv_bq->at[_kv_bi]); _kv_bs; })")
            return true
        }
        put(tok_is(t, "isEmpty") ? "(bool)((" : "(int64_t)((")
        put_bits_ref(a, ha)
        put(tok_is(t, "count") ? ")->count)" : tok_is(t, "capacity") ? ")->cap * 64)" : ")->count == 0)")
        put("; })")
        return true
    }
    if k == N_METHOD && tok_is(t, "copy") && is_bits(type_of(a)) {     // b.copy(), a new owner (#456)
        if nodes[n].b >= 0 {
            gen_error(n, "'.copy()' takes nothing")
            return true
        }
        put("({ ")
        let ha:int64 = bits_hold(a)
        put("kv_bits_copy(")
        put_bits_ref(a, ha)
        put("); })")
        return true
    }
    if k == N_METHOD && (tok_is(t, "append") || tok_is(t, "capacity")) && is_bits(type_of(a)) {   // b.append(x), b.capacity(n), in the var that holds b (#456)
        let v:int64 = nodes[n].b
        let app = tok_is(t, "append")
        if v < 0 || nodes[v].next >= 0 {
            gen_error(n, app ? "'.append(x)' takes one value: a bool, a [bool], an integer or text \"0b...\"" : "'.capacity(n)' takes a count of bits")
            return true
        }
        if app && !bits_part_ok(v, "'.append(x)'") { return true }
        if !app && !bit_number(v, "'.capacity(n)'s n", false) { return true }
        var lead = $"'."
        lead += tok_text(t)
        lead += "' is a var method, which changes "
        if !changes_var(a, &lead) { return true }
        if !changeable_place(a) {
            var m = $"'."
            m += tok_text(t)
            m += "' is a var method, which changes the value it is called on, so that value is a variable"
            gen_error(n, m.cstr)
            return true
        }
        if app {
            put("({ kv_bits *_kv_bp = &(")
            gen_expr(a)
            put("); ")
            put_bits_push("_kv_bp", v)
            put("; (void)0; })")
        } else {
            put("kv_bits_reserve(&(")
            gen_expr(a)
            put("), (int64_t)(")
            gen_expr(v)
            put("))")
        }
        return true
    }
    if k == N_METHOD && tok_is(t, "flip") && is_bits(type_of(a)) {     // b.flip(n), in the var that holds b
        let v:int64 = nodes[n].b
        if v < 0 || nodes[v].next >= 0 {
            gen_error(n, "'.flip(n)' takes one bit's place")
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
        put("), (int64_t)(")
        gen_expr(v)
        put("))")
        return true
    }
    if k != N_BIN || tok_is(t, "??") { return false }   // x ?? none: none has no type to ask (#409)
    let b:int64 = nodes[n].b
    let left = is_bits(side_type(a))
    if !left && !is_bits(side_type(b)) { return false }
    let shift = tok_is(t, "<<") || tok_is(t, ">>")
    let eq = tok_is(t, "==") || tok_is(t, "!=")
    if !shift && !eq && !tok_is(t, "|") && !tok_is(t, "&") && !tok_is(t, "~") {
        var m = $"a Bits has '|', '&', '~', '<<', '>>', '==' and '!=', and no '"
        m += tok_text(t)
        m += "': its u64s are '.u64s'"
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
        put("({ ")
        let ha:int64 = bits_hold(a)
        put(tok_is(t, "<<") ? "kv_bits_shl(" : "kv_bits_shr(")
        put_bits_ref(a, ha)
        put(", (int64_t)(")
        gen_expr(b)
        put(")); })")
        return true
    }
    if !left || !is_bits(type_of(b)) {
        var m = $"'"
        m += tok_text(t)
        m += "' of a Bits takes another Bits: 'Bits(n)' makes one of an integer"
        gen_error(n, m.cstr)
        return true
    }
    put("({ ")
    let ha:int64 = bits_hold(a)
    let hb:int64 = bits_hold(b)
    if eq {
        put(tok_is(t, "!=") ? "(bool)!kv_bits_eq(" : "(bool)kv_bits_eq(")
    } else {
        put("kv_bits_op(")
    }
    put_bits_ref(a, ha)
    put(", ")
    put_bits_ref(b, hb)
    if !eq {
        put(tok_is(t, "|") ? ", '|'" : tok_is(t, "&") ? ", '&'" : ", '^'")
    }
    put("); })")
    return true
}

// b[n] = x, b[n] |= x, &= and ~= of a bool, and b |= c, &=, ~=, <<= and
// >>= of a whole Bits (#387, #455), in the var that holds b, as kelvinc
// writes them; false where n assigns none of them
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
        put("), (int64_t)(")
        gen_expr(nodes[lhs].b)
        put("), ")
        gen_expr(v)
        put(");\n")
        return true
    }
    if !is_bits(type_of(lhs)) || tok_is(t, "=") || tok_is(t, ":=") { return false }
    let shift = tok_is(t, "<<=") || tok_is(t, ">>=")
    if !shift && !tok_is(t, "|=") && !tok_is(t, "&=") && !tok_is(t, "~=") {
        var m = $"a Bits has '|=', '&=', '~=', '<<=' and '>>=', and no '"
        m += tok_text(t)
        m += "': its u64s are '.u64s'"
        gen_error(n, m.cstr)
        return true
    }
    if shift {
        if !bit_number(v, "a shift of a Bits", true) { return true }
        put(tok_is(t, "<<=") ? "kv_bits_shl_assign(&(" : "kv_bits_shr_assign(&(")
        gen_expr(lhs)
        put("), (int64_t)(")
        gen_expr(v)
        put("));\n")
        return true
    }
    if !is_bits(type_of(v)) {
        var m = $"'"
        m += tok_text(t)
        m += "' of a Bits takes another Bits: 'Bits(n)' makes one of an integer"
        gen_error(v, m.cstr)
        return true
    }
    put("({ ")
    let hv:int64 = bits_hold(v)
    put("kv_bits_with(&(")
    gen_expr(lhs)
    put("), ")
    put_bits_ref(v, hv)
    put(tok_is(t, "|=") ? ", '|'" : tok_is(t, "&=") ? ", '&'" : ", '^'")
    put("); });\n")
    return true
}

// alignof(T) and x.align (#395), as kelvinc's: C's _Alignof, of a value
// its __typeof__'s; whether n is one, written
let gen_align(n:int64):bool {
    let k = nodes[n].kind
    let a:int64 = nodes[n].a
    if k == N_ALIGN {                                    // alignof(T) (#395), as kelvinc's: C's _Alignof
        let y:int64 = nodes[n].ty
        if types[y].kind == Y_STRUCT && decl_named(types[y].name, D_STRUCT) < 0 && decl_named(types[y].name, D_ENUM) < 0 && var_type(types[y].name) >= 0 {
            gen_error(n, "alignof takes a type, as C's does: alignof(T); a value's alignment is x.align")
            return true
        }
        put("((int64_t)_Alignof(")
        put_ctype(y)
        put("))")
        return true
    }
    if k == N_FIELD && value_align(n) {                  // x.align (#395), its type's: C's _Alignof of its __typeof__
        put("((int64_t)_Alignof(__typeof__(")
        gen_expr(a)
        put(")))")
        return true
    }
    return false
}

// whether the .type of the N_FIELD f is x's type, kelvinc's #34, not a
// member (#421): of a struct of the program's without a member type, an
// enum, or a value of another type kc knows; a C struct's, and a value's
// kc does not know, a member, as kelvinc's type_is_field
let type_member(f:int64):bool {
    if nodes[f].kind != N_FIELD || !tok_is(nodes[f].t, "type") { return false }
    let b:int64 = type_of(nodes[f].a)
    if b < 0 || types[b].kind == Y_C { return false }
    if types[b].kind == Y_STRUCT {
        if decl_named(types[b].name, D_STRUCT) >= 0 { return field_type(b, nodes[f].t) < 0 }
        return decl_named(types[b].name, D_ENUM) >= 0 || tagged_of(b) >= 0
    }
    return true
}

// whether f is x.typename (#426), as kelvinc's #34: its type's Kelvin
// name, text, but a member of a Kelvin struct named so
let typename_member(f:int64):bool {
    if nodes[f].kind != N_FIELD || !tok_is(nodes[f].t, "typename") { return false }
    if function_named(nodes[f].a) { return true }
    let b:int64 = type_of(nodes[f].a)
    if b >= 0 && types[b].kind == Y_STRUCT && decl_named(types[b].name, D_STRUCT) >= 0 { return field_type(b, nodes[f].t) < 0 }
    return b < 0 || types[b].kind != Y_RANGE             // a Range has none, kelvinc's error
}

// whether a is a function's name, no variable's (#426)
let function_named(a:int64):bool {
    return nodes[a].kind == N_ID && var_type(nodes[a].t) < 0 && decl_named(nodes[a].t, D_FN) >= 0
}

// f.typename of the function the N_ID a names (#426), as kelvinc's:
// (i64, cstr):bool, () of no result
let function_typename(a:int64) {
    var d:int64 = 0 - 1
    var fns:int64 = 0
    for x in decls {                                     // its overloads (#41)
        if nodes[x].kind == D_FN && nodes[x].c < 0 && same_text(nodes[x].t, nodes[a].t) {
            d = x
            fns += 1
        }
    }
    if fns > 1 {                                         // as kelvinc says it
        var m = $"'"
        m += tok_text(nodes[a].t)
        m += "' names "
        m += String(fns)
        m += " functions: say which by its type, as in 'let f:(T):R := "
        m += tok_text(nodes[a].t)
        m += "'"
        gen_error(a, m.cstr)
        return
    }
    put("\"(")
    var p:int64 = nodes[d].a
    while p >= 0 {
        let w:String = kelvin_type_text(nodes[p].ty)
        out += &w
        p = nodes[p].next
        if p >= 0 { put(", ") }
    }
    put(")")
    let r:int64 = nodes[d].ty
    if r >= 0 && types[r].kind != Y_VOID {
        put(":")
        let w:String = kelvin_type_text(r)
        out += &w
    }
    put("\"")
}

// x.typename (#426), as kelvinc's: the name of x's type as C text, x
// never run, a '?' after a '?' escaped (#220); of a literal, whose type
// is C's, "a" a u8^, or of what only C sees, C's _Generic, kv_typename
let gen_typename(n:int64) {
    let a:int64 = nodes[n].a
    if function_named(a) {
        function_typename(a)
        return
    }
    let y:int64 = type_of(a)
    if failed { return }
    if y < 0 || types[y].kind == Y_C || nodes[a].kind == N_NUM || nodes[a].kind == N_CHAR || nodes[a].kind == N_STR {
        put("kv_typename((")
        gen_expr(a)
        put("))")
        return
    }
    let w:String = kelvin_type_text(y)
    put("\"")
    var after_q = false
    for c in w {
        if c.utf32 == '?' && after_q { put("\\") }
        after_q = c.utf32 == '?'
        out += c
    }
    put("\"")
}

// sizeof(T) and sizeof x (#420), as kelvinc's: C's sizeof, an int64 as
// alignof's is; a struct's name a variable's where one hides it, a
// function's a pointer's size, and a name kc does not know C's, size_t;
// whether n is one
let gen_sizeof(n:int64):bool {
    if nodes[n].kind != N_SIZEOF { return false }
    let y:int64 = nodes[n].ty
    let a:int64 = nodes[n].a
    if nodes[n].flag == 1 {                              // as kelvinc says it
        var m = $"sizeof a type needs parentheses: sizeof("
        let w:String = kelvin_type_text(y)
        m += &w
        m += ")"
        gen_error(n, m.cstr)
        return true
    }
    if y < 0 && nodes[n].flag == 2 {                     // sizeof(x.type) (#421): x's size, of x.type^ a pointer's
        var f:int64 = a
        var stars = 0
        while nodes[f].kind == N_DEREF {
            f = nodes[f].a
            stars += 1
        }
        if type_member(f) {
            put("((int64_t)sizeof(")
            if stars == 0 {
                gen_expr(nodes[f].a)
            } else {
                put("__typeof__(")
                gen_expr(nodes[f].a)
                put(")")
                for _ in 0..<stars { put(" *") }
            }
            put("))")
            return true
        }
    }
    if y < 0 && type_member(a) {                         // sizeof x.type, as kelvinc says it
        gen_error(n, "'.type' is a type, not a value: use it where a type goes, as in 'var w:v.type' or 'x as v.type'")
        return true
    }
    put("((int64_t)sizeof(")
    if y >= 0 && types[y].kind == Y_STRUCT && types[y].name >= 0 && var_type(types[y].name) >= 0 {
        put_tok(types[y].name)
    } else if y >= 0 {
        put_ctype(y)
    } else if nodes[a].kind == N_ID && var_type(nodes[a].t) < 0 && decl_named(nodes[a].t, D_FN) >= 0 {
        put("&")
        put_tok(nodes[a].t)
    } else if nodes[a].kind == N_ID && var_type(nodes[a].t) < 0 {
        put_tok(nodes[a].t)
    } else {
        gen_expr(a)
    }
    put("))")
    return true
}

// ---------- a pointer into a temporary (#245) ----------

// whether n, a.t, is a pointer into an owner that a gives, which no
// variable holds (#227)
let points_into_temp(n:int64):bool {
    if nodes[n].kind != N_FIELD || typename_member(n) || tok_is(nodes[n].t, "typename") { return false }
    if !needs_hold(nodes[n].a) || held.get(nodes[n].a, 0 - 1) >= 0 { return false }
    let y = type_of(n)
    return y >= 0 && (types[y].kind == Y_CSTR || types[y].kind == Y_PTR)
}

// whether the call or subscript n gives a pointer, or what only C sees,
// which may be one: its pointers into temporaries go to the one around it
let passes_holds(n:int64):bool {
    let y = type_of(n)
    return y < 0 || types[y].kind == Y_CSTR || types[y].kind == Y_PTR || types[y].kind == Y_C
}

let pointer_holds(n:int64, out:$[int64]^)    // a prototype: the two call each other

// the owners that the pointers in the call n's receiver and arguments,
// or the subscript n's array and index, point into
let chain_holds(n:int64, out:$[int64]^) {
    pointer_holds(nodes[n].a, out)
    if nodes[n].kind == N_INDEX {
        pointer_holds(nodes[n].b, out)
        return
    }
    var a:int64 = nodes[n].b
    while a >= 0 {
        pointer_holds(a, out)
        a = nodes[a].next
    }
}

// the owners that the pointers in n point into, as kelvinc's #245 holds
// them for the call or subscript around n: a call of its own holds its
// own, unless it passes them on; an arm of ?: and the right of &&, || and ?? are not
// always evaluated, so theirs stay errors
let pointer_holds(n:int64, out:$[int64]^) {
    if n < 0 { return }
    let k:nkind = nodes[n].kind
    if points_into_temp(n) {
        out^ += nodes[n].a
    } else if k == N_CALL || k == N_METHOD {
        if passes_holds(n) { chain_holds(n, out) }
    } else if k == N_FIELD || k == N_UNARY || k == N_CAST || k == N_ADDR || k == N_DEREF || k == N_COND || k == N_DESIG {
        pointer_holds(nodes[n].a, out)
    } else if k == N_INDEX {
        chain_holds(n, out)
    } else if k == N_BIN {
        pointer_holds(nodes[n].a, out)
        let t = nodes[n].t
        if !tok_is(t, "&&") && !tok_is(t, "||") && !tok_is(t, "??") { pointer_holds(nodes[n].b, out) }
    } else if k == N_ARRAY || k == N_SET || k == N_DICT || k == N_INIT {
        var e:int64 = nodes[n].b
        while e >= 0 {
            pointer_holds(e, out)
            e = nodes[e].next
        }
    }
}

var holding_chain:int64 = 0 - 1        // the call or subscript whose pointers into temporaries are held

// the call or subscript n with the owners its pointers point into held
// until it is done (#245), as strlen($"abc".cstr) and $"zz".cstr[0]:
// false where it has none, or where it gives a pointer, which passes
// them to the one around it
let gen_holding_chain(n:int64):bool {
    let k:nkind = nodes[n].kind
    if (k != N_CALL && k != N_METHOD && k != N_INDEX) || holding_chain == n { return false }
    let y = type_of(n)
    if y >= 0 && (types[y].kind == Y_CSTR || types[y].kind == Y_PTR) { return false }
    var opened:$[int64] = $[]
    chain_holds(n, &opened)
    if opened.count == 0 { return false }
    for i in 0..<opened.count as int64 { hold_open(opened[i]) }
    let saved = holding_chain
    holding_chain = n
    gen_expr(n)
    holding_chain = saved
    close_holds(&opened)
    return true
}

let gen_expr_of(n:int64)    // a prototype: gen_expr writes n by it

// n, and the owners its call moved out dead after it, as kelvinc marks
// them where the call's arguments end (#441)
let gen_expr(n:int64) {
    resolve_op(n)
    resolve_attr(n)
    gen_expr_of(n)
    if nodes[n].kind == N_CALL || nodes[n].kind == N_METHOD { moves_done() }
}

let gen_expr_of(n:int64) {
    if failed { return }
    if held.get(n, 0 - 1) >= 0 {                         // held in a temporary (#227)
        put("_kv_tmp")
        put_int(held.get(n, 0 - 1))
        return
    }
    if gen_holding_chain(n) { return }                   // (#245)
    if os_call(n) {                                      // OS.name(args), SYS.name (#463)
        gen_os(n)
        return
    }
    if gen_bits(n) { return }                            // a Bits's (#387)
    if gen_align(n) { return }                           // (#395)
    if gen_sizeof(n) { return }                          // (#420)
    let k:nkind = nodes[n].kind
    let t:int64 = nodes[n].t
    if (k == N_ID || k == N_CALL) && nodes[n].ty >= 0 && is_case_word(n) {   // Result<T, E>.err(e), Optional<T>.none (#449)
        let d:int64 = tagged_of(nodes[n].ty)
        let w:int64 = k == N_CALL ? nodes[nodes[n].a].t : t
        if d < 0 || case_named(d, w) == none {           // as kelvinc says it
            var m = kelvin_type_text(nodes[n].ty)
            m += " has no case '"
            m += tok_text(w)
            m += "': the cases are "
            if d >= 0 {
                m += tok_text(nodes[nodes[d].a].t)
                m += ", "
                m += tok_text(nodes[nodes[nodes[d].a].next].t)
            }
            gen_error(n, m.cstr)
            return
        }
        gen_value(n, nodes[n].ty)
        return
    }
    if k == N_ANON {                                     // a value (#428), of its own written type
        let y:int64 = anon_type(n)
        if y >= 0 { gen_fn_value(n, y) }
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
    if k == N_BIN && (tok_is(t, "!!") || (tok_is(t, "??") && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_DICT)) {
        gen_fill(t, nodes[n].a, nodes[n].b, false)       // d0 ?? d1, d0 !! d1 (#460)
        return
    }
    if k == N_LIST && nodes[n].flag == 0 && nodes[n].ty >= 0 {   // ([T](N))[a, b], C's compound literal (#419)
        gen_array_literal(n)
        return
    }
    if k == N_LIST {                                     // as kelvinc says it, kc's for its compound literal (#354)
        gen_error(n, "an array is not a value here: kc reads [a, b] as a declaration's value; elsewhere write its compound literal, ([i32])[1, 2, 3] (#48)")
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
    if k == N_METHOD && (tok_is(t, "join") || tok_is(t, "joined")) && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_ARRAY && method_of(n) < 0 {
        gen_join(n)                                      // xs.join(sep), xs.joined(sep) (#461)
        return
    }
    if k == N_METHOD && (tok_is(t, "sort") || tok_is(t, "sorted")) && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_ARRAY && method_of(n) < 0 {
        gen_array_sort(n)                                // xs.sort(), xs.sorted() (#470)
        return
    }
    if k == N_METHOD && (tok_is(t, "reverse") || tok_is(t, "reversed")) && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind == Y_ARRAY && method_of(n) < 0 {
        gen_array_reverse(n)                             // xs.reverse(), xs.reversed() (#470)
        return
    }
    if k == N_METHOD && tok_is(t, "pow") && power_int(type_of(nodes[n].a)) {
        gen_pow_method(n)                                // b.pow(e), b.pow(e, m) of an integer (#380)
        return
    }
    if k == N_FIELD && scalar_cstr(n) {
        gen_scalar_cstr(n)                               // x.cstr of a number, a bool, a uchr or a pointer (#462)
        return
    }
    if k == N_FIELD && pointer_property(n) > 0 {
        gen_pointer_property(n)                          // x.size, p.addr, p.next, p.prev (#462)
        return
    }
    if k == N_FIELD && tok_is(t, "isNull") && type_of(n) >= 0 && types[type_of(n)].kind == Y_BOOL && type_of(nodes[n].a) >= 0 && types[type_of(nodes[n].a)].kind != Y_STRUCT && types[type_of(nodes[n].a)].kind != Y_C {
        put("((bool)((")                                 // p.isNull (#460), as kelvinc's #50: C's == gives an int
        gen_expr(nodes[n].a)
        put(") == 0))")
        return
    }
    if k == N_FIELD && (tok_is(t, "isNaN") || tok_is(t, "isInfinite") || tok_is(t, "isFinite")) && type_of(nodes[n].a) >= 0 && power_float(type_of(nodes[n].a)) {
        put(tok_is(t, "isNaN") ? "((bool)__builtin_isnan(" : tok_is(t, "isInfinite") ? "((bool)__builtin_isinf(" : "((bool)__builtin_isfinite(")   // x.isNaN (#382), x.isInfinite, x.isFinite (#384), as kelvinc's
        gen_expr(nodes[n].a)
        put("))")
        return
    }
    if k == N_FIELD && tok_is(t, "sign") && type_of(nodes[n].a) >= 0 {
        let sy:int64 = int_view(type_of(nodes[n].a))     // x.sign (#382), as kelvinc's: -1, 0 or 1 of its type;
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
        if is_signed_kind(sk) {
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
        let ay:int64 = int_view(type_of(nodes[n].a))     // an enum's value an i32 (#469)
        let ak:ykind = types[ay].kind
        if ak == Y_F64 || ak == Y_F32 {                  // x.abs (#381), as kelvinc's: fabs
            put(ak == Y_F32 ? "__builtin_fabsf(" : "__builtin_fabs(")
            gen_expr(nodes[n].a)
            put(")")
            return
        }
        if is_signed_kind(ak) {                          // negated in its unsigned type, where i64's least wraps
            let u:cstr := ak == Y_I128 ? "unsigned __int128" : ak == Y_I64 ? "uint64_t" : ak == Y_I32 ? "uint32_t" : ak == Y_I16 ? "uint16_t" : "uint8_t"
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
    if k == N_FIELD && tok_is(t, "isEmpty") && empty_kind(n) != 0 {
        gen_is_empty(n)                                  // x.isEmpty (#435)
        return
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
    } else if k == N_ID && var_type(t) < 0 && fn_named(t) >= 0 {
        let y:int64 = named_fn_type(n)                   // a function's name, a value (#428)
        if y >= 0 { gen_fn_value(n, y) }
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
    } else if k == N_ID && n != anew && moved_error(n) {
        return                                           // read after it moved out, kelvinc's error (#441)
    } else if k == N_NUM && above_i64(t) {
        put_tok(t)                                       // no signed C type holds it, and C warns, as kelvinc says (#472)
        put("U")
    } else if k == N_NUM || k == N_CHAR || k == N_ID {
        put_tok(t)
    } else if k == N_STR {
        put_text(t, 0)
        for more in 1...nodes[n].flag { // "a" "b", C's adjacent literals (#459)
            put(" ")
            put_text(t + more, 0)
        }
    } else if k == N_DSTR {
        put("KV_STRING_LIT(")                            // $"...", its every byte, a NUL too (#299)
        put_text(t, 1)
        put(")")
    } else if k == N_TPL {
        gen_template(n)                                  // (#445)
    } else if k == N_TRY {
        gen_try(n, true)                                 // (#449)
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
    } else if k == N_BIN && (is_bytes(type_of(nodes[n].a)) || is_bytes(type_of(nodes[n].b))) {
        gen_bytes_bin(n)                                 // b == c, b < c, and kelvinc's errors (#439)
    } else if k == N_BIN && is_string_plus(n) {
        gen_string_plus(n)                               // s + t (#284)
    } else if k == N_BIN && (uchr_typed(nodes[n].a) || uchr_typed(nodes[n].b)) {
        gen_uchr_compare(n)                              // c == ' ', c < d, by the codepoint (#478)
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
        } else if y >= 0 && types[y].kind == Y_STRING && is_comparison(t) {
            gen_string_order(n)                          // a < b, by codepoints (#470)
        } else if builtin_kind(type_of(nodes[n].b)) == Y_STRING && is_comparison(t) && !tok_is(t, "==") && !tok_is(t, "!=") {
            gen_error(n, "a String compares with another String")
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
    } else if k == N_CAST && types[nodes[n].ty].kind == Y_UCHR && (type_of(nodes[n].a) < 0 || types[type_of(nodes[n].a)].kind != Y_UCHR) {
        var m = $"'"                                     // a uchr is a struct to C, which no cast makes, as kelvinc says it (#468)
        m += tok_is(t, "as") ? "as " : ":"
        m += "uchr' makes no codepoint: write uchr(\"k\") of text, or n.uchr of an integer"
        gen_error(n, m.cstr)
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
    } else if k == N_INIT && struct_of(nodes[n].ty) >= 0 {   // (T){a, b} (#418)
        put("(")
        put_ctype(nodes[n].ty)
        put(")")
        gen_init(n, struct_of(nodes[n].ty))
    } else if k == N_INIT && nodes[n].ty >= 0 {
        gen_error(n, "kc reads (T){...} of a struct; not yet of another type")
    } else if k == N_DESIG {                             // .name = v where kc sees no struct (#418)
        put(".")
        put_tok(nodes[n].t)
        put(" = ")
        gen_expr(nodes[n].a)
    } else if k == N_INIT {
        put("{")
        gen_args(nodes[n].b)
        put("}")
    } else if k == N_EMPTY {
        empty_error(n)                                   // where no type is written (#348)
    } else if k == N_ARRAY {
        gen_array(n, -1)
    } else if k == N_DICT && tok_is(t, "{") {           // {k: v} where no Dictionary is written (#460), as kelvinc says it
        gen_error(n, "a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'; an anonymous function here writes its parameters, as in '{ (a:i64):i64 in a + 1 }'")
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
    resolve_op(v)
    let k:nkind = nodes[v].kind
    if k == N_STR {
        if nodes[n].c != 1 { gen_error(n, "text is a reference, a cstr: assign it with :=, not =") }
        return base_type(Y_CSTR)
    }
    if k == N_TPL && nodes[v].flag == 0 {               // `a${x}b`, a cstr too (#445)
        if nodes[n].c != 1 { gen_error(n, "text is a reference, a cstr: assign it with :=, not =") }
        return base_type(Y_CSTR)
    }
    if k == N_CHAR { return base_type(Y_U8) }
    if k == N_ANON { return anon_type(v) }               // its written type, or kelvinc's error of $0 (#428)
    if k == N_UNARY && tok_is(nodes[v].t, "-") && nodes[nodes[v].a].kind == N_NUM { return type_of(nodes[v].a) }   // -1, -1.5 (#262)
    if k == N_ARRAY && !one_type(v) { return -1 }                     // $[a, b] (#266)
    if k == N_DICT && tok_is(nodes[v].t, "{") {         // var x = {k: v}, as kelvinc says it (#460)
        gen_error(v, "expected '}', found ':'")
        return -1
    }
    if k == N_DICT && !one_entry_type(v) { return -1 }                // ${k: v} (#267)
    let set_op = k == N_BIN && type_of(nodes[v].a) >= 0 && (types[type_of(nodes[v].a)].kind == Y_SET || types[type_of(nodes[v].a)].kind == Y_BITS)   // s | t, a Set, as kelvinc infers it (#276); b | c, a Bits (#387)
    if k == N_BIN && literal_arith(v) == 2 { return base_type(Y_F64) }   // 1.0 / 0.0, of literals alone (#385)
    if k == N_BIN && literal_arith(v) == 1 {             // 60 * 60, reckoned in an i64
        widened[v] = true
        return base_type(Y_I64)
    }
    if k == N_BIN && tok_is(nodes[v].t, "**") && (!power_operand(nodes[v].a) || !power_operand(nodes[v].b)) { return -1 }   // as kelvinc says it (#380)
    if k == N_METHOD && tok_is(nodes[v].t, "pow") && power_int(type_of(nodes[v].a)) && !pow_arity(v) { return -1 }
    if k == N_BIN && !tok_is(nodes[v].t, "??") && !tok_is(nodes[v].t, "!!") && !is_comparison(nodes[v].t) && tagged_side(v) >= 0 {   // as kelvinc says it (#121)
        gen_variant_eq(v, tagged_side(v))
        return -1
    }
    if k == N_BIN && !is_comparison(nodes[v].t) && !is_string_plus(v) && (uchr_typed(nodes[v].a) || uchr_typed(nodes[v].b)) { return type_of(v) }   // a uchr's arithmetic, in kelvinc's words (#478)
    if k == N_BIN && !is_comparison(nodes[v].t) && !tok_is(nodes[v].t, "??") && !tok_is(nodes[v].t, "!!") && !tok_is(nodes[v].t, "**") && !set_op && !is_string_plus(v) {   // x ?? d is x's T (#217); s + t a String (#284); b ** e kelvinc's (#380); d0 !! d1 (#460)
        gen_error(n, "this variable needs a type: write name:T, since a type is not inferred from arithmetic")
        return -1
    }
    let w:int64 = k == N_ID ? nodes[v].t : k == N_CALL && nodes[nodes[v].a].kind == N_ID ? nodes[nodes[v].a].t : 0 - 1
    let word = w >= 0 && is_case_word(v) && nodes[v].ty < 0 && (tok_is(w, "none") || tok_is(w, "ok") || tok_is(w, "err") || tok_is(w, "some"))   // none, ok(v), err(e) (#341)
    if k == N_EMPTY {                                    // as kelvinc says it (#348)
        empty_error(v)
        return -1
    }
    if bare_init(v) || k == N_NULL || word {
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
    case Y_VOID: return $"any"                               // any^ (#470)
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
    case Y_CSTR: return $"cstr"
    case Y_STRING: return $"String"
    case Y_BYTES: return $"Bytes"
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
        var s = types[y].name == 0 - 3 || types[y].konst == 1 ? $"[const " : $"["   // [const T](N) (#425)
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
        var s = ptr_const(y) ? $"const " : $""           // (#272)
        let e = type_text(types[y].elem)
        s += &e
        s += "^"
        if ptr_restrict(y) { s += " restrict" }          // (#393)
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
    case Y_FN:                                       // (i64, cstr):bool, (i64) of no result, as kelvinc names it (#428)
        var s = $"("
        var p:int64 = types[y].name
        while p >= 0 {
            let w:String = kelvin_type_text(types[p].elem)
            s += &w
            p = types[p].name
            if p >= 0 { s += ", " }
        }
        s += ")"
        if types[y].elem >= 0 {
            s += ":"
            let w:String = kelvin_type_text(types[y].elem)
            s += &w
        }
        return s
    case Y_STRUCT:
        let d = tagged_of(y)
        if d >= 0 && nodes[d].c == 1 {                  // an Array inside as Array<T>, as kelvinc names it (#463)
            var s = kelvin_type_text(some_type(y))
            s += "?"
            return s
        }
        if d >= 0 && kc_made(types[y].name) {           // made by kc, as no Optional: Result<T, E>
            let m = nodes[d].a
            var s = $"Result<"
            s += kelvin_type_text(nodes[m].ty)
            s += ", "
            s += kelvin_type_text(nodes[nodes[m].next].ty)
            s += ">"
            return s
        }
        let spelled:String = os_spellings[tok_text(types[y].name)] ?? $""
        if spelled.count > 0 { return spelled }          // OS.stat's {dev: i64, ...}, as kelvinc spells it (#463)
        return kelvin_name(types[y].name)                 // point.kind, of one nested (#389)
    default: return $"a type only C sees"
    }
}

// whether = or := suits y, as kelvinc has it (#233): a reference, a cstr or
// a T^, takes :=, and a value =; else an error that names t, the name
// assigned, and what it is
let assigns_as(n:int64, t:int64, y:int64, colon:bool):bool {
    let k:ykind = y >= 0 ? types[y].kind : Y_C
    if k == Y_C || k == Y_ARRAY || k == Y_DICT { return true }   // what only C sees; an Array and a Dictionary, as kelvinc
    let reference = types[y].kind == Y_CSTR || types[y].kind == Y_PTR || types[y].kind == Y_FN   // a function's, a pointer in C (#428)
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
    if d >= 0 && kc_made(types[y].name) {               // an Optional's or a Result's, which kc makes
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
// bool, a cstr, a uchr (#479), a struct that owns nothing, or a fixed
// array in turn
let fixed_elem_ok(y:int64):bool {
    let k:ykind = types[y].kind
    if k == Y_FIXED { return fixed_elem_ok(types[y].elem) }
    if is_owner(y) || fixed_inside(y) { return false }
    return is_number_kind(k) || k == Y_BOOL || k == Y_CSTR || k == Y_UCHR || k == Y_STRUCT
}

// a fixed array's C declarator: its element type, name, and [N] for each
// count, the outer first, as C's int64_t m[2][3] (#354)
var fixed_const = false                  // a let global's elements, const in C (#359)

// _Alignas(N) or _Alignas(T) of a variable or member n written alignas (#396)
let put_alignas(n:int64) {
    for i in 0..<aligned.count as int64 {
        if aligned[i] == n {
            put("_Alignas(")
            if aligned_exprs[i] >= 0 { gen_expr(aligned_exprs[i]) } else { put_ctype(aligned_types[i]) }
            put(") ")
            return
        }
    }
}

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
    var konst = false
    while types[base].kind == Y_FIXED {
        if types[base].konst == 1 { konst = true }
        base = types[base].elem
    }
    if konst { put("const ") }                           // [const T](N): const int32_t a[3] (#425)
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

// the type of ([T])[a, b] written y (#419): a count its elements give,
// and a row's its first row's, [[T]] of [[1, 2], [3, 4]] [[T](2)](2), as
// kelvinc counts them
let counted(y:int64, v:int64):int64 {
    if types[y].kind != Y_FIXED { return y }
    var e:int64 = types[y].elem
    let first:int64 = nodes[v].b
    if types[e].kind == Y_FIXED && types[e].name == 0 - 1 && first >= 0 && nodes[first].kind == N_LIST && nodes[first].flag == 0 {
        e = counted(e, first)
    }
    var c:int64 = types[y].name
    if c == 0 - 1 {
        c = 0
        var x:int64 = first
        while x >= 0 {
            c += 1
            x = nodes[x].next
        }
    }
    return type_of_kind(Y_FIXED, e, c)
}

// ([T](N))[a, b] where no type is written (#419): C's (T [N]){a, b}, its
// elements checked as a declaration's, as kelvinc writes it
let gen_array_literal(n:int64) {
    let y:int64 = type_of(n)
    if types[y].kind != Y_FIXED || types[y].name == 0 - 3 {
        gen_error(n, "kc reads an array's compound literal of [T](N) and of [T]; not yet of another type")
        return
    }
    if !fixed_elem_ok(types[y].elem) {
        if is_owner(types[y].elem) {                     // as kelvinc says it
            gen_error(n, "an array of owners is not here yet: a struct may hold them")
        } else {
            fixed_refused(n)
        }
        return
    }
    if fixed_computed(y) {
        gen_error(n, "an array of a count computed at run time takes no elements in C: give them one by one, a[i] = ...")
        return
    }
    if nodes[n].b < 0 {
        gen_error(n, "[] has no elements: write [T](N), N zero elements")
        return
    }
    if !fixed_list_fits(n, y) { return }
    put("(")
    put_fixed_base(y)
    put_fixed_counts(y)
    put(")")
    gen_fixed_list(n, y)
}

// whether the elements of [a, b] fit y, a fixed array: each of its element
// type, as gen_array asks of $[a, b], no more than its count (#354); of
// ([T](N))[a, b], its type y, or one of its elements where y has no count (#419)
let fixed_list_fits(v:int64, y:int64):bool {
    let e:int64 = types[y].elem
    if nodes[v].ty >= 0 && nodes[v].flag == 0 {
        let vy:int64 = plain_fixed(type_of(v))
        if vy != plain_fixed(y) && !(types[y].name == 0 - 1 && types[vy].kind == Y_FIXED && types[vy].elem == e) {   // [const T](N) of ([T](N))[a, b] (#425)
            var m = $"this is "
            let vw:String = type_text(vy)
            m += &vw
            m += ", where "
            let yw:String = type_text(y)
            m += &yw
            m += " goes"
            gen_error(v, m.cstr)
            return false
        }
    }
    var count = 0
    var x = nodes[v].b
    while x >= 0 {
        count += 1
        if nodes[x].kind == N_LIST && nodes[x].flag == 0 && types[e].kind == Y_FIXED {
            if !fixed_list_fits(x, e) { return false }
        } else if is_owner(e) && is_place(x) && !is_case_word(x) {   // as an Array's elements (#364)
            owner_assign_error(x)
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
// whether e is C's constant of an integer: numbers and enumerators, by
// + - * / % and a minus, as [bool](LIMIT + 1) counts (#451)
let constant_count(e:int64):bool {
    let k = nodes[e].kind
    if k == N_NUM { return !float_tok(nodes[e].t) }
    if k == N_ID { return local_at(nodes[e].t) < 0 && decl_named(nodes[e].t, D_GLOBAL) < 0 && enum_of(nodes[e].t) >= 0 }
    if k == N_UNARY && tok_is(nodes[e].t, "-") { return constant_count(nodes[e].a) }
    if k == N_BIN {
        let t:int64 = nodes[e].t
        let arith = tok_is(t, "+") || tok_is(t, "-") || tok_is(t, "*") || tok_is(t, "/") || tok_is(t, "%")
        return arith && constant_count(nodes[e].a) && constant_count(nodes[e].b)
    }
    return false
}

let fixed_computed(y:int64):bool {
    var f:int64 = y
    while types[f].kind == Y_FIXED {
        if types[f].name <= 0 - 10 && !constant_count(0 - 10 - types[f].name) { return true }
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
    let zeros_computed = v >= 0 && nodes[v].kind == N_LIST && nodes[v].flag == 1 && type_of(v) >= 0 && fixed_computed(type_of(v))
    if fixed_computed(y) || zeros_computed {             // a count C computes, a local var's (#366); not of constants (#451)
        if types[y].name == 0 - 1 { y = type_of(v) }
        if !computed_ok(n, y, v) { return }
        set_ty(n, y)
        put_alignas(n)
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
        if types[y].name == 0 - 1 { y = types[y].konst == 1 ? const_fixed(zy) : zy }
        if plain_fixed(y) != zy {                        // [const T](N) of [T](n) (#425)
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
        if nodes[v].b < 0 && types[y].name < 0 && types[y].name > 0 - 10 {   // [T](2) = [], its count's zeros, as kelvinc's
            gen_error(v, "[] has no elements: write [T](N), N zero elements")
            return
        }
        if nodes[v].b >= 0 && !fixed_list_fits(v, y) { return }
        if types[y].name < 0 && types[y].name > 0 - 10 {   // [T] of its elements; [T](LIMIT + 1) keeps its count (#451)
            let konst = types[y].konst == 1
            y = type_of_kind(Y_FIXED, types[y].elem, type_of(v) >= 0 ? types[type_of(v)].name : 0)
            if konst { y = const_fixed(y) }              // (#425)
        }
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
    put_alignas(n)                                       // (#396)
    put_fixed_decl(y, nodes[n].t)
    put(" = ")
    if v >= 0 && nodes[v].kind == N_LIST && nodes[v].flag == 0 && nodes[v].b >= 0 {
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
    let copied = nodes[n].a >= 0 && owner_name(nodes[n].a) && type_of(nodes[n].a) == y   // var s = t, freed twice else (#440)
    if nodes[n].a >= 0 && (owner_part(nodes[n].a) || copied) && nodes[n].c != 1 {   // as kelvinc says it, an alias else (#365)
        owner_assign_error(nodes[n].a)
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
    if static_decls.contains(n) {                        // a local that lives on, C's (#459)
        if is_owner(y) {
            gen_error(n, "a static local lives on past its block, which frees an owner: make it a global")
            return
        }
        put("static ")
    }
    put_alignas(n)                                       // (#396)
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
    if k == N_DESIG { return has_call(nodes[n].a) }    // (#418)
    if k == N_SIZEOF { return false }                  // sizeof calls nothing it reads (#420)
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

// whether n names an enum's constant, which never changes: then an
// error, in kelvinc's words (#469)
let enum_constant_changed(n:int64):bool {
    if nodes[n].kind != N_ID || local_at(nodes[n].t) >= 0 || decl_named(nodes[n].t, D_GLOBAL) >= 0 || enum_of(nodes[n].t) < 0 { return false }
    var m = $"'"
    m += tok_text(nodes[n].t)
    m += "' is an enum's constant and cannot change; copy it into a var, as in 'var k:i32 = "
    m += tok_text(nodes[n].t)
    m += "'"
    gen_error(n, m.cstr)
    return true
}

// the attributes a place's members read, down to what holds them (#131, #133)
let resolve_chain(n:int64) {
    var e = n
    resolve_attr(e)
    while nodes[e].kind == N_FIELD || nodes[e].kind == N_INDEX {
        e = nodes[e].a
        resolve_attr(e)
    }
}

// a change of place n where its variable is a let is an error, in
// kelvinc's words (#271); whether n may change
let may_change(n:int64):bool {
    resolve_chain(n)
    if enum_constant_changed(n) { return false }
    var e = n                                           // a[i] of a parameter's array, its caller's element (#357)
    while nodes[e].kind == N_FIELD || nodes[e].kind == N_INDEX {
        if nodes[e].kind == N_INDEX {
            let ay:int64 = type_of(nodes[e].a)
            if ay >= 0 && types[ay].kind == Y_FIXED && types[ay].name == 0 - 2 { return true }
            if ay >= 0 && types[ay].kind == Y_FIXED && types[ay].konst == 1 {   // (#425)
                var m = $"this changes an element of a "
                let w:String = type_text(ay)
                m += &w
                m += ", whose elements are const: declare it without const to change them"
                gen_error(n, m.cstr)
                return false
            }
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
    if nodes[d].kind == N_SELF && current >= 0 && subscripts.get(current, 0) == 1 {   // (#136)
        gen_error(n, "a let subscript and a var subscript's getter read self and never change it: a var subscript's setter, 'set(v) { ... }', does")
        return false
    }
    if nodes[d].kind == N_SELF && current >= 0 && (attributes.get(current, 0) == 1 || attributes.get(current, 0) == 2) {   // (#137)
        gen_error(n, "a let attribute and a var attribute's getter read self and never change it: a var attribute's setter, 'set(v) { ... }', does")
        return false
    }
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
        if p >= 0 && types[p].kind == Y_PTR && ptr_const(p) {
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
    resolve_chain(n)
    if enum_constant_changed(n) { return false }
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

// v.x = y and v.x += y of a computed attribute (#132): its setter, on the
// var that holds v, in kelvinc's words; whether n is one
let attr_assign(n:int64):bool {
    let lhs:int64 = nodes[n].a
    resolve_attr(lhs)
    if !attr_reads.has(lhs) { return false }
    let a:int64 = nodes[lhs].a
    let x:int64 = nodes[lhs].t
    let t:int64 = nodes[n].t
    let nm:String = tok_text(x)
    let getter:int64 = method_of(lhs)
    var word = $"set_"
    word += &nm
    let setter:int64 = getter >= 0 ? method_named(nodes[getter].c, made_token(&word)) : 0 - 1
    if setter < 0 {
        var m = $"'"
        m += &nm
        m += "' is a let attribute, computed and never set: a var attribute has a setter, 'var T."
        m += &nm
        m += ":R { get { ... } set(v) { ... } }'"
        gen_error(n, m.cstr)
        return true
    }
    if tok_is(t, ":=") {
        gen_error(n, "':=' sets a reference: an attribute is set with '='")
        return true
    }
    if !may_change(a) { return true }
    if !changeable_place(a) {
        var m = $"the setter of '"
        m += &nm
        m += "' changes the value it is called on, so that value is a variable"
        gen_error(n, m.cstr)
        return true
    }
    var v:int64 = nodes[n].b
    if !tok_is(t, "=") {                                // x.y op= v, x.y = x.y op v
        var op = String(compound_op(t))
        if has_call(a) {
            var m = $"'x."
            m += &nm
            m += " "
            m += tok_text(t)
            m += " y' is 'x."
            m += &nm
            m += " = x."
            m += &nm
            m += " "
            m += &op
            m += " y', which reads x twice, so x may not hold a call"
            gen_error(n, m.cstr)
            return true
        }
        let op_tok:int64 = made_token(&op)
        toks[op_tok].kind = T_PUNCT
        toks[op_tok].line = toks[t].line
        toks[op_tok].file = toks[t].file
        let bin:int64 = make_node(N_BIN, op_tok)
        nodes[bin].a = lhs
        nodes[bin].b = v
        v = bin
    }
    put_tok(nodes[setter].c)
    put("__")
    put_tok(nodes[setter].t)
    put("(")
    gen_place(a)
    put(", ")
    gen_args_to(v, setter)
    put(");\n")
    moves_done()
    return true
}

// v[i] = y and v[i] += y of a subscript (#136): the setter of the one the
// read chose, on the var that holds v, in kelvinc's words; whether n is one
let sub_assign(n:int64):bool {
    let lhs:int64 = nodes[n].a
    resolve_attr(lhs)
    let g:int64 = sub_targets.get(lhs, 0 - 1)
    if g < 0 { return false }
    let a:int64 = nodes[lhs].a
    let t:int64 = nodes[n].t
    var setter:int64 = 0 - 1
    for s in sub_setters {
        if setter >= 0 || !same_text(nodes[s].c, nodes[g].c) || count_params(s) != count_params(g) + 1 { continue }
        var same = true
        var p:int64 = nodes[g].a
        var q:int64 = nodes[s].a
        while same && p >= 0 {
            same = nodes[p].ty == nodes[q].ty
            p = nodes[p].next
            q = nodes[q].next
        }
        if same { setter = s }
    }
    if setter < 0 {
        var m = $"this subscript of "
        m += tok_text(nodes[g].c)
        m += " is a let, read and never set: a var subscript has a setter, 'var [](i:I):R { get { ... } set(v) { ... } }'"
        gen_error(n, m.cstr)
        return true
    }
    if tok_is(t, ":=") {
        gen_error(n, "':=' sets a reference: a subscript is set with '='")
        return true
    }
    if !may_change(a) { return true }
    if !changeable_place(a) {
        gen_error(n, "a subscript's setter changes the value it is called on, so that value is a variable")
        return true
    }
    var v:int64 = nodes[n].b
    if !tok_is(t, "=") {                                // v[i] op= y, v[i] = v[i] op y
        var op = String(compound_op(t))
        var twice = !has_call(a)
        var i:int64 = nodes[lhs].b
        while twice && i >= 0 {
            twice = !has_call(i)
            i = nodes[i].next
        }
        if !twice {
            var m = $"'v[i] "
            m += tok_text(t)
            m += " y' is 'v[i] = v[i] "
            m += &op
            m += " y', which reads v and i twice, so neither may hold a call"
            gen_error(n, m.cstr)
            return true
        }
        let op_tok:int64 = made_token(&op)
        toks[op_tok].kind = T_PUNCT
        toks[op_tok].line = toks[t].line
        toks[op_tok].file = toks[t].file
        let bin:int64 = make_node(N_BIN, op_tok)
        nodes[bin].a = lhs
        nodes[bin].b = v
        v = bin
    }
    put_tok(nodes[setter].c)
    put("__")
    put_tok(nodes[setter].t)
    put("(")
    gen_place(a)
    var i:int64 = nodes[lhs].b
    var p:int64 = nodes[setter].a
    while i >= 0 {                                      // the indices, then the new value
        put(", ")
        if !gen_arg_to(i, p, setter) { return true }
        i = nodes[i].next
        p = nodes[p].next
    }
    put(", ")
    if !gen_arg_to(v, p, setter) { return true }
    put(");\n")
    moves_done()
    return true
}

let gen_assign(n:int64) {
    if attr_assign(n) || sub_assign(n) { return }
    let lhs:int64 = nodes[n].a
    var t:int64 = nodes[n].t
    if nodes[lhs].kind == N_FIELD && (tok_is(nodes[lhs].t, "sign") || tok_is(nodes[lhs].t, "exponent") || tok_is(nodes[lhs].t, "significand") || tok_is(nodes[lhs].t, "abs") || tok_is(nodes[lhs].t, "isNaN") || tok_is(nodes[lhs].t, "isInfinite") || tok_is(nodes[lhs].t, "isFinite")) && type_of(nodes[lhs].a) >= 0 && (power_float(type_of(nodes[lhs].a)) || power_int(type_of(nodes[lhs].a))) {
        if !may_change(lhs) { return }                  // a number's own (#381, #382, #383)
        gen_float_set(n)
        return
    }
    if nodes[lhs].kind == N_METHOD && tok_is(nodes[lhs].t, "bit") && power_int(type_of(nodes[lhs].a)) {
        gen_int_bit_set(n)                              // x.bit(n) = b and its kin (#457)
        return
    }
    if nodes[lhs].kind == N_FIELD && tok_is(nodes[lhs].t, "case") && tagged_of(type_of(nodes[lhs].a)) >= 0 {   // a tag alone would leave the value unset (#477)
        gen_error(n, "'.case' is read only: a case is set with its value, 'v.c = x', or 'v = T.c' of a case with none")
        return
    }
    if !may_change(lhs) { return }                      // (#271)
    if compound_by_operator(n) || failed { return }     // z += w, z = z + w of a struct's operator (#42)
    t = nodes[n].t
    if tok_is(t, "??=") || tok_is(t, "!!=") {           // (#460)
        gen_fill_assign(n)
        return
    }
    if tok_is(t, "++") || tok_is(t, "--") {             // p++ and p-- of a pointer, as kelvinc's #51 (#459)
        let y:int64 = type_of(lhs)
        if failed { return }
        if y >= 0 && types[y].kind == Y_CSTR {
            gen_error(n, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a 'var p:u8^ := s'")
            return
        }
        if y >= 0 && types[y].kind != Y_PTR && types[y].kind != Y_C {
            var m = $"'"
            m += tok_text(t)
            m += "' is for pointers, and this is "
            let w:String = kelvin_type_text(y)
            m += &w
            m += ": write 'x "
            m += tok_is(t, "++") ? "+" : "-"
            m += "= 1'"
            gen_error(n, m.cstr)
            return
        }
        gen_expr(lhs)
        put_tok(t)
        put(";\n")
        return
    }
    if text_outlived(n) { return }                      // (#445, #447)
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
    let copied = owner_name(nodes[n].b) && type_of(nodes[n].b) == y   // s = t, freed twice else (#440)
    if is_owner(y) && (owner_part(nodes[n].b) || copied) && tok_is(t, "=") {   // x = p.s, an alias else (#365)
        owner_assign_error(nodes[n].b)
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
        } else if bare_init(nodes[n].b) && struct_of(y) >= 0 {   // {a, b} of a struct case, C's compound literal (#477)
            put("(")
            put_ctype(y)
            put(")")
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
        if !entry_fits(nodes[n].b, into) { return }      // (#460), as kelvinc's #246
        let key:int64 = nodes[lhs].b
        let hold = needs_hold(key)                       // a String key an expression gives, held for the set (#314)
        if hold { hold_open(key) }
        put_dict_name(into)                              // d[k] = v sets the entry (#211)
        put("_set(")
        gen_place(nodes[lhs].a)
        put(", ")
        gen_key(into, key)
        put(", ")
        let v:int64 = nodes[n].b                         // d[k] = none of a V? (#341), text of a String, 5 of an i64?,
        if bare_init(v) {                                // {2} of a struct (#460), as an entry of ${k: v} is
            put("(")
            put_ctype(types[into].elem)
            put(")")
        }
        gen_written(v, types[into].elem)
        put(")")
        if hold { hold_close(key) }
        put(";\n")
    } else if yk == Y_STRING && tok_is(t, "=") {
        put("kv_string_assign(")
        gen_place(lhs)
        put(", ")
        if nodes[nodes[n].b].kind == N_STR {             // s = "y", a String of the text (#460), as kelvinc's #70
            gen_value(nodes[n].b, y)
        } else {
            gen_expr(nodes[n].b)
        }
        put(");\n")
    } else if yk == Y_STRING && tok_is(t, "+=") {
        if owner_name(nodes[n].b) || owner_part(nodes[n].b) {   // s += t would take t's bytes, freed twice (#440)
            owner_copy_error(nodes[n].b, "+=")
            return
        }
        put("KV_STRING_APPEND(")
        gen_place(lhs)
        put(", ")
        gen_expr(nodes[n].b)
        put(");\n")
    } else if yk == Y_BYTES && tok_is(t, "=") {          // the old bytes freed (#439)
        put("kv_bytes_assign(")
        gen_place(lhs)
        put(", ")
        gen_expr(nodes[n].b)
        put(");\n")
    } else if yk == Y_BYTES && tok_is(t, "+=") {         // b += x, as b.append(x) (#439)
        if !may_change(lhs) { return }
        put("KV_BYTES_APPEND(")
        gen_place(lhs)
        put(", ")
        gen_bytes_add(nodes[n].b, "+=")
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
        gen_array_add(y, nodes[n].b, "+=")              // a borrow copied, a place that owns kelvinc's error (#438)
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
    } else if (yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET) && tok_is(t, "=") && (bare_init(nodes[n].b) || (nodes[nodes[n].b].kind == N_DICT && tok_is(nodes[nodes[n].b].t, "{"))) {
        gen_error(nodes[n].b, "a list is not a value here: write a compound literal, as in '(point){1, 2}' or '([i32])[1, 2, 3]'; an anonymous function here writes its parameters, as in '{ (a:i64):i64 in a + 1 }'")
    } else if is_owner(y) && (yk == Y_STRUCT || yk == Y_ARRAY || yk == Y_DICT || yk == Y_SET) && tok_is(t, "=") {
        serial += 1                                      // the new value first, then the old one freed (#217, #225); an Array's, a Dictionary's, a Set's (#460)
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
    if typename_member(v) { return false }               // x.typename, text of its own (#426)
    if k == N_FIELD {                                    // a struct's member or a case's value, not a property that makes one, as f.string
        let y:int64 = type_of(nodes[v].a)
        if y < 0 || (struct_of(y) < 0 && tagged_of(y) < 0) { return false }
    }
    return is_place(v) && is_owner(type_of(v))
}

// whether v names a variable that owns, which let, = and += would copy
// and free twice, as kelvinc's owner_place refuses it; return moves one
// out. A Task's and an Iterator's own words are said where they are (#440)
let owner_name(v:int64):bool {
    if nodes[v].kind != N_ID || is_case_word(v) || var_type(nodes[v].t) < 0 { return false }
    let y:int64 = type_of(v)
    return is_owner(y) && types[y].kind != Y_TASK && types[y].kind != Y_ITER
}

// kelvinc's words of an owner copied by '=', of v, its name or a part (#365, #440)
let owner_assign_error(v:int64) {
    if nodes[v].kind != N_ID {
        gen_error(v, "an owner is not copied by '=' (#54): copy its bytes with it.copy(), or borrow it with ':= &...'")
        return
    }
    var m = $"an owner is not copied by '=' (#54): copy its bytes with '"
    m += tok_text(nodes[v].t)
    m += "'.copy(), or borrow it with ':= &"
    m += tok_text(nodes[v].t)
    m += "'"
    gen_error(v, m.cstr)
}

let gen_return(n:int64) {
    let a:int64 = nodes[n].a
    if a < 0 {
        put("return;\n")
        return
    }
    if void_return(a) { return }
    let text:int64 = text_in_buffer(a)
    if text >= 0 && nodes[text].kind == N_TPL {         // as kelvinc's reject_returned_text (#445)
        gen_error(text, "a template's text lives in this function's block, which is gone once it returns: the caller makes the text itself, as in 'println(`...`)'")
        return
    }
    if text >= 0 {                                       // a number's text (#447)
        let w:String = tok_text(nodes[text].t)
        var m = $"'."
        m += &w
        m += "' text lives in a buffer of this function, which is gone once it returns: the caller takes the text itself, as in '"
        m += anon_fns.contains(current) ? "{ println($0." : "println(x."
        m += &w
        m += anon_fns.contains(current) ? ") }'" : ")'"
        gen_error(text, m.cstr)
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
            if !move_back(a, true) { return }            // dead after it, as kelvinc's (#441)
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
    init_as_case(a, nodes[current].ty)                   // return {.some = v}, {.none} (#121)
    if bare_init(a) {                                    // return {a, b}: of the function's type (#213)
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

// ---------- x.isEmpty (#435) ----------

// how the N_FIELD n, x.isEmpty, reads, as kelvinc's #434: 1 by the count
// of a String, a Bytes (#439), an Array, a Dictionary or a Set, 2 by a fixed array's
// size, 3 by a cstr's first byte, 4 by a Range's bounds, 5 false, of an
// Iterator, an iterator, a Sequence or a lazy one; -1 of a number or a
// bool, -2 of a pointer, which are errors; 0 of any other, a struct's
// field of the name too
let empty_kind(n:int64):int64 {
    let y:int64 = type_of(nodes[n].a)
    if y < 0 { return 0 }
    let k:ykind = types[y].kind
    if k == Y_STRING || k == Y_BYTES || k == Y_ARRAY || k == Y_DICT || k == Y_SET { return 1 }
    if k == Y_FIXED && (types[y].name == 0 - 2 || types[y].name == 0 - 4) { return 0 - 2 }   // a parameter's, a pointer (#357)
    if k == Y_FIXED && types[y].name != 0 - 1 { return 2 }
    if k == Y_CSTR { return 3 }
    if k == Y_RANGE { return 4 }
    if k == Y_ITER { return 5 }
    if k == Y_STRUCT && field_type(y, nodes[n].t) >= 0 { return 0 }
    if k == Y_STRUCT && (iterator_next(y) >= 0 || sequence_maker(y) >= 0 || is_lazy_type(y)) { return 5 }
    if is_int_kind(k) || k == Y_F64 || k == Y_F32 || k == Y_BOOL || k == Y_UCHR { return 0 - 1 }
    if k == Y_PTR { return 0 - 2 }
    return 0
}

// x.isEmpty (#435): the count's 0, a bool, as kelvinc's; an iterator's
// false, its receiver still evaluated; an owner an expression gives held
// while it is read (#227)
let gen_is_empty(n:int64) {
    let a:int64 = nodes[n].a
    let e = empty_kind(n)
    let y:int64 = type_of(a)
    if e < 0 {
        var m = $"'.isEmpty' is a property of collections and iterators, and this is "
        let w:String = type_text(y)
        m += &w
        if e == 0 - 2 { m += ", a pointer: write 'p^.isEmpty' of what it points to" }
        gen_error(n, m.cstr)
        return
    }
    let hold = needs_hold(a)
    if hold { hold_open(a) }
    if e == 1 {
        put("((bool)((")
        gen_expr(a)
        put(").count == 0))")
    } else if e == 2 {
        put("((bool)(sizeof(")
        gen_expr(a)
        put(") == 0))")
    } else if e == 3 {
        put("((bool)(((const char *)(")
        gen_expr(a)
        put("))[0] == 0))")
    } else if e == 4 {                                   // one without an end never is
        put("({ ")
        put_ctype(y)
        put(" _kv_re = (")
        gen_expr(a)
        put("); (bool)(_kv_re.kind == 2 ? 0 : _kv_re.kind ? _kv_re.lo > _kv_re.hi : _kv_re.lo >= _kv_re.hi); })")
    } else {
        put("((void)(")
        gen_expr(a)
        put("), (bool)0)")
    }
    if hold { hold_close(a) }
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
var anon_serial:int64                     // the anonymous functions named, each its number (#444)

// a value returned where the function has no result, as kelvinc says it
// (#427): a call of no value, a function's without a result or C's, passes
let void_return(a:int64):bool {
    let ry:int64 = nodes[current].ty
    if ry >= 0 && types[ry].kind != Y_VOID { return false }
    let k = nodes[a].kind
    if k == N_CALL || k == N_METHOD {
        let y:int64 = type_of(a)
        if y < 0 || types[y].kind == Y_VOID { return false }
    }
    var anon = false
    for i in 0..<anon_fns.count as int64 {
        if anon_fns[i] == current { anon = true }
    }
    var m = $""
    if anon {
        m += "this function has no result, so it returns no value: write its result's type, as in '{ (...):T in ... }', or 'return' alone"
    } else {
        var name = $""
        if nodes[current].c >= 0 {
            name += tok_text(nodes[current].c)
            name += "."
        }
        name += tok_text(nodes[current].t)
        m += "'"
        m += &name
        m += "' has no result, so it returns no value: write its result's type, as in 'let "
        m += &name
        m += "(...):T', or 'return' alone"
    }
    gen_error(a, m.cstr)
    return true
}

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
    name += maker_name(current)
    name += "_fn"
    anon_serial += 1                                 // its own number, where one inside another is made first (#444)
    name += String(anon_serial)
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
        nodes[d].ty = told(type_of(nodes[st].a))     // $0.type told (#424)
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

// the function of the program the name t names, no method's, or -1 (#428)
let fn_named(t:int64):int64 {
    for x in decls {
        if nodes[x].kind == D_FN && nodes[x].c < 0 && same_text(nodes[x].t, t) { return x }
    }
    return 0 - 1
}

// the function type of the function d: its parameters' and its result's (#428)
let decl_fn_type(d:int64):int64 {
    var ps:$[int64] = $[]
    var p:int64 = nodes[d].a
    while p >= 0 {
        ps += nodes[p].ty
        p = nodes[p].next
    }
    let r:int64 = nodes[d].ty
    return fn_type_of(&ps, r >= 0 && types[r].kind == Y_VOID ? 0 - 1 : r)
}

// the function type of the name n of a function (#428); of an overloaded
// name, kelvinc's error, as the type wanted does not say which here
let named_fn_type(n:int64):int64 {
    var d:int64 = 0 - 1
    var fns:int64 = 0
    for x in decls {
        if nodes[x].kind == D_FN && nodes[x].c < 0 && same_text(nodes[x].t, nodes[n].t) {
            if fns == 0 { d = x }
            fns += 1
        }
    }
    if fns > 1 {                                         // as kelvinc says it (#426)
        var m = $"'"
        m += tok_text(nodes[n].t)
        m += "' names "
        m += String(fns)
        m += " functions: say which by its type, as in 'let f:(T):R := "
        m += tok_text(nodes[n].t)
        m += "'"
        gen_error(n, m.cstr)
        return 0 - 1
    }
    if variadic_fns.contains(d) {                        // as parse says it of (T, ...):R (#453)
        gen_error(n, "kc's function types take no '...' yet: C's variadic functions are called by name")
        return 0 - 1
    }
    return decl_fn_type(d)
}

// the function type of the anonymous function n as a value (#428): its
// written parameters' and result's; one of $0 or of names without types
// takes them from where it goes, so here it is kelvinc's error
let anon_type(n:int64):int64 {
    if nodes[n].flag == 1 && nodes[n].c == 1 {           // atexit() { ... }, trailing, naming no $0: of nothing (#470)
        var none:$[int64] = $[]
        return fn_type_of(&none, nodes[n].ty)
    }
    if nodes[n].flag != 0 {
        gen_error(n, "'$0' is a parameter of an anonymous function, and this is not in one; there, '{' starts an initializer list, so an anonymous function writes its parameters, as in '{ (a:i64):i64 in a + 1 }'")
        return 0 - 1
    }
    var ps:$[int64] = $[]
    var p:int64 = nodes[n].a
    while p >= 0 {
        ps += nodes[p].ty
        p = nodes[p].next
    }
    return fn_type_of(&ps, nodes[n].ty)
}

// the function type the callee f of a call calls through (#428): a
// variable's, a parameter's, an anonymous function's or any value's of
// one, or -1 of a function's name, called by it
let callee_type(f:int64):int64 {
    let k = nodes[f].kind
    if k == N_ANON { return anon_type(f) }
    if k == N_TYPE { return 0 - 1 }
    if k == N_ID {
        let vy:int64 = var_type(nodes[f].t)
        return vy >= 0 && types[vy].kind == Y_FN ? vy : 0 - 1
    }
    let y:int64 = type_of(f)
    return y >= 0 && types[y].kind == Y_FN ? y : 0 - 1
}

// the function type of the member of s.f(x), a struct of the program's
// without a method f, or -1 (#428)
let member_fn_type(n:int64):int64 {
    if nodes[n].kind != N_METHOD || method_of(n) >= 0 || names_type(nodes[n].a) { return 0 - 1 }
    let y:int64 = type_of(nodes[n].a)
    if y < 0 || types[y].kind != Y_STRUCT || decl_named(types[y].name, D_STRUCT) < 0 { return 0 - 1 }
    let fy:int64 = field_type(y, nodes[n].t)
    return fy >= 0 && types[fy].kind == Y_FN ? fy : 0 - 1
}

// whether the function type y takes or gives an owner, which kc's
// function values do not yet: n its error (#428)
let fn_owner_refused(y:int64, n:int64):bool {
    var owns = types[y].elem >= 0 && is_owner(types[y].elem)
    var p:int64 = types[y].name
    while p >= 0 {
        if is_owner(types[p].elem) { owns = true }
        p = types[p].name
    }
    if !owns { return false }
    var m = $"kc's function values take and give no owner yet, and this is "
    let w:String = type_text(y)
    m += &w
    m += ": take a borrow, T^, or call a function by its name"
    gen_error(n, m.cstr)
    return true
}

var anon_made:Dictionary<int64, int64>    // the function kc made of each anonymous function as a value (#428)

// the function n, where one of the function type y goes (#428): an
// anonymous function, made a function of the program, of y's types where
// it writes none; a function's name, of y's type; any other value of it
let gen_fn_value(n:int64, y:int64) {
    if fn_owner_refused(y, n) { return }
    let k = nodes[n].kind
    var given:int64 = 0 - 1
    if k == N_ANON && nodes[n].flag != 0 {
        given = y                                        // $0 and names, of y's parameters
    } else if k == N_ANON {
        given = anon_type(n)
    } else {
        given = type_of(n)
    }
    if failed { return }
    if given >= 0 && types[given].kind == Y_C {          // nowhere, and what only C sees
        gen_expr(n)
        return
    }
    if given != y {
        var m = $""
        if k == N_ID && var_type(nodes[n].t) < 0 && fn_named(nodes[n].t) >= 0 {   // as kelvinc says it
            m += "no function '"
            m += tok_text(nodes[n].t)
            m += "' is "
        } else {
            m += "this is "
            let g:String = given >= 0 ? kelvin_type_text(given) : $"no function"
            m += &g
            m += ", where "
        }
        let w:String = kelvin_type_text(y)
        m += &w
        if k == N_ID && var_type(nodes[n].t) < 0 && fn_named(nodes[n].t) >= 0 && given >= 0 {
            m += ": '"
            m += tok_text(nodes[n].t)
            m += "' is "
            let g:String = kelvin_type_text(given)
            m += &g
        } else if !(k == N_ID && var_type(nodes[n].t) < 0) {
            m += " goes"
        }
        gen_error(n, m.cstr)
        return
    }
    if k == N_ID && var_type(nodes[n].t) < 0 {
        let d:int64 = fn_named(nodes[n].t)
        if d >= 0 {
            put_fn_name(d)
            return
        }
    }
    if k != N_ANON {
        gen_expr(n)
        return
    }
    var d:int64 = anon_made.get(n, 0 - 1)
    if d < 0 {
        var ps:$[int64] = $[]
        var p:int64 = types[y].name
        while p >= 0 {
            ps += types[p].elem
            p = types[p].name
        }
        let me = $"this function"
        d = anon_function_of(n, &ps, types[y].elem >= 0 ? types[y].elem : base_type(Y_VOID), &me)
        if d < 0 { return }
        anon_made[n] = d
    }
    put_tok(nodes[d].t)
}

// f(a, b) through the function value f of type fy (#428): each argument
// of its parameter's type, as a call by name passes it
let gen_fn_call(n:int64, fy:int64) {
    let f:int64 = nodes[n].a
    if fn_owner_refused(fy, n) { return }
    var count:int64 = 0
    var want:int64 = 0
    var a:int64 = nodes[n].b
    while a >= 0 {
        count += 1
        a = nodes[a].next
    }
    var p:int64 = types[fy].name
    while p >= 0 {
        want += 1
        p = types[p].name
    }
    if count != want {                                   // as kelvinc says it
        var m = $"this function, of type "
        let w:String = kelvin_type_text(fy)
        m += &w
        m += ", takes "
        m += String(want)
        m += want == 1 ? " argument" : " arguments"
        m += ", and it is given "
        m += String(count)
        gen_error(n, m.cstr)
        return
    }
    var opened = hold_args(nodes[n].b, 0 - 1)
    if nodes[n].kind == N_METHOD {                      // s.f(x), the member f of s
        put("(")
        gen_expr(f)
        put(".")
        put_tok(nodes[n].t)
        put(")")
    } else if nodes[f].kind == N_ID {
        put_tok(nodes[f].t)
    } else {
        put("(")
        if nodes[f].kind == N_ANON { gen_fn_value(f, fy) } else { gen_expr(f) }
        put(")")
    }
    put("(")
    a = nodes[n].b
    p = types[fy].name
    while a >= 0 {
        if a != nodes[n].b { put(", ") }
        gen_value(a, types[p].elem)
        a = nodes[a].next
        p = types[p].name
    }
    put(")")
    close_holds(&opened)
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
    if failed { return }                                 // an anonymous function refused has no signature (#471)
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
    name += maker_name(current)
    name += "_fn"
    anon_serial += 1                                 // its own number, where one inside another is made first (#444)
    name += String(anon_serial)
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
    if !is_int_kind(k) && k != Y_C {
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
        if !is_int_kind(k) && k != Y_C {
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
    return k == Y_I8 ? "INT8_MAX" : k == Y_I16 ? "INT16_MAX" : k == Y_I32 ? "INT32_MAX" : k == Y_U8 ? "UINT8_MAX" : k == Y_U16 ? "UINT16_MAX" : k == Y_U32 ? "UINT32_MAX" : k == Y_U64 ? "UINT64_MAX" : "INT64_MAX"
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
    return y >= 0 && is_unsigned_kind(types[y].kind)
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
    if !is_int_kind(k) && k != Y_C {
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
    return is_int_kind(k) || enum_int(y)
}

// whether y is a plain enum's value, which C's int is, as kelvinc's an
// i32 (#469); not an enum with values
let enum_int(y:int64):bool {
    if y < 0 || types[y].kind != Y_STRUCT { return false }
    let d = decl_named(types[y].name, D_ENUM)
    return d >= 0 && nodes[d].flag != 1
}

// y, or an i32 where it is a plain enum's value (#469)
let int_view(y:int64):int64 {
    return enum_int(y) ? base_type(Y_I32) : y
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
    if enum_int(y) { return base_type(Y_I32) }           // an enum's value too (#469)
    return promoted_int(y)
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
        x = strtod(s.cstr, nowhere)
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
        if strpbrk(text, ".e") == nowhere { put(".0") }
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
    if !power_int_literal(b) && !is_unsigned_kind(types[ey].kind) {
        put("if (_kv_pe < 0) kv_array_fail(\"'**' of integers takes an exponent of 0 or more: a power of an integer less than 0 is no integer\"); ")
    }
    let wide:cstr := int_width(rt) == 128 ? "unsigned __int128" : "uint64_t"   // in a u64, or a u128 of 128 bits, as kelvinc's
    put(wide)
    put(" _kv_pr = 1, _kv_px = (")
    put(wide)
    put(")_kv_pb; for (")
    put(int_width(ey) == 128 ? "unsigned __int128" : "uint64_t")
    put(" _kv_pn = (")
    put(int_width(ey) == 128 ? "unsigned __int128" : "uint64_t")
    put(")_kv_pe; _kv_pn; _kv_pn >>= 1) { if (_kv_pn & 1) _kv_pr *= _kv_px; _kv_px *= _kv_px; } (")
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
    return usual_int(by, my)
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
    if nodes[n].kind != N_BIN || tok_is(nodes[n].t, "??") { return false }   // x ?? none: none has no type to ask (#409)
    let ay:int64 = side_type(nodes[n].a)
    let by:int64 = side_type(nodes[n].b)
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
    let ay:int64 = side_type(nodes[n].a)
    let by:int64 = side_type(nodes[n].b)
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
        put("; if (_kv_c_go && (uint64_t)_kv_c_end - (uint64_t)_kv_c_lo == UINT64_MAX) kv_array_fail(\"this Range has 2^64 values, more than a count holds\"); _kv_c_go ? (uint64_t)_kv_c_end - (uint64_t)_kv_c_lo + 1 : (uint64_t)0; })")
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
    if !is_int_kind(k) && k != Y_C {
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
    let words:[cstr] = ["i64", "i32", "u8", "u32", "i8", "i16", "u16", "u64"]
    let ctypes:[cstr] = ["int64_t", "int32_t", "uint8_t", "uint32_t", "int8_t", "int16_t", "uint16_t", "uint64_t"]
    for i in 0..<8 {
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
        let what = $"'Iterator'"
        if !move_out(a, &what) { return }                // dead after it (#441)
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
    if kind == 1 && yk == Y_SET && types[ry].kind != Y_STRING && !is_int_kind(types[ry].kind) {
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

// ---------- xs.sort() and xs.sorted() (#470) ----------

// what '.sort' or '.sorted' n says of a comparator of the wrong type
let sort_fn_error(n:int64, at:int64, ey:int64, given:int64) {
    var m = $"'."
    m += tok_text(nodes[n].t)
    m += "' takes a comparator of two elements, ("
    let w:String = kelvin_type_text(ey)
    m += &w
    m += ", "
    m += &w
    m += "):bool, true where the first goes before the second, and this is "
    let g:String = given >= 0 ? kelvin_type_text(given) : $"not one"
    m += &g
    gen_error(at, m.cstr)
}

// the function of the program comparator f makes or names, of two
// elements of ey; -1 where it is a value of its own type, called as it is;
// -2 after an error
let sort_fn_of(n:int64, f:int64, ey:int64):int64 {
    var ps:$[int64] = $[]
    ps += ey
    ps += ey
    let want:int64 = fn_type_of(&ps, base_type(Y_BOOL))
    if nodes[f].kind == N_ANON {
        var d:int64 = anon_made.get(f, 0 - 1)
        if d < 0 {
            let st:int64 = nodes[nodes[f].b].a
            let one = st >= 0 && nodes[st].next < 0 && nodes[st].kind == S_EXPR
            var me = $"'."
            me += tok_text(nodes[n].t)
            me += "'"
            d = anon_function_of(f, &ps, one ? 0 - 1 : base_type(Y_BOOL), &me)   // one expression tells its own type
            if d < 0 { return 0 - 2 }
            anon_made[f] = d
        }
        if decl_fn_type(d) != want {
            let ry:int64 = nodes[d].ty
            if nodes[f].flag != 0 && ry >= 0 && (is_number_kind(types[ry].kind) || types[ry].kind == Y_C) {   // as kelvinc says it
                gen_error(f, "this function returns a bool, and this gives a number: compare it, as in 'x != 0'")
                return 0 - 2
            }
            sort_fn_error(n, f, ey, decl_fn_type(d))
            return 0 - 2
        }
        return d
    }
    if nodes[f].kind == N_ID && var_type(nodes[f].t) < 0 {
        var first:int64 = 0 - 1
        for x in decls {
            if nodes[x].kind == D_FN && nodes[x].c < 0 && same_text(nodes[x].t, nodes[f].t) {
                if decl_fn_type(x) == want { return x }          // of the overloads, this one
                if first < 0 { first = x }
            }
        }
        if first >= 0 {
            sort_fn_error(n, f, ey, decl_fn_type(first))
            return 0 - 2
        }
    }
    let given:int64 = type_of(f)
    if failed { return 0 - 2 }
    if given != want {
        sort_fn_error(n, f, ey, given)
        return 0 - 2
    }
    if fn_owner_refused(want, f) { return 0 - 2 }
    return 0 - 1
}

// the program's operator < of two elements of type ey, or -1
let sort_operator(ey:int64):int64 {
    for x in decls {
        if !is_operator(x) || !tok_is(nodes[x].t, "<") { continue }
        let p:int64 = nodes[x].a
        if p >= 0 && nodes[p].ty == ey && nodes[p].next >= 0 && nodes[nodes[p].next].ty == ey { return x }
    }
    return 0 - 1
}

// whether the elements of ey have a < of their kind, else the error
let sort_by_kind(n:int64, ey:int64):bool {
    let k:ykind = types[ey].kind
    if is_int_kind(k) || k == Y_F64 || k == Y_F32 || k == Y_BOOL || k == Y_C || k == Y_STRING || k == Y_BYTES || k == Y_UCHR || k == Y_CSTR { return true }
    let w:String = kelvin_type_text(ey)
    var m = $"'."
    m += tok_text(nodes[n].t)
    m += "' compares the elements with <, and "
    if k == Y_STRUCT && decl_named(types[ey].name, D_STRUCT) >= 0 { m += "struct " }   // as kelvinc names it
    m += &w
    m += " has none: give a comparator, '."
    m += tok_text(nodes[n].t)
    m += " { $0.x < $1.x }', or define one, as in 'let <(a:"
    m += &w
    m += ", b:"
    m += &w
    m += "):bool { ... }'"
    gen_error(n, m.cstr)
    return false
}

// an element at side for the comparator: a copy of one that owns, which
// it owns, as put_eager_arg's
let put_sort_side(ey:int64, side:cstr) {
    if is_owner(ey) {
        put_owner_prefix(ey)
        put("_copy(&")
        put(side)
        put(")")
    } else {
        put(side)
    }
}

// whether the right element goes before the left: by comparator f, the
// function fn or the value itself, or by < of their kind
let put_sort_less(f:int64, fn:int64, ey:int64) {
    if f >= 0 || fn >= 0 {
        if fn >= 0 {
            put_fn_name(fn)
        } else {
            gen_expr(f)
        }
        put("(")
        put_sort_side(ey, "_kv_sa[_kv_sj]")
        put(", ")
        put_sort_side(ey, "_kv_sa[_kv_si]")
        put(")")
        return
    }
    let k:ykind = types[ey].kind
    if k == Y_STRING {
        put("(kv_string_cmp(&_kv_sa[_kv_sj], &_kv_sa[_kv_si]) < 0)")
    } else if k == Y_BYTES {
        put("(kv_bytes_cmp(&_kv_sa[_kv_sj], &_kv_sa[_kv_si]) < 0)")
    } else if k == Y_UCHR {
        put("(_kv_sa[_kv_sj].cp < _kv_sa[_kv_si].cp)")
    } else if k == Y_CSTR {
        put("(strcmp((const char *)_kv_sa[_kv_sj], (const char *)_kv_sa[_kv_si]) < 0)")
    } else {
        put("(_kv_sa[_kv_sj] < _kv_sa[_kv_si])")
    }
}

// the stable merge sort of *_kv_sp, bottom up, through a buffer as large,
// the elements moved as they are, as kelvinc's #185; after _kv_sp's own
let put_merge_sort(f:int64, fn:int64, ey:int64) {
    put("size_t _kv_sn = _kv_sp->count; if (_kv_sn > 1) { __typeof__(_kv_sp->at) _kv_sa = _kv_sp->at, _kv_sb = kv_alloc(_kv_sn * sizeof *_kv_sp->at), _kv_sbuf = _kv_sb; for (size_t _kv_sw = 1; _kv_sw < _kv_sn; _kv_sw *= 2) { for (size_t _kv_slo = 0; _kv_slo < _kv_sn; _kv_slo += 2 * _kv_sw) { size_t _kv_smid = _kv_slo + _kv_sw < _kv_sn ? _kv_slo + _kv_sw : _kv_sn; size_t _kv_shi = _kv_slo + 2 * _kv_sw < _kv_sn ? _kv_slo + 2 * _kv_sw : _kv_sn; size_t _kv_si = _kv_slo, _kv_sj = _kv_smid, _kv_sk = _kv_slo; while (_kv_si < _kv_smid && _kv_sj < _kv_shi) { if (")
    put_sort_less(f, fn, ey)
    put(") _kv_sb[_kv_sk++] = _kv_sa[_kv_sj++]; else _kv_sb[_kv_sk++] = _kv_sa[_kv_si++]; } while (_kv_si < _kv_smid) _kv_sb[_kv_sk++] = _kv_sa[_kv_si++]; while (_kv_sj < _kv_shi) _kv_sb[_kv_sk++] = _kv_sa[_kv_sj++]; } __typeof__(_kv_sa) _kv_st = _kv_sa; _kv_sa = _kv_sb; _kv_sb = _kv_st; } if (_kv_sa != _kv_sp->at) memcpy(_kv_sp->at, _kv_sa, _kv_sn * sizeof *_kv_sa); free(_kv_sbuf); } } while (0)")
}

// xs.sort(), xs.sort { ... } in place; xs.sorted(), xs.sorted { ... } a
// new Array, a copy of one a place holds, or the one an expression gives
let gen_array_sort(n:int64) {
    let a:int64 = nodes[n].a
    let y:int64 = type_of(a)
    let ey:int64 = types[y].elem
    let in_place = tok_is(nodes[n].t, "sort")
    let lent = is_place(a) || held.get(a, 0 - 1) >= 0
    if in_place && !lent {
        gen_error(n, "'.sort' sorts an Array in place, and this one an expression gives would be lost: bind it, or write '.sorted()'")
        return
    }
    if in_place && changed_root(a) >= 0 && how_declared(nodes[changed_root(a)].t) != 0 {
        var m = $"'"
        m += tok_text(nodes[changed_root(a)].t)
        m += "' is a let and cannot change; declare it with var, or write '.sorted()'"
        gen_error(n, m.cstr)
        return
    }
    if in_place && !may_change(a) { return }             // through a read-only borrow
    let f:int64 = nodes[n].b
    if f >= 0 && nodes[f].next >= 0 {
        var m = $"'."
        m += tok_text(nodes[n].t)
        m += "' takes one function, the comparator, or none"
        gen_error(nodes[f].next, m.cstr)
        return
    }
    var fn:int64 = 0 - 1
    if f >= 0 {
        fn = sort_fn_of(n, f, ey)
        if fn == 0 - 2 { return }
    } else {
        fn = sort_operator(ey)                           // a struct's own operator < (#471)
        if fn < 0 && !sort_by_kind(n, ey) { return }
    }
    if in_place {
        put("do { __auto_type _kv_sp = &(")
        gen_expr(a)
        put("); ")
        put_merge_sort(f, fn, ey)
        return
    }
    put("({ ")
    put_array_name(y)
    put(" _kv_so = ")
    if lent {
        put_array_name(y)
        put("_copy(&(")
        gen_expr(a)
        put("))")
    } else {
        gen_expr(a)
    }
    put("; do { __auto_type _kv_sp = &_kv_so; ")
    put_merge_sort(f, fn, ey)
    put("; _kv_so; })")
}

// xs.reverse() in place; xs.reversed() a new Array, a copy of one a
// place holds, or the one an expression gives: the elements swapped from
// both ends, moved as they are, as kelvinc's #186
let gen_array_reverse(n:int64) {
    let a:int64 = nodes[n].a
    let y:int64 = type_of(a)
    let t:int64 = nodes[n].t
    let in_place = tok_is(t, "reverse")
    let lent = is_place(a) || held.get(a, 0 - 1) >= 0
    if in_place && !lent {
        gen_error(n, "'.reverse' reverses an Array in place, and this one an expression gives would be lost: bind it, or write '.reversed()'")
        return
    }
    if in_place && changed_root(a) >= 0 && how_declared(nodes[changed_root(a)].t) != 0 {
        var m = $"'"
        m += tok_text(nodes[changed_root(a)].t)
        m += "' is a let and cannot change; declare it with var, or write '.reversed()'"
        gen_error(n, m.cstr)
        return
    }
    if in_place && !may_change(a) { return }             // through a read-only borrow
    if nodes[n].b >= 0 {
        var m = $"'."
        m += tok_text(t)
        m += "' takes nothing: '."
        m += tok_text(t)
        m += "()'"
        gen_error(nodes[n].b, m.cstr)
        return
    }
    if in_place {
        put("do { __auto_type _kv_rp = &(")
        gen_expr(a)
        put("); ")
    } else {
        put("({ ")
        put_array_name(y)
        put(" _kv_ro = ")
        if lent {
            put_array_name(y)
            put("_copy(&(")
            gen_expr(a)
            put("))")
        } else {
            gen_expr(a)
        }
        put("; do { __auto_type _kv_rp = &_kv_ro; ")
    }
    put("for (size_t _kv_ri = 0, _kv_rj = _kv_rp->count; _kv_ri + 1 < _kv_rj; _kv_ri++, _kv_rj--) { __typeof__(*_kv_rp->at) _kv_rt = _kv_rp->at[_kv_ri]; _kv_rp->at[_kv_ri] = _kv_rp->at[_kv_rj - 1]; _kv_rp->at[_kv_rj - 1] = _kv_rt; } } while (0)")
    if !in_place { put("; _kv_ro; })") }
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
            let what = into_words("", ".", nodes[n].t)
            if !move_out(init, &what) { return }         // dead after it (#441)
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
            let what = into_words("", ".", nodes[n].t)
            if !move_out(init, &what) { return }         // (#441)
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
            let what = into_words("", ".", nodes[n].t)
            if !move_out(other, &what) { return }        // (#441)
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
// d0 ?? d1 and d0 !! d1 a new Dictionary, d0 ??= d1 and d0 !!= d1 in
// place (#460), as kelvinc's #237: d1's entries added, each value copied;
// where d0 has the key, d0's value kept of ?? and ??=, else d1's copy.
// d1 in a variable is lent, else held and freed; d0 that an expression
// gives is taken
let gen_fill(t:int64, a:int64, b:int64, in_place:bool) {
    let keep = tok_is(t, "??") || tok_is(t, "??=")
    let dy:int64 = type_of(a)
    let by:int64 = type_of(b)
    if failed { return }
    if dy < 0 || types[dy].kind != Y_DICT {
        var m = $"'"
        m += tok_text(t)
        m += in_place || !keep ? "' takes Dictionaries, and this is " : "' takes an Optional, a Result or Dictionaries, and this is "
        let w:String = dy >= 0 ? kelvin_type_text(dy) : $"not one"
        m += &w
        gen_error(a, m.cstr)
        return
    }
    if by != dy {
        var m = $"'"
        m += tok_text(t)
        m += "' takes two Dictionaries of the same key and value types, and these are "
        let w:String = kelvin_type_text(dy)
        m += &w
        m += " and "
        let bw:String = by >= 0 ? kelvin_type_text(by) : $"not one"
        m += &bw
        gen_error(b, m.cstr)
        return
    }
    if in_place && !is_place(a) {
        var m = $"'"
        m += tok_text(t)
        m += "' changes a Dictionary in place, so its left is a variable"
        gen_error(a, m.cstr)
        return
    }
    let vy:int64 = types[dy].elem
    let lk:cstr := types[types[dy].name].kind == Y_STRING ? "KV_LK_TEXT" : "KV_LK_INT"
    put("({ ")
    put_ctype(dy)
    if in_place {
        put(" *_kv_md = &(")
        gen_expr(a)
        put("); ")
    } else if is_place(a) {
        put(" _kv_mm = ")
        put_owner_prefix(dy)
        put("_copy(&(")
        gen_expr(a)
        put(")); ")
        put_ctype(dy)
        put(" *_kv_md = &_kv_mm; ")
    } else {
        put(" _kv_mm = (")
        gen_expr(a)
        put("); ")
        put_ctype(dy)
        put(" *_kv_md = &_kv_mm; ")
    }
    if is_place(b) {
        put("const ")
        put_ctype(dy)
        put(" *_kv_me = &(")
        gen_expr(b)
        put("); ")
    } else {
        put("__attribute__((cleanup(")
        put_free(dy)
        put("))) ")
        put_ctype(dy)
        put(" _kv_mo = ")
        gen_expr(b)
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
    if keep {
    } else if is_owner(vy) {                             // d1's copy, the old one freed
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

// whether v may be the value of an entry of the Dictionary dy, as
// kelvinc's #246 has it of d[k] = v, ??= and !!= (#460), else its error
let entry_fits(v:int64, dy:int64):bool {
    let bad:String = value_mismatch_text(v, types[dy].elem)
    if bad.count == 0 { return true }
    var m = $"an entry of "
    let dw:String = kelvin_type_text(dy)
    m += &dw
    m += " is "
    let ew:String = kelvin_type_text(types[dy].elem)
    m += article_of(&ew)
    m += " "
    m += &ew
    m += ", and this is "
    m += &bad
    gen_error(v, m.cstr)
    return false
}

// d[k] ??= v sets the entry only where k is absent, d[k] !!= v only where
// it is present, as kelvinc's #243 (#460): the key read once, v made only
// where it is set; d0 ??= d1 and d0 !!= d1 of Dictionaries, in place
let gen_fill_assign(n:int64) {
    let lhs:int64 = nodes[n].a
    let t:int64 = nodes[n].t
    let v:int64 = nodes[n].b
    let into:int64 = nodes[lhs].kind == N_INDEX ? type_of(nodes[lhs].a) : 0 - 1
    if failed { return }
    if into < 0 || types[into].kind != Y_DICT {
        gen_fill(t, lhs, v, true)
        put(";\n")
        return
    }
    let vy:int64 = types[into].elem
    if is_owner(vy) && is_place(v) && !is_case_word(v) {   // as d[k] = v's
        owner_assign_error(v)
        return
    }
    if !entry_fits(v, into) { return }
    let key:int64 = nodes[lhs].b
    let hold = needs_hold(key)                           // a String key an expression gives, held for the set
    if hold { hold_open(key) }
    put("({ ")
    put_dict_name(into)
    put(" *_kv_dp = ")
    gen_place(nodes[lhs].a)
    put("; __auto_type _kv_dk = ")
    gen_key(into, key)
    put(tok_is(t, "??=") ? "; if (!" : "; if (")
    put_dict_name(into)
    put("_find(_kv_dp, _kv_dk)) ")
    put_dict_name(into)
    put("_set(_kv_dp, _kv_dk, ")
    if bare_init(v) {
        put("(")
        put_ctype(vy)
        put(")")
    }
    gen_written(v, vy)
    put("); (void)0; })")
    if hold { hold_close(key) }
    put(";\n")
}

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

// whether y points to a struct whose next points to one of its own, a
// list, which for x in p walks node by node, as kelvinc's #30 (#444)
let list_walked(y:int64):bool {
    if y < 0 || types[y].kind != Y_PTR { return false }
    let sy:int64 = types[y].elem
    let d:int64 = struct_of(sy)
    if d < 0 { return false }
    var f:int64 = nodes[d].a
    while f >= 0 {
        let ft:int64 = nodes[f].ty
        if tok_is(nodes[f].t, "next") {
            return ft >= 0 && types[ft].kind == Y_PTR && struct_of(types[ft].elem) == d
        }
        f = nodes[f].next
    }
    return false
}

// the IO a loop walks, where an expression gives it, held in the block
// around the loop as _kv_ioheldN, which closes it when the loop is done,
// a break too, as kelvinc's #466
let put_io_held(io:int64, s:int64, depth:int64) {
    if is_place(io) || std_io(io) >= 0 { return }
    indent(depth)
    put("__attribute__((cleanup(kv_io_free))) kv_io _kv_ioheld")
    put_int(s)
    put(" = ")
    gen_expr(io)
    put(";\n")
}

// the address of the IO a loop walks: a place's, or the one held
let put_io_walked(io:int64, s:int64) {
    if is_place(io) || std_io(io) >= 0 {
        gen_place(io)
    } else {
        put("&_kv_ioheld")
        put_int(s)
    }
}

// for b in f.read(n) (#464), as kelvinc's #82: each next n bytes at most
// read into one Bytes, b a Bytes the loop lends
let gen_read_each(n:int64, depth:int64) {
    let src:int64 = nodes[n].a
    let count:int64 = nodes[src].b
    if count < 0 || nodes[count].next >= 0 {             // as kelvinc says it
        gen_error(src, "'.read' takes 1 argument")
        return
    }
    let by:int64 = base_type(Y_BYTES)
    serial += 1
    let s = serial
    put("{\n")
    indent(depth + 1)
    put("__attribute__((cleanup(kv_bytes_free))) kv_bytes _kv_chunk_buf")
    put_int(s)
    put(" = {0};\n")
    put_io_held(nodes[src].a, s, depth + 1)             // IO(path).read(n), held and closed after (#466)
    indent(depth + 1)
    put("kv_io *const _kv_chunk_io")
    put_int(s)
    put(" = (kv_io *)")
    put_io_walked(nodes[src].a, s)
    put(";\n")
    indent(depth + 1)
    put("const size_t _kv_chunk_n")
    put_int(s)
    put(" = ")
    gen_expr(count)
    put(";\n")
    indent(depth + 1)
    put("while (kv_io_read_chunk(_kv_chunk_io")
    put_int(s)
    put(", _kv_chunk_n")
    put_int(s)
    put(", &_kv_chunk_buf")
    put_int(s)
    put("))\n")
    indent(depth + 1)
    put("{\n")
    indent(depth + 2)
    put("const kv_bytes ")
    put_tok(nodes[n].t)
    put(" = _kv_chunk_buf")
    put_int(s)
    put(";\n")
    open_scope()
    declare_each(nodes[n].t, by, 3)                     // lent, as an element is
    indent(depth + 2)
    gen_block(nodes[n].c, depth + 2)
    close_scope()
    indent(depth + 1)
    put("}\n")
    indent(depth)
    put("}\n")
}

// for r in f.lines (#450), as kelvinc's #406: each line read into one
// String, r a Result<String, i64> that borrows it, err the offset where
// its UTF-8 breaks
let gen_lines_each(n:int64, depth:int64) {
    let io:int64 = nodes[nodes[n].a].a
    let ry:int64 = result_of(base_type(Y_STRING), base_type(Y_I64))
    let d:int64 = tagged_of(ry)
    serial += 1
    let s = serial
    put("{\n")
    indent(depth + 1)
    put("__attribute__((cleanup(kv_string_free))) kv_string _kv_line")
    put_int(s)
    put(" = {0};\n")
    put_io_held(io, s, depth + 1)                       // IO(path).lines, held and closed after (#466)
    indent(depth + 1)
    put("kv_io *const _kv_lines")
    put_int(s)
    put(" = (kv_io *)")
    put_io_walked(io, s)
    put(";\n")
    indent(depth + 1)
    put("int64_t _kv_bad")
    put_int(s)
    put(" = -1;\n")
    indent(depth + 1)
    put("while (kv_io_read_line(_kv_lines")
    put_int(s)
    put(", &_kv_line")
    put_int(s)
    put(", &_kv_bad")
    put_int(s)
    put("))\n")
    indent(depth + 1)
    put("{\n")
    indent(depth + 2)
    put("const ")
    put_ctype(ry)
    put(" ")
    put_tok(nodes[n].t)
    put(" = _kv_bad")
    put_int(s)
    put(" >= 0 ? _kv_")
    put_tok(nodes[d].t)
    put("_make_err(_kv_bad")
    put_int(s)
    put(") : _kv_")
    put_tok(nodes[d].t)
    put("_make_ok(_kv_line")
    put_int(s)
    put(");\n")
    open_scope()
    declare_each(nodes[n].t, ry, 3)                     // lent, as an element is
    indent(depth + 2)
    gen_block(nodes[n].c, depth + 2)
    close_scope()
    indent(depth + 1)
    put("}\n")
    indent(depth)
    put("}\n")
}

let gen_each(n:int64, depth:int64) {
    let src0:int64 = nodes[n].a
    if nodes[src0].kind == N_FIELD && tok_is(nodes[src0].t, "lines") && nodes[n].b < 0 {
        let iy:int64 = type_of(nodes[src0].a)
        if iy >= 0 && types[iy].kind == Y_IO {           // for r in f.lines (#450)
            gen_lines_each(n, depth)
            return
        }
    }
    if nodes[src0].kind == N_METHOD && tok_is(nodes[src0].t, "read") && nodes[n].b < 0 {
        let iy:int64 = type_of(nodes[src0].a)
        if iy >= 0 && types[iy].kind == Y_IO {           // for b in f.read(n) (#464)
            gen_read_each(n, depth)
            return
        }
    }
    let y:int64 = type_of(nodes[n].a)
    if y < 0 {                                          // never dropped unwritten (#464)
        if !failed { gen_error(nodes[n].a, "kc does not see the type of what this walks") }
        return
    }
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
    if types[y].kind == Y_FIXED && !is_number_kind(types[types[y].elem].kind) && types[types[y].elem].kind != Y_BOOL && types[types[y].elem].kind != Y_CSTR && types[types[y].elem].kind != Y_UCHR {
        var m = $"kc walks a fixed array of numbers, bools, uchrs or text, to its count or a zero; not yet of "
        let ew:String = type_text(types[y].elem)
        m += &ew
        m += ": index it, a[i]"
        gen_error(nodes[n].a, m.cstr)                    // (#354)
        return
    }
    if nodes[n].b >= 0 && types[y].kind != Y_DICT {    // as kelvinc says it (#269)
        var s = $"two loop variables walk a Dictionary's entries, 'for k, v in d', and this is "
        s += nodes[nodes[n].a].kind == N_STR ? $"not one" : type_text(y)    // "hi", which only C sees, as kelvinc says it
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
        put(types[types[y].elem].kind == Y_UCHR ? "].cp != 0; _kv_i" : "] != 0; _kv_i")   // a uchr's zero, U+0000 (#480)
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
    } else if types[y].kind == Y_CSTR {                // a cstr's bytes, up to its NUL, as kelvinc's #30
        let literal = nodes[src].kind == N_STR          // "hi" is C's char[], which only C sees: c is a char
        put("for (")
        put(literal ? "__auto_type" : "const uint8_t *")
        put(" _kv_p")
        put_int(serial)
        put(" = ")
        gen_expr(src)
        put("; _kv_p")
        put_int(serial)
        put(" != 0 && *_kv_p")
        put_int(serial)
        put(" != 0; _kv_p")
        put_int(serial)
        put("++)\n")
        indent(depth + 1)
        put("{\n")
        indent(depth + 2)
        if literal {
            put("const __typeof__(*_kv_p")
            put_int(serial)
            put(") ")
        } else {
            put("const uint8_t ")
        }
        put_tok(nodes[n].t)
        put(" = *_kv_p")
        put_int(serial)
        put(";\n")
        open_scope()
        declare_each(nodes[n].t, base_type(literal ? Y_C : Y_U8), 3)
    } else if list_walked(y) {                         // each node along next, up to nowhere, as kelvinc's #30 (#444)
        put_ctype(y)
        put(" _kv_p")
        put_int(serial)
        put(" = ")
        gen_expr(src)
        put(";\n")
        indent(depth + 1)
        put("while (_kv_p")
        put_int(serial)
        put(" != NULL)\n")
        indent(depth + 1)
        put("{\n")
        indent(depth + 2)
        put_ctype(y)
        put(" const ")
        put_tok(nodes[n].t)
        put(" = _kv_p")
        put_int(serial)
        put("; _kv_p")                                   // next read first: the body may free the node
        put_int(serial)
        put(" = ")
        put_tok(nodes[n].t)
        put("->next;\n")
        open_scope()
        declare_each(nodes[n].t, y, 3)
    } else if types[y].kind == Y_PTR {
        gen_error(nodes[n].a, "kc walks a pointer only as a list, a struct's along its next: not yet up to a 0 or nowhere")
        return
    } else if types[y].kind == Y_BITS {                  // its bits, each a bool, place 0 first (#456)
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
        put("const bool ")
        put_tok(nodes[n].t)
        put(" = (")
        gen_expr(nodes[n].a)
        put(").at[_kv_i")
        put_int(serial)
        put(" / 64] >> (_kv_i")
        put_int(serial)
        put(" % 64) & 1;\n")
        open_scope()
        declare_each(nodes[n].t, base_type(Y_BOOL), 3)
    } else {
        let ey:int64 = types[y].kind == Y_BYTES ? base_type(Y_U8) : types[y].elem    // a Bytes's bytes (#439)
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
        put_ctype(ey)
        put(" ")
        put_tok(nodes[n].t)
        put(" = (")
        gen_expr(nodes[n].a)
        put(").at[_kv_i")
        put_int(serial)
        put("];\n")
        open_scope()
        declare_each(nodes[n].t, ey, 3)          // (#271)
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
    let bare = nodes[n].t == nodes[n].flag             // if let x = e, an Optional's some, a Result's ok (#442)
    if bare && (y < 0 || d < 0 || value_case(y) < 0) {
        var w = $"'if let' takes an Optional or a Result, and this is "
        if y < 0 { w += "not one" } else { w += eq_type_text(y) }   // struct T, as kelvinc names it
        gen_error(e, w.cstr)
        return
    }
    if d < 0 {
        gen_error(n, "if let takes an enum with values, an Optional or a Result")
        return
    }
    let m = bare ? value_case(y) : case_named(d, nodes[n].t) ?? 0 - 1
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
    put("__auto_type _kv_l")                            // const where e is, a let's or an element's, as kelvinc's (#450)
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

// y with each x.type in it told (#423): x's type, as type_of says it
let told(y:int64):int64 {
    if !late(y) { return y }
    let k:ykind = types[y].kind
    if k == Y_TYPEOF {
        let v:int64 = type_of(types[y].name)
        if v >= 0 && types[y].elem == 1 && types[v].kind == Y_FIXED { return const_fixed(v) }   // const xs.type (#425)
        return v < 0 ? base_type(Y_VOID) : v
    }
    let name:int64 = k == Y_DICT ? told(types[y].name) : types[y].name
    let u:int64 = type_of_kind(k, told(types[y].elem), name)
    return types[y].konst == 1 ? const_fixed(u) : u
}

// each x.type in the expression n and those after it, told (#423); not
// an anonymous function's or an Iterator's, whose statements gen_stmt
// tells where it writes them
let tell_expr(n:int64) {
    var e:int64 = n
    while e >= 0 {
        if late(nodes[e].ty) { nodes[e].ty = told(nodes[e].ty) }
        let k:nkind = nodes[e].kind
        if k != N_ANON && k != N_ITER {
            tell_expr(nodes[e].a)
            tell_expr(nodes[e].b)
            if k == N_COND { tell_expr(nodes[e].c) }
        }
        e = nodes[e].next
    }
}

// each x.type in the statement n's own parts, told before gen writes it,
// the locals before it declared (#423): a local's inferred type is
// known only here, where kc writes its declaration
let tell_stmt(n:int64) {
    let k:nkind = nodes[n].kind
    if late(nodes[n].ty) { nodes[n].ty = told(nodes[n].ty) }
    if k == S_VAR || k == S_EXPR || k == S_RETURN || k == S_IF || k == S_WHILE || k == S_EACH || k == S_SWITCH || k == S_IFLET || k == S_ASSERT {
        tell_expr(nodes[n].a)
    } else if k == S_ASSIGN || k == S_FOR {
        tell_expr(nodes[n].a)
        tell_expr(nodes[n].b)
    }
}

let gen_stmt_of(n:int64, depth:int64)    // a prototype: gen_stmt writes n by it

// the statement n, and the owners it moved out dead after it (#441)
let gen_stmt(n:int64, depth:int64) {
    let at:int64 = out.count as int64
    let made:int64 = block_store.count as int64
    gen_stmt_of(n, depth)
    moves_done()
    if block_store.count as int64 > made && !failed { place_storage(at, made, depth) }   // (#445, #447)
}

let gen_stmt_of(n:int64, depth:int64) {
    if failed { return }
    let k:nkind = nodes[n].kind
    if late_seen { tell_stmt(n) }                        // (#423)
    if k == S_BLOCK {
        gen_block(n, depth)
        return
    }
    indent(depth)
    switch k {                                                   // (#210)
    case S_VAR:
        gen_var(n)
        declare_as(nodes[n].t, nodes[n].ty, nodes[n].flag == 1 ? 1 : 0)   // a let or a var (#271)
    case S_ASSIGN:
        if compound_by_operator(n) || failed { return }  // z += w, z = z + w of a struct's operator (#42)
        if tok_is(nodes[n].t, "=") && declaration_shaped(nodes[n].a) { put("if (1) ") }   // (#402)
        let fresh = tok_is(nodes[n].t, "=") && nodes[nodes[n].a].kind == N_ID   // t = v gives t anew (#441)
        if fresh { anew = nodes[n].a }
        gen_assign(n)
        anew = -1
        if fresh {
            moves_done()
            let i:int64 = local_at(nodes[nodes[n].a].t)
            if i >= 0 { locals[i].moved = false }
        }
    case S_EXPR:
        let v = nodes[n].a
        let vy = type_of(v)
        if vy >= 0 && types[vy].kind == Y_TASK && !is_place(v) {     // as kelvinc's (#313)
            gen_error(v, "a Task dropped here would be awaited at once: bind it, 'let t = async f(x)', and await it when its value is wanted")
            return
        }
        if nodes[v].kind == N_TRY {                   // try f() alone: its value dropped, the err passed up (#449)
            gen_try(v, false)
            put(";\n")
        } else if needs_hold(v) {                     // an owner no one takes, freed (#227)
            let y = type_of(v)
            put("{ __attribute__((cleanup(")
            put_free(y)
            put("))) ")
            put_ctype(y)
            put(" _kv_dropped = ")
            gen_expr(v)
            put("; }\n")
        } else {
            if declaration_shaped(v) { put("if (1) ") }   // never C's declaration (#402)
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
    case S_DO:                                           // do { } while c, C's (#459)
        put("do\n")
        indent(depth)
        gen_block(nodes[n].b, depth)
        indent(depth)
        put("while (")
        gen_cond(nodes[n].a)
        put(");\n")
    case S_CFOR:                                         // C's for (#458): its init the loop's own, each step a statement of its own
        put("{\n")
        open_scope()
        var init:int64 = nodes[n].a
        while init >= 0 && !failed {
            gen_stmt(init, depth + 1)
            init = nodes[init].next
        }
        indent(depth + 1)
        put("for (; ")
        if nodes[n].b >= 0 { gen_cond(nodes[n].b) }
        put(";")
        var step:int64 = nodes[n].flag
        while step >= 0 && !failed {
            put(step == nodes[n].flag ? " ({\n" : ", ({\n")
            gen_stmt(step, depth + 2)
            indent(depth + 1)
            put("})")
            step = nodes[step].next
        }
        put(")\n")
        indent(depth + 1)
        gen_block(nodes[n].c, depth + 1)
        close_scope()
        indent(depth)
        put("}\n")
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
    case S_ASSERT: gen_assert(n)                                 // (#394)
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
    if is_inline(d) { put("static inline ") }          // (#392)
    if static_decls.contains(d) && !is_inline(d) { put("static ") }   // C's (#459)
    if extern_decls.contains(d) { put("extern ") }
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
        if nodes[d].flag == 3 { put("const ") }        // a subscript's getter, by a const pointer (#136)
        put_ctype(type_of_kind(Y_STRUCT, -1, recv))
        put(nodes[d].flag == 3 ? " *const _kv_selfp" : nodes[d].flag == 2 ? " *_kv_selfp" : " self")   // a var method's, the caller's var, as kelvinc's (#320)
    }
    if p < 0 && !takes_self { put(is_main(d) && nodes[d].b >= 0 ? "int _kv_argc, char **_kv_argv" : "void") }   // main's, as kelvinc writes it (#463)
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
    if variadic_fns.contains(d) { put(", ...") }          // C's variadic function (#453)
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
    if tok_is(m, "insert") || tok_is(m, "remove") { return k == Y_ARRAY || k == Y_BYTES }
    if k == Y_BITS { return tok_is(m, "flip") || tok_is(m, "capacity") }   // (#456)
    if tok_is(m, "flip") { return k == Y_BOOL || is_int_kind(k) }   // (#457)
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
        if yk != Y_ARRAY && yk != Y_STRING && yk != Y_BYTES && yk != Y_DICT && yk != Y_SET && yk != Y_IO { return false }
        return builtin_no_value(yk, nodes[e].t)
    }
    if k != N_CALL && k != N_AWAIT { return false }       // await of a Task of none (#313)
    if is_case_word(e) { return false }                   // ok(v), err(e): a value, of no type to ask here (#413)
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
    if attributes.get(d, 0) == 1 || attributes.get(d, 0) == 2 {   // as kelvinc says it (#131)
        let sd:int64 = decl_named(nodes[d].c, D_STRUCT)
        var m:int64 = sd >= 0 ? nodes[sd].a : 0 - 1
        while m >= 0 {
            if same_text(nodes[m].t, nodes[d].t) {
                var e = $"'"
                e += tok_text(nodes[d].t)
                e += "' is a member of "
                e += tok_text(nodes[d].c)
                e += " already: an attribute is computed, a member stored, so name the attribute otherwise"
                gen_error(d, e.cstr)
                return
            }
            m = nodes[m].next
        }
    }
    if subscripts.get(d, 0) != 0 && decl_named(nodes[d].c, D_STRUCT) < 0 && tagged_of(type_of_kind(Y_STRUCT, -1, nodes[d].c)) < 0 {   // as kelvinc says it (#136)
        var m = $"a subscript is of a struct, a union or an enum with values of the program: '"
        m += tok_text(nodes[d].c)
        m += "' has its own indexing"
        gen_error(d, m.cstr)
        return
    }
    if nodes[d].c >= 0 && nodes[d].flag == 2 && subscripts.get(d, 0) == 0 && decl_named(nodes[d].c, D_STRUCT) < 0 {   // as kelvinc's (#320)
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
    let var_method = nodes[d].c >= 0 && (nodes[d].flag == 2 || nodes[d].flag == 3)
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
        if (uses_io || uses_sys) && nodes[d].a >= 0 {
            put("    kv_sys_init(")
            put_tok(nodes[nodes[d].a].t)
            put(", ")
            put_tok(nodes[nodes[nodes[d].a].next].t)
            put(");\n")
        } else if uses_sys {                             // main's own, as kelvinc names them (#463)
            put("    kv_sys_init(_kv_argc, _kv_argv);\n")
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
    put_spelling(nodes[d].t)
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
            let shown:String = kelvin_name(name)                 // point.kind, of one nested (#389)
            out += &shown
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
// struct T; before a function type that names T, whose own C is not
// written yet, or is being written, as of a member's (#428)
let forward_struct(y:int64) {
    var b:int64 = y
    while b >= 0 && types[b].kind == Y_PTR { b = types[b].elem }
    if b < 0 || types[b].kind != Y_STRUCT || written.get(b, 0) == 1 { return }
    if decl_named(types[b].name, D_STRUCT) < 0 && tagged_of(b) < 0 { return }
    put_record_word(b)
    put_tok(types[b].name)
    put(";\n")
}

let write_type(y:int64) {
    if y < 0 || written.has(y) || late(y) { return }   // an x.type's, told in its statement (#423)
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
    } else if k == Y_FN {                               // typedef R (*_kv_fnN)(P, Q) (#428), after its types
        var p:int64 = types[y].name
        while p >= 0 {
            forward_struct(types[p].elem)
            write_type(types[p].elem)
            p = types[p].name
        }
        let r:int64 = types[y].elem
        if r >= 0 {
            forward_struct(r)
            write_type(r)
        }
        put("typedef ")
        if r >= 0 { put_ctype(r) } else { put("void") }
        put(" (*")
        put_ctype(y)
        put(")(")
        p = types[y].name
        if p < 0 { put("void") }
        while p >= 0 {
            put_ctype(types[p].elem)
            p = types[p].name
            if p >= 0 { put(", ") }
        }
        put(");\n")
    } else if k == Y_STRUCT {
        written[y] = 2                                   // while what it holds is written (#346)
        let d = decl_named(types[y].name, D_STRUCT)
        if d >= 0 {
            var f:int64 = nodes[d].a
            while f >= 0 {
                write_type(nodes[f].ty)
                f = nodes[f].next
            }
            put_spelling(nodes[d].t)
            put_record_word(y)
            put_tok(nodes[d].t)
            put("\n{\n")
            f = nodes[d].a
            while f >= 0 {
                put("    ")
                put_alignas(f)                           // (#396)
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
                    set_ty(p, type_of_kind(Y_FIXED, types[y].elem, types[y].name == 0 - 3 || types[y].konst == 1 ? 0 - 4 : 0 - 2))   // [const T](N) too (#425)
                }
                p = nodes[p].next
            }
        }
    }
}

// the token of a variable that static_assert's condition n reads (#394),
// which C does not count as a constant, or -1; .size reads none
let unconstant(n:int64):int64 {
    if n < 0 { return 0 - 1 }
    let k = nodes[n].kind
    if k == N_ID {
        let name:String = tok_text(nodes[n].t)
        return var_type(nodes[n].t) >= 0 && enumerators.get(name, -1) < 0 ? nodes[n].t : 0 - 1
    }
    if k == N_FIELD && tok_is(nodes[n].t, "size") { return 0 - 1 }
    if k == N_BIN || k == N_UNARY || k == N_CAST || k == N_COND || k == N_FIELD {
        var v:int64 = unconstant(nodes[n].a)
        if v < 0 && (k == N_BIN || k == N_COND) { v = unconstant(nodes[n].b) }
        if v < 0 && k == N_COND { v = unconstant(nodes[n].c) }
        return v
    }
    return 0 - 1
}

// x, x^, x[i]: what C could read as a declarator (#402)
let declarator_like(e:int64):bool {
    let k = nodes[e].kind
    if k == N_ID { return true }
    return (k == N_DEREF || k == N_INDEX) && nodes[e].a >= 0 && declarator_like(nodes[e].a)
}

// a statement name(x) of a name kc does not see (#402), as kelvinc's:
// were name a C typedef, C would read a declaration of x, so the C is
// if (1) name(x), where a declaration is no statement
let declaration_shaped(e:int64):bool {
    if e < 0 || nodes[e].kind != N_CALL { return false }
    let f:int64 = nodes[e].a
    let arg:int64 = nodes[e].b
    if f < 0 || nodes[f].kind != N_ID || arg < 0 || nodes[arg].next >= 0 || !declarator_like(arg) { return false }
    let t:int64 = nodes[f].t
    return var_type(t) < 0 && decl_named(t, D_FN) < 0 && !tok_is(t, "print") && !tok_is(t, "println")
}

// static_assert(cond, "message") (#394), as kelvinc's: C's _Static_assert,
// which C judges as it compiles, its message the condition as written
// where none is
let gen_assert(n:int64) {
    let v:int64 = unconstant(nodes[n].a)
    if v >= 0 {
        var m = $"a static_assert is judged as C compiles, before the program runs, and '"
        m += tok_text(v)
        m += "' is a variable, which C does not count as a constant"
        gen_error(n, m.cstr)
        return
    }
    put("_Static_assert(")
    gen_cond(nodes[n].a)
    put(", ")
    if nodes[n].b >= 0 {
        var t:int64 = nodes[n].b
        while toks[t].kind == T_STR {
            if t > nodes[n].b { put(" ") }
            put_text(t, 0)
            t += 1
        }
    } else {
        put("\"")
        let last:int64 = nodes[n].flag - 1
        for i in toks[nodes[n].c].at..<toks[last].at + toks[last].len {
            let c:uint32 = codes[i]
            if c == '\\' || c == '"' {
                put("\\")
                out += c.uchr
            } else if c == '\n' {
                put(" ")
            } else if c == '?' {
                put("\\?")
            } else {
                out += c.uchr
            }
        }
        put("\"")
    }
    put(");\n")
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
    for i in 0..<decls.count as int64 {                  // #import <OS> (#463)
        if nodes[decls[i]].kind == D_IMPORT && (tok_is(nodes[decls[i]].t, "<OS>") || tok_is(nodes[decls[i]].t, "<IO>")) { os_imported = true }   // IO imports OS
    }
    uses_sys = os_imported
    for i in 0..<toks.count as int64 {                   // SYS.name anywhere, before main is written (#463)
        if toks[i].kind == T_ID && tok_is(i, "SYS") && tok_is(i + 1, ".") && var_type(i) < 0 { uses_sys = true }
    }
    for i in 0..<decls.count as int64 {
        let d:int64 = decls[i]
        if nodes[d].kind == D_IMPORT && nodes[d].flag == 1 {
            put("#include <kOS.h>\n#include <kIO.h>\n")
            uses_io = true
        }
        if nodes[d].kind == D_IMPORT && tok_is(nodes[d].t, "<OS>") { put("#include <kOS.h>\n") }   // (#463)
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
            put("enum")
            if !tok_is(nodes[d].t, "enum") {             // enum { ... }, C's anonymous one (#451)
                put(" ")
                put_tok(nodes[d].t)
            }
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
        let made = nodes[d].kind == D_ENUM && kc_made(nodes[d].t)   // an Optional's, a Result's: refused where it is used (#368)
        if nodes[d].kind == D_STRUCT || (nodes[d].kind == D_ENUM && nodes[d].flag == 1 && !made) {
            var f:int64 = nodes[d].a
            while f >= 0 {
                let fy:int64 = nodes[f].ty
                if nodes[d].kind == D_STRUCT && nodes[d].flag == 1 && fy >= 0 && is_owner(fy) {   // as kelvinc says it (#453)
                    gen_error(f, "a union cannot hold an owner (#54): which member to free is unknown")
                    return
                }
                let user_enum = nodes[d].kind == D_ENUM && !kc_made(nodes[d].t)   // not an Optional's, a Result's (#360)
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
    for y in c_tag_types {                               // struct timespec;, C's, as kelvinc declares it (#453)
        put_ctype(y)
        put(";\n")
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
    for i in 0..<fn_types.count as int64 { write_type(fn_types[i]) }   // (#428)
    put("\n")
    for i in 0..<decls.count as int64 {                  // the globals
        let d:int64 = decls[i]
        if nodes[d].kind == D_ASSERT { gen_assert(d) }   // (#394)
        if nodes[d].kind == D_GLOBAL {
            if nodes[d].a >= 0 && nodes[nodes[d].a].kind == N_ASYNC {      // as kelvinc's (#313)
                gen_error(nodes[d].a, "'async' starts a call on a thread of its own, in a function: write it in one")
                return
            }
            if nodes[d].ty < 0 { set_ty(d, inferred(d)) }       // (#214)
            if failed { return }
            write_type(nodes[d].ty)                      // a function type inferred, let f := g (#428)
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
            let fns:int64 = anon_fns.count as int64     // a function an anonymous function makes, declared first (#428)
            let around:int64 = current
            current = d
            var before:String = out.copy()
            out = $""
            if static_decls.contains(d) { put("static ") }   // C's (#459)
            if extern_decls.contains(d) { put("extern ") }
            put_alignas(d)                               // (#396)
            if nodes[d].flag == 1 { put("const ") }
            put_ctype(nodes[d].ty)
            put(" ")
            put_tok(nodes[d].t)
            let declared = extern_decls.contains(d) && nodes[d].a < 0   // an extern's value is C's, elsewhere
            if !declared { put(" = ") }
            if declared {
                put("")
            } else if nodes[d].a >= 0 {
                gen_written(nodes[d].a, nodes[d].ty)    // ${:} (#348)
            } else if is_owner(nodes[d].ty) || types[nodes[d].ty].kind == Y_STRUCT {
                put("{0}")
            } else {
                put("0")
            }
            put(";\n")
            current = around
            var line:String = out.copy()
            out = before.copy()
            for f in fns..<anon_fns.count as int64 {
                gen_signature(anon_fns[f])
                put(";\n")
            }
            out += &line
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
        if nodes[d].kind == D_FN && !is_main(d) && (nodes[d].b >= 0 || nodes[d].c < 0) {   // one with no body too, as kelvinc declares it (#453)
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
        if nodes[d].kind == D_FN && nodes[d].b >= 0 && !failed && !anon_fns.contains(d) { gen_function(d) }   // a global's { ... } with those kc makes (#428)
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
    for i in 0..<fn_types.count as int64 { write_type(fn_types[i]) }   // and the function types of a value (#428)
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
