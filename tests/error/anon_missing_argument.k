// error: it is argument 2, whose parameter is size_t: is an argument missing?
let sort(xs:int64^, n:size_t, before:(int64, int64):bool) { }
let main():int32 {
    var xs:[int64](2) = [2, 1];
    sort(xs) { $0 < $1 }
    return 0;
}
