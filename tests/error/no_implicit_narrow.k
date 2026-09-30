// error: initializer of 'b': expected u8, found i32
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let a = 300; let b: u8 = a;
}
