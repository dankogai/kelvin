// error: expected ';' or a new line after the trailing function, before what follows
each(n:i64, f:(i64)) { for i in 0..<n { f(i); } }
var total:i64 = 0;
main():i32 {
    each(2) { total += $0 } each(2) { total += $0 * 10 }
    return 0;
}
