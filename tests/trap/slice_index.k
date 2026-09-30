// trap: index 2 out of bounds for length 2
struct P { x: i32 }
fn id(x: i32) -> i32 { return x; }
fn id64(x: i64) -> i64 { return x; }
fn noreturn(x: i32) -> i32 { if x == 0 { return 1; } }
fn main() {
    var a = [1, 2, 3, 4]; let s = a[1..3]; let y = s[id(2)];
}
