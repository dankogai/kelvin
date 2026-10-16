// a template with ${...} is made at run time, so not in a type (#44)
let main():int32 {
    let f:([uint8](8)^):int64 := { (a:[uint8](`${1}${1}`.size)^):int64 in 1 }
    println(f(nullptr))
    return 0
}
// error: a template literal with ${...} is made at run time, so it cannot be part of a type
