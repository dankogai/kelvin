// error: struct Node contains itself by value
struct Node { value: i32, next: Node }
fn main() {}
