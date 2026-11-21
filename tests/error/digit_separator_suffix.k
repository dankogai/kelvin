// error: '1_000u': literals have no suffixes in Kelvin; put the type on the declaration, e.g. 'x:u64 = 1_000'
// a literal's error quotes it as written, its _ too (#671)
let main():int32 {
    let x = 1_000u
    println(x)
    return 0
}
