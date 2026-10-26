// !! makes a bool of an integer: it is no two nots (#387)
let main():int32 {
    let b = true
    println(!!b)
    return 0
}
// error: '!!' makes a bool of an integer 0 or 1, and this is a bool already: write it as it is, or '! !b' for two nots
