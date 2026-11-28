// a choice of two numbers' variables where a String is the element is
// no String (#792): kc said an owner is not copied
let main():int32 {
    var x:int64 = 1
    var y:int64 = 2
    var a:$[String] = $[true ? x : y]
    return 0
}
// error: an element of Array<String> is a String, and this is i64
