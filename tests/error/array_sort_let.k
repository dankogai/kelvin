// xs.sort() (#185) sorts in place, which a let cannot be
let main():int32 {
    let xs = $[2, 1]
    xs.sort()
    return 0
}
// error: 'xs' is a let and cannot change; declare it with var, or write '.sorted()'
