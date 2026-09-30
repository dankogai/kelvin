// error: 'f' takes 1 argument, but 2 were given
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    f(1, 2);
}
