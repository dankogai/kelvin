// a struct's array member takes [...], or text where its elements are bytes: a number does not go on inside it, as C's would (#741)
struct bag { n: int64; xs: [int64](3); name: [uint8](8) }
let main():int32 {
    var g:bag = {1, [7, 8, 9], 5}
    return 0
}
// error: 'name' of bag is a [u8](8), and this is a number
