// f.stat is a Stat straight (#104), nothing to try
let main():i32 {
    var r = IO("io_stat_try.k")
    if let ok(f) = r {
        let s = try f.stat
        println(s.size)
    }
    return 0
}
// error: 'try' takes a Result or an Optional
