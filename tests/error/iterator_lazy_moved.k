// an Iterator made lazy moves in, and holds nothing after (#327)
let main():int32 {
    var it = Iterator(0) {
        if $0 > 2 { return none }
        $0 += 1
        return $0
    }
    var l = it.lazy.map { $0 * 2 }
    println(it.next())
    return 0
}
// error: 'it' was moved out and holds nothing now
