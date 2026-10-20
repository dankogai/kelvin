// kc.k - a Kelvin compiler written in Kelvin, the proof of concept of
// selfhost/README.md. It reads the subset of Kelvin it is written in,
// writes C as kelvinc does, for the same runtime, and hands it to cc:
//   kc file.k -o program [-c file.c] [-m modules] [-cc compiler]
// -c keeps the C there, which is how the stages are compared; without
// it the C is a temporary file, in $TMPDIR, removed once cc is done. -m
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

// what reading a file gives: its place among the files, or why not (#215)
enum loaded { read: int64; unread: String }

// reads a file into codes and its tokens into toks
let load(path:String^):loaded {
    var f:IO = IO(path^.cstr, "r")
    if f.error != 0 {
        var why = $"kc: cannot read "
        why += path
        return loaded.unread(why)
    }
    var text:String = f.string
    let file:int64 = fnames.count as int64
    fnames += path^.copy()
    let from:int64 = codes.count as int64
    for c in text {
        codes += c.utf32
    }
    codes += '\n'
    lex_range(from, codes.count as int64, file)
    return loaded.read(file)
}

// whether path is read; where it is not, why is said
let loads(path:String^):bool {
    var got = load(path)
    if got.is(unread) {
        println(got.unread)
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
    var mods = $""
    var compiler:String = env_or("CC", "cc")
    var i = 1
    while i < argc as int64 {
        var a:String = String(argv[i])
        if a == $"-o" && i + 1 < argc as int64 {
            output = String(argv[i + 1])
            i += 1
        } else if a == $"-c" && i + 1 < argc as int64 {
            cfile = String(argv[i + 1])
            i += 1
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
        println("usage: kc file.k -o program [-c file.c] [-m modules] [-cc compiler]")
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
    if failed { return 1 }
    parse_program()
    if failed { return 1 }
    gen_program()
    if failed { return 1 }
    var temporary = false
    if cfile.count == 0 {
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
    if output.count == 0 { return 0 }
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
    cc_arg(&args, "-o")
    args += output.copy()
    args += cfile.copy()
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
