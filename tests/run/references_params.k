// an array parameter is a pointer, as in C: reassign it with :=
let sum(var a:[int32](4), n:int32):int32 {
    var t:int32 = 0;
    var end:int32^ := a + n;
    for (; a < end; a := a + 1)
        t += a^;
    return t;
}

let main(argc:int32, var argv:[uint8^]):int32 {
    argv := argv + 1;
    var xs:[int32](4) = [1, 2, 3, 4];
    println(sum(xs, 4));
    return 0;
}
// out: 10
