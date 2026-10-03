// error: declarations are written 'var name:type', as in 'var x:point'
struct point { x:i32; };
main():i32 {
    point^ p;
    return 0;
}
