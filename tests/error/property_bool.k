// error: '.bin' is a property of integers
struct point { x: i32; };
main(): i32
{
    var b: bool = true; println(b.bin);
    return 0;
}
