// rows that are a v.type of a count C computes (#774) are not printed
// whole either (#776), in a template as by println
let main():int32 {
    var n:int64 = 3
    var v:[int64](n)
    var w:[v.type](2)
    let s = $`${w}`
    return 0
}
// error: an array of arrays of a count C computes is not printed whole: print its rows, println(g[i])
