// a property worked out of its value has no address (#535)
let main():int32 {
    var xs = $[1, 2]
    let r := &xs.count
    return 0
}
// error: '.count' is a value, and has no address: '&' takes a variable, a member, an element or 'p^'; bind the value to a variable first
