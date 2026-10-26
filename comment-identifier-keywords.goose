import std;

// This is a line comment: everything after // to the end of the line is ignored.
fn main() {
    // Identifiers: start with a letter or underscore, then letters, digits, or underscores.
    let my_variable = 10;   // `let` declares an immutable binding; type inferred as an integer
    let _private = 20;      // a leading underscore is allowed
    let value123 = 30;      // digits are allowed after the first character

    // Boolean keywords: `true` and `false`.
    let enabled = true;
    let disabled = false;

    // The `null` keyword is the empty value of an optional type `T?`.
    // `null` alone has no type, so the variable must be annotated.
    let nothing: i32? = null;

    // Integer and floating-point types, written as explicit annotations.
    let a: i32 = 10;        // signed 32-bit integer
    let b: u64 = 100;       // unsigned 64-bit integer
    let c: f64 = 3.14;      // 64-bit floating point
    let flag: bool = true;  // boolean

    // Print the values so the bindings are used.
    print(my_variable, " ", _private, " ", value123);
    print(enabled, " ", disabled);
    print(nothing == null);  // an optional can be compared against null
    print(a, " ", b, " ", c, " ", flag);
}
