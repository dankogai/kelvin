

### 154. Methods and operators on a type with no tag

> now add methods and operators on an enum with no tag

**Claude** asked how a method should name a receiver with no name, and
the user chose its spelling: #121, `let enum{nothing, just: i64}.orZero()`,
which serves a struct or a union with no tag the same way, and
operators that take it by its spelling. On the way, operators the
program defined for any enum with values turned out never to be
reached, since the check of `==` came first; they are now. Details are
provisional P133.

There are 678 tests, and all pass with clang and with gcc 15.
