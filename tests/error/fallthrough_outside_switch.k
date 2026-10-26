// fallthrough goes on into the next case of a switch (#386)
let main():int32 {
    fallthrough
    return 0
}
// error: 'fallthrough' outside a switch
