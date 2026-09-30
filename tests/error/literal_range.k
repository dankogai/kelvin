// error: integer literal 256 does not fit in u8
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let b: u8 = 256;
}
