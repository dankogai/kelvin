// a name may be declared again in a block inside, which hides it there,
// and in each case of a switch, each a block of its own in C (#628)
enum shape { dot; line: i64; box: i64 }
let size(s:shape):i64 {
    switch s {
    case dot:
        let n:i64 = 0
        return n
    case line(len):
        let n:i64 = len
        return n
    case box(side):
        let n:i64 = side * side
        return n
    }
}
let main():int32 {
    let n = 1
    if n > 0 {
        let n = 10
        println(n)
    }
    println(n, " ", size(shape.dot), " ", size(shape.line(3)), " ", size(shape.box(4)))
    return 0
}
// out: 10
// out: 1 0 3 16
