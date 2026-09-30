// error: integer literal -1 does not fit in u32
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let b: u32 = -1;
}
