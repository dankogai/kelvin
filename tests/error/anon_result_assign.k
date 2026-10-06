// error: an assignment has no value (#26), but this function has a result
let apply(x:i64, f:(i64):i64):i64 { return f(x); }
var total:i64 = 0;
let main():i32 {
    println(apply(1) { total += $0 });
    return 0;
}
