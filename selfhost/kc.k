// kc.k - a Kelvin compiler written in Kelvin, experimental (#230), of
// selfhost/README.md. It reads the subset of Kelvin it is written in,
// writes C as kelvinc does, for the same runtime, and hands it to cc:
//   kc [-c | --emit-c] [--no-line] file.k [-o path] [-m modules] [-cc compiler]
// as kelvinc's options (#281): -c makes an object, file.o or the -o
// path; --emit-c writes the C, to the -o path or stdout, and stops,
// which is how the stages are compared; else the C is a temporary file,
// in $TMPDIR, removed once cc is done, and the program a.out or -o. -m
// names the directory of kelvin_prelude.h and the libraries, else
// $KELVIN_HOME/modules, else modules/; -cc the C compiler, else $CC,
// else cc. The files it imports, `#import "x.k"`, are read too, and C's
// headers, `#import <x.h> as C`, are C's, as libc is (#207). A module of
// the prelude that a program names, BigInt or RegExp, is read from its
// M.kh in the modules, and libkelvin defines it (#515). A module it
// imports, `#import <M>`, is M.kh, else M.k, in ./modules, else in the
// modules, as kelvinc finds it; a header's libkM.a beside it is linked,
// with its libkM.link's flags, and <x.k> is that file (#516).
#import <IO>
#import <stdio.h> as C            // remove
#import <stdlib.h> as C           // getenv, strtod
#import <math.h> as C             // pow, of a power of literals (#380)
#import <string.h> as C           // strpbrk
#import <unistd.h> as C           // getpid
#import <kRegExp.h> as C          // rx_check, the runtime's, of a $/.../ literal (#611)
#import "ident.k"                 // the codepoints of a name past ASCII (#385)
#import "lex.k"
#import "parse.k"
#import "gen.k"

// the directory of a path, with its /, or ""
let dir_of(path:String^):String {
    var cut = 0
    var i = 0
    for c in path^.codepoints {
        i += 1
        if c == '/' { cut = i }
    }
    var r = $""
    var j = 0
    for c in path^.codepoints {
        if j < cut { r += c }
        j += 1
    }
    return r
}

// the name of a path without its directory and its .k, as the object of
// kc -c is named (#281)
let base_of(path:String^):String {
    let dir:String = dir_of(path)
    var cs:$[int64] = $[]
    var j = 0
    for c in path^.codepoints {
        if j >= dir.count as int64 { cs += c }
        j += 1
    }
    var n = cs.count as int64
    if n > 2 && cs[n - 2] == '.' && cs[n - 1] == 'k' { n -= 2 }
    var r = $""
    for k in 0..<n {
        r += cs[k]
    }
    return r
}

// the length of the valid UTF-8 sequence at i of b, or 0, as kelvinc's
// utf8_length: no overlong form, no surrogate, nothing past 10FFFF
let utf8_len(b:const $[int64]^, i:int64):int64 {
    let c:int64 = b^[i]
    if c < 0x80 { return 1 }
    var n:int64 = 0
    if c >= 0xC2 && c <= 0xDF {
        n = 2
    } else if c >= 0xE0 && c <= 0xEF {
        n = 3
    } else if c >= 0xF0 && c <= 0xF4 {
        n = 4
    }
    if n == 0 || i + n > b^.count as int64 { return 0 }
    var lo:int64 = 0x80
    var hi:int64 = 0xBF
    if c == 0xE0 { lo = 0xA0 }
    if c == 0xF0 { lo = 0x90 }
    if c == 0xED { hi = 0x9F }
    if c == 0xF4 { hi = 0x8F }
    if b^[i + 1] < lo || b^[i + 1] > hi { return 0 }
    for k in 2..<n {
        if b^[i + k] < 0x80 || b^[i + k] > 0xBF { return 0 }
    }
    return n
}

// the error of the file at path where it is no source kelvinc reads, or
// "": UTF-8, valid and without a BOM (#295, #298), its bytes read by C's
// stdio before IO's .string, whose err says no more than where
let source_error(path:String^):String {
    let fp:FILE^ := fopen(path^.cstr, "rb")
    if fp == nowhere { return $"" }
    var b:$[int64] = $[]
    var c:int64 = fgetc(fp) as int64
    while c >= 0 {
        b += c
        c = fgetc(fp) as int64
    }
    fclose(fp)
    let n = b.count as int64
    if n >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF {
        var bom:String = path^.copy()
        bom += ":1: error: a Kelvin source is UTF-8 without a BOM: remove its first three bytes, EF BB BF (#295)"
        return bom
    }
    var line:int64 = 1
    var i:int64 = 0
    while i < n {
        let k = utf8_len(&b, i)
        if k == 0 {
            var why:String = path^.copy()
            why += ":"
            why += String(line)
            why += ": error: a Kelvin source is valid UTF-8, and byte 0x"
            let h:String = hex_upper(b[i])
            why += &h
            why += " here is not (#295)"
            return why
        }
        if b[i] == 10 { line += 1 }
        i += k
    }
    return $""
}

// reads a file into codes and its tokens into toks: its place among the
// files, or why it cannot (#217)
let load(path:String^):Result<int64, String> {
    var f:IO = IO(path^.cstr, "r")
    if f.error != 0 {
        var why = $"kc: cannot read "
        why += path
        return err(why)
    }
    let wrong:String = source_error(path)                // UTF-8 without a BOM (#298)
    if wrong.count > 0 { return err(wrong) }
    var text:String = f.string ?? $""                    // a Result (#406, #407); source_error saw it is UTF-8
    let file:int64 = fnames.count as int64
    fnames += path^.copy()
    file_by += reading_by
    file_with_a += reading_a
    file_with_b += reading_b
    let from:int64 = codes.count as int64
    for c in text.codepoints {
        codes += c
    }
    codes += '\n'
    lex_range(from, codes.count as int64, file)
    return ok(file)
}

