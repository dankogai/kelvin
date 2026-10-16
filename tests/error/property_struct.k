// error: '.hex' is a property of integers, of f32/f64, and of pointers and functions
struct point { x:int32; };
let main():int32 {
    var p:struct point = {1}; println(p.hex);
    return 0;
}
