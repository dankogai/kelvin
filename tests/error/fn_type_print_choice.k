// error: println cannot show a function: a function has no text
add1(x:i64):i64 { return x + 1; }
mul2(x:i64):i64 { return x * 2; }
main():i32 {
    let c = true;
    println(c ? add1 : mul2);
    return 0;
}
