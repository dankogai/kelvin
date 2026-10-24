// .lazy makes the map or filter after it lazy, of an Iterator too (#327)
let main():int32 {
    var it = Iterator(0) {
        if $0 > 2 { return none }
        $0 += 1
        return $0
    }
    var l = it.lazy.reduce(0) { $0 + $1 }
    return 0
}
// error: '.lazy' makes '.map' or '.filter' after it lazy: write 'it.lazy.map { ... }'
