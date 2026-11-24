// [...] is an array's elements: where an Array is declared it is no value (#48, #724)
let main():int32 {
    let xs:Array<int64> = [1]
    return 0
}
// error: '[...]' initializes an array, and this is Array<i64>: write a value
