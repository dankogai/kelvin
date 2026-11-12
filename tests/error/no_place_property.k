// x.size, a property worked out of its value, is no place (#534)
let main():int32 {
    var x = 1
    x.size = 2
    return 0
}
// error: '.size' is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
