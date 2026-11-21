// an integer divided by a constant zero is kelvinc's error (#662), where C
// only warned and the program's behavior was undefined
let main():int32 {
    let x = 1 / 0
    println(x)
    return 0
}
// error: '/ 0' divides an integer by zero, which has no value: C leaves it undefined
