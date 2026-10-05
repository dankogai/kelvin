// where the overloads differ in a function parameter's types, an anonymous
// function writes them (#41)
apply(f:(i64):i64, n:i64):i64 { f(n) }
apply(f:(f64):f64, x:f64):f64 { f(x) }
main():i32 {
    println(apply({ $0 * 2 }, 3))
    return 0
}
// error: kelvinc cannot see this anonymous function's parameters
