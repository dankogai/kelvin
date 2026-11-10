// an anonymous function is lent what .map and .sort give it (#244); lent
// is for a function's or a method's parameter (#510)
let main():int32 {
    let f:(String):i64 := { (s:lent String):i64 in s.count as i64 }
    return 0
}
// error: 'lent' is for a function's or a method's parameter: an anonymous function is lent the elements .map and .sort give it (#244), and owns what else it takes
