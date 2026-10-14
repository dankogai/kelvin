

### 159. `${v.pretty}` in a template

> now add `${d}.pretty` in a template

**Claude** read it as `${d.pretty}`, the indented text inside a
template, and added #126: it takes kelvinc's printer at the indented
level, cut to a template's room as a long string value is, and whole
in `` $`...` ``. Before, it went through as a String that nothing
freed, or was refused in `` $`...` ``. Details are provisional P138.

There are 684 tests, and all pass with clang and with gcc 15.
