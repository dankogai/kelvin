// error: array literal has 2 elements, but [3]i32 needs 3
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let a: [3]i32 = [1, 2];
}
