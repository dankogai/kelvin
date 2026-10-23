// '.flatMap' of an Array takes a function that gives an Array (#308),
// which it joins into one; one that gives anything else is '.map''s
let main():int32 {
    let xs = $[1, 2]
    println(xs.flatMap { $0 * 2 })
    return 0
}
// error: '.flatMap' of an Array takes a function that gives an Array, and joins them into one; this gives i64, which '.map' takes
