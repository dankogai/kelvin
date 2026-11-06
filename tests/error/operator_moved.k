// an operator is a function: an owner given by value moves into it, and
// is dead afterwards, as in a call (#42, #54, #471)
struct bag { name: String; n: int64 }
let ==(a:bag, b:bag):bool { a.n == b.n }
let main():int32 {
    var a:bag = {$"a", 1}
    var b:bag = {$"b", 2}
    println(a == b)
    println(a)
    return 0
}
// error: 'a' was moved out and holds nothing now: assign it anew before using it
