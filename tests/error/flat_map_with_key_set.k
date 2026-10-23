// flatMapWithKey is a Dictionary's (#308), whose function takes each key:
// a Set has flatMap
let main():int32 {
    let s = ${1}
    println(s.flatMapWithKey { $0 })
    return 0
}
// error: a Set has no '.flatMapWithKey': it is a Dictionary's, whose function takes each key; write '.flatMap'
