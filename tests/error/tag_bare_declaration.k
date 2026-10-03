// error: declarations start with let or var: write 'var p:...', or 'let p:...' if it never changes
struct point { x:i32; y:i32; };
main():i32 {
    p:point = {1, 2};
    return 0;
}
