// xs.gather(ix) and s.gather(ix) of indices in an [i64](N), a variable's
// or a member's, or written in place, [2, 0], as of a $[i64] (#618)
struct box {
    ix: [i64](2)
}

let main():int32 {
    let ix = [2, 0]
    var b:box
    b.ix[0] = 1
    b.ix[1] = 1
    let seed = $["a", "b", "c"]
    println(seed.gather(ix), " ", seed.gather([1, 2]), " ", $"xyz".gather([2, 2]), " ", $"x👍🏽z".gather(ix))
    println($[10, 20].gather(b.ix), " ", $[10].gather([]), " [", $"q".gather([]), "] ", ix)
    var grid = [[0, 1], [1, 0]]
    print(seed.gather(grid[0]), " ", seed.gather(grid[1]))
    println()
    return 0
}
// out: ["c", "a"] ["b", "c"] zz zx
// out: [20, 20] [] [] [2, 0]
// out: ["a", "b"] ["b", "a"]
