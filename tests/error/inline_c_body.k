// #inline C is a statement among a block's, not the body of one (#198, #727)
let main():int32 {
    for (;;)
        #inline C { break; }
    return 0
}
// error: #inline C cannot be the body of a statement or follow a label; put it in a block
