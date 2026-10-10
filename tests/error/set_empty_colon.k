// an empty Set is ${}, an empty Dictionary ${:} (#71)
let main():i32 {
    var x:${i64} = ${:}
    var y:${String: i64} = ${}
    return 0
}
// error: an empty Set is written ${}; ${:} is an empty Dictionary
