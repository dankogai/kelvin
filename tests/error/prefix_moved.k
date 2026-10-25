// an Iterator moves into the Iterator<T> its .prefix gives (#372)
let main():int32 {
    var it = Iterator(0) {
        $0 += 1
        return $0
    }
    var few = it.prefix(2)
    println(it.next())
    return 0
}
// error: 'it' was moved out and holds nothing now: assign it anew before using it
