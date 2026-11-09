// an owner moved out by one argument and read by another: C evaluates
// them in an order it leaves open, and both(s, s.count) read the count
// of an emptied s, 5 for 10 (#500)
let both(a:String, b:i64):i64 { return a.count as i64 + b }
let main():int32 {
    let s = $"hello"
    println(both(s, s.count as i64))
    return 0
}
// error: 's' moves out in this expression, which names it again, and C may read it after the move, when it holds nothing: read it, or copy it, in a statement before
