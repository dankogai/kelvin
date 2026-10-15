// OS and SYS (#94): the system around the program and the program
// itself, prelude namespaces with no import. OS: the working directory,
// the environment, files and directories, a shell command, the pid;
// SYS: the arguments, the platform, and exiting
#import <string.h> as C
#import <IO>
let main():i32 {
    var args = SYS.argv
    println(args.count >= 1, " ", args[0].count > 0, " ", args.typename)
    let p := SYS.platform
    println(strcmp(p, "macos") == 0 || strcmp(p, "linux") == 0 || strcmp(p, "freebsd") == 0, " ", p.typename)
    var cwd = OS.cwd
    if let ok(d) = cwd { println(d.count > 0, " ", OS.isdir(d), " ", OS.isfile(d)) }
    println(OS.pid > 0, " ", OS.pid.typename)
    let dir := "os_sys.tmpdir"
    println(OS.exists(dir), " ", OS.mkdir(dir), " ", OS.exists(dir), " ", OS.isdir(dir), " ", OS.mkdir(dir) != 0)
    var b = IO("os_sys.tmpdir/b.txt", "w")
    b.write("b")
    var a = IO("os_sys.tmpdir/a.txt", "w")
    a.write("a")
    b.close()
    a.close()
    var names = OS.listdir(dir)
    if let ok(ns) = names { for n in ns { print(n, " ") } }
    println(names.typename)
    println(OS.isfile("os_sys.tmpdir/a.txt"), " ", OS.rename("os_sys.tmpdir/a.txt", "os_sys.tmpdir/c.txt"), " ",
            OS.exists("os_sys.tmpdir/a.txt"), " ", OS.exists("os_sys.tmpdir/c.txt"))
    var path = $"os_sys.tmpdir/c.txt"
    println(OS.remove(path), " ", OS.remove("os_sys.tmpdir/b.txt"), " ", OS.remove("os_sys.tmpdir/none") != 0)
    var listed = OS.listdir(dir)
    if let ok(ns) = listed { println(ns.count) }
    let removed = OS.rmdir(dir)
    var gone = OS.listdir(dir)
    println(removed, " ", OS.exists(dir), " ", gone.is(err))
    println(OS.env("KELVIN_OS_TEST").is(none), " ", OS.setenv("KELVIN_OS_TEST", "set"))
    var v = OS.env("KELVIN_OS_TEST")
    println(v.cstr, " ", v.typename, " ", OS.unsetenv("KELVIN_OS_TEST"), " ", OS.env("KELVIN_OS_TEST").is(none))
    println(OS.system("exit 3"), " ", OS.system("true"), " ", OS.chdir("/no/such/dir") != 0)
    var here = OS.cwd
    println(OS.chdir("/"))
    var root = OS.cwd
    println(root.ok, " ", OS.chdir(here.ok))
    var back = OS.cwd
    println(back == here)
    SYS.exit(0)
    println("not reached")
    return 1
}
// out: true true Array<cstr>
// out: true cstr
// out: true true false
// out: true i32
// out: false 0 true true true
// out: a.txt b.txt Result<Array<String>, i32>
// out: true 0 false true
// out: 0 0 true
// out: 0
// out: 0 false true
// out: true 0
// out: some("set") cstr? 0 true
// out: 3 0 true
// out: 0
// out: / 0
// out: true
// c: kv_sys_init(_kv_argc, _kv_argv);
// c: _kv_array_cstr_from((const uint8_t *const *)kv_sys_argv_p(), (size_t)kv_sys_argc_n())
// c: kv_os_listdir(dir, &_kv_at, &_kv_n)
