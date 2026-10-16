// error: '.oct' is a property of integers; f32 and f64 have .dec and .hex
struct point { x:int32; };
let main():int32 {
    var f:float64 = 1.5; println(f.oct);
    return 0;
}
