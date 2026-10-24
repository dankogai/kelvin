// error: this Task has no value, as its function has no result, so it cannot be argument 2 of 'printf'
// nor is await of a Task with no value, given to C's function (#316)
#import <stdio.h> as C
let tell(x:int64) { println(x) }
let main():int32 {
    let t = async tell(1)
    printf("%d\n", await t)
    return 0
}
