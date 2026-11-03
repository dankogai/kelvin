// for line in IO(path).lines and for b in IO(path).read(n) (#466): an IO
// an expression gives, held in a hidden let of a block around the loop,
// closed when the loop is done, a break too, as a variable's would be
#import <IO>
let path := "io_walk_held.tmp"
let lines_of(p:cstr):int64 {
    var n = 0
    for line in IO(p).lines { n += line.ok.count as int64 }
    return n
}
let main():int32 {
    var w = IO(path, "w")
    w.print("one\ntwo\nthree\n")
    w.close()
    for line in IO(path).lines { print(line.ok, " ") }
    println()
    for b in IO(path).read(5) { print("[", b.count, "]") }
    println()
    for line in IO(path, "r").lines {
        println(line.ok)
        break
    }
    println(lines_of(path), " ", OS.remove(path))
    return 0
}
// out: one two three 
// out: [5][5][4]
// out: one
// out: 11 0
