// an Array is a value, an owner, as a String is (#755): := is a
// reference's, where kelvinc could not tell and built it
let main():int32 {
    var xs := $["a", "b"]
    println(xs)
    return 0
}
// error: 'xs' is a value (Array<String>): assign it with '=', not ':='
