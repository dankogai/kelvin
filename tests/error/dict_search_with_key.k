// error: '.containsWithKey' takes a function of two parameters, a key and its value
let main():int32 {
    var d = ${"a": 1}
    println(d.containsWithKey(1))
    return 0
}
