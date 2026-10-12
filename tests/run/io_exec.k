// IO.exec(args, mode) (#90): a program run without the shell, args a
// list of text or an Array of cstr or of String in a variable, its
// output read or its input written; waited for when closed, with
// .status and .signal; a program not found is an err, ENOENT
#import <errno.h> as C
#import <stdio.h> as C
let path := "io_exec.tmp"
let main():i32 {
    var p = IO.exec(["printf", "one\\ntwo\\n"], "r")
    if p.is(ok) {
        for line in p.ok.lines { println("[", line, "]") }
        p.ok.close()
        println(p.ok.status, " ", p.ok.signal)
    }
    var e = IO.exec(["sh", "-c", "exit 3"], "r")
    if e.is(ok) {
        e.ok.close()
        println(e.ok.status)
    }
    var missing = IO.exec(["no-such-program-kelvin"], "r")
    println(missing.is(err), " ", missing.err == ENOENT)
    var w = IO.exec(["sh", "-c", "cat > io_exec.tmp"], "w")
    if w.is(ok) {
        w.ok.println("via exec ", 42)
        w.ok.close()
        println(w.ok.status)
    }
    var back = IO(path, "r")
    if let ok(f) = back { for line in f.lines { println(line) } }
    var args = $["printf", "%s-%s", "a", "b"]
    var a = IO.exec(args, "r")
    if let ok(f) = a {
        var s = f.string
        println(s.cstr)
    }
    var sargs:$[String] = $[$"printf", $"strings"]
    var b = IO.exec(sargs, "r")
    if let ok(f) = b {
        var s = f.string
        println(s.cstr, " ", b.typename)
    }
    var name = $"echo"
    var c = IO.exec([name, "a String argument"], "r")
    if let ok(f) = c { for line in f.lines { println(line) } }
    var k = IO.exec(["sh", "-c", "kill -9 $$"], "r")
    if k.is(ok) {
        k.ok.close()
        println(k.ok.status, " ", k.ok.signal)
    }
    remove(path)
    return 0
}
// out: [one]
// out: [two]
// out: 0 0
// out: 3
// out: true true
// out: 0
// out: via exec 42
// out: ok(a-b)
// out: ok(strings) Result<IO, i32>
// out: a String argument
// out: -1 9
// c: kv_io_exec(&_kv_f, (const char *const[]){(const char *)("printf"), (const char *)("one\\ntwo\\n"), NULL}, "r")
// c: kv_io_exec_cstrs(&_kv_f, (const uint8_t *const *)(args).at, (args).count, "r")
// c: kv_io_exec_strings(&_kv_f, (sargs).at, (sargs).count, "r")
