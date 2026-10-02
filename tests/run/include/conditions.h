/* C functions with a bool result and with an int result */
#include <stdbool.h>
static inline bool is_even(int n) { return n % 2 == 0; }
static inline int count_of(int n) { return n; }
