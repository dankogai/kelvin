// a compound literal where a macro's argument goes (#732): println and a
// header's assert are C's macros, whose arguments the preprocessor
// divides at each comma that no parentheses hold, so kelvinc writes an
// argument that shows a compound literal's commas in parentheses
#import <assert.h> as C
struct point { x: int64; y: int64 }
let first(p:const int64^):int64 { p^ }
let main():int32 {
    println(sizeof ([int32](3))[1, 2, 3])
    println(([int32](3))[1, 2, 3][1], " ", (point){1, 2}.y, " ", sizeof (point){1, 2})
    print(([int64](2))[7, 8][0], "\n")
    println(first(([int64](2))[7, 8]), " ", -([int64](2))[7, 8][1], " ", ([int64](2))[7, 8][1] + (point){1, 2}.y)
    assert(([int64](2))[7, 8][1] == 8)
    assert((point){1, 2}.x == 1)
    println(([cstr](2))["a,b", "c"][0], " ", ([uint8](3))[',', 0, 0][0] == ',', " ", `${(point){3, 4}.y}`)
    return 0
}
// out: 12
// out: 2 2 16
// out: 7
// out: 7 -8 10
// out: a,b true 4
