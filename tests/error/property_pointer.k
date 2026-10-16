// error: '.dec' is a property of integers and of f32/f64
struct point { x:int32; };
let main():int32 {
    var p:int32^; println(p.dec);
    return 0;
}
