// ===================================================================
// 01 - Program skeleton (syntax.md section 1)
// ===================================================================
// - Source files are UTF-8 text with the `.goose` extension (this file!).
// - Run it with:   build/goose 01-program-skeleton.goose
// ===================================================================

// `import NAME;` brings in a module. Standard-library modules are imported
// by name only (no path, no quotes). `std` gives us print, rem, div_euclid, ...
import std;

// ---------------------------------------------------------------
// Top-level declarations can come in ANY order.
// `main` below uses `Point` and `describe`; `describe` is even declared
// AFTER main. There are no forward declarations or header files.
// ---------------------------------------------------------------
struct Point { x: i64, y: i64 }   // a struct with two i64 fields

// ---------------------------------------------------------------
// `fn main()` in the ROOT file (the one you pass to the compiler) is the
// entry point. It takes no parameters and returns nothing here.
// ---------------------------------------------------------------
fn main() {
    // ---------------------------------------------------------------
    // The cheat-sheet example
    // ---------------------------------------------------------------
    let p = Point { 1, 2 };            // positional struct literal; statement ends with `;`
    print("hello ", p);                // print takes any number of args: hello Point { 1, 2 }

    // ---------------------------------------------------------------
    // Using something declared later in the file: order does not matter.
    // ---------------------------------------------------------------
    print("describe: ", describe(p));  // `describe` is defined below main

    // ---------------------------------------------------------------
    // Semicolons
    // Every ordinary statement ends with `;`.
    // Constructs that END IN A BLOCK need no `;`:
    //   if, match, loops (for/while), block, guard ... else {}, nested fn.
    // ---------------------------------------------------------------
    let a = 3;                         // ordinary statement: `;` required
    if a > 2 { print("if: a is big"); }   // ends in `}`: no `;` after it

    for i in 0..2 {                    // a loop also ends in a block: no `;`
        print("for: i = ", i);
    }

    // A nested fn is a block-ended construct too: no `;` after its `}`.
    fn twice(n: i64) -> i64 { n * 2 }  // last expression without `;` is the result
    print("nested fn: ", twice(a));

    // When a block-ended construct is used as a VALUE (initializer), the
    // surrounding `let` statement still needs its own `;`.
    let w = if a > 2 { 10 } else { 20 };
    print("if as value: ", w);

    // An operator never continues a block-ended statement, so to use one
    // as an operand you wrap it in parentheses:
    let v = (if a > 2 { 1 } else { 2 }) + 3;
    print("parenthesized if + 3: ", v);

    // ---------------------------------------------------------------
    // Trailing commas are allowed in EVERY bracketed list:
    // array literals, struct literals, call arguments, params, generics...
    // ---------------------------------------------------------------
    let xs = [1, 2, 3,];               // trailing comma in an array literal
    let q = Point { x: 5, y: 6, };     // trailing comma in a struct literal (named fields)
    print("trailing commas: ", xs, " ", q, " ", add(1, 2,));  // ...and in call args

    // ---------------------------------------------------------------
    // Evaluation is strictly LEFT TO RIGHT: operands, call arguments,
    // and fields of a literal all evaluate in the order written.
    // `trace` prints its label and returns it, so the output order shows
    // the evaluation order.
    // ---------------------------------------------------------------
    let sum = trace(1) + trace(2) * trace(3);   // prints 1, 2, 3 in that order
    print("left-to-right sum = ", sum);         // 1 + 2*3 = 7 (precedence still applies)
    let pt = Point { trace(10), trace(20) };    // fields evaluate left to right too
    print("left-to-right point = ", pt);
}

// Declared after main: perfectly fine.
fn describe(p: Point) -> i64 {
    p.x + p.y                          // no `;`: this expression is the return value
}

// Trailing comma in a parameter list is allowed too.
fn add(a: i64, b: i64,) -> i64 { a + b }

// Helper for demonstrating evaluation order.
fn trace(n: i64) -> i64 {
    print("  evaluating ", n);
    n
}
