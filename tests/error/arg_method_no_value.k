// error: this has no value, so it cannot be argument 1 of '.append': make the call alone, as a line of its own
// nor is an Array's clear, given to a method (#316)
let main():int32 {
    var a = $[1, 2]
    var b = $[3]
    b.append(a.clear())
    return 0
}
