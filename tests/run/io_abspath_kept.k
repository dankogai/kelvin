// f.abspath keeps the last name it found (#195): where neither the path
// nor the descriptor answers, the IO answers by it, as of a removed file
// on FreeBSD, which names none; a closed IO forgets it, and an IO that
// never found one, a pipe's, answers ""
#import <IO>
let main():int32 {
    var f = IO("io_abspath_kept.tmp", "w")
    if f.error == 0 {
        var first = f.abspath
        println(first.count > 0, " ", first.typename)
        println(OS.remove("io_abspath_kept.tmp"), " ", f.exists)
        var kept = f.abspath
        println(kept == first)                       // the name it had, on every system
        f.close()
        var closed = f.abspath
        println(closed.count)                        // a closed IO forgets it
    }
    var ends = IO.pipe()
    if ends.reader.error == 0 {
        var none = ends.reader.abspath
        println(none.count)
    }
    return 0
}
// out: true String
// out: 0 false
// out: true
// out: 0
// out: 0
