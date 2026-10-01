printf(fmt: const u8^, ...): i32;

main(): i32
{
    a: u32 = 12, b: u32 = 10;
    printf("%u %u %u\n", a & b, a | b, a ~ b);   // ~ is XOR
    printf("%u\n", ~a & 0xff);                    // unary ~ is still NOT
    a ~= b;                                        // XOR-assign
    printf("%u\n", a);

    // C precedence is unchanged, quirks included: == binds tighter than &
    printf("%d\n", 6 & (3 == 3));  // what `6 & 3 == 3` means in C and Kelvin
    printf("%d\n", (6 & 3) == 2);

    i: i32 = 5;
    j: i32 = i++;
    k: i32 = ++i;
    printf("%d %d %d\n", j, k, -(-i));
    printf("%d\n", i > 3 ? 1 : 0);
    printf("%ld\n", i64(sizeof(i64)) * 0 + 1);

    x: i32 = 0;
    x = 1, x += 2;
    printf("%d\n", x);
    printf("%d %d\n", 7 / 2, 7 % 3);
    printf("%d\n", 1 << 4 >> 2);
    printf("%s\n", "adjacent " "strings");
    printf("%c%c\n", 'o', '\x6b');
    return 0;
}
// out: 8 14 6
// out: 243
// out: 6
// out: 0
// out: 1
// out: 5 7 7
// out: 1
// out: 1
// out: 3
// out: 3 1
// out: 4
// out: adjacent strings
// out: ok
