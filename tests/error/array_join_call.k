// xs.joined is a method, which makes a String (#461): it is called
let main():int32 {
    let xs = $[1, 2]
    println(xs.joined)
    return 0
}
// error: '.joined' is a method, which makes a String: call it, as in '.joined(", ")', or '.joined()' with nothing between
