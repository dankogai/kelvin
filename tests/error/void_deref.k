// error: cannot dereference *void
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let p: *void = null; let x = *p;
}
