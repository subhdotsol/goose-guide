import std;

// ===================================================================
// 19. Recursion
// ===================================================================
// Recursion is OPT-IN. A function that (directly or through other
// functions) calls itself forms a "recursive cycle", and the ENTRY of
// each cycle must be marked with the `recursive` keyword before `fn`.
// Without it, a call cycle is a compile error.
//
// Why so strict? Goose gives growable locals their own data stacks.
// Forbidding growable locals across recursive calls means recursion only
// uses the native call stack, and running out of it is a clean abort.

// ---------------------------------------------------------------
// The simplest case: direct self-recursion
// ---------------------------------------------------------------
// Every function in a cycle needs a FULLY WRITTEN signature: the result
// type (`-> i64`) cannot be inferred for a recursive function.
recursive fn factorial(n: i64) -> i64 {
    if n <= 1 { return 1; }           // base case
    return n * factorial(n - 1);      // recursive call
}
// fn bad_fact(n: i64) { if n <= 1 { 1 } else { n * bad_fact(n - 1) } }
//   ERROR: a recursive cycle without `recursive`, and with an inferred result.

// ---------------------------------------------------------------
// Mutual recursion: one cycle, the ENTRY is marked `recursive`
// ---------------------------------------------------------------
// is_even -> is_odd -> is_even ... is one cycle. We mark the function
// we call into first (the entry). Both still need full signatures.
recursive fn is_even(n: i64) -> bool { if n == 0 { true } else { is_odd(n - 1) } }
fn is_odd(n: i64) -> bool { if n == 0 { false } else { is_even(n - 1) } }

// ---------------------------------------------------------------
// Recursion over a tree stored in one array
// ---------------------------------------------------------------
// `Tree&<u32>?` is an optional RELATIVE reference (section 14): a 32-bit
// offset to another Tree in the same array, or null.
struct Tree { key: i32, left: Tree&<u32>?, right: Tree&<u32>? }

// `guard n else { ... }` exits when n is null and narrows n to non-null
// afterwards, so n.left / n.right can be read.
recursive fn count(n: Tree?) -> i64 {
    guard n else { return 0; }
    return 1 + count(n.left) + count(n.right);
}

// The sum of every key, same shape as count. (n.key is i32; it widens to i64 implicitly.)
recursive fn key_sum(n: Tree?) -> i64 {
    guard n else { return 0; }
    return n.key + key_sum(n.left) + key_sum(n.right);
}

// ---------------------------------------------------------------
// Rule: no NON-FIXED local may be live across a recursive call
// ---------------------------------------------------------------
// A growable array (`u8[>..]`) or a `str(...)` temporary is "non-fixed".
// Fix: put the scratch data in a `{ }` block that ENDS BEFORE the call.
recursive fn show(n: Tree&, depth: i64) {
    {                                      // scratch block: `line` dies at the `}`
        var line: u8[>..] = [];            // growable local (non-fixed)
        for i in depth { line.append("  "); }  // indent by depth
        format(line, n.key);               // append the key as text
        print(line);
    }                                      // `line` no longer live here
    let l = n.left;                        // read the optional link
    if l { show(l, depth + 1); }           // if non-null, recurse (l narrowed to Tree&)
    let r = n.right;
    if r { show(r, depth + 1); }
}
// recursive fn bad_show(n: Tree&, depth: i64) {
//     var line: u8[>..] = [];             // still in scope at the calls below...
//     let l = n.left;
//     if l { bad_show(l, depth + 1); }    // ERROR: non-fixed local `line` live across call
// }
// Likewise `print(str("x", f(n)))` where f is in the cycle is an error:
// the `str(...)` temporary would be live across the recursive call.

// ---------------------------------------------------------------
// Alternative: pass a shared T[>..<]& and restore it with resize(mark)
// ---------------------------------------------------------------
// `i64[>..<]` is a grow-SHRINK array. Each activation records the
// current length (`mark`), pushes its own entries above, and before
// returning shrinks back with `resize(mark)`. One buffer serves every
// level of the recursion.
recursive fn walk(scratch: i64[>..<]&, depth: i64) -> i64 {
    let mark = scratch.len;                    // remember where my part begins
    scratch.push(depth * 10);                  // my scratch entry
    let mine = scratch[mark..];                // a view of just my part
    var total = 0;
    if depth < 3 { total = walk(scratch, depth + 1); }   // deeper levels push above me
    total += mine[0];                          // my part is still intact
    scratch.resize(mark);                      // restore: give back what I pushed
    return total;
}

fn main() {
    // Direct recursion.
    print("factorial(10) = ", factorial(10));

    // Mutual recursion.
    print("is_even(10) = ", is_even(10), ", is_odd(7) = ", is_odd(7));

    // Build a small tree in one array:   1
    //                                   / \
    //                                  2   3
    //                                 /
    //                                4
    var pool: Tree[>..] = [];                    // all nodes live in this array
    let a .= pool.push(Tree { key: 1 });         // `.=` binds a reference to the pushed node
    a.left .= pool.push(Tree { key: 2 });        // store a relative link to a new node
    a.right .= pool.push(Tree { key: 3 });
    let b .= a.left;                             // follow the link (optional ref)
    if b { b.left .= pool.push(Tree { key: 4 }); }  // add a grandchild

    print("tree:");
    show(a, 0);                                   // recursion with a scratch block
    print("count   = ", count(a));                // a: Tree& converts to Tree?
    print("key_sum = ", key_sum(a));

    // Shared grow-shrink scratch: 0 + 10 + 20 + 30, and len is back to 0.
    var scratch: i64[>..<] = [];
    let w = walk(scratch, 0);                     // result kept in a fixed local first
    print("walk = ", w, ", scratch.len after = ", scratch.len);
}
