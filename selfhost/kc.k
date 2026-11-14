// kc.k - a Kelvin compiler written in Kelvin, experimental (#230), of
// selfhost/README.md. It reads the subset of Kelvin it is written in,
// writes C as kelvinc does, for the same runtime, and hands it to cc:
//   kc [-c | --emit-c] file.k [-o path] [-m modules] [-cc compiler]
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
            reading_by = i                               // whose aliases reach what follows the #import (#550)
            let read = seen || loads(&path)
            reading_by = 0 - 1
            if !read { return false }
        }
        i += 1
    }
    return true
}

// ---------- the modules, of the prelude too (#504, #515, #516) ----------

// whether a token of the files is the name w
let names_word(w:cstr):bool {
    for i in 0..<toks.count as int64 {
        if toks[i].kind == T_ID && tok_is(i, w) { return true }
    }
    return false
}

// whether the files define a type named w: struct, union or enum w
let own_type(w:cstr):bool {
    for i in 0..<toks.count as int64 - 1 {
        if toks[i].kind == T_ID && (tok_is(i, "struct") || tok_is(i, "union") || tok_is(i, "enum")) && tok_is(i + 1, w) { return true }
    }
    return false
}

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

// the library of a module's header, dir/M.kh, as kelvinc's module_library
let module_library(dir:String^, name:String^) {
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
                if read_already(&kh) { return true }
                module_library(&dir, &name)
                reading_by = t                           // (#550)
                let read = loads(&kh)
                reading_by = 0 - 1
                if read { note_module(&base, fnames.count as int64 - 1) }
                return read
            }
            path += ".k"
        }
        if exists(&path) {
            if read_already(&path) { return true }
            reading_by = t
            let read = loads(&path)
            reading_by = 0 - 1
            if read { note_module(&base, fnames.count as int64 - 1) }
            return read
        }
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
    why += ") in ./modules or in Kelvin's modules/ (KELVIN_HOME, or -m)"
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

// a module of the prelude that the files name, as kelvinc's with_prelude:
// RegExp, or a $/.../ literal, and BigInt, or a 123n, as if the program
// began with #import <M>, unless a type of its own has that name, which a
// literal's is then an error; and each #import <M> of one, UnicodeData's
// too, which RegExp.kh imports (#515)
let load_prelude(mods:String^):bool {
    var ucd:String = mods^.copy()                        // UnicodeData, in every program, as kelvinc's (#520)
    ucd += "/UnicodeData.kh"
    if !read_already(&ucd) {
        if !loads(&ucd) { return false }
        var u = $"UnicodeData"
        note_module(&u, fnames.count as int64 - 1)
    }
    if !load_module_imports(mods) { return false }       // each #import <M> first, as kelvinc's with_imports: a module
                                                         // may name BigInt, as Rational's bigrat does (#542)
    let first:int64 = toks.count as int64
    for k in 0..<2 {
        let w:cstr := k == 0 ? "RegExp" : "BigInt"
        if !names_word(w) { continue }
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
        if own_type(w) {
            if k == 0 {
                for t in rx_lits {
                    lex_error(toks[t].file, toks[t].line, "a $/.../ literal is the prelude's RegExp, which a type of this program named RegExp hides: rename that type (#504)")
                }
            } else {
                for t in big_lits {
                    lex_error(toks[t].file, toks[t].line, "a 123n literal is the prelude's BigInt, which a type of this program named BigInt hides: rename that type (#508)")
                }
            }
            continue
        }
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
        println("usage: kc [-c | --emit-c] file.k [-o path] [-m modules] [-cc compiler]")
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
