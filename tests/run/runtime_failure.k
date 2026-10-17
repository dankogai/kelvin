// a check that fails at run time (#174) prints its reason and exits with
// status 1, no core and no crash report: here an index past the count;
// KELVIN_ABORT in the environment makes it abort instead
let main():int32 {
    var b = Bytes([1, 2, 3])
    println("before ", b.count)
    var x = b[3]
    println("never ", x)
    return 0
}
// out: before 3
// exit: 1
// err: kelvin: index 3 is out of range: the Bytes has 3
