printf(fmt: const u8^, ...): i32;

struct sample {
    ok: bool;
    x: f32;
    y: f64;
};

is_even(n: i64): bool
{
    return n % 2 == 0;
}

main(): i32
{
    var s: struct sample = {true, 1.5, 2.25};
    var done: bool = false;
    printf("%d %d %d\n", i32(sizeof(f32)), i32(sizeof(f64)), i32(sizeof(bool)));
    printf("%.2f %.2f\n", s.x * 2, s.y / 3);
    printf("%d %d %d\n", s.ok, done, is_even(10) && !is_even(7));
    var third: f64 = 1.0 / 3;
    printf("%.4f\n", f32(third));
    return 0;
}
// out: 4 8 1
// out: 3.00 0.75
// out: 1 0 1
// out: 0.3333
