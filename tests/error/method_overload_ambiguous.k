// an argument that fits two overloads of a method equally (#158), as of a
// function (#41), is an error: convert it
struct box { v: int64 }
extend box {
    let add(n:int64):int64 { .v + n }
    let add(x:float64):int64 { .v + x as int64 }
}
let main():int32 {
    var b:box = {.v = 1}
    var k:int32 = 2
    println(b.add(k))
    return 0
}
// error: '.add' of struct box fits more than one of its overloads equally: convert an argument, as in 'x as f64'
