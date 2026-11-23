// an enum, a struct or a union with no name in a block: a type defined in
// a function has a name, which its block knows it by (#391); kc says so
// as kelvinc does (#702)
let main():int32 {
    enum { LIMIT = 3, OTHER }
    return 0
}
// error: declarations are written 'var name:type', as in 'var x:T'
