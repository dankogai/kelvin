// error: operator '%' needs integers, found f64
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let a = 1.5 % 2.0;
}
