// **= of an Array is an operator it has not (#763, #766), which kc
// said of the power, '**' takes numbers
let main():int32 {
    var a:$[int64] = $[1]
    a **= 2
    return 0
}
// error: an Array has no '**='
