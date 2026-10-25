// a range without an end is lo..., never lo..< (#373)
let main():int32 {
    let r = 0..<
    return 0
}
// error: '..<' needs an end, as in '0..<10'; a range without one is 'lo...'
