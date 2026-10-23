// a typedef in a body is the same error (#294), where it was "expected an
// expression"
let main():int32 {
    typedef struct pt { x:int64 } pt
    return 0
}
// error: 'typedef' is C's: Kelvin names a type anew with typealias, 'typealias A = T', at the top level (#294)
