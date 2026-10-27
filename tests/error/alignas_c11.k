// C11's _Alignas is spelled alignas, C23's name (#396)
_Alignas(16) var x:i64
let main():i32 { return 0 }
// error: '_Alignas' is C11's spelling: Kelvin writes alignas(N) or alignas(T) before the declaration
