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

// ---------------------------------------------------------------
// defer: run a statement or block when the ENCLOSING block ends,
// however it ends: falling off the end, break, continue, return,
// or a `return ... from` passing through.
// ---------------------------------------------------------------
var depth = 0;                           // a global the defer below restores

fn describe(items: i64[:]) -> i64 {
    depth++;
    defer depth--;                       // runs on EVERY way out of describe
    print("  depth inside describe: ", depth);
    var count = 0;
    for x in items {
        defer count++;                   // in a loop body: runs at the end of EACH iteration,
                                         // including the iterations cut short by `continue`
        if x < 0 { continue; }           // the defer still runs: count++
        if x > 100 { return -1; }        // return: this iteration's defer runs, then depth--
    }
    return count;                        // the return value is built first, THEN the defers run
}

// Several defers run LATEST FIRST, and an exit only runs the defers it has
// already passed. Here the early return skips the third defer entirely.
fn order(stop_early: bool) {
    defer print("  defer 1 (written first, runs last)");
    defer print("  defer 2");
    if stop_early { return; }            // only defers 2 and 1 have been passed
    defer print("  defer 3 (written last, runs first)");
    print("  end of order body");
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

    // ---------------------------------------------------------------
    // defer
    // ---------------------------------------------------------------
    print("defer in a function and a loop:");
    let a = describe([1, 2, -3]);        // -3 hits continue, but count++ still runs: 3
    let b = describe([5, 500, 7]);       // 500 returns -1 early; depth-- still runs
    print("  describe results: ", a, " ", b, ", depth back to ", depth);

    print("defer order (full run):");
    order(false);
    print("defer order (early return):");
    order(true);

    print("defer in a bare block:");
    {
        defer print("  block done");     // runs when this { } ends
        print("  in the block");
    }

    // The defer body sees variables as they are AT THE EXIT, not when the
    // defer was written:
    print("defer sees the value at exit:");
    {
        var n = 1;
        defer print("  n at exit = ", n);    // prints 3, not 1
        n = 3;
    }

    // Rules (each is a compile error):
    //   { defer { return; } }           // error: "return cannot leave a defer body (§6.6)"
    //                                   // (same for break and continue)
    //   defer risky_return_from();      // cannot call anything that uses `return ... from`
    //                                   // (it may run while such a return is in flight)
    //   defer at global scope           // a global initializer has no scope exit
    // And `abort`, a failed `assert` or `exit` end the program WITHOUT running defers.
}
