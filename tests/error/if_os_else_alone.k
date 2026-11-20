// #else ends a branch of an #if (#643)
let main():int32 {
    #else
    return 0
}
// error: '#else' has no '#if' before it
