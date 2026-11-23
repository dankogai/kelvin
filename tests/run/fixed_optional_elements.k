// a fixed array of Optionals given its elements: none, and a value that
// some(v) is made of, as where a T? goes (#222), in a literal and in an
// array's compound literal (#419); kc takes them as kelvinc does (#704)
let main():int32 {
    let xs = ([i64?](2))[none, 1]
    var ys:[i64?](3) = [5, none, 7]
    println(xs[1], " ", xs[0], " ", ys)
    return 0
}
// out: some(1) none [some(5), none, some(7)]
