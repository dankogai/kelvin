// f.println and f.print of .pretty to a file (#124): the value's printer
// writes to the IO's own stream, so the file holds the indented text, as
// println shows it, and whole values on one line beside it (#123)
struct point { x: i64; y: i64 }
let main():i32 {
    var d = ${"a": $[1, 2]}
    let p:point = {1, 2}
    var f = IO("io_pretty.tmp", "w")
    f.println("d = ", d.pretty)
    f.print(p.pretty)
    f.println()
    f.println(d, " ", p)
    f.close()
    var r = IO("io_pretty.tmp")
    var all = r.string
    print(all)
    var lines = 0
    var back = IO("io_pretty.tmp")
    for line in back.lines { lines += 1 }
    println(lines, " ", OS.remove("io_pretty.tmp"))
    return 0
}
// out: d = {
// out:   "a": [
// out:     1,
// out:     2
// out:   ]
// out: }
// out: {
// out:   x: 1,
// out:   y: 2
// out: }
// out: {"a": [1, 2]} {x: 1, y: 2}
// out: 11 0
// c: _kv_show__kv_dict_String_Array_i64(&(kv_out){.fp = kv_io_fp((kv_io *)&f), .width = 2}, &_kv_sv, 0)
