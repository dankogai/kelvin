// alignas is written once (#396)
alignas(16) alignas(8) var x:i64
let main():i32 { return 0 }
// error: 'alignas' is written once
