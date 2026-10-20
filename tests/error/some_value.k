// error: some(v) makes no Optional: give v itself where a T? goes, which becomes some(v); some(v) is a pattern, as in 'if let some(v) = x' (#224)
let half(n:int64):int64? {
    if n % 2 == 1 { return none }
    return some(n / 2)
}
