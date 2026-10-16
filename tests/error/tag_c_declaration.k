// error: declarations are written 'var name:type', as in 'var x:point'
struct point { x:int32; };
let main():i32 {
    point^ p;
    return 0;
}
