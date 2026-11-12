// Bits is no more (#532), as a type too: a struct's flags are an integer,
// its bits flags.bits[n], or a BigInt, or an Array<bool>
struct job { id: int64; flags: Bits }
let main():int32 {
    return 0
}
// error: Bits is no more (#532): an integer's bits are x.bits, an Array<bool>, and x.bits[n] its bit n; a BigInt's are b.bits, of any width; and bools that grow are an Array<bool>
