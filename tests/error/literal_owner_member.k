// a member that owns moves into no literal, as into no call: its struct
// still holds it; kc copied it, and the program freed it twice (#503)
struct P { name: String; n: int64 }
let main():int32 {
    let p:P = {$"a", 1}
    let q = (P){p.name, 2}
    println(q)
    return 0
}
// error: an owner is not copied by '=' (#54): copy its bytes with it.copy(), or borrow it with ':= &...'
