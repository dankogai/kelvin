// xs.reverse() (#186) changes the Array in place, which a let cannot be
let main():int32 {
    let xs = $[1, 2]
    xs.reverse()
    return 0
}
// error: 'xs' is a let and cannot change; declare it with var, or write '.reversed()'
