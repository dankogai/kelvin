// error: '.i64' converts a number or reads text, and num is a union with no field 'i64'
union num { i: i64; f: f64 }
main():i32 {
    var v:num
    v.i = 3
    println(v.i64)
    return 0
}
