// Kelvin's directives do not nest in #inline C (#296): #import stands at
// the top level, where C once read it as its own, and failed
#inline C {
#import <IO>
}
let main():int32 {
    return 0
}
// error: '#import' does not nest in '#inline C': Kelvin's directives stand at the top level, or among a function's statements (#296)
