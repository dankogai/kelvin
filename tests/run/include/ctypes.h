/* values of each C type, which only C sees, for tests/run/overload_types.k (#41) */
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
static inline bool c_bool(void) { return 1; }
static inline char c_char(void) { return 'c'; }
static inline signed char c_schar(void) { return -1; }
static inline unsigned char c_uchar(void) { return 1; }
static inline short c_short(void) { return -1; }
static inline unsigned short c_ushort(void) { return 1; }
static inline int c_int(void) { return -1; }
static inline unsigned c_uint(void) { return 1; }
static inline long c_long(void) { return -1; }
static inline unsigned long c_ulong(void) { return 1; }
static inline long long c_llong(void) { return -1; }
static inline unsigned long long c_ullong(void) { return 1; }
static inline float c_float(void) { return 1.0f; }
static inline double c_double(void) { return 1.0; }
static inline size_t c_size(void) { return 1; }
static inline uintptr_t c_uintptr(void) { return 1; }
