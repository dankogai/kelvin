// a method of the program on an owner that an expression gives (#156): the
// receiver, a borrow to the method, would never be freed; bind it first
#import <UnicodeData>
let main():int32 {
    var fold = $"Straße".fold()
    println(fold)
    return 0
}
// error: '.fold' of a String that an expression gives, which nothing would free: bind it to a variable first
