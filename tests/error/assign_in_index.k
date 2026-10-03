// error: assignment is a statement in Kelvin, not a value
main():i32 {
    var a:i32[3];
    var i:i32 = 0;
    a[i += 1] = 2;
    return 0;
}
