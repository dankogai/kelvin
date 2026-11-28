// arithmetic of numbers is a number where a struct goes (#789), as
// kelvinc names what it sees no type of: kc left it to C
struct pt { x:int64, y:int64 }

let main():int32 {
    var x:int64 = 1
    var o:pt = x + 1
    return 0
}
// error: 'o' is a pt, and this is a number
