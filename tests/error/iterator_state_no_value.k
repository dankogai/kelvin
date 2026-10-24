// its function gives values: a none alone types nothing (#325)
let main():int32 {
    var it = Iterator(0) { return none }
    return 0
}
// error: an Iterator's function gives each value, 'return v', then none, 'return none', and this returns no value
