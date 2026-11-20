// a break in no loop and no switch is kelvinc's error (#649), where it
// was C's
let main():int32 {
    println(1)
    break
    return 0
}
// error: 'break' leaves a loop or a switch, and this is in neither
