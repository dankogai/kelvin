// trap: index -1 out of bounds for length 4
struct P { x: i32 }
fn id(x: i32) -> i32 { return x; }
fn id64(x: i64) -> i64 { return x; }
fn noreturn(x: i32) -> i32 { if x == 0 { return 1; } }
fn main() {
    let a = [1, 2, 3, 4]; let y = a[id(-1)];
}
