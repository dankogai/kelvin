// xs.reverse() in place and xs.reversed() a new Array (#186): the elements
// in the other order, moved as they are; reversed() of an Array an
// expression gives reverses that one, so that it chains
let main():int32 {
    var xs = $[1, 2, 3, 4]
    var ys = xs.reversed()
    xs.reverse()
    var odd = $[1, 2, 3]
    odd.reverse()
    var names = $[$"ann", $"bob", $"cy"]
    var back = names.reversed()
    names.reverse()
    println(xs, " ", ys, " ", odd, " ", back, " ", names)
    var none = Array<int64>()
    none.reverse()
    var one = $[7].reversed()
    var chain = $[3, 1, 2].sorted().reversed().map { $0 * 10 }
    println(none.count, " ", one, " ", chain)
    return 0
}
// out: [4, 3, 2, 1] [4, 3, 2, 1] [3, 2, 1] ["cy", "bob", "ann"] ["cy", "bob", "ann"]
// out: 0 [7] [30, 20, 10]
