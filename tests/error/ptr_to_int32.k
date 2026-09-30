// error: cannot cast *i32 to i32
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    var a = 1; let p = &a; let n = p as i32;
}
