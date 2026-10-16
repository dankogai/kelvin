#import <stdio.h> as C
#import <stdlib.h> as C
#import <string.h> as C
#import "include/greet.h" as C     // found next to this file

let cmp(x:const any^, y:const any^):int32 {
    return (x as const int32^)^ - (y as const int32^)^;
}

let main():int32 {
    var pi = 3.14159;                       // inferred: f64
    var n = 3;                              // inferred: i64
    printf("%.2f %d %d\n", pi * 2, int32(sizeof pi), int32(sizeof n));

    var buf:[uint8](32);
    snprintf(buf, sizeof buf, "%s-%d", "kelvin", 7);
    printf("%s %d\n", buf, int32(strlen(buf)));

    var len:size_t = strlen("four");       // C typedef names work as types
    printf("%d\n", int32(len + 1 as size_t) - 1);

    var out:FILE^ := stdout;                // so does FILE, and macros like stdout
    fprintf(out, "%d\n", greet_answer());

    var p:int32^ := malloc(4 * sizeof(int32)) as int32^;
    if p == NULL {
        return 1;
    }
    p[0] = 3; p[1] = 1; p[2] = 4; p[3] = 2;
    qsort(p, 4, sizeof(int32), cmp);          // a Kelvin function passed to C
    printf("%d%d%d%d\n", p[0], p[1], p[2], p[3]);
    free(p);
    return EXIT_SUCCESS;
}
// out: 6.28 8 8
// out: kelvin-7 8
// out: 4
// out: 42
// out: 1234
