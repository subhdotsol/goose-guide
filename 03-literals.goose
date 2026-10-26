import std;

// `self` literal demo: a ring node whose links point into the global array `ring`.
// `Ring&<u32 in ring>` is a pool-relative reference: a u32 offset from the start of `ring`.
struct Ring { val: i64, prev: Ring&<u32 in ring>, next: Ring&<u32 in ring> }
reusable var ring: Ring[>..] = [];

fn main() {
    // ---------------------------------------------------------------
    // Integer literals
    // No binary literals and no suffixes (no 10u, 10L, ...).
    // An integer literal takes its type from context and defaults to i64.
    // ---------------------------------------------------------------
    let dec = 42;                         // decimal, defaults to i64
    let hex = 0xFF;                       // hexadecimal (255)
    let big: u64 = 18446744073709551615;  // u64 max: fits because the context is u64
    let small: u8 = 200;                  // context makes this literal a u8
    print("ints: ", dec, " ", hex, " ", big, " ", small);

    // ---------------------------------------------------------------
    // Float literals: default to f64
    // Note: `1..2` is a range and `1.` is not a number.
    // ---------------------------------------------------------------
    let f1 = 1.5;                         // plain decimal
    let f2 = 2.5e-3;                      // exponent form: 0.0025
    let f3 = 1e9;                         // exponent without a dot is still a float
    let f4 = 0x1.8p3;                     // hex float: 1.5 * 2^3 = 12
    let f5: f32 = 0.25;                   // context makes this literal an f32
    print("floats: ", f1, " ", f2, " ", f3, " ", f4, " ", f5);

    // ---------------------------------------------------------------
    // Char literals: an INTEGER (the byte value), not a character type
    // ---------------------------------------------------------------
    let ch_a = 'a';                       // 97
    let ch_nl = '\n';                     // 10
    let ch_hex = '\x41';                  // 65, i.e. 'A' (\x needs exactly 2 hex digits)
    print("chars: ", ch_a, " ", ch_nl, " ", ch_hex);
    print("'a' + 1 = ", ch_a + 1);        // chars are ints, so arithmetic works

    // ---------------------------------------------------------------
    // String literals: type const u8[:] (read-only static bytes)
    // Escapes: \n \t \r \0 \\ \" \' and \xNN
    // ---------------------------------------------------------------
    let greeting = "hello\n";             // ends with a newline
    let escapes = "tab:\t quote:\" backslash:\\ hex:\x41";
    print("string: ", greeting, "len = ", greeting.len);
    print(escapes);

    // ---------------------------------------------------------------
    // Raw strings: """ ... """, no escapes are processed
    // ---------------------------------------------------------------
    let path = """C:\temp\new""";         // \t and \n stay as literal characters
    print("raw: ", path);

    // A multi-line raw string strips the closing """'s indentation from every line.
    let usage = """
        usage: wc [-l] file
          -l   count lines only
        """;
    print(usage);

    // ---------------------------------------------------------------
    // Bool literals
    // ---------------------------------------------------------------
    let yes = true;
    let no = false;
    print("bools: ", yes, " ", no);

    // ---------------------------------------------------------------
    // Null literal: the empty value of an optional T?
    // `null` alone has no type, so the binding needs an annotation.
    // ---------------------------------------------------------------
    let missing: i64? = null;
    print("null: ", missing == null);

    // ---------------------------------------------------------------
    // `self`: only inside a struct literal, for relative-reference fields.
    // Here a single node links to itself: prev and next both point at it.
    // ---------------------------------------------------------------
    let head .= ring.push(Ring { val: 7, prev: self, next: self });
    print("self: ", head.val, " ", head.next.val, " ", head.prev .== head);
}
