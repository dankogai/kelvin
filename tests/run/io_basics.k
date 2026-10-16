// IO (#82): stdio as an owner. IO(path, mode) is the IO, straight, with
// f.error the errno when it did not open (#109); f.bytes and f.string the rest of the file, straight (#107: a
// Bytes, a String; text that is not UTF-8 ends the program, so ask
// b.isUTF8 of the bytes first); for x in f.read(n) and for line in f.lines walk
// it; f.write takes text, a borrow or an owner an expression gives;
// IO.stdin, IO.stdout and IO.stderr are never closed; a file closes
// when its block ends, or by .close() through the var that owns it
#import <errno.h> as C
#import <stdio.h> as C
#import <IO>
let path := "io_basics.tmp"
let write_it():Result<int64, int32> {
    let f = IO(path, "w")
    f.write("héllo\n")
    var s = $"wörld"
    f.write(&s)
    f.write("\n")
    f.write($"made\n")                 // an owner an expression gives, written and freed
    var b = Bytes("bytes")
    f.write(&b)
    f.write("\n")
    f.flush()
    return 3                            // f closes here
}
let read_all():Result<int64, int32> {
    let f = IO(path, "r")
    if f.error != 0 { return err(f.error) }   // the errno, passed up by hand (#109)
    let b = f.bytes                     // a Bytes straight (#107)
    return b.count as int64
}
let read_text():Result<String, int32> {
    var p = $"io_basics"
    p += ".tmp"
    let f = IO(p, "r")                  // a String path
    return f.string                     // a String, wrapped as ok
}
let bad_text():Result<bool, int32> {
    var w = IO("io_bad.tmp", "w")
    var b = Bytes("x")
    b += 255
    w.write(&b)
    w.close()
    let f = IO("io_bad.tmp", "r")
    let raw = f.bytes                   // .string of this would end the program
    return raw.isUTF8
}
struct holder { name: String; f: IO }
let main():int32 {
    var w = write_it()
    println(w.cstr)
    var n = read_all()
    println(n.cstr)
    var t = read_text()
    if let ok(s) = t { print(s) }
    var f1 = IO(path, "r")
    var k:int64 = 0
    if f1.error == 0 {
        for line in f1.lines {
            k += 1
            println(k, ": ", line, " ", line.count)
        }
    }
    var f2 = IO(path, "r")
    for chunk in f2.read(7) { print("[", chunk.count, "]") }
    println()
    var missing = IO("/no/such/dir/x", "r")
    println(missing.error == ENOENT, " ", missing.fd, " ", missing.path)   // an IO that did not open (#109)
    var bad = bad_text()
    println(bad.is(ok), " ", bad.ok)
    var e = IO.stderr
    e.write("to stderr\n")
    IO.stdout.write("to stdout\n")
    IO.stdout.flush()
    var out = IO.stdout
    out.write("via a variable\n")
    var h:holder = {$"held", IO.stdout}
    h.f.write("through a member\n")
    println(h.cstr)
    var f3 = IO(path, "r")
    f3.close()                          // closed by hand, through the var that owns it; its block does nothing more
    remove(path)
    remove("io_bad.tmp")
    return 0
}
// out: ok(3)
// out: ok(25)
// out: héllo
// out: wörld
// out: made
// out: bytes
// out: 1: héllo 5
// out: 2: wörld 5
// out: 3: made 4
// out: 4: bytes 5
// out: [7][7][7][4]
// out: true -1 /no/such/dir/x
// out: true false
// out: to stdout
// out: via a variable
// out: through a member
// out: {name: "held", f: <IO>}
// c: __attribute__((cleanup(kv_io_free))) kv_io f =
// c: while (kv_io_read_line(
// c: kv_io_write_owned_string((kv_io *)&f, KV_STRING_OF("made\n"));
