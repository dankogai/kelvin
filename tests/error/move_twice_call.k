// one owner given twice by value moves out twice: the second argument
// took what the first left, nothing, and both(s, s) gave 5 (#500)
let both(a:String, b:String):i64 { return a.count as i64 + b.count as i64 }
let main():int32 {
    let s = $"hello"
    println(both(s, s))
    return 0
}
// error: 's' moves out twice in this expression, and the second takes what the first left, nothing: give one a copy made in a statement before, as 'let s2 = s.copy()'
