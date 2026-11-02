// A calculator: text read into tokens, an enum with values that a switch
// takes apart; the shunting-yard algorithm puts them in postfix order
// with Arrays as stacks; each step gives a Result, the value or why there
// is none, and try passes an err up.

enum token { num: f64; op: u8; open; close }

let rank(op:u8):i64 { op == '+' || op == '-' ? 1 : 2 }

let tokens(s:cstr):Result<$[token], String> {
    var ts:$[token] = $[]
    var i:i64 = 0
    while s[i] != 0 {
        let c = s[i]
        if c >= '0' && c <= '9' {
            var x:f64 = 0
            while s[i] >= '0' && s[i] <= '9' {
                x = x * 10 + (s[i] - '0') as f64
                i += 1
            }
            ts += token.num(x)
            continue
        }
        switch c {
        case ' ': break
        case '+', '-', '*', '/': ts += token.op(c)
        case '(': ts += token.open
        case ')': ts += token.close
        default: return err($`no token starts at column ${i + 1}`)
        }
        i += 1
    }
    return ts
}

let postfix(ts:const $[token]^):Result<$[token], String> {
    var out:$[token] = $[]
    var ops:$[token] = $[]
    for t in ts^ {
        switch t {
        case num: out += t
        case op(o):
            while !ops.isEmpty && ops[ops.count - 1].is(op) && rank(ops[ops.count - 1].op) >= rank(o) {
                out += ops.pop()
            }
            ops += t
        case open: ops += t
        case close:
            while !ops.isEmpty && !ops[ops.count - 1].is(open) {
                out += ops.pop()
            }
            if ops.isEmpty { return err($"a ')' closes nothing") }
            ops.pop()
        }
    }
    while !ops.isEmpty {
        let t = ops.pop()
        if t.is(open) { return err($"a '(' is never closed") }
        out += t
    }
    return out
}

let evaluate(ts:const $[token]^):Result<f64, String> {
    var stack:$[f64] = $[]
    for t in ts^ {
        switch t {
        case num(x): stack += x
        case op(o):
            if stack.count < 2 { return err($"an operator lacks a number") }
            let b = stack.pop()
            let a = stack.pop()
            switch o {
            case '+': stack += a + b
            case '-': stack += a - b
            case '*': stack += a * b
            default:
                if b == 0 { return err($"a division by zero") }
                stack += a / b
            }
        default: break
        }
    }
    if stack.count != 1 { return err($"a number lacks an operator") }
    return stack[0]
}

let calc(s:cstr):Result<f64, String> {
    let ts = try tokens(s)
    let order = try postfix(&ts)
    return evaluate(&order)
}

let main():i32 {
    let inputs:[cstr](8) = ["1 + 2 * 3", "(1 + 2) * 3", "2 * (3 + 4) - 10 / 4", "12 / (6 - 2 * 3)", "1 +", "(2 + 3", "4 5", "2 ^ 3"]
    for s in inputs {
        let r = calc(s)
        if let v = r { println(s, " = ", v) } else { println(s, ": ", r.err) }
    }
    return 0
}
// out: 1 + 2 * 3 = 7.0
// out: (1 + 2) * 3 = 9.0
// out: 2 * (3 + 4) - 10 / 4 = 11.5
// out: 12 / (6 - 2 * 3): a division by zero
// out: 1 +: an operator lacks a number
// out: (2 + 3: a '(' is never closed
// out: 4 5: a number lacks an operator
// out: 2 ^ 3: no token starts at column 3
