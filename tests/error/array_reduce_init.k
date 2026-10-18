// xs.reduce (#184) starts from a value, written first, as in Swift
let main():int32 {
    var xs = $[1, 2]
    var s = xs.reduce { $0 + $1 }
    return 0
}
// error: '.reduce' takes the value to start from: write '.reduce(init) { ... }' or '.reduce(init, f)'
