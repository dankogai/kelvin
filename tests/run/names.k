// Kelvin names that collide with C keywords and libc macros still work.
extern fn printf(fmt: *u8, ...) -> i32;

struct int { long: i32, char: u8 }

var static: i32 = 5;

fn register(errno: i32) -> i32 {
    let size_t = errno + static;
    return size_t;
}

fn main() {
    let x = 1;
    let x = x + 1;
    let auto = int { long: register(x), char: 'z' };
    printf("%d %c\n", auto.long, auto.char);
}
// out: 7 z
