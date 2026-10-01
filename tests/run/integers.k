printf(fmt: const u8^, ...): i32;

answer = 42;                // inferred: i64

main(): i32
{
    i = -1;                 // inferred: i64
    big = 0x7fffffffffffffff;
    printf("%d %d %d %d\n", i32(sizeof(i8)), i32(sizeof(i16)), i32(sizeof(i32)), i32(sizeof(i64)));
    printf("%d %d\n", i32(sizeof answer), i32(sizeof i));
    printf("%d\n", big > 0);

    b: u8 = 255;
    b = b + 1;                  // C semantics: converts back to u8, wraps
    printf("%d\n", b);

    w: u128 = 1;
    w = w << 100;
    printf("%d %d\n", i32(sizeof(u128)), i32(w >> 99));

    s: u8^ = "bytes";       // string literals are u8 arrays in Kelvin
    printf("%s %c\n", s, s[1]);
    return 0;
}
// out: 1 2 4 8
// out: 8 8
// out: 1
// out: 0
// out: 16 2
// out: bytes y
