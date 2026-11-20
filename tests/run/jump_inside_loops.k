// what #649 leaves as it was: break and continue in while, for, a C for
// and do, and break in a switch, a switch's continue in a loop around it
let main():int32 {
    var n = 0
    var skipped = 0
    while true {
        n += 1
        if n > 4 { break }
        switch n {
        case 2:
            skipped += 1
            continue
        default:
            break
        }
    }
    var odd = 0
    for i in 0..<6 {
        if i % 2 == 0 { continue }
        odd += i
    }
    var c = 0
    for (var k = 0; k < 10; k += 1) {
        if k == 3 { break }
        c += 1
    }
    do { c += 10; break } while true
    println(n, " ", skipped, " ", odd, " ", c)
    return 0
}
// out: 5 1 9 13