// whether path is read; where it is not, why is said
let loads(path:String^):bool {
    if let err(why) = load(path) {
        println(why)
        return false
    }
    return true
}

// the files that #import "x.k" names, next to the file that names it,
// each read once, after all of the main file
let load_imports():bool {
    var i = 0
    while i < toks.count as int64 {
        if toks[i].kind == T_IMPORT && codes[toks[i].at] == '"' && !is_header(i) {
            var path:String = dir_of(&fnames[toks[i].file])
            let at:int64 = toks[i].at
            for j in 1..<toks[i].len - 1 {
                path += codes[at + j]
            }
            var seen = false
            for k in 0..<fnames.count as int64 {
                if fnames[k] == path { seen = true }
            }
            if !seen && import_line(i) {                 // a file, and no directory, as kelvinc says it (#40, #611)
                var probe:IO = IO(path.cstr, "r")
                if probe.error != 0 || !probe.isfile {
                    var why = $"cannot find "
                    why += tok_text(i)
                    why += " next to the file that imports it"
                    lex_error(toks[i].file, toks[i].line, why.cstr)
                    return false
                }
            }
            reading_by = i                               // whose aliases reach what follows the #import (#550)
            let read = seen || loads(&path)
            reading_by = 0 - 1
            if !read { return false }
            note_import(toks[i].file, &path)             // (#600)
        }
        i += 1
    }
    return true
}

// ---------- the Kelvin namespace (#600) ----------

// each file's imports, a file and one it imports: a file sees the types
// of its own that the files it imports define, as kelvinc's own_types
var import_from:$[int64] = $[]
var import_to:$[int64] = $[]

// where path is among the files read, as read_already finds it, or -1
let file_index(path:String^):int64 {
    let want = real_of(path)
    for k in 0..<fnames.count as int64 {
        if fnames[k] == path^ { return k }
        let had = real_of(&fnames[k])
        if had == want { return k }
    }
    return 0 - 1
}

let note_import(from:int64, path:String^) {
    let to = file_index(path)
    if to >= 0 && to != from {
        import_from += from
        import_to += to
    }
}

// a file, and the name of a type of its own that one of the prelude's
// has: one it defines, struct BigInt { ... }, or one a file it imports
// sees. Such a type hides the prelude's under the bare name there, and
// nowhere else: BigNum.kh's c64 is math's, whatever the program defines
var sees_file:$[int64] = $[]
var sees_name:$[int64] = $[]

let file_sees(f:int64, t:int64):bool {
    for k in 0..<sees_file.count as int64 {
        if sees_file[k] == f && same_text(sees_name[k], t) { return true }
    }
    return false
}

// whether token t defines a type, struct T { ... }, enum T { ... } or
// typealias T = ..., and does not name one, p:struct tm^, as kelvinc's
// defines_type: its name is the next token
let defines_type(t:int64):bool {
    if t + 2 >= toks.count as int64 || toks[t].kind != T_ID || toks[t + 1].kind != T_ID { return false }
    if t > 0 && toks[t - 1].kind == T_PUNCT && tok_is(t - 1, ".") { return false }
    if toks[t + 2].kind != T_PUNCT { return false }
    if tok_is(t, "typealias") { return tok_is(t + 2, "=") }
    if !tok_is(t, "struct") && !tok_is(t, "union") && !tok_is(t, "enum") { return false }
    return tok_is(t + 2, "{") || tok_is(t + 2, "<") || tok_is(t + 2, ":")
}

// whether token t begins an enum with a name and a body, enum E { ... }
let enum_at(t:int64):bool {
    return t + 2 < toks.count as int64 && toks[t].kind == T_ID && tok_is(t, "enum") && toks[t + 1].kind == T_ID && toks[t + 2].kind == T_PUNCT && tok_is(t + 2, "{")
}

// the words of the enum at t, enum E { a, b = 2 }, as the places of their
// tokens, as kelvinc's enum_words: of an enum of words alone, which are
// names of the whole program; none of an enum with values, whose cases
// are the enum's own
let enum_words(t:int64):$[int64] {
    var words:$[int64] = $[]
    var end:int64 = t + 3
    var values = false
    while end < toks.count as int64 && !(toks[end].kind == T_PUNCT && tok_is(end, "}")) {
        if toks[end].kind == T_PUNCT && (tok_is(end, ":") || tok_is(end, "{")) { values = true }
        end += 1
    }
    for k in t + 3..<end {
        if values || toks[k].kind != T_ID { continue }
        let first = toks[k - 1].kind == T_NL || (toks[k - 1].kind == T_PUNCT && (tok_is(k - 1, "{") || tok_is(k - 1, ",") || tok_is(k - 1, ";")))
        if first { words += k }
    }
    return words
}

// the tokens that declare a member, a struct's x: T or an extend's let x,
// which no name of the top level hides: it is read after a dot (#604)
var member_toks:$[int64] = $[]

