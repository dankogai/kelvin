// error: '.oct' is a property of integers; f32 and f64 have .dec and .hex
struct point { x:i32; };
let main():i32 {
    var f:f64 = 1.5; println(f.oct);
    return 0;
}
