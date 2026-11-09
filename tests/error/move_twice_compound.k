// z += z with a struct's operator is z = z + z, which moves z out
// twice (#42, #471, #500)
struct bag { name: String; n: int64 }
let +(a:bag, b:bag):bag { (bag){a.name + b.name, a.n + b.n} }
let main():int32 {
    var z:bag = {$"z", 1}
    z += z
    println(z)
    return 0
}
// error: 'z' moves out twice in this expression, and the second takes what the first left, nothing: give one a copy made in a statement before, as 'let z2 = z.copy()'
