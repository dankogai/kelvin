// a Set has map, filter and reduce (#307), and no WithKey of them, which
// are a Dictionary's: the message says so, as an Array's does (#241)
let main():int32 {
    let w = ${"a"}
    println(w.reduceWithKey(0) { $0 })
    return 0
}
// error: a Set has no '.reduceWithKey': it is a Dictionary's, whose function takes each key; write '.reduce'
