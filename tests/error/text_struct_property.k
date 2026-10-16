// error: '.i64' converts a number or reads text, and point is a struct with no field 'i64'
struct point { x: int64; y: int64 }
let main():int32 {
    let p:point = {1, 2}
    println(p.int64)
    return 0
}
