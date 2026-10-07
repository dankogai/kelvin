// error: '++' is for pointers, and this is i32: write 'x += 1'
let main():i32 {
    var i:i32 = 0;
    i++;
    return 0;
}
