// T.random() of the number types and of bool (#547), as Swift's
// T.random(in:), by the system's random bits, which no seed repeats: an
// integer type's is any of its values, and with a Range<T> one of the
// range's; a floating-point type's is from 0.0 up to 1.0, up to a limit,
// or from a start up to a limit, without the limit; bool's is true or
// false. What is drawn differs each run, so its bounds, its type and its
// spread are what is checked
let main():int32 {
    var dice:$[i64] = $[0, 0, 0, 0, 0, 0]
    var signs:$[i64] = $[0, 0, 0]
    var heads = 0
    var sum = 0.0
    var out = 0
    for i in 0..<60000 {
        dice[i64.random(0..<6)] += 1
        signs[(i8.random(-1...1) as i64) + 1] += 1
        if bool.random() { heads += 1 }
        let x = f64.random()
        sum += x
        if x < 0.0 || x >= 1.0 { out += 1 }
        let y = f64.random(2.0, 3.0)
        if y < 2.0 || y >= 3.0 { out += 1 }
        let z = f32.random(10)
        if z < 0.0 || z >= 10.0 { out += 1 }
        let w = f64.random(-1.5, -1.25)
        if w < -1.5 || w >= -1.25 { out += 1 }
        let u = u8.random(250...)
        if u < 250 { out += 1 }
        let v = u16.random(..<3)
        if v > 2 { out += 1 }
        let s = i32.random(-7...-5)
        if s < -7 || s > -5 { out += 1 }
    }
    var even = true
    for c in dice { if c < 9000 || c > 11000 { even = false } }
    for c in signs { if c < 19000 || c > 21000 { even = false } }
    let mean:f64 = sum / 60000.0
    println(out, " ", even, " ", heads > 29000 && heads < 31000, " ", mean > 0.49 && mean < 0.51)
    let r:Range<i16> = -2...2
    let d = i16.random(r)
    println(d >= -2 && d <= 2, " ", i64.random(7...7), " ", u8.random(255...), " ", i64.random(-5..<-4), " ", u64.random(0..<1))
    println(i64.random(i64.min...i64.max) != i64.random(), " ", u64.random() != u64.random(), " ", i128.random() != i128.random(), " ", u128.random() != 0)
    println(i64.random().typename, " ", u8.random(1...6).typename, " ", i128.random().typename, " ", f64.random(2.0).typename, " ", f32.random().typename, " ", bool.random().typename)
    let coin = bool.random()
    let n = i8.random()
    let f = f32.random(1, 2)
    println(coin || !coin, " ", n.typename, " ", n >= i8.min && n <= i8.max, " ", f.typename, " ", f >= 1.0 && f < 2.0)
    return 0
}
// out: 0 true true true
// out: true 7 255 -5 0
// out: true true true true
// out: i64 u8 i128 f64 f32 bool
// out: true i8 true f32 true
