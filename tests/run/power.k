// b ** e (#380): Python's, tighter than a prefix on its left and right to
// left; of integers the base's promoted type, wrapping as '*' does, two
// literals worked out exactly; of floating-point numbers C's pow;
// b.pow(e) and b.pow(e, m), Python's pow(b, e, m); x **= y
let kib:int64 = 2 ** 10
let root2:float64 = 2.0 ** 0.5
let main():int32 {
    println(2 ** 10, " ", -2 ** 2, " ", (-2) ** 3, " ", 2 ** 3 ** 2, " ", 0 ** 0, " ", (-2) ** 63, " ", kib)
    var n:int64 = 3
    let e:int32 = 4
    println(n ** e, " ", n ** 40, " ", 2 ** n, " ", -n ** 2, " ", 2 ** -(-n), " ", n ** 0)
    let b:uint8 = 3
    let w:uint32 = 2
    println(b ** 5, " ", w ** 32, " ", w ** 31, " ", 3.pow(4), " ", n.pow(2), " ", 0.pow(0))
    let x:float64 = 2.0
    let f:float32 = 2.0
    println(root2, " ", x ** 0.5, " ", 2 ** 0.5, " ", x ** -1, " ", f ** 3, " ", 2.0 ** 10, " ", (-8.0) ** 3)
    println(4.pow(13, 497), " ", (-4).pow(13, 497), " ", 4.pow(13, -497), " ", 3.pow(-1, 7), " ", 2.pow(100, 1000000007))
    println(n.pow(1000, 9223372036854775783), " ", 5.pow(0, 1), " ", b.pow(e, w))
    n **= 2
    var xs = $[1, 2, 3]
    xs[1] **= 10
    println(n, " ", xs)
    var m:int64 = -1
    println(n ** m)
    return 0
}
// out: 1024 -4 -8 512 1 -9223372036854775808 1024
// out: 81 -6289078614652622815 8 -9 8 1
// out: 243 0 2147483648 81 9 1
// out: 1.4142135623730951 1.4142135623730951 1.4142135623730951 0.5 8.0 1024.0 -512.0
// out: 445 52 -52 5 976371285
// out: 1941952628735780551 0 1
// out: 9 [1, 1024, 3]
// exit: 1
// err: kelvin: '**' of integers takes an exponent of 0 or more: a power of an integer less than 0 is no integer
