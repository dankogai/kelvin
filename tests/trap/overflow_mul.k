// trap: integer overflow in *
struct P { x: i32 }
fn id(x: i32) -> i32 { return x; }
fn id64(x: i64) -> i64 { return x; }
fn noreturn(x: i32) -> i32 { if x == 0 { return 1; } }
fn main() {
    let x: i64 = 4611686018427387904; let y = x * id64(2);
}
