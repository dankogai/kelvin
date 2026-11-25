// a Set is a value too (#755), and a Dictionary: var s := ${...} was
// built by kelvinc, and by kc since #749
let main():int32 {
    var s := ${"a", "b"}
    println(s.count)
    return 0
}
// error: 's' is a value (Set<String>): assign it with '=', not ':='