// each file's own names among the prelude's (#600, #604), as kelvinc's
// own_types: its types', its functions' and the words of its enums. A
// file has one where it defines, at its top level, a type of the name,
// a variable of it, a word of an enum of its own, or, of a word of the
// prelude's, a function; a function of the name of one of the prelude's
// functions is an overload, and no such name. It sees those and what the
// files it imports see. A file of the prelude sees none
let own_types(types:$[int64]^, fns:$[int64]^, words:$[int64]^) {
    while sees_file.count > 0 { sees_file.pop() }
    while sees_name.count > 0 { sees_name.pop() }
    while member_toks.count > 0 { member_toks.pop() }
    var kinds:$[int64] = $[]                             // what each brace belongs to: 1 a struct's or a union's body, 2 an extend's, 0 any other
    var found = false
    for t in 0..<toks.count as int64 - 2 {
        if t > 0 && toks[t].file != toks[t - 1].file {
            while kinds.count > 0 { kinds.pop() }
        }
        let depth:int64 = kinds.count as int64
        let inside:int64 = depth > 0 ? kinds[depth - 1] : 0 - 1
        var own:$[int64] = $[]                           // the names defined here
        if toks[t].kind == T_PUNCT && tok_is(t, "{") {
            var kind:int64 = 0
            if t >= 2 && toks[t - 1].kind == T_ID && toks[t - 2].kind == T_ID {
                if tok_is(t - 2, "struct") || tok_is(t - 2, "union") { kind = 1 }
                if tok_is(t - 2, "extend") { kind = 2 }
            }
            kinds += kind
        } else if toks[t].kind == T_PUNCT && tok_is(t, "}") {
            if depth > 0 { kinds.pop() }
        } else if toks[t].kind != T_ID {
            continue
        } else if inside == 1 && toks[t + 1].kind == T_PUNCT && tok_is(t + 1, ":") {
            member_toks += t
        } else if inside == 2 && t > 0 && toks[t - 1].kind == T_ID && (tok_is(t - 1, "let") || tok_is(t - 1, "var")) {
            member_toks += t
        } else if depth != 0 || prelude_file(toks[t].file) {
            continue
        } else if enum_at(t) {
            own = enum_words(t)
            own += t + 1
        } else if defines_type(t) {
            own += t + 1
        } else if (tok_is(t, "let") || tok_is(t, "var")) && toks[t + 1].kind == T_ID && toks[t + 2].kind == T_PUNCT {
            let variable = tok_is(t + 2, ":") || tok_is(t + 2, "=") || tok_is(t + 2, ":=")
            let function = tok_is(t + 2, "(")
            if variable || (function && text_among(t + 1, words)) { own += t + 1 }
        }
        for u in own {
            let theirs = text_among(u, types) || text_among(u, fns) || text_among(u, words)
            if theirs && !file_sees(toks[u].file, u) {
                sees_file += toks[u].file
                sees_name += u
                found = true
            }
        }
    }
    var more = found
    while more {
        more = false
        for e in 0..<import_from.count as int64 {
            let f:int64 = import_from[e]
            let g:int64 = import_to[e]
            if prelude_file(f) { continue }
            let had:int64 = sees_file.count as int64
            for k in 0..<had {
                if sees_file[k] == g && !file_sees(f, sees_name[k]) {
                    sees_file += f
                    sees_name += sees_name[k]
                    more = true
                }
            }
        }
    }
}

// whether the name at t is the files' own, which hides the prelude's
// there, as kelvinc's own_name: not after a dot, Kelvin.T or a member's,
// nor where it declares a member, nor a literal's, $/.../ or 123n, which
// are the prelude's
let own_name(t:int64):bool {
    if sees_file.count == 0 || toks[t].kind != T_ID { return false }
    if t > 0 && toks[t - 1].kind == T_PUNCT && tok_is(t - 1, ".") { return false }
    if !file_sees(toks[t].file, t) { return false }
    return !big_lits.contains(t) && !rx_lits.contains(t) && !member_toks.contains(t)
}

// ---------- the modules, of the prelude too (#504, #515, #516) ----------

// the libraries of the modules imported as M.kh, libkM.a beside it, or
// -lkM where only a shared libkM is, with the flags of libkM.link, in the
// order imported, linked before libkelvin, as kelvinc's (#516)
var module_libs:$[String] = $[]

// whether a file is there
let exists(path:String^):bool {
    return access(path^.cstr, 0) == 0
}

// the files already read, by path
let read_already(path:String^):bool {
    let want = real_of(path)
    for k in 0..<fnames.count as int64 {
        if fnames[k] == path^ { return true }
        let had = real_of(&fnames[k])                    // modules/M.kh and ./modules/M.kh are one (#520)
        if had == want { return true }
    }
    return false
}

// path with its links and dots resolved, realpath's, else as it is written
let real_of(path:String^):String {
    let r:u8^ := realpath(path^.cstr, nowhere)
    if r == nowhere { return path^.copy() }
    let s = String(r as cstr)
    free(r)
    return s
}

// the flags of dir/libkM.link (#482), split on whitespace, as kelvinc's
let link_flags(path:String^) {
    if !exists(path) { return }
    var f:IO = IO(path^.cstr, "r")
    if f.error != 0 { return }
    let text:String = f.string ?? $""
    f.close()
    var w = $""
    for c in text.codepoints {
        let u = c
        if u == ' ' || u == '\t' || u == '\r' || u == '\n' {
            if w.count > 0 { module_libs += w.copy() }
            w = $""
        } else {
            w += c
        }
    }
    if w.count > 0 { module_libs += w.copy() }
}

// a module's library and what follows it in module_libs, its libkM.link's
// flags (#599), as kelvinc's ModuleLib: by its dir/libkM, where it starts
// and how many it is, and the file of its header; and each pair of a
// module and one its header imports. A library goes before those its
// module imports, as C's linker reads each once, in order
var lib_keys:$[String] = $[]
var lib_at:$[int64] = $[]
var lib_len:$[int64] = $[]
var lib_file:$[int64] = $[]
var lib_moving:$[bool] = $[]
var lib_by:$[int64] = $[]                   // pairs: the importer's place among them, then the imported's

// where the library of dir/libkM is among them, or -1
let lib_mark(dir:String^, name:String^):int64 {
    var key:String = dir^.copy()
    key += "/libk"
    key += name
    for i in 0..<lib_keys.count as int64 {
        if lib_keys[i] == key { return i }
    }
    return -1
}

