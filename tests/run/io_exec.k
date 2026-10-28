// IO.exec(args, mode) (#90): a program run without the shell, args a
// list of text or an Array of cstr or of String in a variable, its
// output read or its input written; waited for when closed, with
// .status and .signal; a program not found leaves f.error ENOENT (#110)
#import <errno.h> as C
#import <stdio.h> as C
#import <IO>
let path := "io_exec.tmp"
let main():int32 {
    var p = IO.exec(["printf", "one\\ntwo\\n"], "r")
    if p.error == 0 {
        for line in p.lines { println("[", line.ok, "]") }
        p.close()
        println(p.status, " ", p.signal)
    }
    var e = IO.exec(["sh", "-c", "exit 3"], "r")
    if e.error == 0 {
        e.close()
        println(e.status)
    }
    var missing = IO.exec(["no-such-program-kelvin"], "r")
    println(missing.error == ENOENT, " ", missing.fd, " ", missing.pid)
    var w = IO.exec(["sh", "-c", "cat > io_exec.tmp"], "w")
    if w.error == 0 {
        w.println("via exec ", 42)
        w.close()
        println(w.status)
    }
    var back = IO(path, "r")
    for line in back.lines { println(line.ok) }
    var args = $["printf", "%s-%s", "a", "b"]
    var a = IO.exec(args, "r")
    var s = a.string ?? $"?"                     // a Result, err where the UTF-8 breaks (#406)
    println(s)
    var sargs:$[String] = $[$"printf", $"strings"]
    var b = IO.exec(sargs, "r")
    var t = b.string ?? $"?"
    println(t, " ", b.typename)
    var name = $"echo"
    var c = IO.exec([name, "a String argument"], "r")
    for line in c.lines { println(line.ok) }
    var k = IO.exec(["sh", "-c", "kill -9 $$"], "r")
    if k.error == 0 {
        k.close()
        println(k.status, " ", k.signal)
    }
    remove(path)
    return 0
}
// out: [one]
// out: [two]
// out: 0 0
// out: 3
// out: true -1 -1
// out: 0
// out: via exec 42
// out: a-b
// out: strings IO
// out: a String argument
// out: -1 9
// c: kv_io_exec((const char *const[]){(const char *)("printf"), (const char *)("one\\ntwo\\n"), NULL}, "r", NULL, NULL, false)
// c: kv_io_exec_cstrs((const uint8_t *const *)(args).at, (args).count, "r", NULL, NULL, false)
// c: kv_io_exec_strings((sargs).at, (sargs).count, "r", NULL, NULL, false)
