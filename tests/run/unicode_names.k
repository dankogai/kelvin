// names past ASCII (#385): UAX #31's letters and digits, and emoji, as
// variables, fields, functions and types, compared as written; the C has
// them in ASCII, and the text a struct prints keeps them, so it pastes back
struct point { x: float64; ♾️: float64; π: int64 }
enum 色 { 赤, 緑 }
let 二倍(n:int64):int64 { n * 2 }
let 階乗(n:int64):int64 { n <= 1 ? 1 : n * 階乗(n - 1) }
let 円周率 = 3.14159
let main():int32 {
    let ♾️ = 1.0/0.0
    let ♾:float64 = 2.0
    let café = 3
    let 🐶🐮 := "dogcow"
    var x_π:int64 = 二倍(café)
    let p:point = {1.0, ♾️, 314}
    let c:色 = 緑
    println(♾️, " ", ♾, " ", café, " ", 🐶🐮, " ", x_π, " ", p.π, " ", ♾️.isInfinite)
    println(p, " ", 階乗(10), " ", 円周率, " ", c == 緑)
    return 0
}
// out: inf 2.0 3 dogcow 6 314 true
// out: {x: 1.0, ♾️: inf, π: 314} 3628800 3.1415899999999999 true
