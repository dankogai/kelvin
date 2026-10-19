// error: unterminated '#inline C {': it ends with the '}' that matches its '{'
#inline C {
int f(void) { return '}'; }
