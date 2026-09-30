// trap: float to integer conversion out of range
struct P { x: i32 }
fn id(x: i32) -> i32 { return x; }
fn id64(x: i64) -> i64 { return x; }
fn noreturn(x: i32) -> i32 { if x == 0 { return 1; } }
fn main() {
    let z = 0.0; let f = z / z; let y = f as i32;
}
