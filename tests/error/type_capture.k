// error: an anonymous function cannot use 'kk' of the function around it
apply(x:i64, f:(i64):i64):i64 { return f(x); }
main():i32 {
    let kk = 1;
    println(apply(1) {
        var x:kk.type = $0;
        return x;
    });
    return 0;
}
