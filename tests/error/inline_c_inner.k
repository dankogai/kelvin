// error: #inline C is for the top level of a file, outside functions, structs and blocks
let main():int32 {
    #inline C { int x; }
    return 0
}
