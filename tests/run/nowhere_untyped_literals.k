// nowhere is an any^ (#774): a literal of no type written that holds
// it is of any^, an Array's, a Dictionary's value and a fixed array's,
// which kc refused, of a type only C sees
let main():int32 {
    var a = $[nowhere, nowhere]
    var d = ${"none": nowhere}
    var f = [nowhere, nowhere, nowhere]
    println(a.count, " ", a[1] == nowhere, " ", d.count, " ", f.count, " ", f[2].isNull)
    println(a.typename, " ", f.typename)
    return 0
}
// out: 2 true 1 3 true
// out: Array<any^> [any^](3)
