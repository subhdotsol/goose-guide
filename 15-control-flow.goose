import std;

// =====================================================================
// 15. Control flow
//
// `if`, `match`, `block` and bare `{ }` are EXPRESSIONS: they produce a value.
// A block's value is its LAST expression, written WITHOUT a trailing `;`.
// =====================================================================

// ---------------------------------------------------------------
// guard with else: continue only if the condition holds.
// The else branch must leave the scope (return / break / continue / abort).
// ---------------------------------------------------------------
fn half(n: i64) -> i64 { guard n % 2 == 0 else { return -1; } n / 2 }

// guard WITHOUT else, inside a function: a failed guard RETURNS.
fn print_if_positive(n: i64) {
    guard n > 0;                         // n <= 0: the function returns here
    print("  positive: ", n);
}

// A small enum so we can show `match` as an expression, too.
enum Light { Red, Yellow, Green }

fn main() {
    let hp = 30;                         // try other values to see the branches change
    let alive = true;

    // ---------------------------------------------------------------
    // if / else if / else as an EXPRESSION
    // Every branch yields a value of the same type; the whole `if` is that value.
    // ---------------------------------------------------------------
    let kind = if hp > 50 { "healthy" } else if hp > 0 { "hurt" } else { "down" };
    print("kind: ", kind);

    // Statement form: no value is used, so no `else` is needed.
    if hp > 0 { print("statement-form if: still alive (", kind, ")"); }

    // To use an `if` as an OPERAND, parenthesize it.
    let v = (if hp > 2 { 1 } else { 2 }) + 3;
    print("parenthesized if as operand: ", v);   // 1 + 3 = 4
    // let w = if hp > 2 { 1 } else { 2 } + 3;   // ERROR: "expected ';' ... found '+'": the if ends at its }

    // Conditions must be bool: there is no truthiness for integers.
    // if hp { }                         // ERROR: i64 is not a bool (only optionals narrow in a condition)

    // ---------------------------------------------------------------
    // match is an expression too (see section 12 for the full story)
    // ---------------------------------------------------------------
    let light = Light.Yellow;
    let action = match light {
        Red => "stop",
        Yellow => "slow",
        Green => "go",
    };
    print("match as expression: ", action);

    // ---------------------------------------------------------------
    // block: a target for `break`, with a VALUE.
    // `break value;` leaves the block with that value; otherwise the
    // block's value is its last expression.
    // ---------------------------------------------------------------
    let verdict = block {
        guard alive else { break "gone"; }    // break out of the block with "gone"
        guard hp > 0 else { break "dead"; }   // ...or "dead"
        "standing"                            // the normal result (no `;`!)
    };
    print("block verdict: ", verdict);

    let dead_verdict = block {
        let my_hp = 0;
        guard my_hp > 0 else { break "dead"; } // this one takes the break
        "standing"
    };
    print("block verdict with hp 0: ", dead_verdict);

    // ---------------------------------------------------------------
    // Bare block: just a scope that has a value
    // ---------------------------------------------------------------
    let doubled = { let tmp = hp + 1; tmp * 2 };   // tmp is local to the braces
    print("bare block value: ", doubled);           // (30 + 1) * 2 = 62
    // print(tmp);                                  // ERROR: tmp is out of scope here

    // A block whose last item ends in `;` has no value:
    { let note = "bare block used as a statement"; print(note); }

    // ---------------------------------------------------------------
    // guard with else (in a function)
    // ---------------------------------------------------------------
    print("half(10) = ", half(10), ", half(7) = ", half(7));

    // ---------------------------------------------------------------
    // guard WITHOUT else: skips the rest of the ENCLOSING body.
    //   - in a function: it returns
    //   - in a loop: it continues with the next iteration
    //   - in a block: it ends that block
    // ---------------------------------------------------------------
    print("guard in a function:");
    print_if_positive(5);                // prints
    print_if_positive(-3);               // returns early, prints nothing

    print("guard in a loop:");
    for i in 5 { guard i % 2 == 0; print("  even ", i); }   // odd i: skip to the next iteration

    print("guard in a block:");
    block {
        guard hp > 100;                  // false: the block ends here
        print("  never printed");
    }
    block {
        guard hp > 10;                   // true: execution continues
        print("  hp > 10, block continued");
    }
}
