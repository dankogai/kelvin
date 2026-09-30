// error: comparison operators cannot be chained
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let a = 1 < 2 < 3;
}
