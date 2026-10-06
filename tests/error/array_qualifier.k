// a qualifier of an array is its elements', inside the brackets (#49)
let main():i32 {
    let s:const [u8] = "hi"
    return 0
}
// error: a qualifier of an array is its elements': write it inside the brackets, as in '[const u8]'
