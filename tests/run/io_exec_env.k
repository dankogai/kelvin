// IO.exec(args, mode, dir, env) (#92): the program's working directory,
// "" for the current, and its environment, "NAME=value" entries added
// to the parent's, a list or an Array of cstr or of String; a directory
// that cannot be entered leaves f.error, as a missing program does (#110)
#import <errno.h> as C
let main():i32 {
    var p = IO.exec(["pwd"], "r", "/")
    for line in p.lines { println(line) }
    var e = IO.exec(["sh", "-c", "echo $KELVIN_A-$KELVIN_B"], "r", "", ["KELVIN_A=hello", "KELVIN_B=world"])
    for line in e.lines { println(line) }
    var env = $["KELVIN_A=from an Array"]
    var a = IO.exec(["sh", "-c", "echo $KELVIN_A"], "r", "", env)
    for line in a.lines { println(line) }
    var senv:$[String] = $[$"KELVIN_A=from Strings"]
    var s = IO.exec(["sh", "-c", "echo $KELVIN_A"], "r", "", senv)
    for line in s.lines { println(line) }
    var dir = $"/"
    var both = IO.exec(["sh", "-c", "echo $KELVIN_A $(pwd)"], "r", dir, ["KELVIN_A=in"])
    for line in both.lines { println(line) }
    var bad = IO.exec(["pwd"], "r", "/no/such/dir")
    println(bad.error == ENOENT, " ", bad.fd)              // a directory not entered: f.error (#110)
    var home = IO.exec(["sh", "-c", "test -n \"$HOME\" && echo kept"], "r", "", ["KELVIN_A=x"])
    for line in home.lines { println(line) }
    return 0
}
// out: /
// out: hello-world
// out: from an Array
// out: from Strings
// out: in /
// out: true -1
// out: kept
// c: kv_io_exec((const char *const[]){(const char *)("pwd"), NULL}, "r", "/", NULL, false)
// c: const char **_kv_env = kv_io_vector_strings((senv).at, (senv).count);
