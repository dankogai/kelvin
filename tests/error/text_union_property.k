// error: '.i64' converts a number or reads text, and num is a union with no field 'i64'
union num { i: int64; f: float64 }
let main():int32 {
    var v:num
    v.i = 3
    println(v.int64)
    return 0
}
