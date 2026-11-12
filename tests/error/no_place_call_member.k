// a member of what a function gives is a member of a value, no place
// (#534)
struct pt { x: i64; y: i64 }
let mk():pt { (pt){1, 2} }
let main():int32 {
    mk().x = 1
    return 0
}
// error: what a function gives is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
