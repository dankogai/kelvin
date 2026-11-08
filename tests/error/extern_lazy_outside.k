// extern lazy is a module's header's, which kelvinc --lib writes (#493)
extern lazy var names:Array<String>
let main():int32 {
    return 0
}
// error: 'extern lazy' is a module's header's, which kelvinc --lib writes: a global is given its value at its first use where C cannot initialize it (#493)
