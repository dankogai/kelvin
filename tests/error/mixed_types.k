// error: operands of '+' have different types: i32 and i64
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let a: i32 = 1; let b: i64 = 2; let c = a + b;
}
