// error: '.hex' is a property of integers and of f32/f64
struct point { x: i32; };
main(): i32
{
    p: struct point = {1}; println(p.hex);
    return 0;
}
