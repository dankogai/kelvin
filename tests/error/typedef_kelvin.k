// typedef is C's: Kelvin's typealias names a type anew (#149), so a
// typedef is an error that says so (#294)
typedef int64 count
let main():int32 {
    return 0
}
// error: 'typedef' is C's: Kelvin names a type anew with typealias, 'typealias A = T', at the top level (#294)
