// error: '$0' cannot be used in the parameters or result of the function it names
let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let main():i32 {
    println(apply(2) { apply($0) { (b:i64[$0]):i64 in 1 } });
    return 0;
}
