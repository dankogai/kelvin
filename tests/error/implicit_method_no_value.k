// error: this has no value, but this function has a result, of type i64
struct box { n:i64 }
box.show() { println(self.n) }
shown(b:box):i64 { b.show() }
main():i32 {
    let b:box = {1}
    println(shown(b))
    return 0
}
