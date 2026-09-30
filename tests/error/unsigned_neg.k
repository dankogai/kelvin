// error: unary '-' needs a signed number
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let a: u32 = 1; let b = -a;
}
