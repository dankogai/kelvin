// while (i == 0) (i) += 1: the parentheses after a condition's are a
// call's, and the assignment is in the condition (#743), kc's words too
let main():int32 {
    var i:int64 = 0
    while (i == 0) (i) += 1
    return 0
}
// error: assignment is a statement in Kelvin, not a value: assign on a line of its own
