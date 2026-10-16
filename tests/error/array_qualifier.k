// a qualifier of an array is its elements', inside the brackets (#49)
let main():int32 {
    let s:const [uint8] = "hi"
    return 0
}
// error: a qualifier of an array is its elements': write it inside the brackets, as in '[const u8]'
