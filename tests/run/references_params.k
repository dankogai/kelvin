// an array parameter is a pointer, as in C: reassign it with :=
sum(var a: i32[4], n: i32): i32
{
    var t: i32 = 0;
    var end: i32^ := a + n;
    for (; a < end; a := a + 1)
        t += a^;
    return t;
}

main(argc: i32, var argv: u8^[]): i32
{
    argv := argv + 1;
    var xs: i32[4] = {1, 2, 3, 4};
    println(sum(xs, 4));
    return 0;
}
// out: 10
