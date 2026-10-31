// a header's value, as its functions, is bare (#416)
#import <stdio.h> as C
let main():int32 {
    let end = C.EOF
    return 0
}
// error: 'C.EOF' names nothing: '#import <x.h> as C' brings a header's names in bare, so write 'EOF'
