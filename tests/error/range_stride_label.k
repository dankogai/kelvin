// Kelvin has no argument labels, Swift's stride(by:) included (#379)
let main():int32 {
    for i in (0..<5).stride(by: 2) { }
    return 0
}
// error: '.stride' takes its step alone, as in 'r.stride(2)': Kelvin has no argument labels
