// error: Kelvin has no '--': write 'x -= 1' as a statement, or 'p := p.prev' for a pointer
let main():i32 {
    var a:i32[2] = [1, 2];
    var p:i32^ := &a[1];
    println(p--^);
    return 0;
}
