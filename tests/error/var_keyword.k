// error: declarations start with let or var: write 'var x:...', or 'let x:...' if it never changes
// C-era Kelvin's declaration without let or var (#27)
f(c:bool):i32 {
    x:i32 = 0;
    return 0;
}
