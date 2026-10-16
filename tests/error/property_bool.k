// error: '.bin' is a property of integers
struct point { x:int32; };
let main():int32 {
    var b:bool = true; println(b.bin);
    return 0;
}
