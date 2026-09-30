// A quick tour of Kelvin: C's step size, on an absolute scale.

extern fn printf(fmt: *u8, ...) -> i32;
extern fn malloc(size: usize) -> *void;
extern fn free(p: *void);

// Declarations read left to right, and order doesn't matter:
// `main` can call `sum` even though `sum` is defined further down.
struct Point {
    x: i32,
    y: i32,
}

fn main() -> i32 {
    let p = Point { x: 3, y: 4 };
    printf("p = (%d, %d), dist2 = %d\n", p.x, p.y, dist2(p));

    // Arrays are values, and they know their length.
    var a = [5, 3, 8, 1, 9, 2];
    sort(a[..]);
    printf("sorted:");
    for i in 0..a.len {
        printf(" %d", a[i]);
    }
    printf("\n");
    printf("sum of middle = %d\n", sum(a[1..5]));

    // Bitwise ops bind tighter than comparisons, unlike C.
    if a[0] & 1 == 1 {
        printf("smallest is odd\n");
    }

    // defer runs at scope exit, in reverse order.
    let buf = malloc(16 * sizeof(i32)) as *i32;
    defer free(buf);
    let s = buf[0..16];
    for i in 0..s.len {
        s[i] = (i * i) as i32;
    }
    printf("s[15] = %d\n", s[15]);

    // Wrapping is explicit; plain + traps on overflow instead of being UB.
    let big: u8 = 250;
    printf("250 +%% 10 = %d\n", big +% 10);
    return 0;
}

fn dist2(p: Point) -> i32 {
    return p.x * p.x + p.y * p.y;
}

fn sum(xs: []i32) -> i32 {
    var total = 0;
    for i in 0..xs.len {
        total += xs[i];
    }
    return total;
}

fn sort(xs: []i32) {
    for i in 1..xs.len {
        var j = i;
        while j > 0 && xs[j - 1] > xs[j] {
            let t = xs[j];
            xs[j] = xs[j - 1];
            xs[j - 1] = t;
            j -= 1;
        }
    }
}
