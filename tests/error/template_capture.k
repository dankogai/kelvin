// error: an anonymous function cannot use 'n' of the function around it
each(k:i64, f:(i64)) { f(k) }
main():i32 {
    let n:i64 = 5
    each(1) { println(`${$0 + n}`) }
    return 0
}
