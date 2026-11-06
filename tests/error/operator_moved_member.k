// a member that owns moves into no operator, as into no function: its
// struct still holds it (#54, #471)
struct bag { name: String; n: int64 }
let +(a:bag, b:bag):bag { (bag){a.name.copy(), a.n + b.n} }
struct holder { b: bag; k: int64 }
let main():int32 {
    var h:holder = {{$"x", 1}, 2}
    var c:bag = {$"y", 2}
    let e = h.b + c
    println(e)
    return 0
}
// error: an owner moves into '+' only as a whole variable: pass a borrow, '&...', or a copy
