/* function-like macros that expand to statements, as real headers have */
#define SWAP(a, b) do { int t_ = (a); (a) = (b); (b) = t_; } while (0)
#define LOG(x) printf("log %d\n", (x));
#define CHECK(c) if (!(c)) printf("check failed\n")
#define BLOCK(x) { printf("block %d\n", (x)); }
