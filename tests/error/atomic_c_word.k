// C11's _Atomic is written atomic in Kelvin, as const is (#642)
var n:_Atomic i64 = 0
let main():int32 {
    println(n)
    return 0
}
// error: '_Atomic' is C's spelling: Kelvin writes 'atomic', as const is, 'var n:atomic i64' (#642)
