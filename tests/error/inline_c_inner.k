// error: #inline C is for the top level of a file and a function's blocks, outside structs, unions and enums
struct point {
    x: int32
    #inline C { int y; }
}
let main():int32 { return 0 }
