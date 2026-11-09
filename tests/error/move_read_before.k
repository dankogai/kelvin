// a read before the move in the source is no read before it in C, which
// evaluates the operands of + in an order it leaves open (#500)
let one(a:String):i64 { return a.count as i64 }
let main():int32 {
    let s = $"hello"
    println(s.count as i64 + one(s))
    return 0
}
// error: 's' moves out in this expression, which names it again, and C may read it after the move, when it holds nothing: read it, or copy it, in a statement before