// the library m, and what follows it, after all the others, and then the
// ones its module imports after it, as kelvinc's module_lib_after: one
// imported already is moved after the module whose header imports it now
let lib_after(m:int64) {
    if m < 0 || lib_moving[m] || lib_len[m] == 0 { return }
    lib_moving[m] = true
    let at = lib_at[m]
    let n = lib_len[m]
    var all:$[String] = $[]
    for i in 0..<module_libs.count as int64 {
        if i < at || i >= at + n { all += module_libs[i].copy() }
    }
    for i in at..<at + n { all += module_libs[i].copy() }
    while module_libs.count > 0 { module_libs.pop() }
    for l in all { module_libs += l.copy() }
    for i in 0..<lib_at.count as int64 {
        if i != m && lib_at[i] > at { lib_at[i] -= n }
    }
    lib_at[m] = module_libs.count as int64 - n
    var k:int64 = 0
    while k + 1 < lib_by.count as int64 {
        if lib_by[k] == m { lib_after(lib_by[k + 1]) }
        k += 2
    }
    lib_moving[m] = false
}

// the library of a module's header, dir/M.kh, as kelvinc's module_library
let module_library(dir:String^, name:String^) {
    let start = module_libs.count as int64
    module_library_of(dir, name)
    if module_libs.count as int64 > start && lib_mark(dir, name) < 0 {
        var key:String = dir^.copy()
        key += "/libk"
        key += name
        lib_keys += key.copy()
        lib_at += start
        lib_len += module_libs.count as int64 - start
        lib_file += 0 - 1
        lib_moving += false
    }
}

let module_library_of(dir:String^, name:String^) {
    var base:String = dir^.copy()
    base += "/libk"
    base += name
    var a:String = base.copy()
    a += ".a"
    var link:String = base.copy()
    link += ".link"
    if exists(&a) {
        module_libs += a.copy()
        link_flags(&link)
        return
    }
    var so:String = base.copy()
    so += ".dylib"
    var so2:String = base.copy()
    so2 += ".so"
    if exists(&so) || exists(&so2) {
        var l = $"-L"
        l += dir
        module_libs += l.copy()
        var k = $"-lk"
        k += name
        module_libs += k.copy()
        link_flags(&link)
    }
}

// the modules read, by name, in the order read, and the file of each
// (#551): <dir/M.k> is M, as kelvinc names a module; an overlay, A+B, is
// none of them, as no overlay of an overlay is looked for
var module_names:$[String] = $[]
var module_files:$[int64] = $[]

let note_module(name:String^, file:int64) {
    for c in name^.codepoints {
        if c == '+' { return }
    }
    module_names += name^.copy()
    module_files += file
}

// the name of the module that #import token t names
let module_base(t:int64):String {
    var from:int64 = 1
    var to:int64 = toks[t].len - 1
    for j in 1..<toks[t].len - 1 {
        if codes[toks[t].at + j] == '/' { from = j + 1 }
    }
    var j:int64 = toks[t].len - 2
    while j >= from {
        if codes[toks[t].at + j] == '.' {
            to = j
            break
        }
        j -= 1
    }
    var s = $""
    for i in from..<to { s += codes[toks[t].at + i] }
    return s
}

// the module #import <M> or <x.k> names, as kelvinc's import_path: <M> is
// M.kh, a module's header, else M.k, in ./modules, else in Kelvin's
// modules; it is read once, and a header's library is linked (#516)
let load_module(mods:String^, t:int64):bool {
    var name = $""
    var base:String = module_base(t)
    var bare = true
    for j in 1..<toks[t].len - 1 {
        let c:uint32 = codes[toks[t].at + j]
        if c == '.' { bare = false }
        name += c
    }
    for k in 0..<2 {
        var dir:String = k == 0 ? $"./modules" : mods^.copy()
        var path:String = dir.copy()
        path += "/"
        path += &name
        if bare {
            var kh:String = path.copy()
            kh += ".kh"
            if exists(&kh) {
                var by:int64 = 0 - 1                     // the module whose header imports it (#599)
                for i in 0..<lib_file.count as int64 {
                    if lib_file[i] == toks[t].file { by = i }
                }
                if read_already(&kh) {
                    note_import(toks[t].file, &kh)       // (#600)
                    let had = lib_mark(&dir, &name)
                    if by >= 0 && had >= 0 {             // its library after that module's
                        lib_by += by
                        lib_by += had
                        lib_after(had)
                    }
                    return true
                }
                module_library(&dir, &name)
                let made = lib_mark(&dir, &name)
                if by >= 0 && made >= 0 {
                    lib_by += by
                    lib_by += made
                }
                reading_by = t                           // (#550)
                let read = loads(&kh)
                reading_by = 0 - 1
                if read && made >= 0 { lib_file[made] = fnames.count as int64 - 1 }
                if read { note_module(&base, fnames.count as int64 - 1) }
                if read { note_import(toks[t].file, &kh) }   // (#600)
                return read
            }
            path += ".k"
        }
        if exists(&path) {
            if read_already(&path) {
                note_import(toks[t].file, &path)         // (#600)
                return true
            }
            reading_by = t
            let read = loads(&path)
            reading_by = 0 - 1
            if read { note_module(&base, fnames.count as int64 - 1) }
            if read { note_import(toks[t].file, &path) }
            return read
        }
    }
    if tok_is(t, "<BigFloat>") {                         // renamed (#590)
        lex_error(toks[t].file, toks[t].line, "<BigFloat> is <BigNum> now, with CBR, CBF and math's functions of them (#590): write #import <BigNum>")
        return false
    }
    var why = $"cannot find "
    let at:int64 = toks[t].at
    for j in 0..<toks[t].len {
        why += codes[at + j]
    }
    why += " ("
    if bare {
        why += &name
        why += ".kh or "
    }
    why += &name
    if bare { why += ".k" }
    why += ") in ./modules or in Kelvin's modules/ (KELVIN_HOME, or next to kelvinc)"
    lex_error(toks[t].file, toks[t].line, why.cstr)
    return false
}

// whether token t is #import <M> of a module, not C's <x.h> nor IO or OS,
// which kc knows
let module_import(t:int64):bool {
    return toks[t].kind == T_IMPORT && codes[toks[t].at] == '<' && !is_header(t) && !tok_is(t, "<IO>") && !tok_is(t, "<OS>")
}

// each #import <M> among the tokens not looked at yet: its module read,
// whose own imports follow in turn
var import_scan:int64 = 0

