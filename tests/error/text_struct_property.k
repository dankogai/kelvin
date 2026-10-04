// error: '.i64' converts a number or reads text, and point is a struct with no field 'i64'
struct point { x: i64; y: i64 }
main():i32 {
    let p:point = {1, 2}
    println(p.i64)
    return 0
}
