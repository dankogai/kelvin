// error: a trailing function starts on the line of the call's ')': on the next line, '{' starts a block
struct box { n:i64 }
let box.each(f:(i64)) { f(self.n) }
let main():i32 {
    let b:box = {1}
    b.each()
    {
        println("x")
    }
    return 0
}
