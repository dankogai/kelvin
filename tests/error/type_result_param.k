// error: the result type, s.x.type, names a parameter, which C has not seen where it writes the result
#import "../run/include/typeof.h" as C
getx(s:struct cpt):s.x.type { return s.x; }
main():i32 { return 0; }
