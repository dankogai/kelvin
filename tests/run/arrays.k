extern fn printf(fmt: *u8, ...) -> i32;

// arrays are values: passed, returned and assigned by copy
fn doubled(a: [4]i32) -> [4]i32 {
    var r = a;
    for i in 0..r.len {
        r[i] *= 2;
    }
    return r;
}

fn total(s: []i32) -> i64 {
    var t: i64 = 0;
    for i in 0..s.len {
        t += s[i] as i64;
    }
    return t;
}

fn main() {
    let a = [1, 2, 3, 4];
    var b = doubled(a);
    printf("%d %d\n", a[3], b[3]);
    printf("%lld %lld\n", total(b[..]), total(b[1..3]));
    let tail = b[2..];
    printf("%d %d\n", tail.len as i32, tail[0]);
    tail[0] = 100;
    printf("%d\n", b[2]);
    let empty = tail[2..2];
    printf("%d\n", empty.len as i32);
    var grid: [2][3]u8;
    grid[1][2] = 7;
    printf("%d %d\n", grid[1][2], grid[0][0]);
    var p = &b;
    printf("%d\n", (*p)[0]);
    var bytes: [3]u8 = ['a', 'b', 0];
    printf("%s\n", bytes[..].ptr);
}
// out: 4 8
// out: 20 10
// out: 2 6
// out: 100
// out: 0
// out: 7 0
// out: 2
// out: ab
