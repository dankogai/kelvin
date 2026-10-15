/* built by tests/run.sh into the modules/ of a copy of tests/project, as
   libkshout.a, the library of the module shout.kh (#143), which
   #import <shout> links by itself */
#include <stdio.h>
void shout(const char *s) { printf("%s!\n", s); }
