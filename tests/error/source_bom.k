// a Kelvin source is UTF-8 without a BOM (#295): this one starts with
// EF BB BF, an error at its first line
let main():int32 {
    return 0
}
// error: a Kelvin source is UTF-8 without a BOM: remove its first three bytes, EF BB BF (#295)
