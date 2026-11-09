// a local owner moved into a literal is named nowhere else in its
// expression (#500, #503): its members move in when the literal ends
struct P { name: String; n: int64 }
let main():int32 {
    var s = $"ab"
    let p = (P){s, s.count as int64}
    println(p)
    return 0
}
// error: 's' moves out in this expression, which names it again, and C may read it after the move, when it holds nothing: read it, or copy it, in a statement before