let load_module_imports(mods:String^):bool {
    while import_scan < toks.count as int64 {
        if module_import(import_scan) && !load_module(mods, import_scan) { return false }
        import_scan += 1
    }
    return true
}

// whether token t has the text of one of the tokens at
let text_among(t:int64, at:$[int64]^):bool {
    for a in at^ {
        if same_text(t, a) { return true }
    }
    return false
}

// math, the prelude's too (#590), as kelvinc's with_math: the files that
// name one of its names read it as if the program began with #import
// <math>. Its names are read from the module itself: what it declares,
// wherever the files write it but where they declare one of their own,
// let log(...), and what it gives f64 and f32, after a dot, f64.tau. So it
// is read first, and its tokens are taken away again where none of them
// is named. A type of the files' own with the name of one of its types,
// c64, hides math's there and names none of it (#600), where it kept all
// of math out. The tokens of the UnicodeData that every program has are
// not asked, file ucd of them
let load_math(mods:String^, ucd:int64):bool {
    var path = $""
    var dir = $""
    var header = false
    for k in 0..<2 {
        dir = k == 0 ? $"./modules" : mods^.copy()
        var kh:String = dir.copy()
        kh += "/math.kh"
        var src:String = dir.copy()
        src += "/math.k"
        if exists(&kh) {
            path = kh.copy()
            header = true
            break
        }
        if exists(&src) {
            path = src.copy()
            break
        }
    }
    if path.count == 0 || read_already(&path) { return true }        // none, or #import <math> written
    let first:int64 = toks.count as int64
    let code0:int64 = codes.count as int64
    if !loads(&path) { return false }
    var names:$[int64] = $[]
    var types:$[int64] = $[]
    var members:$[int64] = $[]
    var depth = 0
    var giving = false                                   // in an extend of a type that is not math's own
    for t in first..<toks.count as int64 - 1 {
        let u:int64 = t + 1
        if toks[t].kind == T_PUNCT && tok_is(t, "{") {
            depth += 1
        } else if toks[t].kind == T_PUNCT && tok_is(t, "}") {
            depth -= 1
        } else if toks[t].kind != T_ID || toks[u].kind != T_ID {
            continue
        } else if depth == 0 && (tok_is(t, "struct") || tok_is(t, "union") || tok_is(t, "enum") || tok_is(t, "typealias")) {
            types += u
        } else if depth == 0 && tok_is(t, "extend") {
            giving = !text_among(u, &types)
        } else if tok_is(t, "let") || tok_is(t, "var") {
            if depth == 0 {
                names += u
            } else if depth == 1 && giving {
                members += u
            }
        }
    }
    var named = false
    var none:$[int64] = $[]
    own_types(&types, &names, &none)                     // a type of the files' own with one of its types' names (#600), a variable with one of its functions' (#604)
    if sees_file.count > 0 { named = true }              // math is read then, named or not: its names hide, as C's math.h declares its functions in every program
    for t in 1..<first {
        if toks[t].kind != T_ID || toks[t].file == ucd { continue }
        if toks[t - 1].kind == T_ID && (tok_is(t - 1, "let") || tok_is(t - 1, "var")) { continue }
        if own_name(t) { continue }                      // their own c64 names no math; Kelvin.c64 does
        let dot = toks[t - 1].kind == T_PUNCT && tok_is(t - 1, ".")
        if text_among(t, &names) || text_among(t, &types) || (dot && text_among(t, &members)) { named = true }
    }
    if !named {                                          // not math's: its tokens, its text and its file go
        while toks.count as int64 > first { toks.pop() }
        while codes.count as int64 > code0 { codes.pop() }
        fnames.pop()
        while file_prelude.count as int64 > fnames.count as int64 { file_prelude.pop() }   // (#600)
        file_by.pop()
        file_with_a.pop()
        file_with_b.pop()
        return true
    }
    var name = $"math"
    if header { module_library(&dir, &name) }
    note_module(&name, fnames.count as int64 - 1)
    return true
}

// a module of the prelude that the files name, as kelvinc's with_prelude:
// RegExp, or a $/.../ literal, and BigInt, or a 123n, as if the program
// began with #import <M>; a type of the files' own of that name hides it
// there, and Kelvin.RegExp and the literals are the prelude's (#600); and
// each #import <M> of one, UnicodeData's too, which RegExp.kh imports
// (#515)
let load_prelude(mods:String^):bool {
    var ucd:String = mods^.copy()                        // UnicodeData, in every program, as kelvinc's (#520)
    ucd += "/UnicodeData.kh"
    var ucd_file:int64 = 0 - 1
    if !read_already(&ucd) {
        if !loads(&ucd) { return false }
        var u = $"UnicodeData"
        ucd_file = fnames.count as int64 - 1
        note_module(&u, ucd_file)
    }
    if !load_module_imports(mods) { return false }       // each #import <M> first, as kelvinc's with_imports: a module
                                                         // may name BigInt, as Rational's BigRat does (#542)
    if !load_math(mods, ucd_file) { return false }       // math, where one of its names is named (#590)
    let first:int64 = toks.count as int64
    for k in 0..<2 {
        let w:cstr := k == 0 ? "RegExp" : "BigInt"
        // a type of the files' own of the name hides the prelude's there,
        // and no longer keeps it out (#600): Kelvin.RegExp names it, and
        // so does a literal; the bare name is the files' own, where they
        // see that type
        var one:$[int64] = $[]
        for t in 0..<first {
            if one.count == 0 && toks[t].kind == T_ID && tok_is(t, w) { one += t }
        }
        if one.count == 0 { continue }
        var none:$[int64] = $[]
        own_types(&one, &none, &none)
        var named = false
        for t in 0..<first {
            if !named && toks[t].kind == T_ID && tok_is(t, w) && !own_name(t) { named = true }
        }
        if !named { continue }
        var imported = false
        for t in 0..<first {
            if toks[t].kind == T_IMPORT && codes[toks[t].at] == '<' && toks[t].len == strlen(w) as int64 + 2 {
                var same = true
                for j in 0..<strlen(w) as int64 {
                    if codes[toks[t].at + 1 + j] != w[j] as uint32 { same = false }
                }
                if same { imported = true }
            }
        }
        if imported { continue }
        var path:String = mods^.copy()
        path += "/"
        path += w
        path += ".kh"
        if !loads(&path) { return false }
        var noted = String(w)
        note_module(&noted, fnames.count as int64 - 1)
    }
    if !load_module_imports(mods) { return false }       // and what the prelude's own import
    return !failed
}

