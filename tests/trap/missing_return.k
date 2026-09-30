// trap: reached end of function without returning a value
struct P { x: i32 }
fn id(x: i32) -> i32 { return x; }
fn id64(x: i64) -> i64 { return x; }
fn noreturn(x: i32) -> i32 { if x == 0 { return 1; } }
fn main() {
    let y = noreturn(id(1));
}
