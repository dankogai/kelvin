// IO.exec(args, mode, dir, env) (#92): the program's working directory,
// "" for the current, and its environment, "NAME=value" entries added
// to the parent's, a list or an Array of cstr or of String; a directory
// that cannot be entered is an err, as a missing program is
#import <errno.h> as C
let main():i32 {
    var p = IO.exec(["pwd"], "r", "/")
    if let ok(f) = p { for line in f.lines { println(line) } }
    var e = IO.exec(["sh", "-c", "echo $KELVIN_A-$KELVIN_B"], "r", "", ["KELVIN_A=hello", "KELVIN_B=world"])
    if let ok(f) = e { for line in f.lines { println(line) } }
    var env = $["KELVIN_A=from an Array"]
    var a = IO.exec(["sh", "-c", "echo $KELVIN_A"], "r", "", env)
    if let ok(f) = a { for line in f.lines { println(line) } }
    var senv:$[String] = $[$"KELVIN_A=from Strings"]
    var s = IO.exec(["sh", "-c", "echo $KELVIN_A"], "r", "", senv)
    if let ok(f) = s { for line in f.lines { println(line) } }
    var dir = $"/"
    var both = IO.exec(["sh", "-c", "echo $KELVIN_A $(pwd)"], "r", dir, ["KELVIN_A=in"])
    if let ok(f) = both { for line in f.lines { println(line) } }
    var bad = IO.exec(["pwd"], "r", "/no/such/dir")
    println(bad.is(err), " ", bad.err == ENOENT)
    var home = IO.exec(["sh", "-c", "test -n \"$HOME\" && echo kept"], "r", "", ["KELVIN_A=x"])
    if let ok(f) = home { for line in f.lines { println(line) } }
    return 0
}
// out: /
// out: hello-world
// out: from an Array
// out: from Strings
// out: in /
// out: true true
// out: kept
// c: kv_io_exec(&_kv_f, (const char *const[]){(const char *)("pwd"), NULL}, "r", "/", NULL, false)
// c: const char **_kv_env = kv_io_vector_strings((senv).at, (senv).count);
