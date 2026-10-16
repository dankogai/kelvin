// error: '.dec' is a property of integers and of f32/f64
struct point { x:i32; };
let main():i32 {
    var p:int32^; println(p.dec);
    return 0;
}