// an overlay (#551), as kelvinc's with_overlays, Swift's cross-import
// overlay: where the modules A and B are both read, and A+B.kh or A+B.k
// is in ./modules or in Kelvin's modules, it is read too, with what it
// imports, which may make another pair. Where it stands among the files
// as kelvinc reads them, after the later of its two, is the alias pass's
// to find (parse.k), which alone asks: its file is marked with the two
let load_overlays(mods:String^):bool {
    var tried:$[String] = $[]
    var again = true
    while again {
        again = false
        var a = 0
        while a < module_names.count as int64 && !again {
            var b = 0
            while b < module_names.count as int64 && !again {
                var name:String = module_names[a].copy()
                name += "+"
                name += &module_names[b]
                var seen = a == b
                for t in tried {
                    if t == name { seen = true }
                }
                if !seen {
                    tried += name.copy()
                    for k in 0..<2 {
                        var dir:String = k == 0 ? $"./modules" : mods^.copy()
                        var path:String = dir.copy()
                        path += "/"
                        path += &name
                        var kh:String = path.copy()
                        kh += ".kh"
                        path += ".k"
                        let header = exists(&kh)
                        if !header && !exists(&path) { continue }
                        if header { path = kh.copy() }
                        if read_already(&path) { break }         // #import <A+B> written
                        if header { module_library(&dir, &name) }
                        reading_by = 0 - 2
                        reading_a = module_files[a]
                        reading_b = module_files[b]
                        let read = loads(&path)
                        reading_by = 0 - 1
                        reading_a = 0 - 1
                        reading_b = 0 - 1
                        if !read || !load_module_imports(mods) { return false }
                        again = true
                        break
                    }
                }
                b += 1
            }
            a += 1
        }
    }
    return !failed
}

// the environment's value of name, else otherwise
// whether the files have nothing of their own named as token x, a
// variable or a function: each of their tokens of the name is a member's,
// after a dot, or a call that no let declares. Kelvin.x is then x, as
// kelvinc's kelvin_name has it: the prelude's is all there is
let nothing_named(x:int64):bool {
    for u in 1..<toks.count as int64 - 1 {
        if toks[u].kind != T_ID || prelude_file(toks[u].file) || !same_text(u, x) { continue }
        if toks[u - 1].kind == T_PUNCT && tok_is(u - 1, ".") { continue }
        if own_name(u) || member_toks.contains(u) { continue }   // the files' own of the name is _kv_own_x, another name (#604); a member's is read after a dot
        let declared = toks[u - 1].kind == T_ID && (tok_is(u - 1, "let") || tok_is(u - 1, "var"))
        let called = toks[u + 1].kind == T_PUNCT && tok_is(u + 1, "(")
        if declared || !called { return false }
    }
    return true
}

// a token's text anew, after the files' codes: before, then what it was
let retext(k:tok^, before:cstr) {
    let at:int64 = codes.count as int64
    var j = 0
    while before[j] != 0 {
        codes += before[j] as uint32
        j += 1
    }
    for i in 0..<k^.len { codes += codes[k^.at + i] }
    k^.at = at
    k^.len = codes.count as int64 - at
}

