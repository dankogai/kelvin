// error: '.oct' is a property of integers; f32 and f64 have .dec and .hex
struct point { x: i32; };
main(): i32
{
    f: f64 = 1.5; println(f.oct);
    return 0;
}
