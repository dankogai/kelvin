// an open file's operations straight (#108): chmod, chown, truncate,
// utime, touch, remove and rename give a bool, true when done, no errno;
// through the descriptor where the system can, so they work on a file
// renamed or removed behind the IO; remove and rename by the path while
// it is there, else by the descriptor's name; false where nothing can be
// done, as of a pipe
let main():i32 {
    var w = IO("io_ops.tmp", "w")
    if w.error == 0 {
        w.write("hello")
        w.flush()
        println(w.chmod(384), " ", w.stat.mode & 511, " ", w.chown(OS.uid, -1), " ", w.truncate(2), " ", w.stat.size)
        println(OS.rename("io_ops.tmp", "io_ops.moved"), " ", w.exists)        // the path is stale
        println(w.utime(1000000000.0, 1000000000.0), " ", w.stat.mtime)    // through the descriptor
        println(w.touch(), " ", w.stat.mtime > 1000000000.0)
        println(w.rename("io_ops.back"), " ", w.path, " ", OS.exists("io_ops.back"))   // by the descriptor's name
        println(w.remove(), " ", w.exists, " ", w.stat.size)             // removed, yet open
        println(w.remove(), " ", w.truncate(0), " ", w.stat.size)        // nothing to remove; the open file still truncates
        println(w.chmod(384).typename)
    }
    var ends = IO.pipe()
    if ends.is(ok) { println(ends.ok.reader.remove(), " ", ends.ok.reader.rename("io_ops.x")) }   // nothing names a pipe
    return 0
}
// out: true 384 true true 2
// out: 0 false
// out: true 1000000000.0
// out: true true
// out: true io_ops.back true
// out: true false 2
// out: false true 0
// out: bool
// out: false false
// c: kv_io_utime((kv_io *)&w, 1000000000.0, 1000000000.0)
