

### 152. A `switch` that binds the case's value

> now add a `switch` that binds the case's value

**Claude** added #119: `case n(x):` runs its body with `x` bound to the
case's value, as `if let n(x) = e` binds it, a let the enum still
owns; a binding case stands alone, a case with no value binds nothing,
and a value no place holds is read once. Details are provisional P131.

There are 671 tests, and all pass with clang and with gcc 15.
