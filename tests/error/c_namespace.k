// `as C` names no namespace (#416): a header's names are bare
#import <ctype.h> as C
let main():int32 {
    println(C.toupper(97))
    return 0
}
// error: 'C.toupper' names nothing: '#import <x.h> as C' brings a header's names in bare, so write 'toupper'
