// error: identifiers beginning with 'kv_' are reserved
extern fn printf(fmt: *u8, ...) -> i32;
struct P { x: i32 }
fn f(a: i32) -> i32 { return a; }
fn main() {
    let kv_x = 1;
}
