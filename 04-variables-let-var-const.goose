// ===================================================================
// 04 - Variables: let, var, const (syntax.md section 4)
// ===================================================================
import std;

// ---------------------------------------------------------------
// Type aliases: `type Name = T;` gives a type another NAME.
// It does NOT create a new type: an `Id` IS a `u32`, freely mixed.
// (A brand-new nominal type only comes from `struct` / `enum`.)
// ---------------------------------------------------------------
type Id = u32;
type Names = u8[..16][>..];   // alias for a growable array of short strings

// ---------------------------------------------------------------
// Globals are declared like locals, at the top level.
// A `let`/`const` global with NO written type and a constant initializer
// is a "named constant": it adapts to any integer type, like a literal.
// ---------------------------------------------------------------
let SIZE = 16;                // named constant
var hits: i64 = 0;            // a mutable global (initialized before main runs)

fn main() {
    // ---------------------------------------------------------------
    // let: a binding that cannot be REASSIGNED.
    // The type is inferred from the initializer (here i64, the literal default).
    // ---------------------------------------------------------------
    let answer = 42;
    print("let answer = ", answer);
    // answer = 43;           // ERROR: cannot assign to a `let` binding

    // ---------------------------------------------------------------
    // var: a reassignable variable. The `: type` annotation is optional;
    // the type follows the name (postfix style).
    // ---------------------------------------------------------------
    var count: i32 = 0;       // explicit type i32
    count = 5;                // plain reassignment is fine for `var`
    count += 1;               // compound assignment: 6
    count++;                  // ++ and -- are STATEMENTS, not expressions: 7
    count--;                  // back to 6
    count++;                  // 7
    print("var count = ", count);
    // let y = count++;       // ERROR: `++` is a statement; it has no value
    // print(count++);        // ERROR for the same reason

    // ---------------------------------------------------------------
    // const: no reassignment AND no writes into the contents.
    // `const x = e;` is a `let` whose type is `const T`.
    // ---------------------------------------------------------------
    const limits = [10, 20, 30];
    print("const limits = ", limits);
    // limits[0] = 1;         // ERROR: limits is const (contents are read-only)
    // limits = [1, 2, 3];    // ERROR: and it cannot be reassigned either

    // ---------------------------------------------------------------
    // let only stops reassigning the NAME; contents stay writable
    // (as far as their type allows).
    // ---------------------------------------------------------------
    let xs = [1, 2, 3];
    xs[0] = 9;                // allowed: this writes INTO xs, it does not rebind xs
    print("let xs after xs[0] = 9: ", xs);
    // xs = [4, 5, 6];        // ERROR: that would reassign xs itself

    // ---------------------------------------------------------------
    // The converse: a `var` of a const type can be re-pointed but never
    // written into. A string literal is a `const u8[:]` (read-only view).
    // ---------------------------------------------------------------
    var s: const u8[:] = "text";
    s = s[1..];               // re-point the view: now "ext"
    print("var const view: ", s);
    // s[0] = 'X';            // ERROR: the bytes behind a const view are read-only

    // ---------------------------------------------------------------
    // Deferred let: declare now, assign EXACTLY ONCE later.
    // The compiler checks that every path assigns it once before it is read.
    // ---------------------------------------------------------------
    let n: i64;               // no initializer yet: the type is required here
    if answer > 0 { n = 1; } else { n = 2; }   // each path assigns once
    print("deferred let n = ", n);
    // let m: i64;
    // m = 1; m = 2;          // ERROR: a deferred let may be assigned only once
    // let k: i64;
    // for i in 0..3 { k = i; } // ERROR: assigning inside a loop counts as twice

    // ---------------------------------------------------------------
    // Every local must be initialized on EVERY path before it is read.
    // ---------------------------------------------------------------
    // let u: i64;
    // if answer > 100 { u = 1; }
    // print(u);              // ERROR: u may be read uninitialized (else path)
    let filled = [0; 4];      // fixed arrays must be fully initialized: [v; n] fill helps
    print("fill literal: ", filled);

    // ---------------------------------------------------------------
    // Shadowing: an inner scope may redeclare a name; the outer one
    // comes back when the scope ends.
    // ---------------------------------------------------------------
    let level = 1;
    if true {
        let level = "inner";  // a NEW binding, even with a different type
        print("shadowed level = ", level);
    }
    print("outer level = ", level);

    // ---------------------------------------------------------------
    // `let r .= expr;` binds a REFERENCE instead of copying (see section 13).
    // Writes through r change the original.
    // ---------------------------------------------------------------
    var nums = [1, 2, 3];
    let copy = nums;          // `=` copies the whole array
    let r .= nums;            // `.=` binds a reference to nums
    r[1] = 99;                // writes into nums through the reference
    print("nums = ", nums, ", copy = ", copy, ", r = ", r);
    nums[2] = 7;              // nums is a var: writable
    print("after nums[2] = 7, r = ", r);   // r sees the change: it IS nums

    // ---------------------------------------------------------------
    // Type aliases in use: Id and u32 are the same type.
    // ---------------------------------------------------------------
    let id: Id = 7;
    let plain: u32 = id;      // no cast needed: an alias is not a new type
    var ns: Names = [];
    ns.push("goose");
    print("alias: ", id + plain, " ", ns);

    // ---------------------------------------------------------------
    // Globals and named constants
    // ---------------------------------------------------------------
    let b: u8 = SIZE;         // the named constant adapts to u8, like the literal 16
    hits += 1;                // a `var` global is writable from any function
    bump();
    print("named constant: ", b, ", global hits = ", hits);
}

fn bump() { hits += 1; }      // modifies the global
