// a String separator that an expression gives would not be freed (#461)
let comma():String { $", " }
let main():int32 {
    let xs = $[1, 2]
    println(xs.join(comma()))
    return 0
}
// error: '.join' takes a String that an expression gives, which nothing would free: bind it to a variable first
