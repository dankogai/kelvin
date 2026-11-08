// a global given its value at its first use is read in C by its accessor,
// under its name, which a local of the name would hide (#493)
var names:Array<String> = $["a"]
let main():int32 {
    var names = 3
    return 0
}
// error: 'names' is a global given its value at its first use (#493), which a local of the name would hide in C: name this one otherwise