// whether token x is a word of the language that is no type, as
// kelvinc's keywords are: Kelvin.while names nothing
let language_word(x:int64):bool {
    let those:[cstr] = ["as", "true", "false", "any", "nowhere", "nullptr", "IO", "OS", "try", "let", "var", "async", "await", "fallthrough", "static_assert", "alignof", "alignas", "typeof", "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register", "restrict", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while"]
    for w in those {
        if tok_is(x, w) { return true }
    }
    return false
}

// a token kc writes, its text s after the files' codes
let made_tok(kind:tkind, s:cstr, line:int64, file:int64):tok {
    let at:int64 = codes.count as int64
    var j = 0
    while s[j] != 0 {
        codes += s[j] as uint32
        j += 1
    }
    let k:tok = {kind, at, codes.count as int64 - at, line, file}
    return k
}

// the number v, a token
let number_tok(v:int64, line:int64, file:int64):tok {
    let at:int64 = codes.count as int64
    var digits:$[uint32] = $[]
    var left:int64 = v
    while left > 0 || digits.count == 0 {
        digits += ('0' + left % 10) as uint32
        left = left / 10
    }
    while digits.count > 0 { codes += digits.pop() }
    let k:tok = {T_NUM, at, codes.count as int64 - at, line, file}
    return k
}

// Kelvin.name (#600), as kelvinc's with_kelvin: the prelude's name,
// whatever the files call their own, what a file of the prelude declares
// at its top level, a function or a type, and print, println and the
// types that are words. Kelvin is no name of a program's own. It is
// settled here, in the tokens, once every file is read: Kelvin.T of a
// type is the one token T, and Kelvin.f of a function the one token
// Kelvin.f, which gen.k chooses among the prelude's alone, or f where the
// files have nothing of the name. And a type of the files' own that has
// the name of one of the prelude's is _kv_own_T in the files that see it,
// so that the two are two types, to kc and to C
let kelvin_names():bool {
    var fns:$[int64] = $[]
    var types:$[int64] = $[]
    // the words of the prelude's enums of words alone, nfc of NormalForm,
    // which are names of every program: each, its enum's name, and its
    // number, or -1 where kc does not see it
    var prelude_words:$[int64] = $[]
    var word_enum:$[int64] = $[]
    var word_value:$[int64] = $[]
    var depth = 0
    for t in 0..<toks.count as int64 - 2 {
        if t > 0 && toks[t].file != toks[t - 1].file { depth = 0 }
        if !prelude_file(toks[t].file) { continue }
        if depth == 0 && enum_at(t) {
            var at:int64 = 0
            var known = true
            for k in enum_words(t) {
                if toks[k + 1].kind == T_PUNCT && tok_is(k + 1, "=") {   // a number written is its own; any other value is C's to see
                    var v:int64 = 0
                    var digits = toks[k + 2].kind == T_NUM && toks[k + 3].kind != T_ID && toks[k + 3].kind != T_NUM
                    for j in 0..<toks[k + 2].len {
                        let c:uint32 = codes[toks[k + 2].at + j]
                        if !is_digit(c) { digits = false }
                        v = v * 10 + (c as int64 - '0' as int64)
                    }
                    if digits { at = v } else { known = false }
                }
                prelude_words += k
                word_enum += t + 1
                word_value += known ? at : 0 - 1
                at += 1
            }
        }
        if toks[t].kind == T_PUNCT && tok_is(t, "{") {
            depth += 1
        } else if toks[t].kind == T_PUNCT && tok_is(t, "}") {
            depth -= 1
        } else if depth != 0 || toks[t].kind != T_ID {
            continue
        } else if defines_type(t) {
            types += t + 1
        } else if (tok_is(t, "let") || tok_is(t, "var")) && toks[t + 1].kind == T_ID && !(toks[t + 2].kind == T_PUNCT && tok_is(t + 2, ".")) {
            fns += t + 1                                 // not static let T.x, a member
        }
    }
    own_types(&types, &fns, &prelude_words)
    var out:$[tok] = $[]
    var place:$[int64] = $[]                             // where each token is among them now
    let n:int64 = toks.count as int64
    var t:int64 = 0
    while t < n {
        place += out.count as int64
        var k:tok = toks[t]
        if k.kind == T_ID && k.len >= 8 && tok_starts(t, "_kv_own_") {
            lex_error(k.file, k.line, "names starting with _kv_ are kelvinc's own, in the C it writes: rename it")
            return false
        }
        if k.kind != T_ID || !tok_is(t, "Kelvin") {
            if own_name(t) {
                var had = false
                for j in 0..<own_at.count as int64 {
                    if own_len[j] == k.len {
                        var same = true
                        for i in 0..<k.len {
                            if codes[own_at[j] + i] != codes[k.at + i] { same = false }
                        }
                        if same { had = true }
                    }
                }
                if !had {
                    own_at += k.at
                    own_len += k.len
                }
                retext(&k, "_kv_own_")
            }
            out += k
            t += 1
            continue
        }
        let member = t > 0 && toks[t - 1].kind == T_PUNCT && tok_is(t - 1, ".")
        let dotted = t + 2 < n && toks[t + 1].kind == T_PUNCT && tok_is(t + 1, ".") && toks[t + 2].kind == T_ID
        if member || !dotted {
            lex_error(k.file, k.line, "'Kelvin' is the prelude's name (#600), as in 'Kelvin.log(x)', the prelude's log whatever the program calls its own: a name of the program's own is another, as 'kelvin'")
            return false
        }
        let x:int64 = t + 2
        var name:tok = toks[x]
        let call = x + 1 < n && toks[x + 1].kind == T_PUNCT && tok_is(x + 1, "(")
        let words:[cstr] = ["i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128", "f32", "f64", "bool", "String", "cstr", "Bytes", "Array", "Dictionary", "Set", "Optional", "Result", "Task", "Iterator", "Range", "SYS", "int8", "int16", "int32", "int64", "int128", "uint8", "uint16", "uint32", "uint64", "uint128", "float32", "float64", "print", "println"]
        var word = false
        for w in words {
            if tok_is(x, w) { word = true }
        }
        if word {
            // a word, which no program defines: the same with and without
        } else if language_word(x) {
            var why = $"'Kelvin."
            why += tok_text(x)
            why += "' names nothing: '"
            why += tok_text(x)
            why += "' is a word of the language, and not a name of the prelude's (#600)"
            lex_error(name.file, name.line, why.cstr)
            return false
        } else if text_among(x, &fns) && (call || !text_among(x, &types)) {
            if !nothing_named(x) { retext(&name, "Kelvin.") }   // the prelude's function, gen.k's to choose
        } else if !text_among(x, &types) && text_among(x, &prelude_words) {
            // a word of an enum of the prelude's, Kelvin.nfc: (0 as NormalForm), its number as its type,
            // which a variable of its name hides neither here nor in C
            var w:int64 = 0
            while !same_text(prelude_words[w], x) { w += 1 }
            if word_value[w] < 0 {
                lex_error(name.file, name.line, "this word of an enum of the prelude's has a number kc does not see: not yet (#600)")
                return false
            }
            place += out.count as int64
            place += out.count as int64
            out += made_tok(T_PUNCT, "(", name.line, name.file)
            out += number_tok(word_value[w], name.line, name.file)
            out += made_tok(T_ID, "as", name.line, name.file)
            var of:tok = toks[word_enum[w]]
            of.line = name.line
            of.file = name.file
            out += of
            out += made_tok(T_PUNCT, ")", name.line, name.file)
            t += 3
            continue
        } else if !text_among(x, &types) {
            var why = $"'Kelvin."
            why += tok_text(x)
            why += "' names nothing: the prelude has no '"
            why += tok_text(x)
            why += "' at its top level (#600); Kelvin.name is a function or a type that a program has with no import, as 'Kelvin.sqrt' and 'Kelvin.BigInt'"
            lex_error(name.file, name.line, why.cstr)
            return false
        }
        place += out.count as int64
        place += out.count as int64
        out += name
        t += 3
    }
    for f in 0..<file_by.count as int64 {                // the #import each file was read for (#550)
        if file_by[f] >= 0 { file_by[f] = place[file_by[f]] }
    }
    while toks.count > 0 { toks.pop() }
    for k in out { toks += k }
    return !failed
}

let env_or(name:cstr, otherwise:cstr):String {
    let v:cstr := getenv(name)
    if v != nowhere { return String(v) }
    return String(otherwise)
}

let cc_arg(args:$[String]^, s:cstr) {
    args^ += String(s)
}

let main(argc:int32, argv:[cstr]):int32 {
    var input = $""
    var output = $""
    var cfile = $""
    var emit_c = false
    var compile_only = false
    var mods = $""
    var compiler:String = env_or("CC", "cc")
    var i = 1
    while i < argc as int64 {
        var a:String = String(argv[i])
        if a == $"-o" && i + 1 < argc as int64 {
            output = String(argv[i + 1])
            i += 1
        } else if a == $"-c" {
            compile_only = true
        } else if a == $"--emit-c" {
            emit_c = true
        } else if a == $"--no-line" {              // no #line in the C, as kelvinc's (#612)
            line_marks = false
        } else if a == $"-m" && i + 1 < argc as int64 {
            mods = String(argv[i + 1])
            i += 1
        } else if a == $"-cc" && i + 1 < argc as int64 {
            compiler = String(argv[i + 1])
            i += 1
        } else {
            input = String(argv[i])
        }
        i += 1
    }
    if input.count == 0 {
        println("usage: kc [-c | --emit-c] [--no-line] file.k [-o path] [-m modules] [-cc compiler]")
        return 2
    }
    if compile_only && emit_c {
        println("kc: -c makes an object, which --emit-c does not")
        return 2
    }
    if mods.count == 0 {
        let home:cstr := getenv("KELVIN_HOME")
        if home != nowhere {
            mods = String(home)
            mods += "/modules"
        } else {
            mods = $"modules"
        }
    }
    if !loads(&input) { return 1 }
    if !load_imports() { return 1 }
    if !load_prelude(&mods) { return 1 }          // BigInt, RegExp (#515), and each #import <M> (#516)
    if !load_overlays(&mods) { return 1 }         // A+B, where A and B are both read (#551)
    if !kelvin_names() { return 1 }               // Kelvin.name, and the files' own types of the prelude's names (#600)
    let end:tok = {T_EOF, codes.count as int64, 0, 0, 0}
    toks += end
    eof_pos = toks.count as int64 - 1
    if failed { return 1 }
    parse_program()
    if failed { return 1 }
    gen_program()
    if failed { return 1 }
    var temporary = false
    if emit_c {                                 // the C alone, as kelvinc --emit-c (#281)
        if output.count == 0 {
            print(out)
            return 0
        }
        cfile = output.copy()
    } else {
        if output.count == 0 && compile_only {
            output = base_of(&input)
            output += ".o"
        }
        if output.count == 0 { output = $"a.out" }
        cfile = env_or("TMPDIR", "/tmp")
        cfile += "/kc-"
        cfile += String(getpid() as int64)
        cfile += ".c"
        temporary = true
    }
    var g:IO = IO(cfile.cstr, "w")
    if g.error != 0 {
        println("kc: cannot write ", cfile)
        return 1
    }
    let c_text:String = ascii_names(&out)              // a name past ASCII in ASCII (#385)
    g.write(&c_text)
    g.close()
    if emit_c { return 0 }
    var args:$[String] = $[]
    args += compiler.copy()
    cc_arg(&args, "-std=c11")
    cc_arg(&args, "-O0")
    cc_arg(&args, "-g0")
    cc_arg(&args, "-Wno-unknown-warning-option")
    cc_arg(&args, "-Wno-pointer-sign")
    cc_arg(&args, "-Wno-incompatible-library-redeclaration")
    cc_arg(&args, "-Wno-builtin-declaration-mismatch")
    cc_arg(&args, "-Wno-tautological-constant-out-of-range-compare")   // a converter's clamp (#513)
    cc_arg(&args, "-Wno-psabi")
    cc_arg(&args, "-ffp-contract=off")             // a * b + c rounded twice, as kelvinc has it: z * w == w * z in <math> (#43, #550)
    var beside = $"-I"                             // #import "x.h" as C looks next to the .k file, as kelvinc's (#612)
    beside += dir_of(&input)
    if beside.count == 2 { beside += "." }
    args += beside.copy()
    var here = $"./modules"
    if exists(&here) {                          // C's headers of a module of ./modules, as kelvinc's (#516)
        var pre = $"./modules/kelvin_prelude.h"
        cc_arg(&args, exists(&pre) ? "-idirafter" : "-I")
        args += here.copy()
    }
    cc_arg(&args, "-isystem")
    args += mods.copy()
    if compile_only { cc_arg(&args, "-c") }        // an object, and nothing linked (#281)
    cc_arg(&args, "-o")
    args += output.copy()
    args += cfile.copy()
    if compile_only {
        var p:IO = IO.exec(args, "r")
        p.close()
        remove(cfile.cstr)
        if p.status != 0 {
            println("kc: cc failed on ", cfile)
            return 1
        }
        return 0
    }
    for l in module_libs {                      // the modules' libraries, before libkelvin's (#516)
        args += l.copy()
    }
    var lib:String = mods.copy()
    lib += "/libkIO.a"
    args += lib.copy()
    lib = mods.copy()
    lib += "/libkOS.a"
    args += lib.copy()
    lib = mods.copy()
    lib += "/libkelvin.a"
    args += lib.copy()
    cc_arg(&args, "-lm")
    cc_arg(&args, "-lpthread")               // a Task's thread (#313)
    var p:IO = IO.exec(args, "r")
    p.close()
    if temporary { remove(cfile.cstr) }
    if p.status != 0 {
        println("kc: cc failed on ", cfile)
        return 1
    }
    return 0
}
