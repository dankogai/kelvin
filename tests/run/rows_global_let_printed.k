// rows of a count that is a global let's are printed whole (#784), as
// kelvinc prints them: kc's printer held them by a struct's member,
// which C refuses of a count it computes
let N:int64 = 3

let main():int32 {
    var g:[[int64](N)](2)
    g[1][2] = 7
    println(g)
    var h:[[[float64](N)](2)](2)
    h[1][0][1] = 1.5
    println("h = ", h)
    println(g[1])
    return 0
}
// out: [[0, 0, 0], [0, 0, 7]]
// out: h = [[[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]], [[0.0, 1.5, 0.0], [0.0, 0.0, 0.0]]]
// out: [0, 0, 7]
