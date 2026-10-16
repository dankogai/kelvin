// map of a place that owns would move its value out (#80)
let twice(n:int64):int64 { return n * 2 }
let parse(s:cstr):Result<int64, String> { return int64(s) }
let main():int32 {
    var r = parse("1")
    var m = r.map(twice)
    return 0
}
// error: '.map' would move the ok out of 'r', which keeps it: map the call itself, or 'r.copy()'
