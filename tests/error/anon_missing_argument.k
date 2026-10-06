// error: it is argument 2, whose parameter is size_t: is an argument missing?
let sort(xs:i64^, n:size_t, before:(i64, i64):bool) { }
let main():i32 {
    var xs:[i64](2) = [2, 1];
    sort(xs) { $0 < $1 }
    return 0;
}
