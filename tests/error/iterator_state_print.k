// an Iterator has no text (#325)
let main():int32 {
    var it = Iterator(0) {
        if $0 > 2 { return none }
        $0 += 1
        return $0
    }
    println(it)
    return 0
}
// error: an Iterator has no text: walk it with for
