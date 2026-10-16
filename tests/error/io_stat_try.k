// f.stat is a Stat straight (#104), nothing to try
#import <IO>
let main():int32 {
    let f = IO("io_stat_try.k")
    let s = try f.stat
    println(s.size)
    return 0
}
// error: 'try' takes a Result or an Optional
