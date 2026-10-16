// map of a place that owns would move its value out (#80)
let twice(n:int64):i64 { return n * 2 }
let parse(s:cstr):Result<i64, String> { return i64(s) }
let main():i32 {
    var r = parse("1")
    var m = r.map(twice)
    return 0
}
// error: '.map' would move the ok out of 'r', which keeps it: map the call itself, or 'r.copy()'
