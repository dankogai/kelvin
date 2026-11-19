// A brainfuck interpreter: the program from the file named on the command
// line, or two built in. The tape is 65536 cells that wrap, as the pointer
// does. A `!` ends the program and starts its input, as swift-bf has it,
// so a source carries its own data; without one, `,` reads stdin. With no
// input left, `,` halts. Unmatched brackets are reported with their offset.
// The file and the three streams are IO's: f.bytes is the whole file,
// IO.stdin.byte the next byte or none, and a byte is written as a Bytes of one.
#import <IO>

struct program {
    code: Bytes          // the commands, comments stripped
    jump: $[i64]         // for each [ and ], the index of its match
    input: Bytes         // the text after the first !
    embedded: bool       // whether there was one: then , reads input, else stdin
}

extend program {
    // the commands of src and their matching brackets, or why there are none
    static let parse(src:Bytes^):Result<Self, String> {   // a function of the type (#111)
        var p:Self = {Bytes(), $[], Bytes(), false}
        var offsets:$[i64] = $[]       // where each command came from, for messages
        var stack:$[i64] = $[]
        let n = src^.count as i64
        var i:i64 = 0
        while i < n {
            let c = src^[i]
            if c == '!' {
                p.input = src^[i + 1...]
                p.embedded = true
                break
            }
            if c == '>' || c == '<' || c == '+' || c == '-' || c == '.' || c == ',' || c == '[' || c == ']' {
                p.code += c
                offsets += i
            }
            i += 1
        }
        p.jump = Array<i64>(p.code.count)
        for k in 0..<p.code.count as i64 {
            let c = p.code[k]
            if c == '[' {
                stack += k
            } else if c == ']' {
                if stack.count == 0 { return err($`unmatched ] at offset ${offsets[k]}`) }
                let open = stack.pop()
                p.jump[open] = k
                p.jump[k] = open
            }
        }
        if stack.count > 0 { return err($`unmatched [ at offset ${offsets[stack[0]]}`) }
        return p
    }

    let run():() {                                        // a method: .code is self.code (#139)
        var tape = Bytes(65536)
        var sp:i64 = 0
        var ip:i64 = 0
        var at:i64 = 0                 // the next byte of the embedded input
        var cell = Bytes(1)            // the byte . writes
        let n = .code.count as i64
        while ip < n {
            switch .code[ip] {
            case '>': sp = (sp + 1) % 65536
            case '<': sp = (sp + 65535) % 65536
            case '+': tape[sp] += 1
            case '-': tape[sp] -= 1
            case '.':
                cell[0] = tape[sp]
                IO.stdout.write(&cell)
            case ',':
                if .embedded {
                    if at >= .input.count as i64 { return }
                    tape[sp] = .input[at]
                    at += 1
                } else {
                    if let c = IO.stdin.byte { tape[sp] = c } else { return }
                }
            case '[': if tape[sp] == 0 { ip = .jump[ip] }
            case ']': if tape[sp] != 0 { ip = .jump[ip] }
            default:
            }
            ip += 1
        }
    }
}

// parses and runs src; 1 and a message on stderr if it does not parse
let interpret(src:Bytes^):i32 {
    var parsed = program.parse(src)
    if let err(why) = parsed {
        IO.stderr.println(why)
        return 1
    }
    parsed.ok.run()
    IO.stdout.flush()
    return 0
}

let hello := "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
let echo := "+[,<>.]-!Hello, Kelvin!\n"   // the eight commands, and their input after the !

let main(argc:i32, argv:[cstr]):i32 {
    if argc > 1 {
        let f = IO(argv[1], "r")
        if f.error != 0 {              // the errno when it did not open
            IO.stderr.println(argv[1], ": ", IO.strerror(f.error))
            return 1
        }
        var src = f.bytes              // the whole file
        return interpret(&src)
    }
    var h = Bytes(hello)
    var e = Bytes(echo)
    if interpret(&h) != 0 { return 1 }
    return interpret(&e)
}
// out: Hello World!
// out: Hello, Kelvin!
