// the whole expression names a moved owner once, the left of && too,
// which C does evaluate first (#500)
let one(a:String):i64 { return a.count as i64 }
let main():int32 {
    let s = $"hello"
    if s.count > 0 && one(s) > 0 { println("yes") }
    return 0
}
// error: 's' moves out in this expression, which names it again, and C may read it after the move, when it holds nothing: read it, or copy it, in a statement before
