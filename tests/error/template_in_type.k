// a template with ${...} is made at run time, so not in a type (#44)
let main():i32 {
    let f:(u8[8]^):i64 := { (a:u8[`${1}${1}`.size]^):i64 in 1 }
    println(f(nullptr))
    return 0
}
// error: a template literal with ${...} is made at run time, so it cannot be part of a type
