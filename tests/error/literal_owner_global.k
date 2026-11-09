// a global owner moves into no struct's literal, which holds an owner,
// never a borrow: copy it (#503)
struct P { name: String; n: int64 }
var g = $"g"
let main():int32 {
    let p = (P){g, 1}
    println(p)
    return 0
}
// error: 'g' is a global owner, which cannot move into a literal of P: copy it, 'g.copy()'
