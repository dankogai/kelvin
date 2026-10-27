// C11's _Generic is left out on purpose (#397): overloads choose by type
let main():i32 {
    let x = _Generic(1, i64: 1, default: 0)
    return 0
}
// error: '_Generic' is C11's, left out on purpose: a function of one name takes several types by overloads, 'let f(x:i64)' and 'let f(x:f64)', and kelvinc chooses, or has C choose (#41)
