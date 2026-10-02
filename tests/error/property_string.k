// error: '.dec' is a property of integers and of f32/f64
struct point { x: i32; };
main(): i32
{
    s: String = 42.toString(); println(s.dec);
    return 0;
}
