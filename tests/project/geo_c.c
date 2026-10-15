/* a C program against libkgeo, the shared library kelvinc --lib makes
   beside libkgeo.a (#147): the module's functions by the names its C has,
   point__norm1 for the attribute norm1 of point, made for the global */
#include <stdio.h>
struct point { double x, y; };
double point__norm1(struct point self);
extern long long made;
int main(void) {
    struct point p = {3, 4};
    printf("%g %lld\n", point__norm1(p), made);
    return 0;
}
