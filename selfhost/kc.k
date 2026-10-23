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
// headers, `#import <x.h> as C`, are C's, as libc is (#207).
#import <IO>
#import <stdio.h> as C            // remove
#import <stdlib.h> as C           // getenv
#import <unistd.h> as C           // getpid
#import "lex.k"
#import "parse.k"
#import "gen.k"

// the directory of a path, with its /, or ""
let dir_of(path:String^):String {
    var cut = 0
    var i = 0
    for c in path^ {
        i += 1
        if c.utf32 == '/' { cut = i }
    }
    var r = $""
    var j = 0
    for c in path^ {
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
    for c in path^ {
        if j >= dir.count as int64 { cs += c.utf32 }
        j += 1
    }
    var n = cs.count as int64
    if n > 2 && cs[n - 2] == '.' && cs[n - 1] == 'k' { n -= 2 }
    var r = $""
    for k in 0..<n {
        r += cs[k].uchr
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
// stdio before IO's .string, which would end kc in words of its own
let source_error(path:String^):String {
    let fp:FILE^ := fopen(path^.cstr, "rb")
    if fp == nullptr { return $"" }
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
    var text:String = f.string
    let file:int64 = fnames.count as int64
    fnames += path^.copy()
    let from:int64 = codes.count as int64
    for c in text {
        codes += c.utf32
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
                path += codes[at + j].uchr
            }
            var seen = false
            for k in 0..<fnames.count as int64 {
                if fnames[k] == path { seen = true }
            }
            if !seen && !loads(&path) { return false }
        }
        i += 1
    }
    return true
}

// the environment's value of name, else otherwise
let env_or(name:cstr, otherwise:cstr):String {
    let v:cstr := getenv(name)
    if v != nullptr { return String(v) }
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
        if home != nullptr {
            mods = String(home)
            mods += "/modules"
        } else {
            mods = $"modules"
        }
    }
    if !loads(&input) { return 1 }
    if !load_imports() { return 1 }
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
    g.write(&out)
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
    var p:IO = IO.exec(args, "r")
    p.close()
    if temporary { remove(cfile.cstr) }
    if p.status != 0 {
        println("kc: cc failed on ", cfile)
        return 1
    }
    return 0
}
