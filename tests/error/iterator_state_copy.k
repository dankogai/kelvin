// an Iterator is an owner, never copied (#325)
let main():int32 {
    var it = Iterator(0) {
        if $0 > 2 { return none }
        $0 += 1
        return $0
    }
    var other = it
    return 0
}
// error: an Iterator is not copied: pass it on, or walk it
