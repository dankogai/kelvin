extern fn printf(fmt: *u8, ...) -> i32;

fn main() -> i32 {
    let a: i8 = -128;
    let b: u64 = 18446744073709551615;
    let c = -2147483648;
    printf("%d %llu %d\n", a, b, c);
    printf("%d %d\n", 7 / 2, -7 % 3);
    printf("%d\n", 1 + 2 * 3 << 1);
    printf("%d\n", 6 & 3 == 2);
    let x: u8 = 200;
    printf("%d %d %d\n", x +% 100, 0 -% x, x *% 2);
    let y: i32 = 2147483647;
    printf("%d\n", y +% 1);
    printf("%d\n", ~0 as u8 as i32);
    printf("%.2f\n", 1.5 * 3.0);
    printf("%d\n", 3.99 as i32);
    printf("%d\n", -3.99 as i32);
    printf("%d\n", true as i32);
    var z = 10;
    z += 5;
    z *= 2;
    z -= 1;
    z /= 3;
    z <<= 2;
    z %= 7;
    printf("%d\n", z);
    return 0;
}
// out: -128 18446744073709551615 -2147483648
// out: 3 -1
// out: 14
// out: 1
// out: 44 56 144
// out: -2147483648
// out: 255
// out: 4.50
// out: 3
// out: -3
// out: 1
// out: 1
