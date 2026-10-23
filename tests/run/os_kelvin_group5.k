// OS's paths, written in Kelvin in runtime/os.k (#306), as Python's
// os.path has them: basename, dirname, splitext, normpath and isabs of
// awkward paths, join, relpath, expanduser, realpath and readlink, what
// differs from machine to machine compared
#import <IO>
#import <errno.h> as C
let main():int32 {
    for p in $["a/b/c.txt", "a/b/", "/", "/a", "a", "", "//a//b", ".hidden", "a.b.c", "a..b", "a/b.c/d", "...", "a/..", "x."] {
        println("[", OS.basename(p), "|", OS.dirname(p), "|", OS.splitext(p).ok.root, "|", OS.splitext(p).ok.ext, "|", OS.normpath(p), "|", OS.isabs(p), "]")
    }
    println(OS.join("a", "b"), " ", OS.join("a/", "b"), " ", OS.join("", "b"), " ", OS.join("a", "/b"), " ", OS.join("/", "b"), " ", OS.join("a", ""))
    for n in $["a//b/./c/../d", "../../x", "/../x", "/a/../../b", "./", "a/b/../../..", "x/./y/"] {
        print(OS.normpath(n), " ")
    }
    println()
    println(OS.relpath("/a/b/c", "/a/d"), " ", OS.relpath("/a/b", "/a/b"), " ", OS.relpath("/x/y", "/a/b"), " ", OS.relpath("/a", "/a/b/c"), " ", OS.relpath("/", "/a"))
    println(OS.expanduser("plain"), " ", OS.expanduser("~/x").ends("/x"), " ", OS.expanduser("~no_such_user_q/x"), " ", OS.expanduser("x/~"))
    println(OS.mkdir("os_g5.dir"), " ", OS.symlink("os_g5.dir", "os_g5.lnk"))
    println(OS.realpath("os_g5.lnk").ok.ends("/os_g5.dir"), " ", OS.realpath("os_g5.none").err == ENOENT, " ", OS.readlink("os_g5.lnk"), " ", OS.readlink("os_g5.dir").err == EINVAL, " ", OS.readlink("os_g5.none").err == ENOENT)
    println(OS.remove("os_g5.lnk"), OS.rmdir("os_g5.dir"))
    return 0
}
// out: [c.txt|a/b|a/b/c|.txt|a/b/c.txt|false]
// out: [|a/b|a/b/||a/b|false]
// out: [|/|/||/|true]
// out: [a|/|/a||/a|true]
// out: [a||a||a|false]
// out: [||||.|false]
// out: [b|//a|//a//b||/a/b|true]
// out: [.hidden||.hidden||.hidden|false]
// out: [a.b.c||a.b|.c|a.b.c|false]
// out: [a..b||a|..b|a..b|false]
// out: [d|a/b.c|a/b.c/d||a/b.c/d|false]
// out: [...||...||...|false]
// out: [..|a|a/..||.|false]
// out: [x.||x|.|x.|false]
// out: a/b a/b b /b /b a/
// out: a/b/d ../../x /x /b . .. x/y 
// out: ../b/c . ../../x/y ../.. ..
// out: plain true ~no_such_user_q/x x/~
// out: 0 0
// out: true true ok("os_g5.dir") true true
// out: 00
