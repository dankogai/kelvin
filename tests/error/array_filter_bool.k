// the function of xs.filter (#184) says whether to keep an element: a bool
let twice(n:int64):int64 { n * 2 }
let main():int32 {
    var xs = $[1, 2]
    var ys = xs.filter(twice)
    return 0
}
// error: '.filter' takes a function that says whether to keep an element, a bool, and this gives i64
