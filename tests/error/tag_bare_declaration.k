// error: declarations start with let or var: write 'var p:...', or 'let p:...' if it never changes
struct point { x:int32; y:int32; };
let main():int32 {
    p:point = {1, 2};
    return 0;
}
