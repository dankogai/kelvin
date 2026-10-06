// error: this has no value, but this function has a result, of type i64
struct box { n:i64 }
let box.show() { println(self.n) }
let shown(b:box):i64 { b.show() }
let main():i32 {
    let b:box = {1}
    println(shown(b))
    return 0
}
