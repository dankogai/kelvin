// IO.exec(args, mode, dir, env, fresh) (#93): true for an environment
// made from nothing but the entries, the program then found on that
// environment's PATH or the system's default; false, or absent, for the
// entries added to this program's
#import <IO>
let main():int32 {
    var only = IO.exec(["env"], "r", "", ["KELVIN_ONLY=1"], true)
    for line in only.lines { println("[", line, "]") }
    var none = IO.exec(["env"], "r", "", [], true)
    var n:int64 = 0
    for _ in none.lines { n += 1 }
    println(n)
    var env = $["KELVIN_A=a", "KELVIN_B=b"]
    var two = IO.exec(["env"], "r", "", env, true)
    for line in two.lines { println(line) }
    let keep = false
    var added = IO.exec(["sh", "-c", "test -n \"$HOME\" && echo kept $KELVIN_C"], "r", "", ["KELVIN_C=c"], keep)
    for line in added.lines { println(line) }
    var withPath = IO.exec(["/bin/sh", "-c", "echo $PATH"], "r", "", ["PATH=/kelvin/bin"], true)   // sh by its path: the PATH is the new one
    for line in withPath.lines { println(line) }
    return 0
}
// out: [KELVIN_ONLY=1]
// out: 0
// out: KELVIN_A=a
// out: KELVIN_B=b
// out: kept c
// out: /kelvin/bin
// c: kv_io_exec((const char *const[]){(const char *)("env"), NULL}, "r", "", (const char *const[]){(const char *)("KELVIN_ONLY=1"), NULL}, (bool)true)
