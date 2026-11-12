// what a method gives is a value and no place (#534)
struct pt { x: i64; y: i64 }
let pt.len():i64 { .x + .y }
let main():int32 {
    var p:pt = {1, 2}
    p.len() = 3
    return 0
}
// error: '.len' is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
