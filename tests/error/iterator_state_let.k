// walking an Iterator changes it, so it is a var (#325)
let main():int32 {
    let it = Iterator(0) {
        if $0 > 2 { return none }
        $0 += 1
        return $0
    }
    for x in it { println(x) }
    return 0
}
// error: for walks an iterator by its var next(), which changes 'it', a let: declare it with var
